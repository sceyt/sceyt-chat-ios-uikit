//
//  ChannelInfoFileCellTransitionTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat
import UIKit

/// Channel Info › Files rows animate their own state changes: the download button shrinks out
/// while the text widens into its slot, and the icon crossfades to the downloaded thumbnail.
/// That only works when the grid re-binds the visible row in place — a `reloadItems` swapped in
/// a freshly bound cell, so everything jumped.
final class ChannelInfoFileCellTransitionTests: XCTestCase {

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 200))
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeAttachment(id: AttachmentId, status: ChatMessage.Attachment.TransferStatus) -> ChatMessage.Attachment {
        .init(
            id: id,
            tid: 0,
            messageId: 1,
            userId: "user",
            url: "https://example.com/files/\(id)/report.pdf",
            filePath: nil,
            type: "file",
            name: "report.pdf",
            metadata: nil,
            uploadedFileSize: 1000,
            createdAt: Date(),
            status: status,
            transferProgress: 0
        )
    }

    private func makeMessage() -> ChatMessage {
        ChatMessage(id: 1, tid: 1, channelId: 1, incoming: true)
    }

    private func makeLayout(_ attachment: ChatMessage.Attachment) -> MessageLayoutModel.AttachmentLayout {
        .init(
            attachment: attachment,
            ownerMessage: makeMessage(),
            ownerChannel: nil,
            thumbnailSize: CGSize(width: 40, height: 40),
            asyncLoadThumbnail: false,
            appearance: MessageCell.appearance
        )
    }

    private func makeCell() -> ChannelInfoViewController.FileCell {
        let cell = ChannelInfoViewController.FileCell(frame: CGRect(x: 0, y: 0, width: 375, height: 56))
        window.addSubview(cell)
        return cell
    }

    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testFinishedDownloadOfBoundRow_animatesTheButtonOut() {
        let cell = makeCell()
        let layout = makeLayout(makeAttachment(id: 8001, status: .downloading))
        cell.data = layout
        cell.layoutIfNeeded()
        XCTAssertFalse(cell.downloadButton.isHidden)
        let textWidthWithButton = cell.textVStack.frame.width

        // The grid re-binds the visible row in place once the attachment updates.
        layout.attachment.status = .done
        cell.data = layout

        XCTAssertFalse(cell.downloadButton.layer.animationKeys()?.isEmpty ?? true,
                       "the button must shrink out, not vanish")
        pump(ChannelInfoViewController.FileCell.transitionDuration + 0.2)
        XCTAssertTrue(cell.downloadButton.isHidden)
        XCTAssertEqual(cell.downloadButton.transform, .identity, "no shrunk leftover may keep its slot")
        XCTAssertEqual(cell.downloadButton.alpha, 1)
        XCTAssertGreaterThan(cell.textVStack.frame.width, textWidthWithButton, "the text takes the freed space")
    }

    func testBindingADifferentAttachment_doesNotAnimate() {
        let cell = makeCell()
        cell.data = makeLayout(makeAttachment(id: 8002, status: .downloading))
        cell.prepareForReuse()
        cell.data = makeLayout(makeAttachment(id: 8003, status: .done))

        XCTAssertTrue(cell.downloadButton.isHidden, "a reused row shows its new state at once")
        XCTAssertTrue(cell.downloadButton.layer.animationKeys()?.isEmpty ?? true)
    }

    func testShowingTheButtonMidShrink_restoresItFully() {
        let cell = makeCell()
        let layout = makeLayout(makeAttachment(id: 8004, status: .downloading))
        cell.data = layout
        cell.layoutIfNeeded()
        layout.attachment.status = .done
        cell.data = layout                       // shrink-out starts

        layout.attachment.status = .pauseDownloading
        cell.data = layout                       // and is interrupted

        XCTAssertFalse(cell.downloadButton.isHidden)
        XCTAssertEqual(cell.downloadButton.transform, .identity)
        XCTAssertEqual(cell.downloadButton.alpha, 1)
    }

    func testThumbnailReplacingAnImage_crossfades() {
        let cell = makeCell()
        cell.data = makeLayout(makeAttachment(id: 8005, status: .done))
        cell.iconView.image = UIImage()          // blurred placeholder on screen

        cell.setIcon(UIImage(), animated: true)  // sharp thumbnail lands

        XCTAssertFalse(cell.iconView.layer.animationKeys()?.isEmpty ?? true, "blurred → sharp must crossfade")
    }

    func testSubclassOverridingUpdateStatus_stillAnimates() {
        // Host apps override `updateStatus()` (WAAFI hides the button once the file is on disk)
        // and call `showDownloadButton(_:)` themselves; that must keep compiling and animating.
        let cell = HidingFileCell(frame: CGRect(x: 0, y: 0, width: 375, height: 56))
        window.addSubview(cell)
        let layout = makeLayout(makeAttachment(id: 8006, status: .downloading))
        cell.data = layout
        cell.layoutIfNeeded()
        XCTAssertFalse(cell.downloadButton.isHidden)

        cell.fileIsOnDisk = true
        cell.data = layout

        XCTAssertFalse(cell.downloadButton.layer.animationKeys()?.isEmpty ?? true)
    }
}

private final class HidingFileCell: ChannelInfoViewController.FileCell {
    var fileIsOnDisk = false

    override func updateStatus() {
        if fileIsOnDisk {
            showDownloadButton(false)
            return
        }
        super.updateStatus()
    }
}
