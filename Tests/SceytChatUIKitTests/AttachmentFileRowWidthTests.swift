//
//  AttachmentFileRowWidthTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat
import UIKit

/// Pins down the file attachment row's width contract:
/// - the bubble's date/tick InfoView is drawn over the row's *size* line, so that line — and
///   only the bottom-most row — gets trailing space reserved for it, plus a real gap;
/// - a long file name can no longer swallow that reserve (it used to, via `max(name, size)`);
/// - the reserve tracks the message's own appearance, not the global static one;
/// - the cached row width is re-derived when the attachment's name or byte count lands after
///   the first layout, which is what left the size text drawn under the clock;
/// - rows built for the shared-media / global-search lists keep their pinned size and get no
///   reserve at all.
final class AttachmentFileRowWidthTests: XCTestCase {

    private let channelId: ChannelId = 77
    private let messageId: MessageId = 7

    private var defaults: MessageLayoutModel.Defaults { Components.messageLayoutModel.defaults }

    /// `messageWidth` is a lazy member, so it needs a mutable copy to be read.
    private var messageWidth: CGFloat {
        var defaults = self.defaults
        return defaults.messageWidth
    }

    /// Everything the row spends on chrome: the icon slot's leading inset (row-relative), the
    /// slot, the gap to the labels and their trailing inset.
    private var chrome: CGFloat {
        (MessageCell.Layouts.attachmentFilePadding - MessageCell.Layouts.attachmentStackBubbleInset)
            + MessageCell.Layouts.attachmentFileIconSize
            + MessageCell.Layouts.horizontalPadding * 2
    }

    // MARK: - Fixtures

    private func makeAttachment(
        id: AttachmentId = 1,
        type: String = "file",
        name: String = "report.pdf",
        uploadedFileSize: UInt = 36_352
    ) -> ChatMessage.Attachment {
        .init(
            id: id,
            tid: 0,
            messageId: messageId,
            userId: "u1",
            url: "https://example.com/files/\(id)/\(name)",
            filePath: nil,
            type: type,
            name: name,
            metadata: nil,
            uploadedFileSize: uploadedFileSize,
            createdAt: Date(),
            status: .done,
            transferProgress: 0
        )
    }

    private func makeModel(
        _ attachments: [ChatMessage.Attachment],
        incoming: Bool = false,
        appearance: MessageCell.Appearance = MessageCell.appearance
    ) -> MessageLayoutModel {
        MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "file-row-width"),
            message: ChatMessage(
                id: messageId,
                channelId: channelId,
                incoming: incoming,
                attachments: attachments,
                user: ChatUser(id: incoming ? "other" : "me")
            ),
            appearance: appearance
        )
    }

    private func infoWidth(_ model: MessageLayoutModel, appearance: MessageCell.Appearance = MessageCell.appearance) -> CGFloat {
        MessageCell.InfoView.measure(
            channel: model.channel,
            message: model.message,
            appearance: appearance).width
    }

    private func textWidth(_ text: String, appearance: MessageCell.Appearance = MessageCell.appearance) -> CGFloat {
        var config = TextSizeMeasure.Config()
        config.maximumNumberOfLines = 1
        config.font = appearance.attachmentFileSizeLabelAppearance.font
        return TextSizeMeasure.calculateSize(of: text, config: config).textSize.width
    }

    private func sizeTextWidth(
        _ layout: MessageLayoutModel.AttachmentLayout,
        appearance: MessageCell.Appearance = MessageCell.appearance
    ) -> CGFloat {
        textWidth(layout.widestTransferSizeText(using: appearance.attachmentFileSizeFormatter),
                  appearance: appearance)
    }

    // MARK: - The reserve

    func testFileRowReservesRoomForTheInfoView() throws {
        let model = makeModel([makeAttachment()])
        let layout = try XCTUnwrap(model.attachments.first)

        XCTAssertEqual(
            layout.reservedTrailingWidth,
            infoWidth(model) + MessageCell.Layouts.attachmentFileInfoSpacing,
            accuracy: 0.5,
            "the file row must reserve the InfoView's width plus the gap")
        XCTAssertGreaterThanOrEqual(
            layout.thumbnailSize.width - chrome,
            sizeTextWidth(layout) + layout.reservedTrailingWidth - 0.5,
            "the measured row must fit the size line and the reserve side by side")
    }

    /// The regression: the reserve used to be folded into `max(nameWidth, sizeWidth)`, so a name
    /// wider than the size line made it disappear and the size text ran under the timestamp.
    func testLongFileNameDoesNotSwallowTheReserve() throws {
        let model = makeModel([makeAttachment(name: "WAAFI_1_regression_e2e_test_suite.xml")])
        let layout = try XCTUnwrap(model.attachments.first)

        let available = layout.thumbnailSize.width - chrome
        XCTAssertGreaterThanOrEqual(
            available,
            sizeTextWidth(layout) + layout.reservedTrailingWidth - 0.5,
            "a long name must not eat the space the timestamp needs")
    }

    func testReserveTracksTheModelsOwnAppearance() throws {
        let bigDate = MessageCell.Appearance(
            reference: MessageCell.appearance,
            messageDateLabelAppearance: LabelAppearance(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(24)))

        let plain = try XCTUnwrap(makeModel([makeAttachment()]).attachments.first)
        let custom = try XCTUnwrap(makeModel([makeAttachment()], appearance: bigDate).attachments.first)

        XCTAssertGreaterThan(
            custom.reservedTrailingWidth,
            plain.reservedTrailingWidth,
            "a host that enlarges the date font must get a proportionally larger reserve")
    }

    /// The two halves of "<downloaded> • <total>" are formatted independently, so while a 1.5MB
    /// download is still under a megabyte the line reads "277.94KB • 1.50MB" — wider than the
    /// "1.50MB • 1.50MB" the row used to be measured against, and it truncated mid-transfer.
    func testRowFitsTheWidestMidTransferString() throws {
        let total: UInt = 1_500_000
        let model = makeModel([makeAttachment(name: "IMG_1420.HEIC", uploadedFileSize: total)])
        let layout = try XCTUnwrap(model.attachments.first)
        let formatter = MessageCell.appearance.attachmentFileSizeFormatter

        // Every state a real transfer passes through must fit the measured row.
        let available = layout.thumbnailSize.width - chrome - layout.reservedTrailingWidth
        for fraction in stride(from: 0.0, through: 1.0, by: 0.05) {
            let downloaded = UInt64(Double(total) * fraction)
            let line = "\(formatter.format(downloaded)) • \(formatter.format(UInt64(total)))"
            XCTAssertLessThanOrEqual(
                textWidth(line), available + 0.5,
                "\"\(line)\" does not fit the measured row")
        }
    }

    func testWidestTransferTextPicksTheLongestLeftHalf() throws {
        let model = makeModel([makeAttachment(uploadedFileSize: 1_500_000)])
        let layout = try XCTUnwrap(model.attachments.first)

        // "1000.00KB", not "999.99KB": FileSizeFormatter rounds 999_999 / 1000 with "%.2f". That
        // string really does appear on screen at that byte count, so it is the width to measure.
        XCTAssertEqual(
            layout.widestTransferSizeText(using: MessageCell.appearance.attachmentFileSizeFormatter),
            "1000.00KB • 1.50MB",
            "the downloaded half is formatted on its own, so it can be a unit smaller and longer")
    }

    // MARK: - Which row gets it

    func testOnlyTheBottomMostRowIsReserved() throws {
        let model = makeModel([
            makeAttachment(id: 1, name: "first.pdf"),
            makeAttachment(id: 2, name: "second.pdf")
        ])
        XCTAssertEqual(model.attachments.count, 2)
        XCTAssertEqual(model.attachments.first?.reservedTrailingWidth, 0,
                       "the InfoView is pinned to the bubble's bottom — it overlaps nothing above the last row")
        XCTAssertGreaterThan(model.attachments.last?.reservedTrailingWidth ?? 0, 0)
    }

    func testVoiceLastRowGetsNoReserve() throws {
        let model = makeModel([
            makeAttachment(id: 1, name: "doc.pdf"),
            makeAttachment(id: 2, type: "voice", name: "voice.m4a")
        ])
        // Voice rows dodge the InfoView vertically, so nothing in the stack needs the reserve.
        for layout in model.attachments {
            XCTAssertEqual(layout.reservedTrailingWidth, 0)
        }
    }

    // MARK: - The width cap

    func testFileOnlyBubbleMayGrowPastTheMediaCap() throws {
        let model = makeModel([makeAttachment(name: String(repeating: "long_file_name_", count: 8) + ".pdf")])
        let layout = try XCTUnwrap(model.attachments.first)

        XCTAssertGreaterThan(
            layout.thumbnailSize.width,
            defaults.imageAttachmentSize.width,
            "a file-only bubble is no longer capped at the image width")
        XCTAssertLessThanOrEqual(
            layout.thumbnailSize.width,
            min(defaults.fileAttachmentSize.width, messageWidth - 4),
            "and never runs past the bubble's own limit")
    }

    func testFileBesideMediaKeepsTheMediaCap() throws {
        let model = makeModel([
            makeAttachment(id: 1, type: "image", name: "photo.jpg"),
            makeAttachment(id: 2, name: String(repeating: "long_file_name_", count: 8) + ".pdf")
        ])
        let file = try XCTUnwrap(model.attachments.last)

        XCTAssertEqual(file.type, .file)
        XCTAssertLessThanOrEqual(
            file.thumbnailSize.width,
            defaults.imageAttachmentSize.width,
            "media rows take the stack's width at a fixed height, so a wider file row would stretch them")
    }

    // MARK: - Late attachment updates

    func testUpdateRederivesTheRowWidthWhenTheByteCountLands() throws {
        let model = makeModel([makeAttachment(uploadedFileSize: 0)])
        let layout = try XCTUnwrap(model.attachments.first)
        let before = layout.thumbnailSize.width

        layout.update(attachment: makeAttachment(uploadedFileSize: 4_294_967))
        XCTAssertGreaterThan(
            layout.thumbnailSize.width,
            before,
            "a byte count that arrives after the first layout must widen the row")
    }

    func testUpdateRederivesTheRowWidthWhenTheNameGrows() throws {
        let model = makeModel([makeAttachment(name: "a.pdf")])
        let layout = try XCTUnwrap(model.attachments.first)
        let before = layout.thumbnailSize.width

        layout.update(attachment: makeAttachment(name: "WAAFI_1_regression_e2e_test_suite.xml"))
        XCTAssertGreaterThan(layout.thumbnailSize.width, before)
    }

    /// The shared-media and global-search lists pin `thumbnailSize` themselves; nothing here may
    /// re-derive it under them, and they never see a reserve.
    func testPinnedThumbnailSizeIsNeverRederived() {
        let pinned = CGSize(width: 40, height: 40)
        let layout = MessageLayoutModel.AttachmentLayout(
            attachment: makeAttachment(name: "a.pdf", uploadedFileSize: 0),
            ownerMessage: nil,
            ownerChannel: nil,
            thumbnailSize: pinned,
            appearance: MessageCell.appearance)

        XCTAssertEqual(layout.reservedTrailingWidth, 0)
        layout.update(attachment: makeAttachment(name: "WAAFI_1_regression_e2e_test_suite.xml",
                                                 uploadedFileSize: 4_294_967))
        XCTAssertEqual(layout.thumbnailSize, pinned, "a caller-pinned row size must survive updates")
    }

    // MARK: - Geometry: the size label actually stays clear

    /// The assertion that encodes the bug: laid out at its measured width, the size label must
    /// end before the InfoView begins. The InfoView is pinned to `bubble.trailing - 12` while the
    /// row starts 2pt inside the bubble, so in row coordinates it begins at
    /// `rowWidth - 10 - infoWidth`.
    func testSizeLabelStaysClearOfTheInfoView() throws {
        for name in ["a.pdf",
                     "WAAFI_1_e2e_test_suite.xml",
                     String(repeating: "long_file_name_", count: 8) + ".pdf"] {
            let model = makeModel([makeAttachment(name: name)])
            let layout = try XCTUnwrap(model.attachments.first)

            let stack = MessageCell.AttachmentStackView()
            stack.data = model
            stack.frame = CGRect(origin: .zero, size: model.attachmentsContainerSize)
            stack.layoutIfNeeded()

            let row = try XCTUnwrap(
                stack.subviews.compactMap { $0 as? MessageCell.AttachmentFileView }.first,
                "the stack built no file row for \(name)")

            XCTAssertLessThanOrEqual(
                row.sizeLabel.frame.maxX,
                stack.bounds.width - 10 - infoWidth(model) + 0.5,
                "the size line must not reach the timestamp — \(name), row width \(layout.thumbnailSize.width)")
            XCTAssertFalse(row.sizeLabel.frame.isEmpty, "the size line must still be visible — \(name)")
        }
    }
}
