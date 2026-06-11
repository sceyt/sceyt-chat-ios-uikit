//
//  AttachmentLayoutThumbnailTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat
import UIKit

// MARK: - Mock data session

/// Routes `fileProvider.thumbnailFile(for:preferred:)` to an in-memory map so each
/// attachment id resolves to a controlled image file. Thread-safe because
/// `loadThumbnail()` reads it from background queues.
final class MockThumbnailDataSession: NSObject, SCTDataSession {

    private let lock = NSLock()
    private var thumbnailPaths = [AttachmentId: String]()

    func setThumbnailPath(_ path: String?, for id: AttachmentId) {
        lock.lock(); defer { lock.unlock() }
        thumbnailPaths[id] = path
    }

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        lock.lock(); defer { lock.unlock() }
        return thumbnailPaths[attachment.id]
    }

    func getFilePath(attachment: ChatMessage.Attachment) -> String? { nil }
    func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {}
    func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {}
}

// MARK: - Tests

/// Pins down the `AttachmentLayout` thumbnail contract:
/// - each attachment loads the image its data session resolves to (no mixing),
/// - a layout's `onLoadThumbnail` cannot paint a view that has been rebound to
///   another layout (the `===` guard),
/// - a thumbnail that becomes available after a download is always delivered to
///   the currently bound view without requiring a rebind (no "appears only
///   after scrolling"),
/// - a corrupt thumbnail file does not permanently block reloading.
final class AttachmentLayoutThumbnailTests: XCTestCase {

    private var mock: MockThumbnailDataSession!
    private var originalDataSession: SCTDataSession?
    private var tempDir: URL!

    /// Image size doubles as the identity marker: "red" is 10×10, "blue" is 20×20.
    private var redPath: String!
    private var bluePath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mock = MockThumbnailDataSession()
        originalDataSession = Components.dataSession
        Components.dataSession = mock

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AttachmentLayoutThumbnailTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        redPath = try writeImage(side: 10, color: .red, name: "red.jpg")
        bluePath = try writeImage(side: 20, color: .blue, name: "blue.jpg")
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

    private func makeAttachment(
        id: AttachmentId,
        type: String = "image",
        name: String = "image.jpg",
        metadata: String? = nil,
        status: ChatMessage.Attachment.TransferStatus = .pending
    ) -> ChatMessage.Attachment {
        .init(
            id: id,
            tid: 0,
            messageId: 1,
            userId: "user",
            url: "https://example.com/files/\(id)/\(name)",
            filePath: nil,
            type: type,
            name: name,
            metadata: metadata,
            uploadedFileSize: 0,
            createdAt: Date(),
            status: status,
            transferProgress: 0
        )
    }

    private func makeLayout(
        _ attachment: ChatMessage.Attachment,
        async: Bool
    ) -> MessageLayoutModel.AttachmentLayout {
        .init(
            attachment: attachment,
            ownerMessage: nil,
            ownerChannel: nil,
            thumbnailSize: CGSize(width: 100, height: 100),
            asyncLoadThumbnail: async,
            appearance: MessageCell.appearance
        )
    }

    /// Spins the main run loop until `condition` is true or `timeout` elapses.
    /// Pumping the run loop is required because the layout publishes thumbnails
    /// via `DispatchQueue.main.async`.
    @discardableResult
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    private func imageWidth(_ view: MessageCell.AttachmentView) -> CGFloat {
        view.imageView.image?.size.width ?? 0
    }

    // MARK: - Right image per attachment

    func testLoadsCorrectThumbnailForEachAttachment() {
        mock.setThumbnailPath(redPath, for: 1)
        mock.setThumbnailPath(bluePath, for: 2)

        let layoutA = makeLayout(makeAttachment(id: 1), async: false)
        let layoutB = makeLayout(makeAttachment(id: 2), async: false)

        XCTAssertTrue(waitUntil { layoutA.thumbnail != nil && layoutB.thumbnail != nil })
        XCTAssertEqual(layoutA.thumbnail?.size.width, 10, "attachment 1 must load red.jpg")
        XCTAssertEqual(layoutB.thumbnail?.size.width, 20, "attachment 2 must load blue.jpg")
    }

    func testAsyncLoadDeliversCorrectThumbnailForEachAttachment() {
        mock.setThumbnailPath(redPath, for: 1)
        mock.setThumbnailPath(bluePath, for: 2)

        let layoutA = makeLayout(makeAttachment(id: 1), async: true)
        let layoutB = makeLayout(makeAttachment(id: 2), async: true)

        XCTAssertTrue(waitUntil {
            layoutA.thumbnail?.size.width == 10 && layoutB.thumbnail?.size.width == 20
        }, "async loads must deliver each attachment its own image")
    }

    // MARK: - Stale closure cannot cross-paint a rebound view

    func testStaleClosureFromReboundViewDoesNotPaint() {
        mock.setThumbnailPath(redPath, for: 1)
        mock.setThumbnailPath(bluePath, for: 2)

        let layoutA = makeLayout(makeAttachment(id: 1), async: false)
        let layoutB = makeLayout(makeAttachment(id: 2), async: false)

        let view = MessageCell.AttachmentImageView()
        view.data = layoutA
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 }, "view must paint A's thumbnail")

        view.data = layoutB
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 20 }, "view must paint B's thumbnail")

        // layoutA still holds the closure installed when the view displayed A.
        // Firing it simulates A's load finishing after the view moved on to B.
        let marker = UIImage()
        layoutA.onLoadThumbnail?(marker)
        XCTAssertFalse(view.imageView.image === marker,
                       "a stale layout's fire must not paint a view bound to another layout")
        XCTAssertEqual(imageWidth(view), 20, "view must keep B's thumbnail")

        // The currently bound layout's fire must still paint.
        layoutB.onLoadThumbnail?(marker)
        XCTAssertTrue(view.imageView.image === marker,
                      "the bound layout's fire must reach the view")
    }

    // MARK: - Download completion always paints the bound view

    func testThumbnailIsAlwaysPaintedAfterDownloadCompletes() {
        for i in 0..<30 {
            let id = AttachmentId(100 + i)
            let attachment = makeAttachment(id: id)
            // Not downloaded yet: resolves to no file. For an image without metadata
            // the placeholder is legitimately nil (AttachmentIconProvider returns nil
            // for images), so settle on the publish itself via a probe closure.
            let layout = makeLayout(attachment, async: true)
            var initialLoadSettled = false
            layout.onLoadThumbnail = { _ in initialLoadSettled = true }
            XCTAssertTrue(waitUntil { initialLoadSettled },
                          "iteration \(i): initial load must publish")

            let view = MessageCell.AttachmentImageView()
            view.data = layout

            // Download finishes: the file exists now, completion arrives off-main
            // like a URLSession callback.
            mock.setThumbnailPath(redPath, for: id)
            DispatchQueue.global().async {
                layout.update(attachment: attachment)
            }

            XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 },
                          "iteration \(i): thumbnail must reach the bound view without rebinding")
        }
    }

    // MARK: - Identity guard: same attachment, different layout instance

    func testStaleInstanceOfSameAttachmentDoesNotPaint() {
        mock.setThumbnailPath(redPath, for: 1)
        let attachment = makeAttachment(id: 1)

        // Two layout instances wrapping the SAME attachment. Attachment equality
        // (==) cannot tell them apart — only instance identity (===) can. This is
        // the test that fails if the guard is ever "simplified" to id/tid checks.
        let layoutOld = makeLayout(attachment, async: false)
        let layoutNew = makeLayout(attachment, async: false)

        let view = MessageCell.AttachmentImageView()
        view.data = layoutOld
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 })
        view.data = layoutNew
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 })

        let marker = UIImage()
        layoutOld.onLoadThumbnail?(marker)
        XCTAssertFalse(view.imageView.image === marker,
                       "a stale instance of the same attachment must not paint the view")
    }

    func testRebindingBackToOriginalLayoutPaintsAgain() {
        mock.setThumbnailPath(redPath, for: 1)
        mock.setThumbnailPath(bluePath, for: 2)
        let layoutA = makeLayout(makeAttachment(id: 1), async: false)
        let layoutB = makeLayout(makeAttachment(id: 2), async: false)

        let view = MessageCell.AttachmentImageView()
        view.data = layoutA
        view.data = layoutB
        view.data = layoutA
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 })

        let marker = UIImage()
        layoutA.onLoadThumbnail?(marker)
        XCTAssertTrue(view.imageView.image === marker,
                      "after rebinding back, the original layout's fire must paint again")
    }

    // MARK: - Subscription timing

    func testLateSubscriberIsFiredImmediately() {
        mock.setThumbnailPath(redPath, for: 1)
        let layout = makeLayout(makeAttachment(id: 1), async: false)

        var settled = false
        layout.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled }, "initial load must publish")

        // Assigning a closure after the load completed must fire it synchronously
        // (the onLoadThumbnail.didSet re-fire path) — no run loop pump after this line.
        var lateImage: UIImage?
        layout.onLoadThumbnail = { lateImage = $0 }
        XCTAssertEqual(lateImage?.size.width, 10,
                       "a subscriber attached after the load must receive the thumbnail immediately")
    }

    func testBindAfterLoadPaintsSynchronously() {
        mock.setThumbnailPath(redPath, for: 1)
        let layout = makeLayout(makeAttachment(id: 1), async: false)
        var settled = false
        layout.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })

        // Binding a settled layout must paint in didSet itself — the no-flicker contract.
        let view = MessageCell.AttachmentImageView()
        view.data = layout
        XCTAssertEqual(imageWidth(view), 10, "bind must paint synchronously, with no run loop pump")
    }

    // MARK: - update(attachment:) skip semantics

    func testUpdateSkipsReloadOnceLoadedFromFile() {
        let attachment = makeAttachment(id: 1)
        mock.setThumbnailPath(redPath, for: 1)
        let layout = makeLayout(attachment, async: false)
        XCTAssertTrue(waitUntil { layout.thumbnail?.size.width == 10 })

        // The thumbnail file for a given path never changes content by contract,
        // so once loaded from file, update(attachment:) must not reload.
        mock.setThumbnailPath(bluePath, for: 1)
        layout.update(attachment: attachment)
        _ = waitUntil(timeout: 0.3) { false } // give a wrongful reload time to land
        XCTAssertEqual(layout.thumbnail?.size.width, 10,
                       "update must skip reloading once the thumbnail came from a file")
    }

    // MARK: - Video view guard

    func testVideoViewBlocksStaleClosureFire() {
        mock.setThumbnailPath(redPath, for: 1)
        mock.setThumbnailPath(bluePath, for: 2)
        let layoutA = makeLayout(makeAttachment(id: 1, type: "video", name: "a.mp4"), async: false)
        let layoutB = makeLayout(makeAttachment(id: 2, type: "video", name: "b.mp4"), async: false)

        let view = MessageCell.AttachmentVideoView()
        view.data = layoutA
        XCTAssertTrue(waitUntil { (view.imageView.image?.size.width ?? 0) == 10 })
        view.data = layoutB
        XCTAssertTrue(waitUntil { (view.imageView.image?.size.width ?? 0) == 20 })

        let marker = UIImage()
        layoutA.onLoadThumbnail?(marker)
        XCTAssertFalse(view.imageView.image === marker,
                       "video view must also block stale layout fires")

        layoutB.onLoadThumbnail?(marker)
        XCTAssertTrue(view.imageView.image === marker,
                      "video view must accept the bound layout's fire")
    }

    // MARK: - Lifecycle

    func testLayoutDeallocatesDespiteInstalledClosure() {
        mock.setThumbnailPath(redPath, for: 1)
        var layout: MessageLayoutModel.AttachmentLayout? = makeLayout(makeAttachment(id: 1), async: false)
        weak var weakLayout = layout

        var settled = false
        layout?.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })

        var view: MessageCell.AttachmentImageView? = MessageCell.AttachmentImageView()
        view?.data = layout

        layout = nil
        view = nil
        XCTAssertNil(weakLayout,
                     "the view-installed closure must not retain the layout ([weak data])")
    }

    // MARK: - Concurrency smoke

    func testConcurrentUpdatesConvergeToCorrectThumbnail() {
        let attachment = makeAttachment(id: 1)
        mock.setThumbnailPath(redPath, for: 1)
        let layout = makeLayout(attachment, async: true)

        for _ in 0..<20 {
            DispatchQueue.global().async {
                layout.update(attachment: attachment)
            }
        }

        XCTAssertTrue(waitUntil { layout.thumbnail?.size.width == 10 },
                      "concurrent updates must converge to the correct thumbnail")
    }

    // MARK: - Corrupt thumbnail file does not poison reloading

    func testCorruptThumbnailFileDoesNotBlockReload() throws {
        let id: AttachmentId = 7
        let attachment = makeAttachment(id: id)

        let garbageURL = tempDir.appendingPathComponent("garbage.jpg")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: garbageURL)
        mock.setThumbnailPath(garbageURL.path, for: id)

        let layout = makeLayout(attachment, async: false)
        var initialLoadSettled = false
        layout.onLoadThumbnail = { _ in initialLoadSettled = true }
        XCTAssertTrue(waitUntil { initialLoadSettled }, "first load must publish")
        XCTAssertNotEqual(layout.thumbnail?.size.width, 10,
                          "corrupt file must not decode into a thumbnail")

        // The file is replaced with a valid one (e.g. re-download repaired it).
        mock.setThumbnailPath(redPath, for: id)
        layout.update(attachment: attachment)

        XCTAssertTrue(waitUntil { layout.thumbnail?.size.width == 10 },
                      "a corrupt first load must not permanently block reloading from file")
    }
}
