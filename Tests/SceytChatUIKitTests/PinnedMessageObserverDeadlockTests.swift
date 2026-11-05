//
//  PinnedMessageObserverDeadlockTests.swift
//  SceytChatUIKitTests
//
//  Regression suite for the 0x8BADF00D watchdog kill in WAAFI 8.3.24 (71529), 2026-11-05.
//  Symbolicated stacks:
//
//  Main:     ChannelListRouter.showChannelViewController → ChannelViewModel.init
//              → startDatabaseObserver → startPinnedMessageObserver
//              → DatabaseObserver.startObserver → updateFetchedObjects
//              → NSFetchedResultsController.performFetch → performBlockAndWait   (waits for context)
//  Context:  LazyDatabaseObserver.didChangeObjects (perform) → reload → insert
//              → ChannelViewModel.createMessageObserver closure → createLayoutModel
//              → AttachmentLayout.recalculateThumbnailSizeIfNeeded → TextSizeMeasure
//              → NSTextStorage edit → NotificationCenter.post → waitUntilFinished  (waits for main)
//
//  Both observers sat on the one shared `backgroundReadOnlyObservableContext`. An NSTextStorage
//  edit posts `NSTextStorage.will/didProcessEditing`, and with any observer registered on
//  `queue: .main` the post blocks until main runs it. The production observer is not ours (none
//  in WAAFI or the SDK), so these tests register one to stand in for it.
//
//  Fix: the chat's pin observer reads from `viewContext` (as `ChannelPinnedMessageListViewModel`
//  already does), so starting it on main never waits on the shared background context.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class PinnedMessageObserverDeadlockTests: XCTestCase {

    private var database: MockDatabase!
    private var originalPinningEnabled: Bool!
    private var mainQueueObservers: [NSObjectProtocol] = []

    private let channelId: ChannelId = 4_711
    private let messageIds: [MessageId] = [47_111, 47_112]

    private let text = NSAttributedString(
        string: "Caption long enough to wrap across several lines when it is measured.",
        attributes: [.font: UIFont.systemFont(ofSize: 16)]
    )

    override func setUp() {
        super.setUp()
        // One shared observable context, as in production — without it the two sides would
        // never contend and the deadlock could not occur.
        database = MockDatabase(sharesObservableContext: true)
        originalPinningEnabled = SceytChatUIKit.shared.config.isMessagePinningEnabled
        SceytChatUIKit.shared.config.isMessagePinningEnabled = true
        seedChannelAndMessages()
    }

    override func tearDown() {
        mainQueueObservers.forEach(NotificationCenter.default.removeObserver)
        mainQueueObservers = []
        SceytChatUIKit.shared.config.isMessagePinningEnabled = originalPinningEnabled
        database = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func seedChannelAndMessages() {
        let ctx = database.container.viewContext
        let (channel, _) = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        for id in messageIds {
            let message = MessageDTO.fetchOrCreate(id: id, tid: Int64(id), channelId: Int64(channelId), context: ctx)
            message.id = Int64(id)
            message.tid = Int64(id)
            message.channelId = Int64(channelId)
            message.body = "message \(id)"
            message.type = "text"
            message.createdAt = Date().bridgeDate
            message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        }
        try? ctx.save()
    }

    @discardableResult
    private func pin(_ id: MessageId, in ctx: NSManagedObjectContext) -> PinnedMessageDTO? {
        ctx.pinMessage(id: id, tid: Int64(id), channelId: channelId, scope: .forAll,
                       pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me")
    }

    /// Stand-in for the (system/third-party) main-queue observer seen in the crash.
    private func observeTextStorageEditingOnMainQueue() {
        for name in [NSTextStorage.willProcessEditingNotification, NSTextStorage.didProcessEditingNotification] {
            mainQueueObservers.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in }
            )
        }
    }

    // MARK: - The crash

    /// Opening a chat starts the pin observer on main while the message observer is measuring
    /// attachment text on the shared observable context.
    ///
    /// Before the fix this deadlocks for good; a true deadlock cannot be recovered in-process,
    /// so a watchdog crashes the runner after 5 s with an explicit message (the system watchdog
    /// allows 10 s). After the fix `startObserver()` returns at once.
    func test_startingPinObserverOnMain_doesNotDeadlockWithTextMeasureOnObservableContext() throws {
        observeTextStorageEditingOnMainQueue()
        let shared = database.backgroundReadOnlyObservableContext
        XCTAssertTrue(shared === database.backgroundReadOnlyObservableContext, "precondition: one shared context")

        let blockEntered = DispatchSemaphore(value: 0)
        let measured = expectation(description: "context block finishes measuring")
        shared.perform { [text] in
            blockEntered.signal()
            usleep(300_000) // let main reach startObserver() while this block holds the context
            _ = TextSizeMeasure.calculateSize(of: text) // posts → needs main
            measured.fulfill()
        }
        blockEntered.wait()

        let returned = AtomicFlag()
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 5)
            if !returned.value {
                fatalError("DEADLOCK: main stuck in pin observer startObserver() while the shared "
                           + "observable context waits on main inside TextSizeMeasure (0x8BADF00D)")
            }
        }

        let observer = ChannelViewModel.makePinnedMessageObserver(channelId: channelId, database: database)
        addTeardownBlock { observer.stopObserver() }
        // Mark "returned" on the throwing path too, so a fetch error fails this test normally
        // instead of tripping the watchdog 5 s later inside an unrelated test.
        do {
            try observer.startObserver()
        } catch {
            returned.value = true
            throw error
        }
        returned.value = true

        // Main is free again, so it can serve the posted notification and the context drains.
        wait(for: [measured], timeout: 5)
    }

    // MARK: - No behaviour change

    /// The banner must still show pins already on disk the moment the chat opens — the fix must
    /// not turn the initial load asynchronous.
    func test_pinsOnDisk_areAvailableSynchronouslyAfterStart() throws {
        let ctx = database.container.viewContext
        XCTAssertNotNil(pin(messageIds[0], in: ctx))
        try ctx.save()

        let observer = ChannelViewModel.makePinnedMessageObserver(channelId: channelId, database: database)
        addTeardownBlock { observer.stopObserver() }
        try observer.startObserver()

        XCTAssertEqual(observer.orderedItems.map(\.messageId), [messageIds[0]])
    }

    /// A pin written on the background write context (sync, socket event, user action) must
    /// still reach the observer, and its callback must arrive on main.
    func test_pinWrittenInBackground_reachesObserver_onMainThread() throws {
        let observer = ChannelViewModel.makePinnedMessageObserver(channelId: channelId, database: database)
        addTeardownBlock { observer.stopObserver() }
        try observer.startObserver()
        XCTAssertTrue(observer.orderedItems.isEmpty)

        let changed = expectation(description: "observer sees the new pin")
        changed.assertForOverFulfill = false
        var callbackOnMain = true
        observer.onDidChange = { _ in
            callbackOnMain = callbackOnMain && Thread.isMainThread
            if !observer.orderedItems.isEmpty { changed.fulfill() }
        }

        let written = expectation(description: "write saved")
        database.write(resultQueue: .main, { [self] ctx in
            XCTAssertNotNil(pin(messageIds[1], in: ctx))
        }, completion: { error in
            XCTAssertNil(error)
            written.fulfill()
        })

        wait(for: [written, changed], timeout: 5)
        XCTAssertEqual(observer.orderedItems.map(\.messageId), [messageIds[1]])
        XCTAssertTrue(callbackOnMain, "pin observer callbacks must arrive on main")
    }

    /// Unpinning in the background must also reach the observer.
    func test_unpinWrittenInBackground_removesPinFromObserver() throws {
        let ctx = database.container.viewContext
        XCTAssertNotNil(pin(messageIds[0], in: ctx))
        try ctx.save()

        let observer = ChannelViewModel.makePinnedMessageObserver(channelId: channelId, database: database)
        addTeardownBlock { observer.stopObserver() }
        try observer.startObserver()
        XCTAssertEqual(observer.orderedItems.count, 1)

        let removed = expectation(description: "observer drops the pin")
        removed.assertForOverFulfill = false
        observer.onDidChange = { _ in
            if observer.orderedItems.isEmpty { removed.fulfill() }
        }

        database.write(resultQueue: .main, { [self] ctx in
            ctx.unpinMessage(id: messageIds[0], tid: Int64(messageIds[0]), channelId: channelId)
        }, completion: nil)

        wait(for: [removed], timeout: 5)
        XCTAssertTrue(observer.orderedItems.isEmpty)
    }
}

private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}
