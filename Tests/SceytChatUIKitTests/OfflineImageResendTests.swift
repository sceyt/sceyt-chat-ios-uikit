//
//  OfflineImageResendTests.swift
//  SceytChatUIKitTests
//
//  Created by Vahagn Manasyan on 05.10.26.
//
//  An image sent with no connection ended up permanently blurred, on the sender and on the
//  receiver. The device trace showed four seams in a row, and each one is pinned here:
//
//  1. **The upload filter.** Opening the unsent image in the previewer marks it `.done`.
//     `uploadableAttachments` skips `.done`, so on reconnect the resend never handed the file to
//     the app's uploader. The message went out with only a local `filePath`, so
//     `ChatMessage.Attachment.builder` fell back to `Attachment.Builder(filePath:)` and SceytChat
//     uploaded the file itself, to a url the app's data session cannot download.
//  2. **The resend.** For the same reason `uploadAttachmentsIfNeeded` completed at once, without
//     asking the data session to upload anything.
//  3. **The ack merge.** The ack attachment carries a url the local row never had and tid 0, so
//     `createOrUpdate(attachments:dto:)` matched nothing, created a second row with no `filePath`
//     and orphaned the local one. The sender lost its copy and fell back to the thumbHash.
//  4. **The heal.** The re-download failed, but the transport left its error body at the
//     destination, and the reconcile read "a file is on disk" as "the download finished". The
//     image was marked `.done` with bytes that are not an image, so it never retried.
//  5. **The duplicate resend.** The connection handler and the channel sync each resent the
//     message on reconnect, 2 ms apart: two uploads of one file and two sends of one message.
//
//  The guards pin what must not change: an attachment that already has its url is not uploaded
//  again, the usual ack (which echoes the url) keeps the local file, and a real image on disk
//  still heals to `.done`.
//

@testable import SceytChatUIKit
import CoreData
import ObjectiveC
import SceytChat
import UIKit
import XCTest

final class OfflineImageResendTests: XCTestCase {

    private var session: MockTransferDataSession!
    private var mockDB: MockDatabase!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!
    private var temporaryFiles = [String]()

    private let channelId: ChannelId = 700
    private let messageTid: Int64 = -6_221_683_302_793_740_286
    private let attachmentTid: Int64 = -6_221_683_302_793_740_287
    private let serverMessageId: MessageId = 866_486_305_949_343_744
    private let serverAttachmentId: AttachmentId = 866_486_305_949_343_745
    /// What the app's own uploader returns: a bare transfer id, not a url.
    private let transferId = "22DA3E08-94CD-4AA3-AD91-281A677D8B3B"
    /// What SceytChat returns when it uploads the file itself.
    private let sdkUploadedUrl = "https://files.example/user/api/v1/files/app/add6b824/IMG_1590.jpg"
    private let fileName = "IMG_1590.jpg"
    private let userId = "me"

    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        mockDB = MockDatabase()
        DataProvider.database = mockDB
        originalDataSession = Components.dataSession
        session = MockTransferDataSession()
        Components.dataSession = session
    }

    override func tearDownWithError() throws {
        for path in temporaryFiles {
            try? FileManager.default.removeItem(atPath: path)
        }
        temporaryFiles.removeAll()
        Components.dataSession = originalDataSession
        DataProvider.database = originalDatabase
        session = nil
        mockDB = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    /// The outgoing attachment as the resend reads it: never uploaded, so no url, with the
    /// resized copy on disk.
    private func makeOutgoingAttachment(
        url: String? = nil,
        filePath: String,
        status: ChatMessage.Attachment.TransferStatus
    ) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            id: 0,
            tid: attachmentTid,
            messageId: 0,
            userId: userId,
            url: url,
            filePath: filePath,
            type: "image",
            name: fileName,
            uploadedFileSize: 0,
            createdAt: Date(),
            status: status
        )
    }

    private func makeOutgoingMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(
            id: 0,
            tid: messageTid,
            channelId: channelId,
            type: "media",
            attachments: attachments,
            user: ChatUser(id: userId)
        )
    }

    /// The sender's own message after the ack, as the cell binds it.
    private func makeSentMessage(status: ChatMessage.Attachment.TransferStatus) -> (ChatMessage, ChatMessage.Attachment) {
        let attachment = ChatMessage.Attachment(
            id: serverAttachmentId,
            tid: 0,
            messageId: serverMessageId,
            userId: userId,
            url: sdkUploadedUrl,
            filePath: nil,
            type: "image",
            name: fileName,
            uploadedFileSize: 76_723,
            createdAt: Date(),
            status: status
        )
        let message = ChatMessage(
            id: serverMessageId,
            tid: messageTid,
            channelId: channelId,
            type: "media",
            attachments: [attachment],
            user: ChatUser(id: userId)
        )
        return (message, attachment)
    }

    /// The pending row a relaunch reads back: the message has no server id yet, and its
    /// attachment has a tid and a local file.
    @discardableResult
    private func seedOutgoingRow(
        url: String? = nil,
        filePath: String,
        status: ChatMessage.Attachment.TransferStatus
    ) throws -> AttachmentDTO {
        _ = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        let message = MessageDTO.fetchOrCreate(id: 0, tid: messageTid, channelId: Int64(channelId), context: ctx)
        message.tid = messageTid
        message.channelId = Int64(channelId)
        message.incoming = false
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: userId, context: ctx)

        let attachment = AttachmentDTO.create(context: ctx)
        attachment.tid = attachmentTid
        attachment.channelId = Int64(channelId)
        attachment.userId = userId
        attachment.type = "image"
        attachment.name = fileName
        attachment.url = url
        attachment.filePath = filePath
        attachment.status = status.rawValue
        attachment.createdAt = Date().bridgeDate
        attachment.message = message
        try ctx.save()
        return attachment
    }

    /// The attachment as the server acks it: a server id, and no tid.
    private func ackAttachment(url: String) throws -> Attachment {
        let attachment = Attachment.Builder(url: url, type: "image").name(fileName).build()
        // The SDK has no public way to build an attachment with a server id, so set the two
        // fields the way the ack fills them.
        try XCTSkipIf(
            class_getInstanceVariable(Attachment.self, "_id") == nil
                || class_getInstanceVariable(Attachment.self, "_tid") == nil,
            "SCTAttachment no longer stores id/tid in _id/_tid"
        )
        attachment.setValue(NSNumber(value: serverAttachmentId), forKey: "id")
        attachment.setValue(NSNumber(value: 0), forKey: "tid")
        return attachment
    }

    private func ack(attachmentUrl: String) throws -> Message {
        Message.Builder()
            .id(serverMessageId)
            .tid(Int(messageTid))
            .attachments([try ackAttachment(url: attachmentUrl)])
            .build()
    }

    /// Written inside the storage folder, where real transfers land: `AttachmentDTO` stores
    /// `filePath` relative to that folder and re-absolutises it on read.
    private func makeFile(named name: String, contents: Data) throws -> String {
        let directory = URL(fileURLWithPath: Components.storage.storingKey.storageFolderPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory
            .appendingPathComponent("offline-image-\(UUID().uuidString)-\(name)").path
        try contents.write(to: URL(fileURLWithPath: path))
        temporaryFiles.append(path)
        return path
    }

    private func jpegData() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }

    /// The body S3 sends with a 404, which the transport saved as the "downloaded" image.
    private var notFoundBody: Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message>\
        <Key>public/\(sdkUploadedUrl)</Key><RequestId>KG6C8WN1E9VWB14J</RequestId>\
        <HostId>NYJDXoIq4e7mbsYgfMYanTJyrJzA8nw23k81bfOIfOaOW1BOwYpWy+mRBN4DzmmWW6zlhnSq8dQXV6juK0ym25YzvNEhNKTZ</HostId></Error>
        """.utf8)
    }

    private func attachmentRows() -> [AttachmentDTO] {
        ctx.refreshAllObjects()
        return (try? ctx.fetch(AttachmentDTO.fetchRequest())) ?? []
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    // MARK: - Seam 1: the upload filter

    /// The reported bug: the image was opened full screen while offline, which marked it `.done`
    /// with no url. It has still never been uploaded, so the resend must upload it.
    func testPreviewedOfflineImageIsStillUploadable() throws {
        let path = try makeFile(named: fileName, contents: try jpegData())
        let attachment = makeOutgoingAttachment(filePath: path, status: .done)
        let message = makeOutgoingMessage([attachment])
        let sender = ChannelMessageSender(channelId: channelId)

        XCTAssertEqual(
            sender.uploadableAttachments(of: message).map(\.tid), [attachmentTid],
            "an attachment with no url has not been uploaded, whatever its status says"
        )
    }

    /// Guard: an attachment that already has its url must not be uploaded a second time.
    func testUploadedAttachmentIsNotUploadedAgain() throws {
        let path = try makeFile(named: fileName, contents: try jpegData())
        let attachment = makeOutgoingAttachment(url: transferId, filePath: path, status: .done)
        let message = makeOutgoingMessage([attachment])
        let sender = ChannelMessageSender(channelId: channelId)

        XCTAssertTrue(sender.uploadableAttachments(of: message).isEmpty)
    }

    // MARK: - Seam 2: the resend goes through the app's uploader

    /// With the filter skipping it, `uploadAttachmentsIfNeeded` completed at once and the message
    /// was sent with only a local path. The app's data session must be asked to upload it.
    func testResendHandsThePreviewedImageToTheDataSession() throws {
        let path = try makeFile(named: fileName, contents: try jpegData())
        try seedOutgoingRow(filePath: path, status: .done)
        let attachment = makeOutgoingAttachment(filePath: path, status: .done)
        let message = makeOutgoingMessage([attachment])
        let sender = ChannelMessageSender(channelId: channelId)

        sender.uploadAttachmentsIfNeeded(message: message) { _, _ in }

        // The mock keys an upload with no url under its file path.
        XCTAssertTrue(
            waitUntil { self.session.task(forUrl: path) != nil },
            "the resend sent the message without asking the data session to upload the file"
        )
    }

    // MARK: - Seam 3: the ack keeps the local file

    /// The ack attachment has a url the local row never had and tid 0. The local row must still
    /// be the one updated, or the sender loses its file and shows the thumbHash.
    func testSendAckWithANewUrlKeepsTheLocalFile() throws {
        let path = try makeFile(named: fileName, contents: try jpegData())
        try seedOutgoingRow(filePath: path, status: .done)

        _ = ctx.resolveSendAck(sentMessage: try ack(attachmentUrl: sdkUploadedUrl), channelId: channelId)
        try ctx.save()

        let rows = attachmentRows()
        XCTAssertEqual(rows.count, 1, "the ack must update the local row, not add a second one beside it")
        let row = try XCTUnwrap(MessageDTO.fetch(id: serverMessageId, context: ctx)?.attachments?.first)
        XCTAssertEqual(row.id, Int64(serverAttachmentId))
        XCTAssertEqual(row.url, sdkUploadedUrl)
        XCTAssertEqual(row.fullFilePath, path, "the sender must keep its local copy after the ack")
    }

    /// Guard: the usual ack echoes the url the app's uploader returned, and that path already
    /// keeps the local file.
    func testSendAckWithTheUploadedUrlKeepsTheLocalFile() throws {
        let path = try makeFile(named: fileName, contents: try jpegData())
        try seedOutgoingRow(url: transferId, filePath: path, status: .done)

        _ = ctx.resolveSendAck(sentMessage: try ack(attachmentUrl: transferId), channelId: channelId)
        try ctx.save()

        XCTAssertEqual(attachmentRows().count, 1)
        let row = try XCTUnwrap(MessageDTO.fetch(id: serverMessageId, context: ctx)?.attachments?.first)
        XCTAssertEqual(row.url, transferId)
        XCTAssertEqual(row.fullFilePath, path)
    }

    // MARK: - Seam 4: a failed download is not healed by its error body

    /// The download 404'd and the transport saved the error body where the image should be. That
    /// file is not the image, so it must not turn the attachment `.done`. Covers both statuses the
    /// trace showed reaching the reconcile: the failure itself and a stale `.pending` copy.
    func testErrorBodyOnDiskDoesNotMarkAFailedImageDownloadDone() throws {
        for status: ChatMessage.Attachment.TransferStatus in [.failedDownloading, .pending] {
            let path = try makeFile(named: fileName, contents: notFoundBody)
            session.setLocalPath(path, forUrl: sdkUploadedUrl)
            let (message, attachment) = makeSentMessage(status: status)
            let transfer = AttachmentTransfer()

            transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

            XCTAssertNotEqual(attachment.status, .done,
                              "\(status): bytes that are not an image must not complete an image download")
            XCTAssertNotEqual(attachment.filePath, path,
                              "\(status): the error body must not be adopted as the image file")
        }
    }

    /// Guard: an unreadable file is removed once, not on every bind. If its re-download is
    /// unreadable too, it is a real file ImageIO cannot decode, and removing it again would
    /// download it on every bind.
    func testUnreadableImageIsRemovedOnlyOnce() throws {
        let path = try makeFile(named: fileName, contents: notFoundBody)
        session.setLocalPath(path, forUrl: sdkUploadedUrl)
        let transfer = AttachmentTransfer()

        let (firstMessage, first) = makeSentMessage(status: .pending)
        transfer.downloadMessageAttachmentsIfNeeded(message: firstMessage, attachments: [first])
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "the first time, the unreadable file is removed")

        // The re-download brought the same bytes back.
        try notFoundBody.write(to: URL(fileURLWithPath: path))
        let (secondMessage, second) = makeSentMessage(status: .pending)
        transfer.downloadMessageAttachmentsIfNeeded(message: secondMessage, attachments: [second])

        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "the second time, it is kept")
        XCTAssertEqual(second.status, .done)
    }

    /// Guard: a real image on disk still heals a stale status to `.done`.
    func testImageOnDiskStillHealsAFailedDownloadToDone() throws {
        let path = try makeFile(named: fileName, contents: try jpegData())
        session.setLocalPath(path, forUrl: sdkUploadedUrl)
        let (message, attachment) = makeSentMessage(status: .failedDownloading)
        let transfer = AttachmentTransfer()

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertEqual(attachment.status, .done)
        XCTAssertEqual(attachment.filePath, path)
    }

    // MARK: - Seam 5: one resend per message at a time

    /// The second resend of a message waits for the first, and both callers hear the outcome:
    /// `SyncService` counts every resend's completion before it flushes pending deletes.
    func testSecondResendOfTheSameMessageWaitsForTheFirst() throws {
        let tid = Int64.random(in: Int64.min ..< -1)
        var outcomes = [String]()

        let first = ChannelMessageSender.beginResend(tid: tid) { _ in outcomes.append("first") }
        let second = ChannelMessageSender.beginResend(tid: tid) { _ in outcomes.append("second") }

        let token = try XCTUnwrap(first, "the first resend must run")
        XCTAssertNil(second, "a resend of a message already being resent must wait instead of uploading again")
        ChannelMessageSender.endResend(tid: tid, token: token).forEach { $0?(nil) }
        XCTAssertEqual(outcomes, ["first", "second"])

        let later = try XCTUnwrap(ChannelMessageSender.beginResend(tid: tid, completion: nil),
                                  "once it has ended, the message can be resent again")
        _ = ChannelMessageSender.endResend(tid: tid, token: later)
    }

    /// A resend whose completion never arrives must not block that message for the session, and
    /// whoever was waiting on it still hears how the message ends.
    func testStaleResendIsReplacedAndItsCallersCarriedOver() throws {
        let tid = Int64.random(in: Int64.min ..< -1)
        let start = Date()
        var outcomes = [String]()

        let stale = try XCTUnwrap(ChannelMessageSender.beginResend(tid: tid, completion: { _ in outcomes.append("stale") }, now: start))
        let fresh = try XCTUnwrap(ChannelMessageSender.beginResend(
            tid: tid,
            completion: { _ in outcomes.append("fresh") },
            now: start.addingTimeInterval(ChannelMessageSender.inFlightResendStaleInterval + 1)
        ), "a resend past the stale interval must be replaced")

        XCTAssertTrue(ChannelMessageSender.endResend(tid: tid, token: stale).isEmpty,
                      "the replaced resend ending late must not end the one that replaced it")
        ChannelMessageSender.endResend(tid: tid, token: fresh).forEach { $0?(nil) }
        XCTAssertEqual(outcomes, ["stale", "fresh"])
    }
}
