//
//  ForwardedReplyLayoutTests.swift
//  SceytChatUIKitTests
//
//  A message loaded from the server can carry both `forwardingDetails` and a `parent`
//  (the iOS forward path clears the parent, other clients / the server may not). Forward
//  wins: `layoutConstraints` and `measure` both skip the reply branch when `isForwarded`,
//  so the reply view gets no constraints and no height. `MessageCell.bind` must therefore
//  keep it hidden — otherwise it is drawn at a stale frame over the forward header and
//  the attachments.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import UIKit
import XCTest

final class ForwardedReplyLayoutTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }
    private var hosts = [UIView]()

    private let channelId: ChannelId = 88
    private let channel = ChatChannel(id: 88, type: "group", uri: "forwarded-reply")

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        let (channel, _) = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        try? ctx.save()
    }

    override func tearDown() {
        hosts.removeAll()
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    @discardableResult
    private func seedMessage(id: MessageId, body: String, userId: UserId, incoming: Bool) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: id, tid: Int64(id), channelId: Int64(channelId), context: ctx)
        message.id = Int64(id)
        message.tid = Int64(id)
        message.channelId = Int64(channelId)
        message.body = body
        message.type = "text"
        message.incoming = incoming
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: userId, context: ctx)
        try? ctx.save()
        return message
    }

    private func addImage(id: AttachmentId, to message: MessageDTO) {
        let attachment = AttachmentDTO.insertNewObject(into: ctx)
        attachment.id = Int64(id)
        attachment.messageId = message.id
        attachment.channelId = message.channelId
        attachment.userId = message.user?.id ?? ""
        attachment.type = "image"
        attachment.name = "photo-\(id).jpg"
        attachment.url = "https://cdn.example/forwarded-reply/\(id).jpg"
        attachment.uploadedFileSize = 120_000
        attachment.message = message
        try? ctx.save()
    }

    /// The server shape: a forwarded message that is also a reply, both sides with an image.
    private func seedForwardedReply() -> MessageDTO {
        let parent = seedMessage(id: 1, body: "original with photo", userId: "alice", incoming: true)
        addImage(id: 101, to: parent)

        let message = seedMessage(id: 2, body: "", userId: "bob", incoming: true)
        addImage(id: 102, to: message)
        message.parent = parent
        message.forwardMessageId = 999
        message.forwardChannelId = 555
        message.forwardHops = 1
        message.forwardUser = UserDTO.fetchOrCreate(id: "carol", context: ctx)
        try? ctx.save()
        return message
    }

    private func bind(_ model: MessageLayoutModel) -> MessageCell {
        let cell = ChannelViewController.IncomingMessageCell(frame: .init(x: 0, y: 0, width: 390, height: 400))
        let host = UIView(frame: .init(x: 0, y: 0, width: 390, height: 400))
        hosts.append(host)
        host.addSubview(cell)
        cell.data = model
        host.setNeedsLayout()
        host.layoutIfNeeded()
        return cell
    }

    // MARK: - Tests

    func testPreconditionModelIsBothForwardedAndReply() {
        let model = MessageLayoutModel(channel: channel, message: ChatMessage(dto: seedForwardedReply()), appearance: MessageCell.appearance)

        XCTAssertTrue(model.isForwarded, "fixture must be forwarded")
        XCTAssertTrue(model.hasReply, "fixture must also be a reply")
        XCTAssertNotNil(model.replyLayout, "a reply layout is built for the parent")
        XCTAssertFalse(model.attachments.isEmpty, "fixture must carry attachments")
    }

    /// The bug: layout/measure drop the reply for forwarded messages, bind does not.
    func testForwardedReplyDoesNotShowReplyView() {
        let model = MessageLayoutModel(channel: channel, message: ChatMessage(dto: seedForwardedReply()), appearance: MessageCell.appearance)
        let cell = bind(model)

        XCTAssertFalse(cell.forwardView.isHidden, "the forward header is shown")
        XCTAssertTrue(cell.replyView.isHidden,
                      "forward wins over reply: the reply view has no constraints and no measured height, "
                      + "so it must stay hidden (frame=\(cell.replyView.frame))")
    }

    /// The visible symptom: the unpositioned reply view lands on top of the forward header
    /// or the attachment.
    func testForwardedReplyViewDoesNotOverlapContent() {
        let model = MessageLayoutModel(channel: channel, message: ChatMessage(dto: seedForwardedReply()), appearance: MessageCell.appearance)
        let cell = bind(model)
        guard !cell.replyView.isHidden else { return }

        let reply = cell.replyView.convert(cell.replyView.bounds, to: cell)
        let forward = cell.forwardView.convert(cell.forwardView.bounds, to: cell)
        let attachment = cell.attachmentView.convert(cell.attachmentView.bounds, to: cell)
        XCTAssertFalse(reply.intersects(forward) || reply.intersects(attachment),
                       "reply=\(reply) overlaps forward=\(forward) / attachment=\(attachment)")
    }
}
