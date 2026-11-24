//
//  OwnDeviceMessageDuplicateRaceTests.swift
//  SceytChatUIKitTests
//
//  Core Data mechanism behind: "a message sent from another device shows twice for a moment
//  after a cold launch, then collapses to one" (2026-11-19).
//
//  Two writers stored the same server message on DIFFERENT contexts at the same time — the
//  chat-list page (`channel.lastMessage`, then on `performWriteTask`) and the chat's first
//  message page (serial `write`). Both `MessageDTO.fetchOrCreate` calls miss, both insert. The
//  MessageDTO rows are identical and merge through the uniqueness constraint
//  (id, tid, createdAt, channelId, replied, repliedInThread, unlisted); the AttachmentDTO rows
//  have no constraint and both survive on the merged message, so its cell draws the attachment
//  twice until the next write of the message replaces the relationship.
//
//  The fix moved the chat-list writers to the serial context; ChannelListStoreWriteContextTests
//  guards that. These tests document the underlying behaviour on raw contexts.
//
//  These tests pin the interleaving deterministically (fetch on both contexts before either
//  saves) instead of relying on real thread timing.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class OwnDeviceMessageDuplicateRaceTests: XCTestCase {

    private var mockDB: MockDatabase!
    private let channelId: ChannelId = 77
    private let messageId: MessageId = 9_001
    private let webTid = 555_123
    private let serverCreatedAt = Date(timeIntervalSince1970: 1_794_000_000)

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        let ctx = mockDB.container.viewContext
        _ = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        try? ctx.save()
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// An outgoing (sent by *this* account on another device) view-once image message, as the
    /// server delivers it. `incoming` and `createdAt` are read-only on the SDK type, so they are
    /// set through KVC the way the SDK's own decoder fills them.
    private func ownDeviceViewOnceMessage(tid: Int, createdAt: Date? = nil) -> Message {
        let attachment = Attachment.Builder(url: "https://cdn.example/viewonce.jpg", type: "image")
            .name("viewonce.jpg")
            .build()
        let message = Message.Builder()
            .id(messageId)
            .tid(tid)
            .type("media")
            .body("")
            .viewOnce(true)
            .attachments([attachment])
            .build()
        message.setValue(false, forKey: "incoming")
        message.setValue(createdAt ?? serverCreatedAt, forKey: "createdAt")
        return message
    }

    /// A context configured like `PersistentContainer.createBackgroundContext()` — what
    /// `performWriteTask` uses for every call.
    private func freshWriteContext() -> NSManagedObjectContext {
        let ctx = mockDB.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }

    /// Rows the chat screen would render for this message: the same predicate as
    /// `LazyMessagesObserver`, narrowed to the message id.
    private func visibleRows(for id: MessageId) -> [MessageDTO] {
        let ctx = mockDB.container.viewContext
        ctx.refreshAllObjects()
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = NSPredicate(
            format: "channelId == %lld AND repliedInThread == false AND replied == false AND unlisted == false AND id == %lld",
            channelId, id
        )
        return MessageDTO.fetch(request: request, context: ctx)
    }

    /// Runs both writers with the race interleaving: each upserts on its own context, and only
    /// then do they save — event writer first, channel-sync writer second.
    private func race(eventPayload: Message, channelSyncPayload: Message,
                      file: StaticString = #filePath, line: UInt = #line) {
        let eventContext = mockDB.backgroundPerformContext   // database.write
        let syncContext = freshWriteContext()                  // database.performWriteTask

        eventContext.performAndWait {
            eventContext.createOrUpdate(message: eventPayload, channelId: channelId)
        }
        syncContext.performAndWait {
            syncContext.createOrUpdate(message: channelSyncPayload, channelId: channelId)
        }
        var eventError: Error?
        eventContext.performAndWait {
            do { try eventContext.save() } catch { eventError = error }
        }
        var syncError: Error?
        syncContext.performAndWait {
            do { try syncContext.save() } catch { syncError = error }
        }
        XCTAssertNil(eventError, "event save failed: \(String(describing: eventError))", file: file, line: line)
        XCTAssertNil(syncError, "channel-sync save failed: \(String(describing: syncError))", file: file, line: line)
    }

    private func describe(_ rows: [MessageDTO]) -> String {
        rows.map { "id=\($0.id) tid=\($0.tid) createdAt=\($0.createdAt.timeIntervalSince1970) viewOnce=\($0.viewOnce) attachments=\($0.attachments?.count ?? 0)" }
            .joined(separator: " | ")
    }

    // MARK: - Control: no race, no duplicate

    /// Same two writers, run one after the other. `fetchOrCreate` matches by id, so this must
    /// always be a single row — if it isn't, the bug is not a race.
    func testSequentialWriters_storeOneRow() {
        let eventContext = mockDB.backgroundPerformContext
        eventContext.performAndWait {
            eventContext.createOrUpdate(message: ownDeviceViewOnceMessage(tid: webTid), channelId: channelId)
            try? eventContext.save()
        }
        let syncContext = freshWriteContext()
        syncContext.performAndWait {
            syncContext.createOrUpdate(message: ownDeviceViewOnceMessage(tid: 0), channelId: channelId)
            try? syncContext.save()
        }

        let rows = visibleRows(for: messageId)
        XCTAssertEqual(rows.count, 1, describe(rows))
    }

    // MARK: - Race reproductions

    /// Both writers carry byte-identical payloads. The uniqueness constraint should merge the
    /// two inserts into one row.
    func testRace_identicalPayloads() {
        race(eventPayload: ownDeviceViewOnceMessage(tid: webTid),
             channelSyncPayload: ownDeviceViewOnceMessage(tid: webTid))

        let rows = visibleRows(for: messageId)
        XCTAssertEqual(rows.count, 1, "Duplicate rows for one server message: \(describe(rows))")
    }

    // MARK: - The attachment, not the message, is what doubles

    /// Documents WHY writers of the same message must share the serial context (see
    /// ChannelListStoreWriteContextTests for the guard on the real writers). Device logs
    /// (17:34:14) showed one cell completing the download on TWO attachment views while the
    /// message was stored once: identical payloads merge the MessageDTO rows through the
    /// uniqueness constraint, but AttachmentDTO has none, so each context's attachment row
    /// survives and both end up on the merged message. If this ever starts asserting 1, Core Data
    /// or the model changed (e.g. an AttachmentDTO constraint was added).
    func testRace_separateContexts_mergeTheMessageButDoubleItsAttachment() {
        race(eventPayload: ownDeviceViewOnceMessage(tid: webTid),
             channelSyncPayload: ownDeviceViewOnceMessage(tid: webTid))

        let rows = visibleRows(for: messageId)
        XCTAssertEqual(rows.count, 1, "message rows: \(describe(rows))")
        XCTAssertEqual(rows.first?.attachments?.count, 2,
                       "Two contexts inserting one message leave it with two attachment rows")
    }

    /// And the collapse: the next write of the message replaces the relationship with the
    /// payload's single attachment.
    func testRace_nextWriteDropsTheExtraAttachment() {
        race(eventPayload: ownDeviceViewOnceMessage(tid: webTid),
             channelSyncPayload: ownDeviceViewOnceMessage(tid: webTid))
        let before = visibleRows(for: messageId).first?.attachments?.count ?? 0

        let ctx = mockDB.backgroundPerformContext
        ctx.performAndWait {
            ctx.createOrUpdate(message: ownDeviceViewOnceMessage(tid: webTid), channelId: channelId)
            try? ctx.save()
        }
        let after = visibleRows(for: messageId).first?.attachments?.count ?? 0
        XCTAssertEqual(before, 2, "precondition: the race doubled the attachment")
        XCTAssertEqual(after, 1)
    }
}
