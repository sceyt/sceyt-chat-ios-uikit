//
//  ChannelListStoreWriteContextTests.swift
//  SceytChatUIKitTests
//
//  Regression for "a message sent from another device shows twice for a moment after a cold
//  launch". A chat-list page stores each channel's `lastMessage`; the chat screen stores the same
//  message from its first page on the serial write context. When the chat-list store ran on a
//  context of its own (`performWriteTask`), both writers inserted the message: the MessageDTO
//  rows merged through their uniqueness constraint, the AttachmentDTO rows (no constraint) did
//  not, and the cell drew the attachment twice. See OwnDeviceMessageDuplicateRaceTests for the
//  Core Data mechanism.
//
//  The chat-list writers must therefore use the serial `write`, never `performWriteTask`.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class ChannelListStoreWriteContextTests: XCTestCase {

    private var inner: MockDatabase!
    private var database: RecordingDatabase!
    private var originalDatabase: Database!
    private let channelId: ChannelId = 77
    private let messageId: MessageId = 9_001

    override func setUp() {
        super.setUp()
        inner = MockDatabase()
        database = RecordingDatabase(inner: inner)
        originalDatabase = DataProvider.database
        DataProvider.database = database
    }

    override func tearDown() {
        DataProvider.database = originalDatabase
        database = nil
        inner = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// An outgoing message as the server delivers it (`incoming`/`createdAt` are read-only on the
    /// SDK type and set the way its decoder fills them).
    private func serverMessage() -> Message {
        let attachment = Attachment.Builder(url: "https://cdn.example/photo.jpg", type: "image")
            .name("photo.jpg")
            .build()
        let message = Message.Builder()
            .id(messageId)
            .tid(555_123)
            .type("media")
            .body("")
            .attachments([attachment])
            .build()
        message.setValue(false, forKey: "incoming")
        message.setValue(Date(timeIntervalSince1970: 1_794_000_000), forKey: "createdAt")
        return message
    }

    /// `SCTChannel` has no public initializer (channels only come from the server), so build one
    /// at runtime and fill the fields `ChannelDTO.map` reads.
    private func serverChannel(lastMessage: Message) -> Channel {
        let channel = (Channel.self as NSObject.Type).init() as! Channel
        channel.setValue(channelId, forKey: "id")
        channel.setValue("direct", forKey: "type")
        channel.setValue("", forKey: "uri")
        channel.setValue("", forKey: "subject")
        channel.setValue(Date(timeIntervalSince1970: 1_700_000_000), forKey: "createdAt")
        channel.setValue(lastMessage, forKey: "lastMessage")
        return channel
    }

    /// A channel with nothing but the fields `ChannelDTO.map` reads. Each gets its own
    /// `createdAt`: `sortingKey` (unique in the model) is derived from it.
    private func plainChannel(id: ChannelId) -> Channel {
        let channel = (Channel.self as NSObject.Type).init() as! Channel
        channel.setValue(id, forKey: "id")
        channel.setValue("direct", forKey: "type")
        channel.setValue("", forKey: "uri")
        channel.setValue("", forKey: "subject")
        channel.setValue(Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id)), forKey: "createdAt")
        return channel
    }

    private func page(of count: Int) -> [Channel] {
        (1...count).map { plainChannel(id: ChannelId(10_000 + $0)) }
    }

    private func storedChannelCount() -> Int {
        let ctx = inner.container.viewContext
        ctx.refreshAllObjects()
        return (try? ctx.count(for: ChannelDTO.fetchRequest())) ?? -1
    }

    private func storedChannel(id: ChannelId) -> ChannelDTO? {
        let ctx = inner.container.viewContext
        ctx.refreshAllObjects()
        return ChannelDTO.fetch(id: id, context: ctx)
    }

    private func storedAttachmentCount() -> Int {
        let ctx = inner.container.viewContext
        ctx.refreshAllObjects()
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = NSPredicate(format: "id == %lld", messageId)
        let rows = MessageDTO.fetch(request: request, context: ctx)
        XCTAssertEqual(rows.count, 1, "message rows")
        return rows.first?.attachments?.count ?? 0
    }

    // MARK: - Tests

    func testChannelListStore_writesOnTheSerialContext() {
        let done = expectation(description: "stored")
        ChannelListProvider().store(channels: [serverChannel(lastMessage: serverMessage())]) { _ in
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(database.calls, ["write"],
                       "The chat-list store must share the serial context with the chat screen's writes")
    }

    func testStoreChannelsOperation_writesOnTheSerialContext() {
        let operation = StoreChannelsOperation(database: database,
                                               channels: [serverChannel(lastMessage: serverMessage())])
        // Wait without blocking main: the write's completion is delivered on the main queue.
        let finished = expectation(description: "operation finished")
        operation.completionBlock = { finished.fulfill() }
        let queue = OperationQueue()
        queue.addOperation(operation)
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(database.calls, ["write"],
                       "The sync's channel store must share the serial context with the chat screen's writes")
    }

    // MARK: - Chunked page save
    //
    // A 50-channel page takes 210–340 ms on device (channel_save_performance_findings.md). On the
    // serial context every received message, send ack and message-page load queued behind it
    // waited for the whole page. The page is now stored in chunks, each queued only after the
    // previous one finished, so such a write waits for one chunk at most.

    func testChannelListStore_largePage_isStoredInSerialChunks() {
        let provider = ChannelListProvider()
        var reported: [Channel]?
        provider.onStoreChannels = { page, _ in reported = page }
        let done = expectation(description: "page stored")   // over-fulfil fails: completion once
        provider.store(channels: page(of: 25)) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: defaultWaitTimeout)

        XCTAssertEqual(database.calls, ["write", "write", "write"],
                       "25 channels in chunks of \(ChunkedChannelStore.chunkSize), all on the serial context")
        XCTAssertEqual(storedChannelCount(), 25)
        XCTAssertEqual(reported?.count, 25, "onStoreChannels reports the whole page once")
    }

    func testChannelListStore_writeQueuedDuringPage_runsBetweenChunks() {
        let pageDone = expectation(description: "page stored")
        let otherDone = expectation(description: "other write")
        var channelsSeenByOtherWrite = -1

        ChannelListProvider().store(channels: page(of: 25)) { _ in pageDone.fulfill() }
        // Stands for a received message or send ack arriving while the page is being stored.
        database.write({ ctx in
            channelsSeenByOtherWrite = (try? ctx.count(for: ChannelDTO.fetchRequest())) ?? -1
        }, completion: { _ in otherDone.fulfill() })
        wait(for: [pageDone, otherDone], timeout: defaultWaitTimeout)

        XCTAssertEqual(channelsSeenByOtherWrite, ChunkedChannelStore.chunkSize,
                       "the other write must run after the first chunk, not after the whole page")
        XCTAssertEqual(storedChannelCount(), 25)
    }

    func testChannelListStore_smallPage_isOneWrite() {
        let done = expectation(description: "page stored")
        ChannelListProvider().store(channels: page(of: 3)) { _ in done.fulfill() }
        wait(for: [done], timeout: defaultWaitTimeout)

        XCTAssertEqual(database.calls, ["write"])
        XCTAssertEqual(storedChannelCount(), 3)
    }

    // MARK: - Chunked page safety (ChunkedChannelStore)

    /// A channel deleted between two chunks (a channel-deleted event) must not be re-created by a
    /// later chunk carrying the page's copy.
    func testChannelDeletedBetweenChunks_isNotBroughtBack() {
        let pageDone = expectation(description: "page stored")
        let deleteDone = expectation(description: "delete stored")
        let lastId = ChannelId(10_025)

        let provider = ChannelListProvider()
        var page: [Channel]?
        var stored: [Channel]?
        provider.onStoreChannels = { pageChannels, storedChannels in
            page = pageChannels
            stored = storedChannels
        }
        provider.store(channels: self.page(of: 25)) { _ in pageDone.fulfill() }
        // The channel is not stored yet (the page creates it), so `deleteChannel(id:)` finds no
        // row and records the id at once. `deleteChannel` itself cannot run here: its message
        // cleanup merges into `SceytChatUIKit.shared.database`, which a test store cannot share.
        database.write({ _ in DeletedChannelLog.record([lastId]) }, completion: { _ in deleteDone.fulfill() })
        wait(for: [pageDone, deleteDone], timeout: defaultWaitTimeout)

        XCTAssertNil(storedChannel(id: lastId), "the deleted channel must stay deleted")
        XCTAssertEqual(storedChannelCount(), 24)
        XCTAssertEqual(page?.count, 25, "paging and the sweep still see the whole page")
        XCTAssertEqual(stored?.map(\.id).contains(lastId), false,
                       "the deleted channel gets no message catch-up")
        XCTAssertEqual(stored?.count, 24)
    }

    /// A stored channel deleted between two chunks: the delete is recorded when its save commits.
    func testStoredChannelDeletedBetweenChunks_isNotBroughtBack() {
        let lastId = ChannelId(10_025)
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            ctx.createOrUpdate(channel: plainChannel(id: lastId))
            try? ctx.save()
        }
        let pageDone = expectation(description: "page stored")
        let deleteDone = expectation(description: "delete stored")

        ChannelListProvider().store(channels: page(of: 25)) { _ in pageDone.fulfill() }
        // What `deleteChannel(id:)` does to a stored row (minus its merge into
        // `SceytChatUIKit.shared.database`, which a test store cannot share).
        database.write({ ctx in
            ChannelDTO.fetch(id: lastId, context: ctx).map(ctx.delete)
        }, completion: { _ in deleteDone.fulfill() })
        wait(for: [pageDone, deleteDone], timeout: defaultWaitTimeout)

        XCTAssertNil(storedChannel(id: lastId), "the deleted channel must stay deleted")
        XCTAssertEqual(storedChannelCount(), 24)
    }

    /// A delete that rolls back is not recorded: the channel still exists and later chunks must
    /// keep updating it.
    func testRolledBackDelete_doesNotSkipTheChannel() {
        let pageDone = expectation(description: "page stored")
        let deleteDone = expectation(description: "delete rolled back")
        let lastId = ChannelId(10_025)
        let channels = page(of: 25)
        channels.last?.setValue("from page", forKey: "subject")

        ChannelListProvider().store(channels: channels) { _ in pageDone.fulfill() }
        database.write({ ctx in
            ctx.createOrUpdate(channel: self.plainChannel(id: lastId))
            ChannelDTO.fetch(id: lastId, context: ctx).map(ctx.delete)
            // The write fails, as `PersistentContainer.write` does on an error: nothing is saved.
            ctx.rollback()
            throw NSError(domain: "test", code: 1)
        }, completion: { _ in deleteDone.fulfill() })
        wait(for: [pageDone, deleteDone], timeout: defaultWaitTimeout)

        XCTAssertEqual(storedChannel(id: lastId)?.subject, "from page")
        XCTAssertEqual(storedChannelCount(), 25)
    }

    /// A newer copy that was already stored before the page started is updated by the page as
    /// usual: only changes made while the page is being stored are protected.
    func testNewerCopyStoredBeforeThePage_isStillUpdatedByIt() {
        let lastId = ChannelId(10_025)
        let before = plainChannel(id: lastId)
        before.setValue(Date(timeIntervalSince1970: 1_790_000_100), forKey: "updatedAt")
        before.setValue("before", forKey: "subject")
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            ctx.createOrUpdate(channel: before)
            try? ctx.save()
        }
        let channels = page(of: 25)
        channels.last?.setValue(Date(timeIntervalSince1970: 1_790_000_000), forKey: "updatedAt")
        channels.last?.setValue("from page", forKey: "subject")

        let done = expectation(description: "page stored")
        ChannelListProvider().store(channels: channels) { _ in done.fulfill() }
        wait(for: [done], timeout: defaultWaitTimeout)

        XCTAssertEqual(storedChannel(id: lastId)?.subject, "from page")
    }

    /// An update event stored between two chunks is newer than the page and must not be
    /// overwritten by it.
    func testChannelUpdatedBetweenChunks_isNotOverwritten() {
        let pageDone = expectation(description: "page stored")
        let updateDone = expectation(description: "update stored")
        let lastId = ChannelId(10_025)
        let channels = page(of: 25)
        channels.last?.setValue(Date(timeIntervalSince1970: 1_790_000_000), forKey: "updatedAt")
        channels.last?.setValue("old", forKey: "subject")
        let updated = plainChannel(id: lastId)
        updated.setValue(Date(timeIntervalSince1970: 1_790_000_100), forKey: "updatedAt")
        updated.setValue("new", forKey: "subject")

        ChannelListProvider().store(channels: channels) { _ in pageDone.fulfill() }
        database.write({ $0.createOrUpdate(channel: updated) }, completion: { _ in updateDone.fulfill() })
        wait(for: [pageDone, updateDone], timeout: defaultWaitTimeout)

        XCTAssertEqual(storedChannel(id: lastId)?.subject, "new")
        XCTAssertEqual(storedChannelCount(), 25)
    }

    /// The page's copy still wins over an older stored copy.
    func testOlderStoredCopy_isUpdatedByThePage() {
        let old = plainChannel(id: 10_001)
        old.setValue(Date(timeIntervalSince1970: 1_790_000_000), forKey: "updatedAt")
        old.setValue("old", forKey: "subject")
        let fresh = plainChannel(id: 10_001)
        fresh.setValue(Date(timeIntervalSince1970: 1_790_000_100), forKey: "updatedAt")
        fresh.setValue("new", forKey: "subject")
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            ctx.createOrUpdate(channel: old)
            try? ctx.save()
        }

        let done = expectation(description: "page stored")
        ChannelListProvider().store(channels: [fresh]) { _ in done.fulfill() }
        wait(for: [done], timeout: defaultWaitTimeout)

        XCTAssertEqual(storedChannel(id: 10_001)?.subject, "new")
    }

    /// A failed chunk does not stop the rest of the page; the error is reported once at the end
    /// and the page is not reported as stored.
    func testFailedChunk_restOfPageIsStillStored() {
        database.failingWriteNumber = 2
        let provider = ChannelListProvider()
        var reported = false
        provider.onStoreChannels = { _, _ in reported = true }
        let done = expectation(description: "page stored")
        var reportedError: Error?
        provider.store(channels: page(of: 25)) { error in
            reportedError = error
            done.fulfill()
        }
        wait(for: [done], timeout: defaultWaitTimeout)

        XCTAssertNotNil(reportedError)
        XCTAssertFalse(reported)
        XCTAssertEqual(database.calls, ["write", "write", "write"])
        XCTAssertEqual(storedChannelCount(), 15, "chunks 1 and 3 are stored, chunk 2 failed")
    }

    /// The hops between chunks must not wait for the main thread; only the final completion
    /// is delivered there.
    func testChunkHops_doNotGoThroughMain() {
        let done = expectation(description: "page stored")
        ChannelListProvider().store(channels: page(of: 25)) { _ in
            XCTAssertTrue(Thread.isMainThread)
            done.fulfill()
        }
        wait(for: [done], timeout: defaultWaitTimeout)

        XCTAssertEqual(database.writeResultQueuesOnMain, [false, false, false])
    }

    /// A full sync is stored in chunks too, so other writes are not held back by all of it.
    func testStoreChannelsOperation_largeSync_isStoredInChunks() {
        let operation = StoreChannelsOperation(database: database, channels: page(of: 25))
        let finished = expectation(description: "operation finished")
        operation.completionBlock = { finished.fulfill() }
        OperationQueue().addOperation(operation)
        wait(for: [finished], timeout: defaultWaitTimeout)

        XCTAssertEqual(database.calls, ["write", "write", "write"])
        XCTAssertEqual(storedChannelCount(), 25)
    }

    /// End to end: the chat-list page and the chat's first message page store the same message
    /// back to back, as they do right after a cold launch. One attachment must come out.
    func testChannelListAndMessagePage_storeTheSameMessage_keepOneAttachment() {
        let listDone = expectation(description: "channel list stored")
        let pageDone = expectation(description: "message page stored")

        ChannelListProvider().store(channels: [serverChannel(lastMessage: serverMessage())]) { _ in
            listDone.fulfill()
        }
        ChannelMessageProvider(channelId: channelId).store(messages: [serverMessage()]) { _ in
            pageDone.fulfill()
        }
        wait(for: [listDone, pageDone], timeout: 5)

        XCTAssertEqual(storedAttachmentCount(), 1)
    }
}

/// Forwards to `MockDatabase`, records which write API each caller used, and gives
/// `performWriteTask` a context of its own like `PersistentContainer` does (MockDatabase routes it
/// through the serial context, which would hide the race).
private final class RecordingDatabase: Database {

    let inner: MockDatabase
    private let lock = NSLock()
    private var _calls: [String] = []
    var calls: [String] { lock.lock(); defer { lock.unlock() }; return _calls }

    init(inner: MockDatabase) { self.inner = inner }

    private var _writeResultQueuesOnMain: [Bool] = []
    /// For each `write`, whether its completion was asked for on the main queue.
    var writeResultQueuesOnMain: [Bool] { lock.lock(); defer { lock.unlock() }; return _writeResultQueuesOnMain }
    /// 1-based number of the `write` whose block throws (and whose changes are rolled back).
    var failingWriteNumber: Int?

    private func record(_ call: String) { lock.lock(); _calls.append(call); lock.unlock() }

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?) {
        lock.lock()
        _calls.append("write")
        _writeResultQueuesOnMain.append(resultQueue === DispatchQueue.main)
        let shouldFail = failingWriteNumber == _calls.filter { $0 == "write" }.count
        lock.unlock()
        guard shouldFail else {
            inner.write(resultQueue: resultQueue, perform, completion: completion)
            return
        }
        inner.write(resultQueue: resultQueue, { ctx in
            try perform(ctx)
            ctx.rollback()
            throw NSError(domain: "RecordingDatabase", code: 1)
        }, completion: completion)
    }

    func performWriteTask(resultQueue: DispatchQueue,
                          _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)?) {
        record("performWriteTask")
        let ctx = inner.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.perform {
            do {
                try perform(ctx)
                if ctx.hasChanges { try ctx.save() }
                resultQueue.async { completion?(nil) }
            } catch {
                resultQueue.async { completion?(error) }
            }
        }
    }

    func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws {
        try inner.syncWrite(perform)
    }

    func read<Fetch>(resultQueue: DispatchQueue,
                     _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?) {
        inner.read(resultQueue: resultQueue, perform, completion: completion)
    }

    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error> {
        inner.read(perform)
    }

    func performBgTask<Fetch>(resultQueue: DispatchQueue,
                              _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                              completion: ((Result<Fetch, Error>) -> Void)?) {
        inner.performBgTask(resultQueue: resultQueue, perform, completion: completion)
    }

    var viewContext: NSManagedObjectContext { inner.viewContext }
    var backgroundPerformContext: NSManagedObjectContext { inner.backgroundPerformContext }
    var backgroundReadOnlyContext: NSManagedObjectContext { inner.backgroundReadOnlyContext }
    var backgroundReadOnlyObservableContext: NSManagedObjectContext { inner.backgroundReadOnlyObservableContext }

    func recreate(completion: @escaping ((Error?) -> Void)) { inner.recreate(completion: completion) }
    func deleteAll(completion: (() -> Void)?) { inner.deleteAll(completion: completion) }
}
