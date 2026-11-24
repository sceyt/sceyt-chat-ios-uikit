//
//  StorePendingSerializationTests.swift
//  SceytChatUIKitTests
//
//  `storePending` stores a new outgoing message at `max(phone time, newest list row + 1 ms)` so
//  it never sorts above a message received just before it (MessageOrderClockSkewTests). It runs
//  on `performWriteTask` — a context of its own per call, so a send never waits behind a
//  channel-list page on the serial context (channel_save_performance_findings.md).
//
//  Two `storePending` calls running at the same time could then both read the same newest row
//  and both store newest + 1 ms: same `createdAt`, both `id == 0`, so their order in the list was
//  undefined. `storePending` calls now wait for each other (and only for each other).
//
//  `BarrierDatabase` makes the race deterministic: every `performWriteTask` holds its save until
//  a second one has run its block too (or 0.3 s passed), the interleaving that produced the tie.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class StorePendingSerializationTests: XCTestCase {

    private var inner: MockDatabase!
    private var database: BarrierDatabase!
    private var originalDatabase: Database!

    private let channelId: ChannelId = 740_046
    private let receivedId: MessageId = 884_559_669_371_215_872
    private let t0 = Date(timeIntervalSince1970: 1_795_000_000)
    private let phoneBehind: TimeInterval = 18.7

    override func setUp() {
        super.setUp()
        inner = MockDatabase()
        database = BarrierDatabase(inner: inner)
        originalDatabase = DataProvider.database
        DataProvider.database = database
        let ctx = inner.backgroundPerformContext
        ctx.performAndWait {
            _ = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
            let received = Message.Builder().id(receivedId).tid(Int(receivedId)).type("text").body("Message 1").build()
            received.setValue(true, forKey: "incoming")
            received.setValue(t0, forKey: "createdAt")
            received.setValue(MessageDeliveryStatus.sent.rawValue, forKey: "deliveryStatus")
            ctx.createOrUpdate(message: received, channelId: channelId)
            try? ctx.save()
        }
    }

    override func tearDown() {
        DataProvider.database = originalDatabase
        database = nil
        inner = nil
        super.tearDown()
    }

    private func pendingMessage(tid: Int, phoneCreatedAt: Date, body: String) -> Message {
        let message = Message.Builder().tid(tid).type("text").body(body).build()
        message.setValue(false, forKey: "incoming")
        message.setValue(phoneCreatedAt, forKey: "createdAt")
        message.setValue(MessageDeliveryStatus.pending.rawValue, forKey: "deliveryStatus")
        return message
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

    /// Two sends stored at the same time (a system message and a user send, the share extension
    /// and the app) must get distinct times, in call order, both below the received message.
    func testConcurrentStorePending_getDistinctTimesInCallOrder() {
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

        let rows = listRows()
        XCTAssertEqual(rows.map(\.body), ["Message 1", "first", "second"])
        let first = rows.first { $0.body == "first" }?.createdAt.bridgeDate
        let second = rows.first { $0.body == "second" }?.createdAt.bridgeDate
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        if let first, let second {
            XCTAssertLessThan(first, second, "the two pending messages must not share a createdAt")
        }
    }

    /// A store whose write never reports back must not block later sends forever.
    func testStorePending_doesNotWaitForeverOnAStuckWrite() {
        ChannelMessageProvider.pendingStoreTimeout = 0.5
        defer { ChannelMessageProvider.pendingStoreTimeout = ChannelMessageProvider.defaultPendingStoreTimeout }
        database.dropNextCompletion = true

        let provider = ChannelMessageProvider(channelId: channelId)
        provider.storePending(message: pendingMessage(tid: 7_101, phoneCreatedAt: t0, body: "stuck")) { _ in }
        let laterDone = expectation(description: "later stored")
        provider.storePending(message: pendingMessage(tid: 7_102, phoneCreatedAt: t0, body: "later")) { _ in
            laterDone.fulfill()
        }
        wait(for: [laterDone], timeout: defaultWaitTimeout)
    }
}

/// `MockDatabase` with a `performWriteTask` that, like `PersistentContainer`, uses a context of
/// its own per call — and holds each save until a second `performWriteTask` has run its block
/// (or 0.3 s passed), the interleaving that made two concurrent `storePending` calls tie.
private final class BarrierDatabase: Database {

    let inner: MockDatabase
    private let lock = NSLock()
    private var arrived = 0
    private let bothArrived = DispatchSemaphore(value: 0)
    /// The next `performWriteTask` never calls its completion (a stuck write).
    var dropNextCompletion = false

    init(inner: MockDatabase) { self.inner = inner }

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?) {
        inner.write(resultQueue: resultQueue, perform, completion: completion)
    }

    func performWriteTask(resultQueue: DispatchQueue,
                          _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)?) {
        lock.lock()
        let drop = dropNextCompletion
        dropNextCompletion = false
        lock.unlock()
        let ctx = inner.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.perform { [self] in
            do {
                try perform(ctx)
                lock.lock()
                arrived += 1
                let count = arrived
                lock.unlock()
                if count == 2 {
                    bothArrived.signal()
                    bothArrived.signal()
                }
                _ = bothArrived.wait(timeout: .now() + 0.3)
                if ctx.hasChanges { try ctx.save() }
                if !drop { resultQueue.async { completion?(nil) } }
            } catch {
                if !drop { resultQueue.async { completion?(error) } }
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
