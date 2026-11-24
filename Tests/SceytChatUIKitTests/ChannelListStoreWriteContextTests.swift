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

    private func record(_ call: String) { lock.lock(); _calls.append(call); lock.unlock() }

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?) {
        record("write")
        inner.write(resultQueue: resultQueue, perform, completion: completion)
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
