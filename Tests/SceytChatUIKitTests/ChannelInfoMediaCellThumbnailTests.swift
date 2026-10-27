//
//  ChannelInfoMediaCellThumbnailTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat
import UIKit

/// The Channel Info › Media grid cell must swap its blurred placeholder for the
/// downloaded image as soon as it learns the transfer is over — whatever state its
/// progress ring is in at that moment.
///
/// It used to reload the thumbnail only as a side effect of the ring's shrink-out
/// animation. The 100% progress tick lands before the file is moved into place, so
/// that hide could reload while there was still no file, and every later "done"
/// signal found the ring already hidden and reloaded nothing: the cell stayed
/// blurred until something rebound it (opening and closing the preview did).
final class ChannelInfoMediaCellThumbnailTests: XCTestCase {

    private var mock: MockThumbnailDataSession!
    private var originalDataSession: SCTDataSession?
    private var tempDir: URL!
    /// 10×10 — far below what the 100pt cell asks of a relayed thumbnail, so the
    /// sharp relay's size guard can't be what paints it in the tests below.
    private var sharpPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        ThumbnailReloadGate.reset()
        mock = MockThumbnailDataSession()
        originalDataSession = Components.dataSession
        Components.dataSession = mock

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChannelInfoMediaCellThumbnailTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        sharpPath = try writeImage(side: 10, color: .red, name: "sharp.jpg")
    }

    override func tearDownWithError() throws {
        Components.dataSession = originalDataSession
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    // MARK: Helpers

    private func writeImage(side: CGFloat, color: UIColor, name: String) throws -> String {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: .init(width: side, height: side), format: format)
            .image { ctx in
                color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }
        let url = tempDir.appendingPathComponent(name)
        try XCTUnwrap(image.jpegData(compressionQuality: 1)).write(to: url)
        return url.path
    }

    private func makeAttachment(id: AttachmentId, metadata: String? = nil) -> ChatMessage.Attachment {
        .init(
            id: id,
            tid: 0,
            messageId: 1,
            userId: "user",
            url: "https://example.com/files/\(id)/image.jpg",
            filePath: nil,
            type: "image",
            name: "image.jpg",
            metadata: metadata,
            uploadedFileSize: 0,
            createdAt: Date(),
            status: .downloading,
            transferProgress: 0
        )
    }

    /// Binds a grid cell the way `MediaCollectionView.configure` does, including the
    /// `onLoadThumbnail` slot that paints the cell.
    private func makeBoundCell(_ attachment: ChatMessage.Attachment) -> ChannelInfoViewController.ImageAttachmentCell {
        let layout = MessageLayoutModel.AttachmentLayout(
            attachment: attachment,
            ownerMessage: nil,
            ownerChannel: nil,
            thumbnailSize: CGSize(width: 300, height: 300),
            asyncLoadThumbnail: false,
            appearance: MessageCell.appearance
        )
        let cell = ChannelInfoViewController.ImageAttachmentCell(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        layout.onLoadThumbnail = { [weak cell, weak layout] _ in
            guard let cell, let layout, layout == cell.data else { return }
            cell.imageView.image = layout.thumbnail
        }
        cell.data = layout
        return cell
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    /// Lets the bind-time placeholder load land.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    private func isSharp(_ cell: ChannelInfoViewController.AttachmentCell) -> Bool {
        cell.imageView.image?.size == CGSize(width: 10, height: 10)
    }

    // MARK: Tests

    func testDoneAfterRingAlreadyHidden_paintsDownloadedImage() {
        let attachment = makeAttachment(id: 7001)
        let cell = makeBoundCell(attachment)
        settle()

        // Download runs to 100%; the ring shrinks out and its completion reloads the
        // thumbnail — but the file isn't on disk yet, so that reload stays blurred.
        cell.setProgress(0.5)
        cell.setProgress(1)
        XCTAssertTrue(waitUntil { cell.progressView.isHidden }, "ring should finish hiding")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(isSharp(cell))

        // Now the file lands and the transfer reports done.
        mock.setThumbnailPath(sharpPath, for: attachment.id)
        cell.attachmentTransferStatusDidChange(attachment, status: .done)

        XCTAssertTrue(waitUntil { self.isSharp(cell) },
                      "a done transfer must repaint the cell from the downloaded file")
    }

    func testDoneWithRingNeverShown_paintsDownloadedImage() {
        // The transfer was driven from another screen; this cell never showed a ring
        // and only learns about the finished file from a database re-sync.
        let attachment = makeAttachment(id: 7002)
        let cell = makeBoundCell(attachment)
        settle()
        XCTAssertTrue(cell.progressView.isHidden)

        mock.setThumbnailPath(sharpPath, for: attachment.id)
        cell.update(status: .done)

        XCTAssertTrue(waitUntil { self.isSharp(cell) },
                      "a done transfer must repaint the cell from the downloaded file")
    }

    func testDoneWhenLayoutAlreadySharp_repaintsStaleScreen() {
        // The layout healed (its sharp load landed) but the paint went to a slot this
        // cell no longer owns, so the screen still shows the placeholder.
        let attachment = makeAttachment(id: 7003)
        let cell = makeBoundCell(attachment)
        settle()
        let placeholder = UIImage()

        cell.data.onLoadThumbnail = nil
        mock.setThumbnailPath(sharpPath, for: attachment.id)
        cell.data.reloadThumbnailFromFileIfNeeded()
        XCTAssertTrue(waitUntil { cell.data.isThumbnailLoadedFromFile })
        cell.imageView.image = placeholder

        cell.update(status: .done)

        XCTAssertTrue(waitUntil { self.isSharp(cell) },
                      "a done transfer must show the layout's sharp thumbnail")
    }

    func testDoneUpgradesSmallFileBackedPoster() {
        // A video shows its small downloaded "video_thumb" poster — file-backed — before the
        // video itself is local. Once the video is done, a grid-sized frame must replace it;
        // a file-backed layout used to be treated as final.
        let attachment = makeAttachment(id: 7006)
        let cell = makeBoundCell(attachment)
        settle()
        let poster = UIImage(contentsOfFile: sharpPath)!            // 10×10
        cell.data.setFileBackedThumbnail(poster)
        XCTAssertTrue(cell.data.isThumbnailLoadedFromFile)

        let bigPath = try! writeImage(side: 400, color: .blue, name: "frame.jpg")
        mock.setThumbnailPath(bigPath, for: attachment.id)
        cell.update(status: .done)

        XCTAssertTrue(waitUntil { cell.imageView.image?.size == CGSize(width: 400, height: 400) },
                      "a done video must replace a too-small poster with its real thumbnail")
    }

    func testSharpRelayForSmallSourceImage_isAccepted() {
        // The source image itself is 10×10 — smaller than the cell — so no thumbnail of
        // it can ever meet the cell's pixel size. Rejecting it left the relay unable to
        // heal small images at all.
        let metadata = #"{"szw":10,"szh":10,"tmb":"","dur":0}"#
        let attachment = makeAttachment(id: 7004, metadata: metadata)
        let cell = makeBoundCell(attachment)
        settle()
        cell.data.onLoadThumbnail = nil

        let image = UIImage(contentsOfFile: sharpPath)!
        cell.attachmentSharpThumbnailDidLoad(attachment, image: image)

        XCTAssertTrue(isSharp(cell), "a thumbnail at the source's full resolution is as sharp as it gets")
    }
}
