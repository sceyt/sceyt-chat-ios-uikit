//
//  PinnedMessageConcurrencyTests.swift
//  SceytChatUIKitTests
//
//  Hammers the pinned-message state from several Core Data contexts at once.
//
//  Pinned messages are written from more places than most tables: the user tapping Pin, the
//  provider's confirm after the server acks, `didPinMessages` / `didUnpinMessages` from another
//  device, every message write via `syncPin` + `applyPinDetails`, and the channel-open sweep's
//  pages and reconcile. Several of those can land in the same instant on different contexts.
//
//  Two things are asserted throughout:
//
//  1. **No crash and no duplicate rows.** The table has a `(messageTid, channelId)` uniqueness
//     constraint, and `fetchOrCreate` collapses concurrent inserts by hand rather than leaning
//     on the constraint — because a constraint violation aborts the whole transaction, taking
//     unrelated writes down with it.
//  2. **The two sides never drift.** `PinnedMessageDTO` and the `MessageDTO.pinDetails` mirror
//     are written in the same transaction, so for any message with a local row the two must
//     agree once the dust settles. `assertPinStateIsConsistent` is that invariant.
//
//  Deliberately uses `container.newBackgroundContext()` directly rather than `MockDatabase.write`,
//  which funnels every write through one serial context and so cannot race at all.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

private typealias PinScope = PinnedMessageScope

final class PinnedMessageConcurrencyTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var originalDatabase: Database!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    /// Every context these tests make, retained until `tearDown`.
    ///
    /// Releasing a background context while Core Data still has an async reference callback
    /// registered for it corrupts its object registry — `_PFManagedObjectReferenceQueue` frees a
    /// pointer it does not own and the process aborts. Creating and dropping dozens of contexts
    /// per test hits that reliably. It is a harness hazard, not a product one (the app has a
    /// fixed set of contexts), so the harness simply keeps them alive.
    private var liveContexts = [NSManagedObjectContext]()

    private let channelId: ChannelId = 55
    /// Enough contention to shake out an ordering bug without making the suite slow.
    private let iterations = 40

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        originalDatabase = DataProvider.database
        DataProvider.database = mockDB
        seedChannel(id: channelId)
    }

    override func tearDown() {
        SyncService.cancelAllPinSyncs()
        DataProvider.database = originalDatabase
        // `reset()` before releasing them: dropping a context that still has objects registered
        // leaves Core Data's async reference queue to `_forgetObject:` them later, against memory
        // the context no longer owns. That is the SIGSEGV this whole arrangement avoids.
        liveContexts.forEach { context in
            context.performAndWait { context.reset() }
        }
        liveContexts.removeAll()
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func seedChannel(id: ChannelId) -> ChannelDTO {
        let (channel, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        try? ctx.save()
        return channel
    }

    @discardableResult
    private func seedMessage(id: MessageId, channelId: ChannelId) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: id, tid: Int64(id), channelId: Int64(channelId), context: ctx)
        message.id = Int64(id)
        message.tid = Int64(id)
        message.channelId = Int64(channelId)
        message.body = "message \(id)"
        message.type = "text"
        message.createdAt = Date(timeIntervalSince1970: 1_000 + Double(id)).bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    /// Runs `work` on `count` separate background contexts at the same time and waits for all
    /// of them. A save conflict is reported rather than swallowed — that is a finding, not noise.
    private func concurrently(
        _ count: Int,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ work: @escaping (Int, NSManagedObjectContext) -> Void
    ) {
        // A fixed pool rather than a context per work item: `performAndWait` serializes within a
        // context, so eight of them still give eight-way parallelism — which is what these tests
        // are about — without the context churn that trips Core Data's reference queue.
        let poolSize = max(1, min(count, 8))
        let pool = (0 ..< poolSize).map { _ in freshContext() }

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "pin.concurrency", attributes: .concurrent)
        let failures = NSMutableArray()
        let lock = NSLock()

        for index in 0 ..< count {
            group.enter()
            queue.async {
                let context = pool[index % poolSize]
                context.performAndWait {
                    work(index, context)
                    do {
                        if context.hasChanges { try context.save() }
                    } catch {
                        lock.lock()
                        failures.add("\(error)")
                        lock.unlock()
                    }
                }
                group.leave()
            }
        }

        awaitGroup(group, description: "concurrent pin writes", file: file, line: line)
        XCTAssertEqual(failures.count, 0,
                       "concurrent writes must not fail to save: \(failures)", file: file, line: line)
        ctx.refreshAllObjects()
    }

    /// Waits for `group` **without blocking the main thread**.
    ///
    /// `DispatchGroup.wait` on the main thread is a deadlock here: `Database` delivers its write
    /// completions on the main queue, so anything that pins on a database write would never
    /// finish. `wait(for:)` pumps the runloop instead.
    private func awaitGroup(
        _ group: DispatchGroup,
        description: String,
        timeout: TimeInterval = 60,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let done = expectation(description: description)
        group.notify(queue: .global()) { done.fulfill() }
        let result = XCTWaiter.wait(for: [done], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(description) never finished", file: file, line: line)
    }

    /// Creates a background context and keeps it alive for the test. Call sparingly — see
    /// `liveContexts`.
    private func freshContext() -> NSManagedObjectContext {
        let context = mockDB.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        liveContexts.append(context)
        return context
    }

    private lazy var readContext: NSManagedObjectContext = freshContext()
    private lazy var repairContext: NSManagedObjectContext = freshContext()

    /// A context that reads **committed** state.
    ///
    /// The assertions below must not go through `viewContext`: these tests save from sibling
    /// background contexts, and a sibling's save is not merged into an already-faulted to-one
    /// relationship — so `message.pinDetails` reads a stale nil even though the store has the
    /// row. `reset()` drops everything this context has registered, so the next fetch comes from
    /// the store.
    ///
    /// One reused context rather than a fresh one per assertion: churning contexts is what
    /// corrupts Core Data's reference queue.
    private func committedContext() -> NSManagedObjectContext {
        readContext.performAndWait { readContext.reset() }
        return readContext
    }

    /// Runs `count` writes through `Database.write` — the path every pin write in the module
    /// actually takes — and waits without blocking the main thread.
    ///
    /// `Database.write` funnels onto a single serial context, so this is the *real* production
    /// concurrency: many callers, one writer. `concurrently(_:)` above is the harsher case of
    /// genuinely parallel contexts, which only the `performWriteTask` sweeps and a host writing
    /// pins itself can produce.
    private func throughDatabaseWrite(
        _ count: Int,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ work: @escaping (Int, NSManagedObjectContext) -> Void
    ) {
        let group = DispatchGroup()
        for index in 0 ..< count {
            group.enter()
            DispatchQueue.global().async {
                self.mockDB.write({ context in work(index, context) }, completion: { _ in
                    group.leave()
                })
            }
        }
        awaitGroup(group, description: "serialized pin writes", file: file, line: line)
    }

    /// Applies the repair every `reconcilePins` applies, so a test can assert the state the user
    /// actually sees once the channel has been opened.
    ///
    /// Runs on a fresh context and fails loudly if the save does not go through: a repair that
    /// silently rolled back would make the convergence assertions below meaningless.
    @discardableResult
    private func runReconcileRepair(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Int {
        let context = repairContext
        context.performAndWait { context.reset() }
        var repaired = 0
        var saveError: Error?
        context.performAndWait {
            repaired = context.repairPinMirrors(channelId: channelId)
            do {
                if context.hasChanges { try context.save() }
            } catch {
                saveError = error
            }
        }
        XCTAssertNil(saveError, "the mirror repair failed to save", file: file, line: line)
        return repaired
    }

    /// The module's stated invariant: for every message that has a local row, a live pin row
    /// exists exactly when the bubble's mirror says pinned.
    private func assertPinStateIsConsistent(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ctx = committedContext()
        for message in MessageDTO.fetch(request: MessageDTO.fetchRequest(), context: ctx) {
            let cid = ChannelId(message.channelId)
            let hasPin = PinnedMessageDTO.fetch(messageTid: message.tid, channelId: cid, context: ctx) != nil
                || PinnedMessageDTO.fetch(messageId: MessageId(message.id), channelId: cid, context: ctx) != nil
            let mirrorSaysPinned = message.pinDetails?.isPinned == true

            XCTAssertEqual(
                hasPin, mirrorSaysPinned,
                """
                pin row and mirror disagree for message \(message.id): \
                row=\(hasPin) mirror=\(mirrorSaysPinned). \
                \(diagnostics(for: message, in: ctx))
                """,
                file: file, line: line
            )
        }
    }

    /// Dumps enough of both tables to tell a lost mirror apart from an orphaned one.
    private func diagnostics(for message: MessageDTO, in context: NSManagedObjectContext) -> String {
        let cid = ChannelId(message.channelId)
        let pins = PinnedMessageDTO.fetchAll(channelId: cid, context: context)
            .filter { $0.messageTid == message.tid || $0.messageId == message.id }
            .map { "pin(tid:\($0.messageTid) msgId:\($0.messageId) serverPinId:\($0.serverPinId) sync:\($0.sync) until:\(String(describing: $0.pinnedUntil)))" }
        let mirrors = PinDetailsDTO.fetchAll(channelId: cid, context: context)
            .filter { $0.messageTid == message.tid }
            .map { "mirror(tid:\($0.messageTid) isPinned:\($0.isPinned) attached:\($0.message != nil))" }
        return "rows=[\(pins.joined(separator: ", "))] mirrors=[\(mirrors.joined(separator: ", "))] messageTid=\(message.tid) relationship=\(String(describing: message.pinDetails))"
    }

    private func assertNoDuplicateRows(file: StaticString = #filePath, line: UInt = #line) {
        let rows = PinnedMessageDTO.fetchAll(context: committedContext())
        let keys = rows.map { "\($0.channelId)-\($0.messageTid)" }
        XCTAssertEqual(
            Set(keys).count, keys.count,
            "duplicate pin rows for the same (messageTid, channelId): \(keys)",
            file: file, line: line
        )
    }

    private func serverPin(id: MessageId, tid: Int64) -> Message {
        Message.Builder().id(id).tid(Int(tid)).body("message \(id)").type("text").build()
    }

    // MARK: - Concurrent pinning

    func testPinningManyDifferentMessagesAtOnce_landsEveryPinExactlyOnce() {
        let ids = (1 ... iterations).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }

        concurrently(iterations) { index, context in
            let id = ids[index]
            context.pinMessage(
                id: id,
                tid: Int64(id),
                channelId: self.channelId,
                scope: .forAll,
                pinnedAt: Date(),
                pinnedUntil: nil,
                pinnedBy: "me"
            )
        }

        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: committedContext()), iterations)
        assertNoDuplicateRows()
        assertPinStateIsConsistent()
    }

    /// Two devices, or a sweep page and a pin event, reporting the same pin at the same instant.
    /// `fetchOrCreate` collapses the losers rather than letting the uniqueness constraint abort
    /// the transaction.
    func testPinningTheSameMessageFromEveryContextAtOnce_leavesOneRow() {
        seedMessage(id: 100, channelId: channelId)

        concurrently(iterations) { _, context in
            context.pinMessage(
                id: 100,
                tid: 100,
                channelId: self.channelId,
                scope: .forAll,
                pinnedAt: Date(),
                pinnedUntil: nil,
                pinnedBy: "me"
            )
        }

        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: committedContext()), 1)
        assertNoDuplicateRows()

        // Parallel contexts can lose the mirror to a constraint merge — see
        // `testPinningAndUnpinningTheSameMessage_acrossContexts_convergesAfterTheRepair`.
        runReconcileRepair()
        assertPinStateIsConsistent()
    }

    func testStoringTheSameServerPinFromEveryContextAtOnce_leavesOneRow() {
        seedMessage(id: 101, channelId: channelId)

        concurrently(iterations) { _, context in
            context.storePin(
                message: self.serverPin(id: 101, tid: 101),
                channelId: self.channelId,
                serverPinId: 900,
                pinnedBy: ChatUser(id: "bob"),
                pinnedUntil: nil,
                scope: .forAll
            )
        }

        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: committedContext()), 1)
        XCTAssertEqual(pinRow(tid: 101)?.serverPinId, 900)
        assertNoDuplicateRows()

        runReconcileRepair()
        assertPinStateIsConsistent()
    }

    /// The real cross-path race: the acting device's `confirm` and another device's
    /// `didPinMessages` write the same pin from different contexts.
    func testConfirmAndStorePinRacing_convergeOnOneSyncedRow() {
        let message = seedMessage(id: 102, channelId: channelId)
        _ = ctx.pinMessage(
            id: 102, tid: message.tid, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        concurrently(iterations) { index, context in
            if index.isMultiple(of: 2) {
                context.confirmPin(
                    messageTid: 102,
                    channelId: self.channelId,
                    serverPinId: 901,
                    pinnedUntil: nil,
                    scope: .forAll
                )
            } else {
                context.storePin(
                    message: self.serverPin(id: 102, tid: 102),
                    channelId: self.channelId,
                    serverPinId: 901,
                    pinnedBy: ChatUser(id: "bob"),
                    pinnedUntil: nil,
                    scope: .forAll
                )
            }
        }

        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: committedContext()), 1)
        let row = pinRow(tid: 102)
        XCTAssertEqual(row?.serverPinId, 901)
        XCTAssertEqual(row?.sync, .synced, "both writers agree the pin is on the server")

        runReconcileRepair()
        assertPinStateIsConsistent()
    }

    // MARK: - Concurrent pin and unpin

    /// Rapid toggling on the path production actually uses — many callers, one serial writer.
    /// Whichever write lands last, the row and the mirror must agree with no repair needed;
    /// a half-applied toggle is the bug.
    func testPinningAndUnpinningTheSameMessage_throughDatabaseWrite_staysConsistent() {
        seedMessage(id: 200, channelId: channelId)

        throughDatabaseWrite(iterations) { index, context in
            if index.isMultiple(of: 2) {
                context.pinMessage(
                    id: 200, tid: 200, channelId: self.channelId,
                    scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
                )
            } else {
                context.unpinMessage(id: 200, tid: 200, channelId: self.channelId)
            }
        }

        assertNoDuplicateRows()
        assertPinStateIsConsistent()
    }

    /// The same storm on genuinely parallel contexts, which is harsher than anything the module
    /// itself does. Here the two sides *can* drift for one specific reason, and the assertions
    /// say exactly how far the guarantee goes:
    ///
    /// Both entities carry a `(messageTid, channelId)` uniqueness constraint. A context inserting
    /// the mirror can have that insert constraint-merged onto a row another context is deleting
    /// in the same instant; the delete wins, the mirror vanishes, and the pin row — a separate
    /// entity with no delete pending — survives. So: never a crash, never a duplicate, and
    /// `repairPinMirrors` (which every `reconcilePins` runs) converges it.
    func testPinningAndUnpinningTheSameMessage_acrossContexts_convergesAfterTheRepair() {
        seedMessage(id: 200, channelId: channelId)

        concurrently(iterations) { index, context in
            if index.isMultiple(of: 2) {
                context.pinMessage(
                    id: 200, tid: 200, channelId: self.channelId,
                    scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
                )
            } else {
                context.unpinMessage(id: 200, tid: 200, channelId: self.channelId)
            }
        }

        assertNoDuplicateRows()

        runReconcileRepair()
        assertPinStateIsConsistent()
    }

    func testUnpinningTheSameMessageFromEveryContextAtOnce_isIdempotent() {
        seedMessage(id: 201, channelId: channelId)
        _ = ctx.pinMessage(
            id: 201, tid: 201, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        concurrently(iterations) { _, context in
            context.unpinMessage(id: 201, tid: 201, channelId: self.channelId)
        }

        XCTAssertNil(pinRow(tid: 201))
        XCTAssertNil(MessageDTO.fetch(id: 201, context: committedContext())?.pinDetails)
        assertPinStateIsConsistent()
    }

    /// A remote unpin event and a sweep page arriving together — both real, both from
    /// `ChannelEventHandler` / the sweep, both on `Database.write`'s serial context.
    func testDeletePinRacingWithStorePin_throughDatabaseWrite_staysConsistent() {
        seedMessage(id: 202, channelId: channelId)

        throughDatabaseWrite(iterations) { index, context in
            if index.isMultiple(of: 2) {
                context.storePin(
                    message: self.serverPin(id: 202, tid: 202),
                    channelId: self.channelId,
                    serverPinId: 902,
                    pinnedBy: ChatUser(id: "bob"),
                    pinnedUntil: nil,
                    scope: .forAll
                )
            } else {
                context.deletePin(serverPinId: 902, messageId: 202, channelId: self.channelId)
            }
        }

        assertNoDuplicateRows()
        assertPinStateIsConsistent()
    }

    /// And on parallel contexts: no crash, no duplicates, and converges after the repair. See
    /// `testPinningAndUnpinningTheSameMessage_acrossContexts_convergesAfterTheRepair` for why
    /// the mirror is the side that can be lost.
    func testDeletePinRacingWithStorePin_acrossContexts_convergesAfterTheRepair() {
        seedMessage(id: 203, channelId: channelId)

        concurrently(iterations) { index, context in
            if index.isMultiple(of: 2) {
                context.storePin(
                    message: self.serverPin(id: 203, tid: 203),
                    channelId: self.channelId,
                    serverPinId: 903,
                    pinnedBy: ChatUser(id: "bob"),
                    pinnedUntil: nil,
                    scope: .forAll
                )
            } else {
                context.deletePin(serverPinId: 903, messageId: 203, channelId: self.channelId)
            }
        }

        assertNoDuplicateRows()

        let repaired = runReconcileRepair()
        XCTAssertGreaterThanOrEqual(repaired, 0, "repaired \(repaired) mirror(s)")
        assertPinStateIsConsistent()
    }

    // MARK: - Mirror repair

    /// The repair's forward direction: a pin row whose mirror was swept away — which is what a
    /// batch delete leaves behind, since `NSBatchDeleteRequest` ignores deletion rules.
    func testRepairPinMirrors_reProjectsAPinRowWhoseMirrorIsGone() {
        let message = seedMessage(id: 210, channelId: channelId)
        _ = ctx.pinMessage(
            id: 210, tid: message.tid, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        // Simulate the batch delete: drop the mirror, leave the pin row.
        if let details = message.pinDetails {
            ctx.delete(details)
            message.pinDetails = nil
        }
        try? ctx.save()
        XCTAssertNil(message.pinDetails)

        XCTAssertEqual(ctx.repairPinMirrors(channelId: channelId), 1)
        try? ctx.save()

        XCTAssertEqual(message.pinDetails?.isPinned, true,
                       "the banner listed this pin, so the bubble has to be marked too")
    }

    /// And the reverse: a mirror with no pin row behind it.
    func testRepairPinMirrors_clearsAMirrorWithNoPinRow() {
        let message = seedMessage(id: 211, channelId: channelId)
        let details = PinDetailsDTO.fetchOrCreate(for: message, context: ctx)
        details.isPinned = true
        try? ctx.save()

        XCTAssertEqual(ctx.repairPinMirrors(channelId: channelId), 1)
        try? ctx.save()

        XCTAssertNil(message.pinDetails, "nothing pins this message, so nothing should mark it")
    }

    /// The exact shape a constraint merge leaves behind: the mirror row still points at its
    /// message, but `MessageDTO.pinDetails` reads nil. Assigning only the inverse is a no-op
    /// assignment in that state, so the repair has to write the forward key too — otherwise the
    /// bubble stays unmarked and `RelationshipKeyPathsObserver`, which walks the inverse, never
    /// repaints it.
    func testRepairPinMirrors_reattachesAMirrorWhoseForwardLinkWasLost() {
        let message = seedMessage(id: 216, channelId: channelId)
        _ = ctx.pinMessage(
            id: 216, tid: message.tid, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        let details = message.pinDetails
        XCTAssertNotNil(details)
        // Break only the forward key, leaving the inverse pointing at the message.
        message.setValue(nil, forKey: "pinDetails")
        try? ctx.save()
        XCTAssertNil(message.pinDetails, "the forward key is now the broken one")

        ctx.repairPinMirrors(channelId: channelId)
        try? ctx.save()

        XCTAssertEqual(message.pinDetails?.isPinned, true,
                       "the repair must write the forward key, not just the inverse")
        XCTAssertIdentical(message.pinDetails, details, "and adopt the existing row, not add one")
        XCTAssertEqual(PinDetailsDTO.fetchAll(channelId: channelId, context: ctx).count, 1)
    }

    func testRepairPinMirrors_isANoOpWhenTheTwoSidesAgree() {
        let message = seedMessage(id: 212, channelId: channelId)
        _ = ctx.pinMessage(
            id: 212, tid: message.tid, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        XCTAssertEqual(ctx.repairPinMirrors(channelId: channelId), 0)
    }

    /// A pin whose message was never fetched has no bubble to mark, and must not be treated as
    /// drift — that is the case the whole denormalized snapshot exists for.
    func testRepairPinMirrors_ignoresAPinWhoseMessageIsNotStoredLocally() {
        ctx.storePin(
            message: serverPin(id: 213, tid: 213),
            channelId: channelId,
            serverPinId: 904,
            pinnedBy: ChatUser(id: "bob"),
            pinnedUntil: nil,
            scope: .forAll
        )
        try? ctx.save()
        XCTAssertNil(MessageDTO.fetch(id: 213, context: ctx))

        XCTAssertEqual(ctx.repairPinMirrors(channelId: channelId), 0)
        XCTAssertNotNil(pinRow(tid: 213), "and the pin itself must survive the repair")
    }

    /// `applyPinDetails` legitimately marks a bubble before the sweep has created the pin row —
    /// a personal pin from another device looks exactly like that. The repair must not undo it
    /// while a pin row for that message exists.
    func testRepairPinMirrors_keepsAMirrorThatItsOwnPinRowBacks() {
        let message = seedMessage(id: 214, channelId: channelId)
        ctx.storePin(
            message: serverPin(id: 214, tid: 214),
            channelId: channelId,
            serverPinId: 905,
            pinnedBy: ChatUser(id: "bob"),
            pinnedUntil: nil,
            scope: .forMe
        )
        try? ctx.save()

        ctx.repairPinMirrors(channelId: channelId)
        try? ctx.save()

        XCTAssertEqual(message.pinDetails?.isPinned, true)
        XCTAssertNotNil(pinRow(tid: 214))
    }

    /// The repair is reached through the sweep, which is what makes a channel open converge it.
    func testReconcilePins_repairsMirrorsEvenWhenItDeletesNothing() {
        let message = seedMessage(id: 215, channelId: channelId)
        let row = ctx.pinMessage(
            id: 215, tid: message.tid, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        row?.serverPinId = 906
        row?.sync = .synced
        try? ctx.save()

        if let details = message.pinDetails {
            ctx.delete(details)
            message.pinDetails = nil
        }
        try? ctx.save()

        // The server still reports this pin, so nothing is deleted — the repair still runs.
        ctx.reconcilePins(channelId: channelId, keeping: [906])
        try? ctx.save()

        XCTAssertNotNil(pinRow(tid: 215))
        XCTAssertEqual(message.pinDetails?.isPinned, true)
    }

    /// "Unpin everything" landing while other messages are being pinned.
    ///
    /// `unpinAllMessages` clears every mirror in the channel, so on a parallel context it can
    /// wipe a mirror another context created for a *different* message an instant earlier —
    /// while that message's pin row, inserted after the delete's snapshot, survives. No crash,
    /// no duplicates, and the repair every `reconcilePins` runs converges it.
    func testUnpinAllRacingWithPinning_convergesAfterTheRepair() {
        let ids = (300 ..< 300 + UInt64(iterations)).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }

        concurrently(iterations) { index, context in
            if index.isMultiple(of: 4) {
                context.unpinAllMessages(channelId: self.channelId)
            } else {
                let id = ids[index]
                context.pinMessage(
                    id: id, tid: Int64(id), channelId: self.channelId,
                    scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
                )
            }
        }

        assertNoDuplicateRows()

        runReconcileRepair()
        assertPinStateIsConsistent()
    }

    /// The same on `Database.write`'s serial context, where it must be consistent with no repair.
    func testUnpinAllRacingWithPinning_throughDatabaseWrite_staysConsistent() {
        let ids = (350 ..< 350 + UInt64(iterations)).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }

        throughDatabaseWrite(iterations) { index, context in
            if index.isMultiple(of: 4) {
                context.unpinAllMessages(channelId: self.channelId)
            } else {
                let id = ids[index]
                context.pinMessage(
                    id: id, tid: Int64(id), channelId: self.channelId,
                    scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
                )
            }
        }

        assertNoDuplicateRows()
        assertPinStateIsConsistent()
    }

    // MARK: - Concurrent reconcile

    /// The sweep's reconcile running against live pin traffic. Pins the server did report must
    /// survive, and an optimistic pin inside its grace window must survive too.
    func testReconcileRacingWithPinning_keepsTheServersPinsAndTheInFlightOnes() {
        let kept = seedMessage(id: 400, channelId: channelId)
        _ = ctx.pinMessage(
            id: 400, tid: kept.tid, channelId: channelId,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        fixturePinRow(tid: 400)?.serverPinId = 910
        fixturePinRow(tid: 400)?.sync = .synced
        let fresh = (500 ..< 500 + UInt64(iterations)).map { MessageId($0) }
        fresh.forEach { seedMessage(id: $0, channelId: channelId) }
        try? ctx.save()

        concurrently(iterations) { index, context in
            if index.isMultiple(of: 3) {
                context.reconcilePins(channelId: self.channelId, keeping: [910])
            } else {
                let id = fresh[index]
                context.pinMessage(
                    id: id, tid: Int64(id), channelId: self.channelId,
                    scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
                )
            }
        }

        XCTAssertNotNil(pinRow(tid: 400), "a pin the server reported must survive the sweep")
        assertNoDuplicateRows()
        assertPinStateIsConsistent()
    }

    /// Two sweeps landing at once — the conversation's and the pinned list's, say. On
    /// `Database.write`'s serial context the second is a no-op over the first's result.
    func testReconcileRacingWithItself_throughDatabaseWrite_isIdempotent() {
        let keep = seedReconcileFixture(startingAt: 600, pinIdBase: 920)

        throughDatabaseWrite(iterations) { _, context in
            context.reconcilePins(channelId: self.channelId, keeping: keep)
        }

        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: committedContext()), 5,
                       "repeating the same reconcile must not delete more than the first one did")
        assertPinStateIsConsistent()
    }

    /// The same on parallel contexts. No count is asserted: with
    /// `NSMergeByPropertyObjectTrumpMergePolicy` a context that deletes a row can lose to one
    /// that merely updates it, so a row can legitimately survive a sweep that another context
    /// had already condemned. What must hold is that nothing crashes, nothing duplicates, and
    /// the survivors are a subset of what was there.
    func testReconcileRacingWithItself_acrossContexts_neverDeletesWhatTheServerKept() {
        let keep = seedReconcileFixture(startingAt: 700, pinIdBase: 940)

        concurrently(iterations) { _, context in
            context.reconcilePins(channelId: self.channelId, keeping: keep)
        }

        assertNoDuplicateRows()
        let survivors = PinnedMessageDTO.fetchAll(channelId: channelId, context: committedContext())
        XCTAssertLessThanOrEqual(survivors.count, 10)
        for pin in survivors where pin.hasServerPinId {
            XCTAssertTrue(
                keep.contains(pin.serverPinId),
                "pin \(pin.serverPinId) is not in the keep set, so no sweep should have kept it"
            )
        }
        // And every pin the server reported is still there — the guarantee that matters.
        for pinId in keep {
            XCTAssertNotNil(
                PinnedMessageDTO.fetch(serverPinId: pinId, channelId: channelId, context: committedContext()),
                "pin \(pinId) was reported by the server and must survive every sweep"
            )
        }
    }

    /// Ten synced pins, of which the server still reports the first five. Returns the keep set.
    private func seedReconcileFixture(startingAt first: UInt64, pinIdBase: Int64) -> Set<Int64> {
        let ids = (first ..< first + 10).map { MessageId($0) }
        for (offset, id) in ids.enumerated() {
            let message = seedMessage(id: id, channelId: channelId)
            let row = ctx.pinMessage(
                id: id, tid: message.tid, channelId: channelId,
                scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
            )
            row?.serverPinId = pinIdBase + Int64(offset)
            row?.sync = .synced
        }
        try? ctx.save()
        return Set((0 ..< 5).map { pinIdBase + Int64($0) })
    }

    // MARK: - Concurrent message writes

    /// Every message write runs `syncPin` then `applyPinDetails`. Under contention with real pin
    /// traffic those must not fight — the residual "mirror set, no row" state is legal, but a
    /// row with no mirror is not.
    func testMessageWritesRacingWithPinning_doNotClobberThePinState() {
        let ids = (700 ..< 700 + UInt64(iterations)).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }

        concurrently(iterations) { index, context in
            let id = ids[index]
            if index.isMultiple(of: 2) {
                context.pinMessage(
                    id: id, tid: Int64(id), channelId: self.channelId,
                    scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
                )
            } else if let dto = MessageDTO.fetch(id: id, context: context) {
                context.syncPin(for: dto)
                context.applyPinState(isPinned: true, pinnedUntil: nil, scope: .forAll, to: dto)
            }
        }

        assertNoDuplicateRows()
        // Not `assertPinStateIsConsistent`: `applyPinState` legitimately sets a mirror with no
        // row (a personal pin from another device looks exactly like that, and so does the
        // window before the sweep lands). Assert the direction that must never happen instead.
        let committed = committedContext()
        for row in PinnedMessageDTO.fetchAll(channelId: channelId, context: committed) {
            guard let message = MessageDTO.fetch(id: MessageId(row.messageId), context: committed) else { continue }
            XCTAssertEqual(
                message.pinDetails?.isPinned, true,
                "a pin row with no mirror leaves the bubble unmarked while the banner lists it"
            )
        }
    }

    func testApplyPinStateRacingWithUnpin_convergesWithoutDuplicatingTheMirror() {
        let ids = (800 ..< 800 + UInt64(iterations)).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }

        concurrently(iterations) { index, context in
            let id = ids[index]
            guard let dto = MessageDTO.fetch(id: id, context: context) else { return }
            if index.isMultiple(of: 2) {
                context.applyPinState(isPinned: true, pinnedUntil: nil, scope: .forAll, to: dto)
            } else {
                context.applyPinState(isPinned: false, pinnedUntil: nil, scope: .forAll, to: dto)
            }
        }

        let mirrors = PinDetailsDTO.fetchAll(channelId: channelId, context: committedContext())
        let keys = mirrors.map { "\($0.channelId)-\($0.messageTid)" }
        XCTAssertEqual(Set(keys).count, keys.count, "duplicate mirror rows: \(keys)")
    }

    // MARK: - Concurrent sweeps

    /// Several screens opening at once, plus a cancel landing mid-flight. The per-channel guard
    /// must hand out exactly one slot per channel and always give it back.
    func testManySweepsAtOnce_startOncePerChannelAndAlwaysReleaseTheSlot() {
        let channels: [ChannelId] = [55, 56, 57, 58]
        channels.dropFirst().forEach { seedChannel(id: $0) }

        let finished = expectation(description: "every started sweep finished")
        finished.expectedFulfillmentCount = channels.count

        let lock = NSLock()
        var startsPerChannel = [ChannelId: Int]()

        let group = DispatchGroup()
        for channel in channels {
            // Ten callers per channel; exactly one may win the slot.
            for _ in 0 ..< 10 {
                group.enter()
                DispatchQueue.global().async {
                    SyncService.syncChannelPins(channelId: channel) { started in
                        if started {
                            lock.lock()
                            startsPerChannel[channel, default: 0] += 1
                            lock.unlock()
                            finished.fulfill()
                        }
                    }
                    group.leave()
                }
            }
        }
        awaitGroup(group, description: "every sweep request dispatched", timeout: 30)
        wait(for: [finished], timeout: 60)

        lock.lock()
        let starts = startsPerChannel
        lock.unlock()
        XCTAssertEqual(starts.count, channels.count, "every channel must get its own sweep")
        for channel in channels {
            XCTAssertEqual(starts[channel], 1, "channel \(channel) started more than one sweep")
        }

        // And the slots are free again, which is what a leaked generation would break.
        for channel in channels {
            let restarted = expectation(description: "\(channel) restarted")
            SyncService.syncChannelPins(channelId: channel) { started in
                XCTAssertTrue(started, "channel \(channel)'s slot was never released")
                restarted.fulfill()
            }
            wait(for: [restarted], timeout: 20)
        }
    }

    func testCancellingSweepsWhileTheyStart_neitherCrashesNorLeaksASlot() {
        let group = DispatchGroup()
        for index in 0 ..< iterations {
            group.enter()
            DispatchQueue.global().async {
                if index.isMultiple(of: 3) {
                    SyncService.cancelPinSync(channelId: self.channelId)
                } else if index.isMultiple(of: 7) {
                    SyncService.cancelAllPinSyncs()
                } else {
                    SyncService.syncChannelPins(channelId: self.channelId)
                }
                group.leave()
            }
        }
        awaitGroup(group, description: "cancel/start storm dispatched", timeout: 30)

        SyncService.cancelAllPinSyncs()
        let done = expectation(description: "slot usable again")
        SyncService.syncChannelPins(channelId: channelId) { started in
            XCTAssertTrue(started, "the channel's slot leaked")
            done.fulfill()
        }
        wait(for: [done], timeout: 20)
    }

    /// The provider's flush/rollback cycle hammered from many threads. Nothing is asserted about
    /// which write wins — only that the pair of tables stays consistent and nothing traps.
    func testProviderPinAndUnpinHammered_staysConsistent() {
        let ids = (900 ..< 900 + UInt64(iterations)).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }
        // The mock operator matters here: the real one would never call back without a
        // connection, so this would hang instead of finishing.
        let provider = MockPinnedMessageProvider(channelId: channelId)

        let group = DispatchGroup()
        for (index, id) in ids.enumerated() {
            let message = MessageDTO.fetch(id: id, context: ctx)!.convert()
            group.enter()
            DispatchQueue.global().async {
                if index.isMultiple(of: 2) {
                    provider.pin(message: message, scope: .forAll) { _ in group.leave() }
                } else {
                    provider.unpin(message: message) { _ in group.leave() }
                }
            }
        }
        awaitGroup(group, description: "the provider's pin/unpin cycle")

        assertNoDuplicateRows()
    }

    // MARK: - Ordering under contention

    /// The sort key has to hold up when ids arrive out of order from different contexts.
    func testConcurrentlyStampedServerPinIds_stillReadBackInPinOrder() {
        let ids = (1_000 ..< 1_010).map { MessageId($0) }
        ids.forEach { seedMessage(id: $0, channelId: channelId) }

        // Pin ids assigned in reverse of the timeline, from ten different contexts.
        concurrently(ids.count) { index, context in
            let id = ids[index]
            let row = context.pinMessage(
                id: id, tid: Int64(id), channelId: self.channelId,
                scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
            )
            row?.serverPinId = Int64(1_100 - index)
            row?.sync = .synced
        }

        let order = committedContext().pinnedMessages(channelId: channelId).map(\.messageId)
        XCTAssertEqual(order, ids.reversed(), "the banner must read back in pin-id order")
        assertNoDuplicateRows()
    }

    // MARK: - Private

    /// Reads a pin row's committed state. **Read-only**: the context it comes from is discarded,
    /// so a mutation here is silently lost — and, worse, leaves a live managed object in a
    /// released context, which crashes Core Data's reference queue on the next pool drain. Use
    /// `fixturePinRow(tid:)` to write.
    private func pinRow(tid: Int64) -> PinnedMessageDTO? {
        PinnedMessageDTO.fetch(messageTid: tid, channelId: channelId, context: committedContext())
    }

    /// A pin row on the long-lived `viewContext`, for setting a fixture up. Caller saves.
    private func fixturePinRow(tid: Int64) -> PinnedMessageDTO? {
        PinnedMessageDTO.fetch(messageTid: tid, channelId: channelId, context: ctx)
    }
}
