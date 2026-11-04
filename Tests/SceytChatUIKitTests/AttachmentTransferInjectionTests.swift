//
//  AttachmentTransferInjectionTests.swift
//  SceytChatUIKitTests
//
//  The sender and the view models send through the transfer they were given, not the
//  process-wide one: a test (or a screen) replaces it per instance.
//

@testable import SceytChatUIKit
import XCTest

final class AttachmentTransferInjectionTests: XCTestCase {

    /// Records the uploads it is asked for and reports each one done at once.
    private final class RecordingTransfer: AttachmentTransfer {
        let uploads = Locked([[ChatMessage.Attachment]]())

        override func uploadMessageAttachments(
            message: ChatMessage,
            attachments: [ChatMessage.Attachment]? = nil,
            completion: ((ChatMessage?, Error?) -> Void)? = nil
        ) {
            uploads.mutate { $0.append(attachments ?? []) }
            completion?(message, nil)
        }
    }

    private func makeAttachment(filePath: String?, status: ChatMessage.Attachment.TransferStatus) -> ChatMessage.Attachment {
        .init(
            id: 0,
            tid: 7,
            messageId: 0,
            userId: "user",
            url: nil,
            filePath: filePath,
            type: "file",
            name: "report.pdf",
            metadata: nil,
            uploadedFileSize: 1024,
            createdAt: Date(),
            status: status
        )
    }

    func testSenderUploadsThroughItsInjectedTransfer() {
        let transfer = RecordingTransfer()
        let sender = ChannelMessageSender(channelId: 100)
        sender.attachmentTransfer = transfer
        let attachment = makeAttachment(filePath: "/tmp/report.pdf", status: .pending)
        let message = ChatMessage(id: 0, channelId: 100, attachments: [attachment], user: ChatUser(id: "u1"))

        let done = expectation(description: "upload completion")
        sender.uploadAttachmentsIfNeeded(message: message) { sent, error in
            XCTAssertTrue(sent === message)
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 2)

        XCTAssertEqual(transfer.uploads.wrapped.count, 1)
        XCTAssertTrue(transfer.uploads.wrapped.first?.first === attachment)
    }

    func testSenderWithNothingToUploadLeavesItsTransferAlone() {
        let transfer = RecordingTransfer()
        let sender = ChannelMessageSender(channelId: 100)
        sender.attachmentTransfer = transfer
        // No local file: nothing to send.
        let message = ChatMessage(id: 0, channelId: 100, attachments: [makeAttachment(filePath: nil, status: .pending)], user: ChatUser(id: "u1"))

        let done = expectation(description: "completion")
        sender.uploadAttachmentsIfNeeded(message: message) { _, _ in done.fulfill() }
        wait(for: [done], timeout: 2)

        XCTAssertTrue(transfer.uploads.wrapped.isEmpty)
    }

    func testViewModelsDefaultToTheSharedTransfer() {
        let files = GlobalSearchAllFilesViewModel(attachmentTypes: ["file"], appearance: MessageCell.appearance)
        XCTAssertTrue(files.attachmentTransfer === fileProvider)
        XCTAssertTrue(ChannelMessageSender(channelId: 1).attachmentTransfer === fileProvider)

        let replaced = RecordingTransfer()
        files.attachmentTransfer = replaced
        XCTAssertTrue(files.attachmentTransfer === replaced)
    }
}
