//
//  MediaPickerViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import PhotosUI
import UIKit

open class MediaPickerViewController: ViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegate
{
    private let imageManager = PHCachingImageManager()

    @available(*, deprecated, message: "Pagination was removed — PHFetchResult is already lazy and faults assets in on demand. This value is unused.")
    public static let pageSize = 100

    public var onSelected: (([PHAsset], MediaPickerViewController) -> Bool)?
    /// Every asset the picker considers selected: `preSelectedIdentifiers` ∪ the ones tapped
    /// in this session. Drives the selected count, the selection limit and the checkmarks.
    private var selectedIdentifiers = Set<String>()
    private var preSelectedIdentifiers = Set<String>()
    /// Identifiers tapped *in this session*, in tap order — the assets handed to `onSelected`.
    /// Pre-selected ones are deliberately absent: they are already in the composer, and
    /// returning them again would attach duplicates.
    ///
    /// Keyed by `localIdentifier` rather than `IndexPath` because index paths go stale across
    /// any reload — a photo-library change used to shift them and hand back the *wrong* assets.
    private var selectedIdentifierOrder = [String]()
    private var attachmentSelectionLimit = SceytChatUIKit.shared.config.attachmentSelectionLimit

    /// How many items the collection view is actually showing, as of the last applied update.
    ///
    /// `collectionView.numberOfItems(inSection:)` cannot be trusted for this: `reloadData()` is
    /// lazy, so between a `reloadData()` and the next layout pass UIKit still reports the
    /// *pre-reload* count. Incremental updates computed against that stale number are what
    /// aborted `performBatchUpdates` in production. Tracked explicitly instead, and every
    /// incremental update validates against it before it is applied.
    private var appliedItemCount = 0
    
    open lazy var collectionView = Components.mediaPickerCollectionView
        .init()
        .withoutAutoresizingMask
 
    open lazy var footerView = Components.mediaPickerFooterView.init()
        .withoutAutoresizingMask
    
    open var collectionViewLayout: MediaPickerCollectionViewLayout? {
        collectionView.collectionViewLayout as? MediaPickerCollectionViewLayout
    }

    public var allowsMultipleSelection = true {
        didSet {
            collectionView.allowsMultipleSelection = allowsMultipleSelection
        }
    }
    
    public var allowedMediaTypes: Set<PHAssetMediaType>? {
        didSet {
            updateFetchOptionPredicate()
        }
    }
    
    public var allowedMediaSubtypes: PHAssetMediaSubtype? {
        didSet {
            updateFetchOptionPredicate()
        }
    }
    
    open lazy var fetchOptions: PHFetchOptions = {
        $0.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return $0
    }(PHFetchOptions())
    
    public private(set) var assets: PHFetchResult<PHAsset> = PHFetchResult()
    
    /// Passthrough to `fetchOptions.fetchLimit`. The picker no longer paginates — it fetches the
    /// whole library and lets `PHFetchResult` fault assets in on demand — so this is `0`
    /// (unlimited) unless a host deliberately caps it.
    public var fetchLimit: Int {
        get {
            return fetchOptions.fetchLimit
        }
        set {
            fetchOptions.fetchLimit = newValue
        }
    }
    
    public required init(selectedAssetIdentifiers: Set<String>? = nil, attachmentSelectionLimit: Int) {
        super.init(nibName: nil, bundle: nil)
        if let selectedAssetIdentifiers {
            self.attachmentSelectionLimit = attachmentSelectionLimit
            preSelectedIdentifiers = selectedAssetIdentifiers
            selectedIdentifiers = selectedAssetIdentifiers
            footerView.selectedCount = selectedAssetIdentifiers.count
        }
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override open func setup() {
        super.setup()
        
        collectionView.allowsMultipleSelection = allowsMultipleSelection
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionViewLayout?.minimumInteritemSpacing = 2
        collectionViewLayout?.minimumLineSpacing = 2
        collectionView.register(Components.mediaPickerCell.self)
        collectionView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.MediaPicker.collectionView

        navigationItem.leftBarButtonItem =
            UIBarButtonItem(
                title: L10n.Alert.Button.cancel,
                style: .done,
                target: self,
                action: #selector(cancelAction(_:))
            )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.MediaPicker.cancelButton
        footerView.attachButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.MediaPicker.attachButton
        footerView.attachButton.addTarget(self, action: #selector(attachButtonAction(_:)), for: .touchUpInside)
        
        resetCachedAssets()
        PHPhotoLibrary.shared().register(self)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        title = appearance.titleText
        
        view.backgroundColor = appearance.backgroundColor
        collectionView.backgroundColor = .clear
        footerView.appearance = appearance
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(collectionView)
        view.addSubview(footerView)
        
        collectionView.pin(to: view, anchors: [.leading, .trailing])
        collectionView.topAnchor.pin(to: view.safeAreaLayoutGuide.topAnchor)
        collectionView.bottomAnchor.pin(to: footerView.topAnchor)
        footerView.pin(to: view, anchors: [.leading, .trailing])
        footerView.bottomAnchor.pin(to: view.safeAreaLayoutGuide.bottomAnchor)
    }
    
    override open func setupDone() {
        super.setupDone()
        
        requestPhotoAccessIfNeeded(photoAuthorizationStatus)
        updateManageAccessView()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionViewLayout?.itemSize = itemSize()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func updateUI(for status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            fetchAssets()
        case .limited:
            fetchAssets()
        case .restricted, .denied:
            collectionView.delegate = nil
            collectionView.dataSource = nil
        case .notDetermined:
            break

        @unknown default:
            break
        }
    }

    @objc
    open func cancelAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @objc
    open func attachButtonAction(_ sender: AttachButton) {
        loader.isLoading = true
        // Resolved by identifier, so assets scrolled out of — or filtered out of — the current
        // fetch result still come back, and a library change can never substitute a different
        // photo for one the user actually tapped.
        let selectedAssets = resolveAssets(for: selectedIdentifierOrder)
        let shouldDismiss = onSelected?(selectedAssets, self)
        if shouldDismiss != false {
            dismiss(animated: true)
        }
    }
    
    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        loader.isLoading = false
        super.dismiss(animated: flag, completion: completion)
    }
    
    // MARK: Asset Caching
    
    fileprivate func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }
    
    fileprivate func updateCachedAssets() {
        // Update only if the view is visible.
        guard isViewLoaded && view.window != nil else { return }
        
        // The preheat window is twice the height of the visible rect.
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        
        // Compute the assets to start caching and to stop caching.
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in assets.object(at: indexPath.item) }
        let removedAssets = removedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in assets.object(at: indexPath.item) }
        
        // Update the assets the PHCachingImageManager is caching.
        imageManager.startCachingImages(for: addedAssets,
                                        targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        
        // Store the preheat rect to compare against in the future.
        previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
    
    // MARK: CollectionViewDataSource

    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            for: indexPath,
            cellType: Components.mediaPickerCell.self
        )
        cell.data = (imageManager, assets.object(at: indexPath.item), thumbnailSize)
        return cell
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        assets.count
    }
    
    open func itemSize() -> CGSize {
        let space = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? 0
        let sectionInset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let width = collectionView.bounds.width - sectionInset.left - sectionInset.right
        let height = collectionView.bounds.height - sectionInset.top - sectionInset.bottom
        let perLineCount: CGFloat = height > width ? 3 : 5
        let size = Int((width - space * (perLineCount - 1)) / perLineCount)
        return .init(width: size, height: size)
    }
    
    var thumbnailSize: CGSize {
        let itemSize = itemSize()
        return .init(width: itemSize.width * UIScreen.main.traitCollection.displayScale, height: itemSize.height * UIScreen.main.traitCollection.displayScale)
    }
    
    fileprivate var previousPreheatRect = CGRect.zero
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        guard let cell = collectionView.cell(for: indexPath, cellType: Components.mediaPickerCell.self),
              cell.imageView.image != nil
        else { return false }
        guard attachmentSelectionLimit > 0
        else { return true }
        guard attachmentSelectionLimit > selectedIdentifiers.count
        else {
            showAlert(message: L10n.Error.maxValueItems(attachmentSelectionLimit))
            return false
        }
        if indexPath.item < assets.count,
           preSelectedIdentifiers.contains(assets[indexPath.item].localIdentifier)
        {
            return false
        }
        
        return true
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            let identifier = assets[indexPath.item].localIdentifier
            selectedIdentifiers.insert(identifier)
            // A `reloadData()` clears the collection view's own selection while `willDisplay`
            // keeps drawing the checkmark from `selectedIdentifiers`, so the same cell can be
            // "selected" twice. Appending unconditionally would attach it twice as well.
            if !selectedIdentifierOrder.contains(identifier) {
                selectedIdentifierOrder.append(identifier)
            }
        }
        footerView.selectedCount = selectedIdentifiers.count
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        didDeselectItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            let identifier = assets[indexPath.item].localIdentifier
            selectedIdentifiers.remove(identifier)
            selectedIdentifierOrder.removeAll(where: { $0 == identifier })
        }
        footerView.selectedCount = selectedIdentifiers.count
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            let isSelected = selectedIdentifiers.contains(assets[indexPath.item].localIdentifier)
            if cell.isSelected != isSelected {
                cell.isSelected = isSelected
            }
        } else if cell.isSelected {
            cell.isSelected = false
        }
    }
    
    @objc open func onTapManageAccess(_ sender: UIBarButtonItem) {
        if #available(iOS 14, *) {
            var actions = [SheetAction]()
            actions.append(.init(title: L10n.ImagePicker.ManageAccess.more, style: .default, handler: {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            }))
            actions.append(.init(title: L10n.ImagePicker.ManageAccess.change, style: .default, handler: {
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                UIApplication.shared.open(settingsUrl)
            }))
            showBottomSheet(actions: actions, withCancel: true)
        }
    }
}

private extension MediaPickerViewController {
    var photoAuthorizationStatus: PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            return PHPhotoLibrary.authorizationStatus()
        }
    }

    func requestPhotoAccessIfNeeded(_ status: PHAuthorizationStatus) {
        guard status != .authorized else { return updateUI(for: status) }
        PHPhotoLibrary.requestAuthorization { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.fetchAssets()
                self.updateManageAccessView()
            }
        }
    }
    
    func updateManageAccessView() {
        if #available(iOS 14, *) {
            if photoAuthorizationStatus == .limited {
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: L10n.ImagePicker.ManageAccess.action,
                    style: .done,
                    target: self,
                    action: #selector(onTapManageAccess)
                )
            } else {
                navigationItem.rightBarButtonItem = nil
            }
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    /// Re-fetches the whole library from scratch and reloads. `PHFetchOptions.fetchLimit` is
    /// left alone: the picker does not paginate, so the fetch result covers every matching
    /// asset and `PHFetchResult` faults them in as the grid scrolls.
    func fetchAssets() {
        assets = PHAsset.fetchAssets(with: fetchOptions)
        reloadCollectionView()
    }

    /// The single reload entry point — keeps `appliedItemCount` and the selection in step with
    /// whatever `assets` now holds.
    func reloadCollectionView() {
        collectionView.reloadData()
        appliedItemCount = assets.count
        reapplySelection()
        resetCachedAssets()
    }

    /// Maps identifiers back to assets, preserving the order they were given in.
    ///
    /// `fetchAssets(withLocalIdentifiers:options:)` deliberately passes no options: this is an
    /// identity lookup, so the picker's predicate and sort must not filter or reorder it.
    func resolveAssets(for identifiers: [String]) -> [PHAsset] {
        guard !identifiers.isEmpty else { return [] }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var byIdentifier = [String: PHAsset](minimumCapacity: fetched.count)
        fetched.enumerateObjects { asset, _, _ in
            byIdentifier[asset.localIdentifier] = asset
        }
        return identifiers.compactMap { byIdentifier[$0] }
    }

    /// Restores the collection view's selection after a `reloadData()`, which clears it.
    ///
    /// Resolves by identifier rather than walking `assets` — that is now the entire library, so
    /// an enumeration would be O(library). Assets that no longer resolve have been deleted from
    /// the library and are dropped from the selection; previously they produced an
    /// `IndexPath(item: NSNotFound)`.
    func reapplySelection() {
        guard !selectedIdentifiers.isEmpty else { return }

        let resolved = resolveAssets(for: Array(selectedIdentifiers))
        let existing = Set(resolved.map { $0.localIdentifier })
        if existing.count != selectedIdentifiers.count {
            selectedIdentifiers.formIntersection(existing)
            preSelectedIdentifiers.formIntersection(existing)
            selectedIdentifierOrder.removeAll { !existing.contains($0) }
            footerView.selectedCount = selectedIdentifiers.count
        }

        for asset in resolved {
            let index = assets.index(of: asset)
            guard index != NSNotFound else { continue }
            collectionView.selectItem(
                at: IndexPath(item: index, section: 0),
                animated: false,
                scrollPosition: []
            )
        }
    }
    
    func updateFetchOptionPredicate() {
        var predicates: [NSPredicate] = []
        if let allowedMediaTypes = allowedMediaTypes {
            let mediaTypePredicates = allowedMediaTypes.map { NSPredicate(format: "mediaType = %d", $0.rawValue) }
            predicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates: mediaTypePredicates)
            )
        }
        
        if let allowedMediaSubtypes = allowedMediaSubtypes {
            predicates.append(
                NSPredicate(format: "(mediaSubtype & %d) == 0", allowedMediaSubtypes.rawValue)
            )
        }
        
        if predicates.count > 0 {
            fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else {
            fetchOptions.predicate = nil
        }
        fetchAssets()
    }
    
    /// Applies a photo-library change to the grid.
    func apply(_ changes: PHFetchResultChangeDetails<PHAsset>) {
        // `updateUI(for:)` detaches the data source when photo access is revoked. Anything
        // applied now would be a batch update against a view with no data source; restoring
        // access goes back through `fetchAssets()`, which re-syncs everything from scratch.
        guard collectionView.dataSource != nil else { return }

        assets = changes.fetchResultAfterChanges

        // The incremental indexes are only meaningful if the collection view is really showing
        // `fetchResultBeforeChanges`. A `reloadData()` from `fetchAssets()` earlier in this same
        // run-loop turn has not been laid out yet, so UIKit's cached count is still the
        // pre-reload one — applying a diff on top of that is exactly what aborted
        // `performBatchUpdates` in production. `appliedItemCount` catches that; moves are sat
        // out because the sort is stable enough that they are rare, and a reload is correct.
        guard changes.hasIncrementalChanges,
              !changes.hasMoves,
              changes.fetchResultBeforeChanges.count == appliedItemCount
        else {
            reloadCollectionView()
            return
        }

        let removed = (changes.removedIndexes ?? []).map { IndexPath(item: $0, section: 0) }
        let inserted = (changes.insertedIndexes ?? []).map { IndexPath(item: $0, section: 0) }
        // Captured as assets, not indexes: `changedIndexes` is in pre-change coordinates, and
        // reloading in the same batch as inserts/deletes (UIKit implements a reload as a
        // delete + insert) is a well-known way to trip the same assertion. Resolved back to
        // post-change index paths and reloaded once the batch has landed.
        let changedAssets = (changes.changedIndexes ?? []).map {
            changes.fetchResultBeforeChanges.object(at: $0)
        }

        guard !removed.isEmpty || !inserted.isEmpty || !changedAssets.isEmpty else {
            appliedItemCount = assets.count
            return
        }

        collectionView.performBatchUpdates {
            if !removed.isEmpty {
                collectionView.deleteItems(at: removed)
            }
            if !inserted.isEmpty {
                collectionView.insertItems(at: inserted)
            }
        } completion: { [weak self] _ in
            guard let self, !changedAssets.isEmpty else { return }
            let changedPaths = changedAssets.compactMap { asset -> IndexPath? in
                let index = self.assets.index(of: asset)
                return index == NSNotFound ? nil : IndexPath(item: index, section: 0)
            }
            guard !changedPaths.isEmpty else { return }
            self.collectionView.reloadItems(at: changedPaths)
        }
        appliedItemCount = assets.count

        reapplySelection()
        resetCachedAssets()
    }
}

extension MediaPickerViewController: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Delivered on an arbitrary serial queue, so the diff is deferred to main rather than
        // computed here: `assets` is main-thread state, and reading it on Photos' queue races
        // `apply(_:)` and `fetchAssets()` writing it. `PHChange` is an immutable snapshot and the
        // block retains it, so deferring costs nothing.
        //
        // Diffing on main also means `fetchResultBeforeChanges` is, by construction, the fetch
        // result the picker is actually displaying — so `apply(_:)`'s `appliedItemCount` check
        // passes in the normal case and the change lands as an incremental update rather than
        // degrading to a full reload.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let changes = changeInstance.changeDetails(for: self.assets)
            else { return }
            self.apply(changes)
        }
    }
}

private extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect) ?? []
        return allLayoutAttributes.map { $0.indexPath }
    }
}
