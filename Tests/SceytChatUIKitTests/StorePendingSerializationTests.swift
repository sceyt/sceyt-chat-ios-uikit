//
//  StorePendingSerializationTests.swift
//  SceytChatUIKitTests
//
//  `storePending` stores a new outgoing message at `max(phone time, newest list row + 1 ms)` so
//  it never sorts above a message received just before it (MessageOrderClockSkewTests).
//
//  That lookup is only right if it sees every write queued before it. It runs on the serial
//  writer (`database.write`), the context that also stores incoming messages, send acks and
//  message pages. On a context of its own (`performWriteTask`) it missed an incoming row that
//  had not committed yet, and two pending stores could both read the same newest row and tie.
//
//  `SplitContextDatabase` makes `performWriteTask` use a context of its own per call, as
//  `PersistentContainer` does (`MockDatabase` routes it to the serial writer, which would hide
//  the race).
//
//  Also covered: the caller's `Message` is never written to, and a thread reply is placed
//  against its thread's replies, not the channel's main list.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class StorePendingSerializationTests: XCTestCase {

    private var inner: MockDatabase!
    private var database: SplitContextDatabase!
    private var originalDatabase: Database!

    private let channelId: ChannelId = 740_046
    private let receivedId: MessageId = 884_559_669_371_215_872
    private let threadRootId: MessageId = 884_559_600_000_000_000
    private let threadReplyId: MessageId = 884_559_640_000_000_000
    private let t0 = Date(timeIntervalSince1970: 1_795_000_000)
    private let phoneBehind: TimeInterval = 18.7

    override func setUp() {
        super.setUp()
        inner = MockDatabase()
        database = SplitContextDatabase(inner: inner)
        originalDatabase = DataProvider.database
        DataProvider.database = database
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            _ = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
            try? ctx.save()
        }
    }

    override func tearDown() {
        DataProvider.database = originalDatabase
        database = nil
        inner = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func serverMessage(id: MessageId, createdAt: Date, body: String, inThread: Bool = false) -> Message {
        let builder = Message.Builder().id(id).tid(Int(id)).type("text").body(body)
        if inThread {
            builder.parentMessageId(threadRootId)
            builder.replyInThread(true)
        }
        let message = builder.build()
        message.setValue(true, forKey: "incoming")
        message.setValue(createdAt, forKey: "createdAt")
        message.setValue(MessageDeliveryStatus.sent.rawValue, forKey: "deliveryStatus")
        return message
    }

    private func pendingMessage(tid: Int, phoneCreatedAt: Date, body: String, inThread: Bool = false) -> Message {
        let builder = Message.Builder().tid(tid).type("text").body(body)
        if inThread {
            builder.parentMessageId(threadRootId)
            builder.replyInThread(true)
        }
        let message = builder.build()
        message.setValue(false, forKey: "incoming")
        message.setValue(phoneCreatedAt, forKey: "createdAt")
        message.setValue(MessageDeliveryStatus.pending.rawValue, forKey: "deliveryStatus")
        return message
    }

    /// Writes on the serial writer and waits for the save.
    private func write(_ messages: Message...) {
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            for message in messages {
                ctx.createOrUpdate(message: message, channelId: channelId)
            }
            try? ctx.save()
        }
    }

    /// Stores the thread root and one reply in it (the reply linked to its root, as a sync does).
    private func writeThread(replyCreatedAt: Date) {
        write(serverMessage(id: threadRootId, createdAt: t0.addingTimeInterval(-100), body: "root"))
        write(serverMessage(id: threadReplyId, createdAt: replyCreatedAt, body: "reply", inThread: true))
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            let reply = MessageDTO.fetch(id: threadReplyId, context: ctx)
            reply?.parent = MessageDTO.fetch(id: threadRootId, context: ctx)
            try? ctx.save()
        }
    }

    private func storePending(_ message: Message, threadMessageId: MessageId? = nil) {
        let done = expectation(description: "storePending")
        ChannelMessageProvider(channelId: channelId, threadMessageId: threadMessageId)
            .storePending(message: message) { error in
                XCTAssertNil(error)
                done.fulfill()
            }
        wait(for: [done], timeout: defaultWaitTimeout)
    }

    private func createdAt(tid: Int) -> Date? {
        let ctx = inner.container.viewContext
        ctx.refreshAllObjects()
        let request = MessageDTO.fetchRequest()
        request.predicate = NSPredicate(format: "tid == %lld", Int64(tid))
        return (try? ctx.fetch(request))?.first?.createdAt.bridgeDate
    }

    private func listRows() -> [MessageDTO] {
        let ctx = inner.container.viewContext
        ctx.refreshAllObjects()
        let request = MessageDTO.fetchRequest()
        request.predicate = LazyMessagesObserver.listPredicate(channelId: channelId)
        request.sortDescriptors = [
            .init(keyPath: \MessageDTO.createdAt, ascending: true),
            .init(keyPath: \MessageDTO.id, ascending: true)
        ]
        return (try? ctx.fetch(request)) ?? []
    }

    // MARK: - Ordering against other writes

    /// Two sends stored at the same time (a system message and a user send, the share extension
    /// and the app) must get distinct times, in call order, both below the received message.
    func testConcurrentStorePending_getDistinctTimesInCallOrder() {
        write(serverMessage(id: receivedId, createdAt: t0, body: "Message 1"))
        let firstDone = expectation(description: "first stored")
        let secondDone = expectation(description: "second stored")
        let provider = ChannelMessageProvider(channelId: channelId)

        provider.storePending(message: pendingMessage(tid: 7_001, phoneCreatedAt: t0.addingTimeInterval(1 - phoneBehind), body: "first")) { _ in
            firstDone.fulfill()
        }
        provider.storePending(message: pendingMessage(tid: 7_002, phoneCreatedAt: t0.addingTimeInterval(2 - phoneBehind), body: "second")) { _ in
            secondDone.fulfill()
        }
        wait(for: [firstDone, secondDone], timeout: defaultWaitTimeout)

        XCTAssertEqual(listRows().map(\.body), ["Message 1", "first", "second"])
        if let first = createdAt(tid: 7_001), let second = createdAt(tid: 7_002) {
            XCTAssertLessThan(first, second, "the two pending messages must not share a createdAt")
        } else {
            XCTFail("both pending rows must be stored")
        }
    }

    /// A message received just before the send, still being written on the serial writer when
    /// `storePending` is called, must be seen: the sent message goes below it.
    func testStorePending_seesIncomingStillBeingWritten() {
        let received = serverMessage(id: receivedId, createdAt: t0, body: "Message 1")
        let incomingQueued = expectation(description: "incoming stored")
        // A slow incoming write: still uncommitted for 0.3 s after `storePending` is called.
        database.write({ ctx in
            ctx.createOrUpdate(message: received, channelId: self.channelId)
            Thread.sleep(forTimeInterval: 0.3)
        }, completion: { _ in incomingQueued.fulfill() })

        storePending(pendingMessage(tid: 7_201, phoneCreatedAt: t0.addingTimeInterval(3.8 - phoneBehind), body: "2"))
        wait(for: [incomingQueued], timeout: defaultWaitTimeout)

        XCTAssertEqual(listRows().map(\.body), ["Message 1", "2"])
    }

    // MARK: - The caller's message

    /// The time is moved on the stored row only. The caller keeps using its `Message` (send
    /// payload, in-memory model) on other threads, so `storePending` must not write to it.
    func testStorePending_doesNotChangeCallersMessage() {
        write(serverMessage(id: receivedId, createdAt: t0, body: "Message 1"))
        let phoneTime = t0.addingTimeInterval(3.8 - phoneBehind)
        let message = pendingMessage(tid: 7_301, phoneCreatedAt: phoneTime, body: "2")

        storePending(message)

        XCTAssertEqual(message.createdAt.timeIntervalSince1970, phoneTime.timeIntervalSince1970, accuracy: 0.0001)
        XCTAssertGreaterThan(createdAt(tid: 7_301) ?? .distantPast, t0, "the stored row is still moved below the received message")
    }

    // MARK: - Threads

    /// A thread reply is placed against its thread's replies: a newer main-channel message must
    /// not push it forward.
    func testThreadReply_ignoresNewerMainChannelMessage() {
        writeThread(replyCreatedAt: t0.addingTimeInterval(-50))
        write(serverMessage(id: receivedId, createdAt: t0, body: "Message 1"))
        let phoneTime = t0.addingTimeInterval(-40)

        storePending(pendingMessage(tid: 7_401, phoneCreatedAt: phoneTime, body: "my reply", inThread: true),
                     threadMessageId: threadRootId)

        XCTAssertEqual(createdAt(tid: 7_401)?.timeIntervalSince1970 ?? 0, phoneTime.timeIntervalSince1970, accuracy: 0.001)
    }

    /// A thread reply stamped before the thread's newest reply goes just below it.
    func testThreadReply_placedAfterNewestReplyInThread() {
        let newestReply = t0.addingTimeInterval(-50)
        writeThread(replyCreatedAt: newestReply)

        storePending(pendingMessage(tid: 7_402, phoneCreatedAt: t0.addingTimeInterval(-60), body: "my reply", inThread: true),
                     threadMessageId: threadRootId)

        XCTAssertEqual(createdAt(tid: 7_402)?.timeIntervalSince1970 ?? 0,
                       newestReply.addingTimeInterval(0.001).timeIntervalSince1970, accuracy: 0.0005)
    }

    /// A main-list message is not moved by a newer thread reply (replies are not in that list).
    func testMainListMessage_ignoresNewerThreadReply() {
        writeThread(replyCreatedAt: t0)
        let phoneTime = t0.addingTimeInterval(-40)

        storePending(pendingMessage(tid: 7_403, phoneCreatedAt: phoneTime, body: "2"))

        XCTAssertEqual(createdAt(tid: 7_403)?.timeIntervalSince1970 ?? 0, phoneTime.timeIntervalSince1970, accuracy: 0.001)
    }
}

/// `MockDatabase` whose `performWriteTask` uses a context of its own per call, like
/// `PersistentContainer`; `write` stays on the shared serial context.
private final class SplitContextDatabase: Database {

    let inner: MockDatabase

    init(inner: MockDatabase) { self.inner = inner }

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?) {
        inner.write(resultQueue: resultQueue, perform, completion: completion)
    }

    func performWriteTask(resultQueue: DispatchQueue,
                          _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)?) {
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
