//
//  LazyDBObserver.swift
//  SceytChatUIKit
//
//  Created by Sargis Mkhitaryan on 03.06.26.
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation

/// An observer that fronts an `NSFetchedResultsController` with a flat `[Item]` snapshot
/// and a batch-oriented change callback.
///
/// `LazyDBObserver` is positioned alongside ``LazyDatabaseObserver`` and differs from it
/// in two key ways:
///
/// - ``rawItems`` is a fully converted snapshot of *every* row matching the predicate, not
///   a lazily mapped view that resolves rows on demand. The cost is paid up front in the
///   change cycle, then reads are cheap value-type accesses.
/// - Changes arrive batched (``onDidChange`` fires once per FRC cycle with
///   `[DBChangeItem<Item>]`), instead of being recomputed from raw
///   `NSManagedObjectContextObjectsDidChange` notifications.
///
/// ## Threading
///
/// - All Core Data work runs on the context's queue — typically a private background queue
///   passed in at init.
/// - ``onWillChange``, ``onDidChange``, and ``onReset`` are delivered on the **main queue**.
/// - ``rawItems`` blocks the caller with `performAndWait` to read items off the context
///   queue, and returns a value-type copy that is safe to pass across threads.
///
/// ## Lifecycle
///
/// ``startObserving()`` is idempotent — a second call is a no-op until ``stopObserving()``
/// runs. ``restart(predicate:)`` is a single-shot full reload under a new predicate.
open class LazyDBObserver<Item, DTO: NSManagedObject> {

    // MARK: - Public callbacks

    /// Fires on the main queue when the underlying FRC reports that its content is about
    /// to change.
    ///
    /// During this callback, reads of ``rawItems`` return the *previous* snapshot rather
    /// than the in-flight one — consumers can use this to capture pre-change UI state
    /// (e.g. animation source frames). The "previous snapshot" behaviour is only active
    /// for the duration of this callback.
    public var onWillChange: (() -> Void)?

    /// Fires on the main queue once per FRC change cycle, after the snapshot has been
    /// rebuilt.
    ///
    /// The array describes the cycle's structural changes (`.insert`, `.update`, `.move`,
    /// `.delete`) already translated from DTOs into `Item`. Consumers can apply the
    /// changes directly, or ignore them and re-read ``rawItems`` for a fresh snapshot.
    public var onDidChange: (([DBChangeItem<Item>]) -> Void)?

    /// Fires on the main queue after ``restart(predicate:)`` has swapped the predicate
    /// and rebuilt the snapshot.
    ///
    /// Consumers should treat this as a full reload — discard any cached previous state
    /// and re-read ``rawItems``. Granular ``onDidChange`` callbacks are *not* emitted for
    /// the restart's transition; this single signal stands in for them.
    public var onReset: (() -> Void)?

    // MARK: - Configuration

    /// Converts a DTO into the consumer's `Item`. Invoked on the FRC's context queue.
    private let itemCreator: (DTO) throws -> Item

    /// Optional pair of string keypaths used by ``DatabaseItemConverter`` to reuse
    /// already-converted `Item` values across change cycles instead of running
    /// ``itemCreator`` again for unchanged rows.
    private let itemReuseKeyPaths: (item: KeyPath<Item, String>, dto: KeyPath<DTO, String>)?

    /// Optional post-fetch sort applied after DTO→`Item` conversion. Empty when the FRC's
    /// own `sortDescriptors` already produce the desired order.
    private let sorting: [SortValue<Item>]

    // MARK: - Collaborators

    /// The underlying fetched results controller. Exposed for diagnostics and tests; do
    /// not mutate from outside the observer.
    public private(set) var frc: NSFetchedResultsController<DTO>

    /// The FRC delegate that buffers per-row callbacks and emits them as a converted
    /// `[DBChangeItem<Item>]` batch per cycle.
    let changeRelay: ChangeRelay<DTO, Item>

    /// Observes context changes for the relationship keypaths supplied at init and
    /// refreshes affected fetched rows so the FRC reports them as `.update`s. `nil` when
    /// no relationship keypaths were requested.
    ///
    /// `NSFetchedResultsController` only reports a row when the fetched entity's *own*
    /// attributes change; a change confined to a *related* object (e.g. the last
    /// message's `deliveryStatus`) leaves the parent `DTO` untouched, so the FRC stays
    /// silent and the row's snapshot goes stale until the next fetch. This observer
    /// closes that gap by re-faulting the parent rows whose tracked relationships changed.
    private var relationshipKeyPathsObserver: RelationshipKeyPathsObserver<DTO>?

    // MARK: - Internal state

    /// Serial queue guarding the will-change snapshot fields and the start-guard flag.
    private let queue = DispatchQueue(label: "com.sceyt.uikit.lazy-db-observer", qos: .userInitiated)

    /// The current cached snapshot. Mutated on the FRC's context queue and read by
    /// ``rawItems`` under `performAndWait`.
    private var _items: [Item]?

    /// Snapshot captured at `controllerWillChangeContent` so ``rawItems`` can serve the
    /// previous list during the ``onWillChange`` callback.
    private var _willChangeItems: [Item]?

    /// `true` while ``onWillChange`` is on the call stack; gates ``rawItems`` to read
    /// from ``_willChangeItems`` instead of ``_items``.
    private var _notifyingWillChange = false

    /// The current snapshot of converted items.
    ///
    /// During the ``onWillChange`` callback this returns the *previous* snapshot, so
    /// consumers can capture pre-change state. Outside that callback it returns the
    /// post-change snapshot.
    ///
    /// Reading blocks briefly on the FRC's context queue via `performAndWait` so the
    /// values are read safely off the context. The returned array is a value-type copy
    /// that can be passed across threads.
    public var rawItems: [Item] {
        if onWillChange != nil {
            let willChangeState: (active: Bool, cachedItems: [Item]?) = queue.sync { (_notifyingWillChange, _willChangeItems) }
            if willChangeState.active {
                return willChangeState.cachedItems ?? []
            }
        }

        var rawItems: [Item]!
        frc.managedObjectContext.performAndWait {
            rawItems = _items ?? updateItems(nil)
        }
        return rawItems
    }

    /// Backing storage for ``isInitialized``. Mutated only via the serial ``queue``.
    private var _isInitialized: Bool = false

    /// Thread-safe view of the start guard. Reads and writes are serialised on ``queue``
    /// so concurrent ``startObserving()`` calls collapse to one fetch.
    private var isInitialized: Bool {
        get { queue.sync { _isInitialized } }
        set { queue.sync { _isInitialized = newValue } }
    }

    // MARK: - Init

    /// Creates a new observer.
    ///
    /// No callbacks fire until you call ``startObserving()``.
    ///
    /// - Important: The provided `fetchRequest` **must** declare at least one
    ///   `NSSortDescriptor`. `NSFetchedResultsController` asserts otherwise.
    ///
    /// - Parameters:
    ///   - context: The managed object context the FRC observes. Pass a private-queue
    ///     background context for production use; tests can use a stable
    ///     `newBackgroundContext()` from the persistent container.
    ///   - fetchRequest: Describes the rows to track. Its `sortDescriptors` determine
    ///     row order; `predicate` determines membership.
    ///   - itemCreator: Converts a DTO into the consumer's `Item`. Called on the
    ///     context's queue; should not perform Core Data work outside that scope.
    ///   - itemReuseKeyPaths: Optional pair of string keypaths used by
    ///     ``DatabaseItemConverter`` to reuse already-converted `Item`s across cycles.
    ///     Pass `nil` to re-run `itemCreator` for every row every cycle.
    ///   - sorting: Optional post-fetch sort applied after DTO→`Item` conversion. Use
    ///     this when the desired order can only be expressed against the `Item` value;
    ///     prefer `fetchRequest.sortDescriptors` for sortable DTO attributes.
    ///   - relationshipKeyPaths: Optional set of `to-one` relationship keypaths (e.g.
    ///     `"lastMessage.deliveryStatus"`) whose changes should also surface as row
    ///     updates. Without this, the FRC ignores changes confined to a related object
    ///     and the row's snapshot goes stale until the next fetch. Pass `nil` (the
    ///     default) when every display-relevant value lives on the `DTO` itself.
    ///   - fetchedResultsControllerType: Override hook for tests that need to inject a
    ///     subclass (e.g. one that stubs `performFetch()` or `fetchedObjects`).
    ///     Defaults to the standard `NSFetchedResultsController`.
    public init(
        context: NSManagedObjectContext,
        fetchRequest: NSFetchRequest<DTO>,
        itemCreator: @escaping (DTO) throws -> Item,
        itemReuseKeyPaths: (item: KeyPath<Item, String>, dto: KeyPath<DTO, String>)? = nil,
        sorting: [SortValue<Item>] = [],
        relationshipKeyPaths: Set<String>? = nil,
        fetchedResultsControllerType: NSFetchedResultsController<DTO>.Type = NSFetchedResultsController<DTO>.self
    ) {
        self.itemCreator = itemCreator
        self.itemReuseKeyPaths = itemReuseKeyPaths
        self.sorting = sorting
        changeRelay = ChangeRelay<DTO, Item>(itemCreator: itemCreator)
        frc = fetchedResultsControllerType.init(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        if let relationshipKeyPaths, !relationshipKeyPaths.isEmpty {
            relationshipKeyPathsObserver = RelationshipKeyPathsObserver(
                keyPaths: relationshipKeyPaths,
                fetchedResultsController: frc
            )
        }
        changeRelay.onWillChange = { [weak self] in
            self?.notifyWillChange()
        }
        changeRelay.onDidChange = { [weak self] changes in
            guard let self else { return }
            self.updateItems(changes)
            self.notifyDidChange(changes: changes)
        }
    }

    // MARK: - Lifecycle

    /// Performs the initial fetch and starts forwarding subsequent changes to
    /// ``onDidChange``.
    ///
    /// Idempotent: a second call before ``stopObserving()`` is a no-op. The initial
    /// snapshot is delivered as a single ``onDidChange`` cycle of `.insert` changes
    /// after the fetch completes on the context queue.
    ///
    /// - Throws: Whatever `NSFetchedResultsController.performFetch()` throws.
    public func startObserving() throws {
        guard !isInitialized else { return }
        isInitialized = true

        do {
            try frc.performFetch()
        } catch {
            logger.error("LazyDBObserver failed to start observing: \(error)")
            throw error
        }

        frc.delegate = changeRelay

        frc.managedObjectContext.perform { [weak self] in
            guard let self else { return }
            let items = self.updateItems(nil)
            let changes: [DBChangeItem<Item>] = items.enumerated().map { .insert($1, IndexPath(item: $0, section: 0)) }
            self.notifyDidChange(changes: changes)
        }
    }

    /// Detaches the FRC delegate, clears the cached snapshot, and resets the start
    /// guard.
    ///
    /// After this call, ``startObserving()`` can be invoked again to resume — useful
    /// for "delete everything and resync" flows.
    public func stopObserving() {
        frc.delegate = nil
        isInitialized = false
        frc.managedObjectContext.perform { [weak self] in
            self?._items = nil
        }
    }

    /// Re-runs the fetch with a new predicate and fires ``onReset`` once the snapshot
    /// has been rebuilt.
    ///
    /// Use this for search restarts and similar "scope changes" — the observer remains
    /// the same instance, but tracks a different slice of the database. Granular
    /// ``onDidChange`` callbacks are *not* emitted for the transition; ``onReset`` is
    /// the single signal that stands in for them.
    ///
    /// - Parameter predicate: The new fetch predicate, replacing the one set at init.
    public func restart(predicate: NSPredicate) {
        frc.managedObjectContext.perform { [weak self] in
            guard let self else { return }
            self.frc.fetchRequest.predicate = predicate
            do {
                try self.frc.performFetch()
            } catch {
                logger.error("LazyDBObserver restart performFetch failed: \(error)")
                return
            }
            if self.frc.delegate !== self.changeRelay {
                self.frc.delegate = self.changeRelay
            }
            self.isInitialized = true
            self._items = nil
            _ = self.updateItems(nil)

            DispatchQueue.main.async { [weak self] in
                self?.onReset?()
            }
        }
    }

    // MARK: - Private

    /// Caches the current snapshot as ``_willChangeItems`` and dispatches the public
    /// ``onWillChange`` callback to the main queue with the cache flag flipped on, so
    /// that reads of ``rawItems`` during the callback return the previous snapshot.
    private func notifyWillChange() {
        guard let onWillChange = onWillChange else { return }
        queue.sync {
            _willChangeItems = _items
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queue.async {
                self._notifyingWillChange = true
            }
            onWillChange()
            self.queue.async {
                self._willChangeItems = nil
                self._notifyingWillChange = false
            }
        }
    }

    /// Forwards the converted change list to the public ``onDidChange`` callback on
    /// the main queue.
    private func notifyDidChange(changes: [DBChangeItem<Item>]) {
        guard let onDidChange = onDidChange else { return }
        DispatchQueue.main.async {
            onDidChange(changes)
        }
    }

    /// Recomputes the local snapshot from the FRC's fetched objects via
    /// ``DatabaseItemConverter`` and writes it to ``_items``. Called on the context
    /// queue after each change cycle (and once at start).
    ///
    /// - Parameter changes: The cycle's change list. Used by the converter when
    ///   ``itemReuseKeyPaths`` is set, to thread newly converted items through the
    ///   reuse lookup. Pass `nil` for the initial fetch.
    /// - Returns: The newly written snapshot.
    @discardableResult
    private func updateItems(_ changes: [DBChangeItem<Item>]?) -> [Item] {
        let items = DatabaseItemConverter.convert(
            dtos: frc.fetchedObjects ?? [],
            existing: _items ?? [],
            changes: changes,
            itemCreator: itemCreator,
            itemReuseKeyPaths: itemReuseKeyPaths,
            sorting: sorting
        )
        _items = items
        return items
    }
}

/// FRC delegate that buffers changes per cycle and emits `[DBChangeItem<Item>]` once the cycle ends.
/// DTO → Item conversion happens in `controllerDidChangeContent` to avoid recursive FRC calls during conversion.
class ChangeRelay<DTO: NSManagedObject, Item>: NSObject, NSFetchedResultsControllerDelegate {
    let itemCreator: (DTO) throws -> Item

    var onWillChange: (() -> Void)?
    var onDidChange: (([DBChangeItem<Item>]) -> Void)?

    private var currentChanges: [DBChangeItem<DTO>] = []

    init(itemCreator: @escaping (DTO) throws -> Item) {
        self.itemCreator = itemCreator
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        onWillChange?()
        currentChanges = []
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        guard let dto = anObject as? DTO else {
            logger.debug("Skipping the update from DB because the DTO has invalid type: \(anObject)")
            return
        }

        switch type {
        case .insert:
            guard let index = newIndexPath else {
                logger.warn("Skipping the update from DB because `newIndexPath` is missing for `.insert` change.")
                return
            }
            currentChanges.append(.insert(dto, index))

        case .move:
            guard let fromIndex = indexPath, let toIndex = newIndexPath else {
                logger.warn("Skipping the update from DB because `indexPath` or `newIndexPath` are missing for `.move` change.")
                return
            }
            currentChanges.append(.move(dto, fromIndex, toIndex))

        case .update:
            guard let index = indexPath else {
                logger.warn("Skipping the update from DB because `indexPath` is missing for `.update` change.")
                return
            }
            currentChanges.append(.update(dto, index))

        case .delete:
            guard let index = indexPath else {
                logger.warn("Skipping the update from DB because `indexPath` is missing for `.delete` change.")
                return
            }
            currentChanges.append(.delete(dto, index))

        default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let itemChanges = currentChanges.compactMap { dtoChange -> DBChangeItem<Item>? in
            do {
                switch dtoChange {
                case .update(let dto, let indexPath):
                    return try .update(itemCreator(dto), indexPath)
                case .insert(let dto, let indexPath):
                    return try .insert(itemCreator(dto), indexPath)
                case .move(let dto, let fromIndex, let toIndex):
                    return try .move(itemCreator(dto), fromIndex, toIndex)
                case .delete(let dto, let indexPath):
                    return try .delete(itemCreator(dto), indexPath)
                }
            } catch {
                logger.debug("Skipping the update from DB because the DTO can't be converted to the model object: \(error)")
                return nil
            }
        }
        onDidChange?(itemChanges)
        currentChanges.removeAll()
    }
}
