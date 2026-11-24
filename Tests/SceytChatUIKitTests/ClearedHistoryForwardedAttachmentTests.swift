//
//  ClearedHistoryForwardedAttachmentTests.swift
//  SceytChatUIKitTests
//
//  Reproduction for "after killing and reopening the app on a poor network, the first chat
//  open shows forwarded attachment messages with a broken UI" (empty bubble: only the
//  "Forwarded message" header and a media-style time pill hanging off the left edge).
//
//  Chain under test:
//  1. `createOrUpdate(attachments:dto:)` maps a NEW AttachmentDTO before it is attached to its
//     message, so `AttachmentDTO.map` keeps the SERVER attachment `createdAt`. For a forwarded
//     file that is the original upload time, which can be older than the forwarded message.
//  2. Every channel write that carries `messagesClearedAt` (channel sync after relaunch) runs
//     `deleteAllMessages(channelId:before:)`, which keeps messages newer than the clear date
//     but sweeps attachments by the ATTACHMENT's own `createdAt` (`deleteAllAttachments`).
//  3. The forwarded message (newer than the clear) survives with zero attachments, so its
//     layout model has empty `contentOptions`; `isForwarded` skips the " " text fallback and the
//     outgoing cell lands in its final `else` branch (pill shown, attachmentView width 0).
//  4. The UI recovers only when the server page for the channel arrives and recreates the
//     rows — which on a poor network takes long enough to be seen.
//
//  These tests encode the EXPECTED behaviour, so they FAIL while the bug is present.
//
//  They run against `SceytChatUIKit.shared.database` instead of `MockDatabase`, because the
//  sweep is an `NSBatchDeleteRequest` that merges into the shared database's contexts.
//

@testable import SceytChatUIKit
import CoreData
import ObjectiveC
import SceytChat
import UIKit
import XCTest

final class ClearedHistoryForwardedAttachmentTests: XCTestCase {

    // Unique ids so the shared database is not polluted for other suites.
    private let channelId: ChannelId = 9_420_001
    private let forwardedMessageId: MessageId = 9_420_101
    private let forwardedAttachmentId: AttachmentId = 9_420_201
    private let freshMessageId: MessageId = 9_420_102
    private let freshAttachmentId: AttachmentId = 9_420_202

    /// Original upload of the file that was later forwarded.
    private let originalUploadDate = Date(timeIntervalSince1970: 1_700_000_000)
    /// The user cleared the chat history here.
    private let messagesClearedAt = Date(timeIntervalSince1970: 1_700_100_000)
    /// The file was forwarded into the chat after the clear.
    private let forwardedAt = Date(timeIntervalSince1970: 1_700_200_000)

    private var context: NSManagedObjectContext {
        SceytChatUIKit.shared.database.backgroundPerformContext
    }

    override func tearDown() {
        let context = context
        let channelId = channelId
        context.performAndWait {
            let messages = MessageDTO.fetchRequest()
            messages.predicate = .init(format: "channelId == %lld", Int64(channelId))
            (try? context.fetch(messages))?.forEach { context.delete($0) }
            let attachments = AttachmentDTO.fetchRequest()
            attachments.predicate = .init(format: "channelId == %lld", Int64(channelId))
            (try? context.fetch(attachments))?.forEach { context.delete($0) }
            try? context.save()
        }
        super.tearDown()
    }

    // MARK: - Fixtures

    /// The SDK has no public way to set server-assigned fields; set them the way the server
    /// payload fills them (same technique as `OfflineImageResendTests`).
    private func serverAttachment(id: AttachmentId, url: String, createdAt: Date) throws -> Attachment {
        try XCTSkipIf(class_getInstanceVariable(Attachment.self, "_id") == nil
                      || class_getInstanceVariable(Attachment.self, "_createdAt") == nil,
                      "SCTAttachment no longer stores id/createdAt in _id/_createdAt")
        let attachment = Attachment.Builder(url: url, type: "file").name("IMG_1420-6.HEIC").build()
        attachment.setValue(NSNumber(value: id), forKey: "id")
        attachment.setValue(NSNumber(value: 0), forKey: "tid")
        attachment.setValue(createdAt, forKey: "createdAt")
        return attachment
    }

    private func serverMessage(id: MessageId, createdAt: Date, attachments: [Attachment]) throws -> Message {
        try XCTSkipIf(class_getInstanceVariable(Message.self, "_createdAt") == nil,
                      "SCTMessage no longer stores createdAt in _createdAt")
        let message = Message.Builder()
            .id(id)
            .tid(0)
            .body("")
            .type("file")
            .attachments(attachments)
            .build()
        message.setValue(createdAt, forKey: "createdAt")
        return message
    }

    /// Stores both messages the way a server page / channel sync does, then runs the sweep the
    /// channel write performs for `messagesClearedAt`.
    private func storeMessagesThenSyncChannelWithClearedHistory() throws {
        let forwarded = try serverMessage(
            id: forwardedMessageId,
            createdAt: forwardedAt,
            attachments: [try serverAttachment(id: forwardedAttachmentId,
                                               url: "https://cdn.example/IMG_1420-6.HEIC",
                                               createdAt: originalUploadDate)]
        )
        let fresh = try serverMessage(
            id: freshMessageId,
            createdAt: forwardedAt,
            attachments: [try serverAttachment(id: freshAttachmentId,
                                               url: "https://cdn.example/fresh.HEIC",
                                               createdAt: forwardedAt)]
        )

        let context = context
        let channelId = channelId
        let clearedAt = messagesClearedAt
        var thrown: Error?
        context.performAndWait {
            let (channel, _) = ChannelDTO.fetchOrCreate(id: channelId, context: context)
            channel.createdAt = Date(timeIntervalSince1970: 1_600_000_000).bridgeDate
            channel.type = "group"
            context.createOrUpdate(message: forwarded, channelId: channelId)
            context.createOrUpdate(message: fresh, channelId: channelId)
            do { try context.save() } catch { thrown = error }

            // Relaunch: channel sync re-applies `messagesClearedAt`
            // (ChannelDatabaseSession.createOrUpdate(channel:) -> deleteAllMessages(before:)).
            try? context.deleteAllMessages(channelId: channelId, before: clearedAt)
            do { try context.save() } catch { thrown = error }
            context.refreshAllObjects()
        }
        if let thrown { throw thrown }
    }

    private func storedMessage(id: MessageId) -> ChatMessage? {
        var result: ChatMessage?
        let context = context
        context.performAndWait {
            result = MessageDTO.fetch(id: id, context: context).map { ChatMessage(dto: $0) }
        }
        return result
    }

    // MARK: - Diagnostics (pass today; they document the preconditions)

    /// Step 1 of the chain: a newly created attachment row keeps the server's createdAt
    /// instead of its message's.
    func testNewAttachmentRowKeepsServerCreatedAtNotMessageCreatedAt() throws {
        let forwarded = try serverMessage(
            id: forwardedMessageId,
            createdAt: forwardedAt,
            attachments: [try serverAttachment(id: forwardedAttachmentId,
                                               url: "https://cdn.example/IMG_1420-6.HEIC",
                                               createdAt: originalUploadDate)]
        )
        let context = context
        let channelId = channelId
        var stored: Date?
        context.performAndWait {
            let dto = context.createOrUpdate(message: forwarded, channelId: channelId)
            stored = dto.attachments?.first?.createdAt?.bridgeDate
            try? context.save()
        }
        XCTAssertEqual(stored, originalUploadDate,
                       "precondition of the bug: the row is dated by the server attachment, not the message")
    }

    /// Why it is intermittent: once the message is re-saved while its row exists (a second page
    /// load of the chat), `map` finds `message` set and re-dates the row to the message, so the
    /// next sweep keeps it. Only a row CREATED on the last write (first load on the device, or
    /// recreated after a previous sweep) is exposed on the next relaunch.
    func testResavingWhileRowExistsRedatesItAndSurvivesTheSweep() throws {
        let make = { [self] in
            try serverMessage(
                id: forwardedMessageId,
                createdAt: forwardedAt,
                attachments: [try serverAttachment(id: forwardedAttachmentId,
                                                   url: "https://cdn.example/IMG_1420-6.HEIC",
                                                   createdAt: originalUploadDate)]
            )
        }
        let first = try make()
        let second = try make()
        let context = context
        let channelId = channelId
        let clearedAt = messagesClearedAt
        context.performAndWait {
            context.createOrUpdate(message: first, channelId: channelId)
            try? context.save()
            context.createOrUpdate(message: second, channelId: channelId)   // chat opened again
            try? context.save()
            try? context.deleteAllMessages(channelId: channelId, before: clearedAt)
            try? context.save()
            context.refreshAllObjects()
        }
        XCTAssertEqual(storedMessage(id: forwardedMessageId)?.attachments?.count, 1)
    }

    // MARK: - Reproduction (fail while the bug is present)

    /// The forwarded message survives the clear (it is newer than it) but loses its attachment.
    func testClearedHistorySweepKeepsAttachmentsOfMessagesNewerThanTheClear() throws {
        try storeMessagesThenSyncChannelWithClearedHistory()

        let forwarded = try XCTUnwrap(storedMessage(id: forwardedMessageId),
                                      "the message is newer than messagesClearedAt and must survive")
        let fresh = try XCTUnwrap(storedMessage(id: freshMessageId))

        XCTAssertEqual(fresh.attachments?.count, 1,
                       "control: an attachment uploaded after the clear survives")
        XCTAssertEqual(forwarded.attachments?.count, 1,
                       "BUG: the forwarded message survived the clear but its attachment was swept, "
                       + "because deleteAllAttachments filters by the attachment's (original upload) createdAt")
    }

    // MARK: - Regression: the sweep still does its job

    private func attachmentRowCount(id: AttachmentId) -> Int {
        var count = 0
        let context = context
        context.performAndWait {
            let request = AttachmentDTO.fetchRequest()
            request.predicate = .init(format: "id == %lld", Int64(id))
            count = (try? context.count(for: request)) ?? 0
        }
        return count
    }

    /// A message inside the cleared window goes, and its attachment with it — even when the
    /// attachment row is dated AFTER the clear (the old sweep leaked these).
    func testClearedMessageLosesItsAttachmentEvenWhenTheRowIsNewer() throws {
        let oldMessageId: MessageId = 9_420_103
        let oldAttachmentId: AttachmentId = 9_420_203
        let old = try serverMessage(
            id: oldMessageId,
            createdAt: originalUploadDate,
            attachments: [try serverAttachment(id: oldAttachmentId,
                                               url: "https://cdn.example/old.HEIC",
                                               createdAt: forwardedAt)]
        )
        let context = context
        let channelId = channelId
        let clearedAt = messagesClearedAt
        context.performAndWait {
            context.createOrUpdate(message: old, channelId: channelId)
            try? context.save()
            try? context.deleteAllMessages(channelId: channelId, before: clearedAt)
            try? context.save()
            context.refreshAllObjects()
        }
        XCTAssertNil(storedMessage(id: oldMessageId), "the cleared message is deleted")
        XCTAssertEqual(attachmentRowCount(id: oldAttachmentId), 0, "and so is its attachment")
    }

    /// A cleared message that still anchors a reply is kept as a hidden stub, and keeps its
    /// attachment so the reply preview keeps its thumbnail.
    func testClearedReplyParentStubKeepsItsAttachment() throws {
        let parentId: MessageId = 9_420_104
        let parentAttachmentId: AttachmentId = 9_420_204
        let replyId: MessageId = 9_420_105
        let parent = try serverMessage(
            id: parentId,
            createdAt: originalUploadDate,
            attachments: [try serverAttachment(id: parentAttachmentId,
                                               url: "https://cdn.example/parent.HEIC",
                                               createdAt: originalUploadDate)]
        )
        let reply = try serverMessage(id: replyId, createdAt: forwardedAt, attachments: [])
        let context = context
        let channelId = channelId
        let clearedAt = messagesClearedAt
        context.performAndWait {
            let parentDTO = context.createOrUpdate(message: parent, channelId: channelId)
            let replyDTO = context.createOrUpdate(message: reply, channelId: channelId)
            replyDTO.parent = parentDTO
            try? context.save()
            try? context.deleteAllMessages(channelId: channelId, before: clearedAt)
            try? context.save()
            context.refreshAllObjects()
        }
        XCTAssertNotNil(storedMessage(id: parentId), "the parent is kept as a stub")
        XCTAssertEqual(attachmentRowCount(id: parentAttachmentId), 1, "with its attachment")
    }

    /// What the user sees: the layout model of that message has nothing to draw.
    func testForwardedMessageAfterSweepStillHasDrawableContent() throws {
        try storeMessagesThenSyncChannelWithClearedHistory()
        let stored = try XCTUnwrap(storedMessage(id: forwardedMessageId))

        // Mark it forwarded the way the server does (forwardingDetails from another user).
        let message = ChatMessage(
            id: stored.id,
            tid: stored.tid,
            channelId: stored.channelId,
            body: stored.body,
            type: stored.type,
            createdAt: stored.createdAt,
            incoming: false,
            attachments: stored.attachments,
            user: ChatUser(id: "me"),
            forwardingDetails: .init(messageId: 1, channelId: 2, hops: 1,
                                     user: ChatUser(id: "someone-else"))
        )
        let channel = ChatChannel(id: channelId, type: "group", uri: "cleared-history")
        let model = MessageLayoutModel(channel: channel, message: message, appearance: MessageCell.appearance)

        XCTAssertTrue(model.isForwarded)
        XCTAssertFalse(model.contentOptions.isEmpty,
                       "BUG: forwarded message rendered with empty contentOptions -> the outgoing cell's "
                       + "fall-through branch: media pill shown, attachmentView width 0 (the broken bubble)")
    }
}
