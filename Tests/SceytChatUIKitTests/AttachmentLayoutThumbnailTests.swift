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
        status: ChatMessage.Attachment.TransferStatus = .pending,
        filePath: String? = nil
    ) -> ChatMessage.Attachment {
        .init(
            id: id,
            tid: 0,
            messageId: 1,
            userId: "user",
            url: "https://example.com/files/\(id)/\(name)",
            filePath: filePath,
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
        async: Bool,
        thumbnailSize: CGSize = CGSize(width: 100, height: 100)
    ) -> MessageLayoutModel.AttachmentLayout {
        .init(
            attachment: attachment,
            ownerMessage: nil,
            ownerChannel: nil,
            thumbnailSize: thumbnailSize,
            asyncLoadThumbnail: async,
            appearance: MessageCell.appearance
        )
    }

    /// A design size small enough that the 10px fixtures satisfy the relay's
    /// size-adequacy guard on any simulator scale (3×3 → ≤8.1px required @3x).
    private let relayCompatibleSize = CGSize(width: 3, height: 3)

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
        weak var weakLayout: MessageLayoutModel.AttachmentLayout?

        // Scope the strong refs to an explicit pool: views are weak-registered in
        // AttachmentSharpThumbnailRelay, and any weak-table read (a relay post — including
        // one from a neighboring test's leftover async work) retains+autoreleases the live
        // members, deferring their death to the next pool drain. That is not a leak; what
        // this test guards against is PERMANENT retention, which would survive the drain.
        autoreleasepool {
            var layout: MessageLayoutModel.AttachmentLayout? = makeLayout(makeAttachment(id: 1), async: false)
            weakLayout = layout

            var settled = false
            layout?.onLoadThumbnail = { _ in settled = true }
            XCTAssertTrue(waitUntil { settled })

            var view: MessageCell.AttachmentImageView? = MessageCell.AttachmentImageView()
            view?.data = layout

            layout = nil
            view = nil
        }
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

    // MARK: - Bind-time self-heal ("blurry placeholder stays after download")

    /// The core fix. A downloaded image whose layout is stuck on the low-res placeholder —
    /// because the sharp post-download load landed on a *different* (duplicate) layout
    /// instance, or the progress-completion observer never fired for this view — must be
    /// healed simply by (re)binding the view: it pulls the sharp thumbnail from disk on its
    /// own, with no `update(attachment:)`, no progress completion, and no `onLoadThumbnail`
    /// fire. This is what makes "scroll fixes it" automatic.
    func testBindSelfHealsDownloadedImageStuckOnPlaceholder() {
        let id: AttachmentId = 200
        let attachment = makeAttachment(id: id, status: .done)

        // Initial load runs while the file is not yet resolvable → the layout settles on the
        // placeholder (isThumbnailLoadedFromFile == false). This is the "blurry stays" state.
        let layout = makeLayout(attachment, async: false)
        var initialSettled = false
        layout.onLoadThumbnail = { _ in initialSettled = true }
        XCTAssertTrue(waitUntil { initialSettled }, "initial (file-less) load must publish")
        XCTAssertFalse(layout.isThumbnailLoadedFromFile,
                       "precondition: layout is on the placeholder, not file-backed")

        // The sharp thumbnail is now on disk, but nothing pushes it into the layout.
        mock.setThumbnailPath(redPath, for: id)

        let view = MessageCell.AttachmentImageView()
        view.data = layout
        // isThumbnailLoadedFromFile flips to true ONLY via the file-load path
        // (setFileBackedThumbnail) — the definitive signal that the bind-time self-heal ran.
        // (imageView width alone can't tell us: the onLoadThumbnail fallback
        // `attachment.thumbnailImage` also reads the same mocked file.)
        XCTAssertTrue(waitUntil { layout.isThumbnailLoadedFromFile },
                      "binding a downloaded image not yet file-backed must self-heal from disk")
        XCTAssertEqual(imageWidth(view), 10, "the healed view shows the sharp thumbnail")
    }

    /// Faithful reproduction of the production symptom: the layout carries a *non-nil* low-res
    /// placeholder (the decoded thumbHash). Because `thumbnail` is non-nil, the onLoadThumbnail
    /// `?? attachment.thumbnailImage` fallback is never reached — the cell paints the blurry
    /// placeholder and stays there until a scroll. The bind-time self-heal must swap it for the
    /// sharp file thumbnail. Distinguishable by size: blue 20×20 placeholder → red 10×10 sharp.
    func testBindSwapsNonNilBlurryPlaceholderToSharp() {
        let id: AttachmentId = 230
        let attachment = makeAttachment(id: id, status: .done)
        let layout = makeLayout(attachment, async: false)
        var settled = false
        layout.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })

        // Stand in for the blurry thumbHash: a non-nil placeholder that is NOT file-backed.
        layout.thumbnail = UIImage(contentsOfFile: bluePath)
        XCTAssertFalse(layout.isThumbnailLoadedFromFile, "precondition: placeholder, not file-backed")

        // The sharp thumbnail is now on disk.
        mock.setThumbnailPath(redPath, for: id)

        let view = MessageCell.AttachmentImageView()
        view.data = layout
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 },
                      "bind must swap the non-nil blurry placeholder (20) for the sharp thumbnail (10)")
        XCTAssertTrue(layout.isThumbnailLoadedFromFile)
    }

    /// Even if the sharp post-download load was delivered to a *sibling* layout instance
    /// (the duplicate-instance race), the view bound to the instance that never received it
    /// still heals on bind. The strict `===` guard is preserved — see
    /// `testStaleInstanceOfSameAttachmentDoesNotPaint` — so cross-instance delivery happens
    /// via disk, not by accepting a foreign instance's fire.
    func testBindSelfHealsEvenWhenSharpLoadLandedOnDuplicateInstance() {
        let id: AttachmentId = 210
        let attachment = makeAttachment(id: id, status: .done)
        let visible = makeLayout(attachment, async: false)
        let orphan = makeLayout(attachment, async: false)
        var visibleSettled = false, orphanSettled = false
        visible.onLoadThumbnail = { _ in visibleSettled = true }
        orphan.onLoadThumbnail = { _ in orphanSettled = true }
        XCTAssertTrue(waitUntil { visibleSettled && orphanSettled })

        // Download completes: the file is available and the load is delivered to the ORPHAN
        // instance only (mirrors the observer/cache fan-out updating a duplicate layout).
        mock.setThumbnailPath(redPath, for: id)
        orphan.update(attachment: attachment)
        XCTAssertTrue(waitUntil { orphan.isThumbnailLoadedFromFile },
                      "the duplicate instance received the sharp thumbnail")
        XCTAssertFalse(visible.isThumbnailLoadedFromFile,
                       "the visible instance never received the sharp load (the bug)")

        // Binding the view to the *visible* instance must heal that instance from disk.
        let view = MessageCell.AttachmentImageView()
        view.data = visible
        XCTAssertTrue(waitUntil { visible.isThumbnailLoadedFromFile },
                      "the view must heal its own instance from disk regardless of which got the load")
        XCTAssertEqual(imageWidth(view), 10)
    }

    /// The self-heal is gated on `.done`: an attachment that is still downloading must not
    /// pull from disk (the file is not final yet), so the placeholder remains.
    func testBindDoesNotHealWhileStillDownloading() {
        let id: AttachmentId = 202
        let attachment = makeAttachment(id: id, status: .downloading)
        let layout = makeLayout(attachment, async: false)
        var settled = false
        layout.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })
        XCTAssertFalse(layout.isThumbnailLoadedFromFile)

        // File becomes resolvable, but the transfer is still in progress.
        mock.setThumbnailPath(redPath, for: id)

        let view = MessageCell.AttachmentImageView()
        view.data = layout
        _ = waitUntil(timeout: 0.4) { false } // give a wrongful reload time to land
        // The self-heal would flip isThumbnailLoadedFromFile via setFileBackedThumbnail; the
        // status gate must prevent it. (imageView may show the file via the thumbnailImage
        // fallback, so the flag — not the pixels — is the correct signal here.)
        XCTAssertFalse(layout.isThumbnailLoadedFromFile,
                       "bind must not file-back from disk until the attachment is downloaded (.done)")
    }

    /// The self-heal is gated on `!isThumbnailLoadedFromFile`: once a sharp file-backed
    /// thumbnail is loaded, binding must not re-read the disk (avoids redundant work and,
    /// since a thumbnail path's content is fixed by contract, prevents any unexpected swap).
    func testBindDoesNotReloadWhenAlreadyFileBacked() {
        let id: AttachmentId = 203
        mock.setThumbnailPath(redPath, for: id)
        let attachment = makeAttachment(id: id, status: .done)
        let layout = makeLayout(attachment, async: false)
        XCTAssertTrue(waitUntil { layout.thumbnail?.size.width == 10 })
        XCTAssertTrue(layout.isThumbnailLoadedFromFile, "precondition: already file-backed")

        // Swap the underlying file. A wrongful re-pull on bind would change the view to blue.
        mock.setThumbnailPath(bluePath, for: id)
        let view = MessageCell.AttachmentImageView()
        view.data = layout
        _ = waitUntil(timeout: 0.4) { false }
        XCTAssertEqual(imageWidth(view), 10,
                       "bind must not re-pull from disk once the thumbnail is file-backed")
    }

    /// The video view (a separate `AttachmentView` subclass with its own `data` override) has
    /// the same bug and must get the same self-heal.
    func testVideoBindSelfHealsDownloadedVideoStuckOnPlaceholder() {
        let id: AttachmentId = 220
        let attachment = makeAttachment(id: id, type: "video", name: "v.mp4", status: .done)
        let layout = makeLayout(attachment, async: false)
        var initialSettled = false
        layout.onLoadThumbnail = { _ in initialSettled = true }
        XCTAssertTrue(waitUntil { initialSettled })
        XCTAssertFalse(layout.isThumbnailLoadedFromFile)

        mock.setThumbnailPath(redPath, for: id)

        let view = MessageCell.AttachmentVideoView()
        view.data = layout
        XCTAssertTrue(waitUntil { layout.isThumbnailLoadedFromFile },
                      "binding a downloaded video not yet file-backed must self-heal from disk")
        XCTAssertEqual(view.imageView.image?.size.width, 10)
    }

    // MARK: - Sharp-thumbnail relay (instance-agnostic delivery, no rebind required)

    /// Case 5: every sharp apply can land on layout instances whose `onLoadThumbnail` slot is
    /// owned by a dead view, leaving the model "healed" while no live view painted. The relay
    /// must deliver a sharp load that lands on a *sibling* instance to the live bound view with
    /// NO rebind, NO completion callback, and NO self-heal (the bound layout stays .downloading,
    /// which gates the bind-time heal — isolating the relay as the only possible healer).
    func testRelayHealsBoundViewWhenSharpLoadLandsOnSiblingInstance() {
        let id: AttachmentId = 300
        let visible = makeLayout(makeAttachment(id: id, status: .downloading), async: false, thumbnailSize: relayCompatibleSize)
        var settled = false
        visible.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })
        XCTAssertFalse(visible.isThumbnailLoadedFromFile)

        let view = MessageCell.AttachmentImageView()
        view.data = visible

        // Download lands: the sharp file appears and a SIBLING layout (fresh equal-identity
        // attachment object, as the observer fan-out produces) loads it and posts to the relay.
        mock.setThumbnailPath(redPath, for: id)
        let sibling = makeLayout(makeAttachment(id: id, status: .done), async: false)
        XCTAssertTrue(waitUntil { sibling.isThumbnailLoadedFromFile },
                      "precondition: the sibling instance received the sharp load")

        XCTAssertTrue(waitUntil { visible.isThumbnailLoadedFromFile },
                      "the relay must heal the bound instance when the sharp load lands on a sibling")
        XCTAssertEqual(imageWidth(view), 10, "the live view must paint sharp without any rebind")
    }

    /// The exact Case 5 mechanics: the bound layout's closure slot is owned by another (dead)
    /// view — cell reuse and back-to-back reconfigures can rebind/steal the single slot in any
    /// order. When the layout's own sharp load then fires the stolen slot, the live view gets
    /// nothing from the closure path; the relay's direct paint must cover it.
    func testRelayPaintsViewWhenClosureSlotIsOwnedElsewhere() {
        let id: AttachmentId = 310
        let attachment = makeAttachment(id: id, status: .downloading)
        let layout = makeLayout(attachment, async: false, thumbnailSize: relayCompatibleSize)
        var settled = false
        layout.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })

        let view = MessageCell.AttachmentImageView()
        view.data = layout
        // A dying sibling view bound to the same instance overwrites the slot after us.
        layout.onLoadThumbnail = { _ in }

        mock.setThumbnailPath(redPath, for: id)
        layout.update(attachment: attachment)

        XCTAssertTrue(waitUntil { self.imageWidth(view) == 10 },
                      "the relay must paint the live view directly even when the closure slot is owned elsewhere")
        XCTAssertTrue(layout.isThumbnailLoadedFromFile)
    }

    /// Identity isolation: a relay post for one attachment must never repaint a view bound to a
    /// different attachment (the multicast analog of the `===` cross-paint guard).
    func testRelayDoesNotTouchViewsBoundToOtherAttachments() {
        mock.setThumbnailPath(bluePath, for: 2)
        let other = makeLayout(makeAttachment(id: 2), async: false)
        let view = MessageCell.AttachmentImageView()
        view.data = other
        XCTAssertTrue(waitUntil { self.imageWidth(view) == 20 })

        // A different attachment loads sharp and posts.
        mock.setThumbnailPath(redPath, for: 1)
        let poster = makeLayout(makeAttachment(id: 1), async: false)
        XCTAssertTrue(waitUntil { poster.isThumbnailLoadedFromFile })

        _ = waitUntil(timeout: 0.3) { false } // give a wrongful cross-paint time to land
        XCTAssertEqual(imageWidth(view), 20,
                       "a relay post for another attachment must not repaint this view")
    }

    /// The video view is a separate `AttachmentView` subclass with its own `data` override and
    /// closure wiring — it must get the same relay heal.
    func testRelayHealsVideoViewWhenSharpLoadLandsOnSiblingInstance() {
        let id: AttachmentId = 320
        let visible = makeLayout(makeAttachment(id: id, type: "video", name: "v.mp4", status: .downloading), async: false, thumbnailSize: relayCompatibleSize)
        var settled = false
        visible.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })

        let view = MessageCell.AttachmentVideoView()
        view.data = visible

        mock.setThumbnailPath(redPath, for: id)
        let sibling = makeLayout(makeAttachment(id: id, type: "video", name: "v.mp4", status: .done), async: false)
        XCTAssertTrue(waitUntil { sibling.isThumbnailLoadedFromFile })

        XCTAssertTrue(waitUntil { visible.isThumbnailLoadedFromFile },
                      "the relay must heal the bound video instance from a sibling's sharp load")
        XCTAssertEqual(view.imageView.image?.size.width, 10)
    }

    /// Case 6: the relay is keyed by attachment identity only, but one attachment is consumed
    /// at several design sizes — the message bubble AND a small reply preview. The reply-sized
    /// sibling's file-backed load is sharp for ITS size yet far too small for the bubble;
    /// accepting it would repaint the bubble pixelated and lock the layout file-backed so no
    /// reload path could restore the right thumbnail (the WAAFI rotation repro, 2026-07-16).
    func testRelayIgnoresThumbnailTooSmallForThisConsumer() {
        let id: AttachmentId = 330
        // Bubble consumer: 100×100 design → the 10px fixture can never satisfy it.
        let visible = makeLayout(makeAttachment(id: id, status: .downloading), async: false)
        var settled = false
        visible.onLoadThumbnail = { _ in settled = true }
        XCTAssertTrue(waitUntil { settled })

        let view = MessageCell.AttachmentImageView()
        view.data = visible

        // Reply-preview consumer of the SAME attachment loads its small sharp file and posts.
        mock.setThumbnailPath(redPath, for: id)
        let replySibling = makeLayout(makeAttachment(id: id, status: .done), async: false, thumbnailSize: relayCompatibleSize)
        XCTAssertTrue(waitUntil { replySibling.isThumbnailLoadedFromFile },
                      "precondition: the reply-sized sibling received its sharp load")

        _ = waitUntil(timeout: 0.3) { false } // give a wrongful clobber time to land
        XCTAssertFalse(visible.isThumbnailLoadedFromFile,
                       "a too-small relayed thumbnail must not lock the bubble layout file-backed")
        XCTAssertTrue(view.imageView.image !== replySibling.thumbnail,
                      "the bubble must not paint the reply-preview-resolution image")
    }

    /// Defense-in-depth for Case 6: once a layout is file-backed, a smaller image must never
    /// replace the bigger one in place — isThumbnailLoadedFromFile keeps gating every reload
    /// path afterwards, so a downgrade would stick until the layout is rebuilt.
    func testSetFileBackedThumbnailNeverDowngrades() {
        mock.setThumbnailPath(bluePath, for: 2)
        let layout = makeLayout(makeAttachment(id: 2), async: false)
        XCTAssertTrue(waitUntil { layout.isThumbnailLoadedFromFile })
        XCTAssertEqual(layout.thumbnail?.size.width, 20)

        let smaller = UIImage(contentsOfFile: redPath)!
        layout.setFileBackedThumbnail(smaller)
        XCTAssertEqual(layout.thumbnail?.size.width, 20,
                       "a smaller image must not replace the bigger file-backed thumbnail")
        XCTAssertTrue(layout.isThumbnailLoadedFromFile)
    }

    // MARK: - Live reconfigure trigger (MessageLayoutModel.update(message:))

    private func makeChannel() -> ChatChannel {
        ChatChannel(id: 100, type: "group", uri: "test-uri")
    }

    /// Messages here must carry a user: `MessageLayoutModel.init` calls
    /// `senderNameFormatter.format(message.user)`, which force-unwraps it.
    private func makeMediaMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(id: 1, channelId: 100, attachments: attachments, user: ChatUser(id: "u1"))
    }

    /// The bind-time self-heal only fires on a (re)bind. For the LIVE case (download completes
    /// while the cell is visible, no scroll), the cell must be reconfigured. `update(message:)`
    /// must therefore force a reconfigure on the media download-completion edge — otherwise the
    /// change is swallowed (filePath/status are not render-affecting in the classic reload path,
    /// and the event is dropped at makeEvents' `guard !paths.isEmpty`). We assert via the durable
    /// `contentVersion` (the signal the snapshot diff reloads on) and the `.reload` updateOption
    /// (what keeps the reload hint alive through the VM pipeline).
    func testUpdateForcesReconfigureWhenMediaFinishesDownloading() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, status: .downloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        // Same attachment id, now downloaded.
        model.update(channel: channel, message: makeMediaMessage([makeAttachment(id: 1, status: .done)]))

        XCTAssertGreaterThan(model.contentVersion, versionBefore,
                             "a media download-completion must bump contentVersion so the cell reconfigures")
        XCTAssertTrue(model.updateOptions.contains(.reload),
                      "completion edge must insert .reload to survive makeEvents' empty-paths guard")
    }

    /// The reconfigure trigger is scoped to the completion *edge* — an attachment that is still
    /// downloading (no .done transition) must NOT force a reconfigure, so we don't churn the cell
    /// (and tear down its progress observer) on every transfer event.
    func testUpdateDoesNotForceReconfigureWhileStillDownloading() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, status: .downloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        // Still downloading — no completion edge.
        model.update(channel: channel, message: makeMediaMessage([makeAttachment(id: 1, status: .downloading)]))

        XCTAssertEqual(model.contentVersion, versionBefore,
                       "no completion edge → no forced reconfigure")
        XCTAssertFalse(model.updateOptions.contains(.reload))
    }

    /// Real download ordering: the downloader writes `filePath` BEFORE flipping status to `.done`
    /// (SCTSession: updateLocalFileLocation → success), so the observer can emit an intermediate
    /// `.downloading + filePath` state. The reconfigure edge must be aligned to `.done` (the view's
    /// self-heal gate): it must NOT be consumed by the earlier filePath arrival, and it MUST fire on
    /// the later `.done` transition. (A filePath-based edge would fire while still `.downloading` —
    /// when the self-heal can't run — and then miss the real `.done` edge, leaving it blurry.)
    func testUpdateForcesReconfigureOnDoneEvenWhenFilePathArrivesFirst() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, status: .downloading)]),
            appearance: MessageCell.appearance)

        // Intermediate: filePath written, but status is still .downloading. The self-heal is gated
        // on .done, so this must NOT consume the completion edge.
        model.update(channel: channel, message: makeMediaMessage([makeAttachment(id: 1, status: .downloading, filePath: "/tmp/sceyt-test-thumb.jpg")]))
        let versionAfterFilePath = model.contentVersion

        // .done arrives — the edge the self-heal acts on; it MUST reconfigure here.
        model.update(channel: channel, message: makeMediaMessage([makeAttachment(id: 1, status: .done, filePath: "/tmp/sceyt-test-thumb.jpg")]))

        XCTAssertGreaterThan(model.contentVersion, versionAfterFilePath,
                             "reconfigure must fire on the .done edge even when filePath arrived earlier")
        XCTAssertTrue(model.updateOptions.contains(.reload))
    }

    // MARK: - Live reconfigure trigger (pause / resume)

    /// The reported bug: pausing a download from the Media tab left the chat thread's *visible*
    /// cell spinning, while scrolling it out of view and back showed it correctly paused.
    /// `updateAttachmentLayouts` heals the layout in place (hence the correct state on rebind),
    /// but a status-only change inserts no updateOption, so `contentVersion` never bumped,
    /// `makeEvents` stripped the reload hint and the snapshot diff reconfigured nothing.
    func testUpdateForcesReconfigureWhenADownloadIsPaused() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .downloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        model.update(channel: channel,
                     message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .pauseDownloading)]))

        XCTAssertGreaterThan(model.contentVersion, versionBefore,
                             "a pause raised on another screen must bump contentVersion so the visible cell reconfigures")
        XCTAssertTrue(model.updateOptions.contains(.reload),
                      "the pause edge must insert .reload to survive makeEvents' hint strip")
    }

    /// And back again — resuming from the Media tab has the identical gap.
    func testUpdateForcesReconfigureWhenADownloadIsResumed() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .pauseDownloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        model.update(channel: channel,
                     message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .downloading)]))

        XCTAssertGreaterThan(model.contentVersion, versionBefore,
                             "a resume must reconfigure the visible cell too")
        XCTAssertTrue(model.updateOptions.contains(.reload))
    }

    /// A download that fails is the same class of change — the cell has to swap to its retry
    /// affordance rather than keep a ring that silently stopped.
    func testUpdateForcesReconfigureWhenADownloadFails() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .downloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        model.update(channel: channel,
                     message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .failedDownloading)]))

        XCTAssertGreaterThan(model.contentVersion, versionBefore)
    }

    /// `didFinishDownloadingMedia` is scoped to image/video, so a file or voice attachment
    /// reaching `.done` bumped nothing and depended entirely on its progress subscription
    /// still being alive. The transfer-state edge is deliberately type-agnostic.
    func testUpdateForcesReconfigureWhenAFileFinishesDownloading() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, type: "file", name: "doc.pdf", status: .downloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        model.update(channel: channel,
                     message: makeMediaMessage([makeAttachment(id: 1, type: "file", name: "doc.pdf", status: .done)]))

        XCTAssertGreaterThan(model.contentVersion, versionBefore,
                             "a file download completing must reconfigure the cell, not only image/video")
    }

    /// The guard that keeps this cheap: the edge is gated on the *class* of the status, so the
    /// per-tick progress stream — which never changes `status` — cannot reach it. Without this
    /// the cell would be torn down and rebuilt on every byte, taking its progress observer with it.
    func testUpdateDoesNotReconfigureForProgressOnlyChanges() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .downloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        let ticked = makeAttachment(id: 1, type: "video", status: .downloading)
        ticked.transferProgress = 0.42
        model.update(channel: channel, message: makeMediaMessage([ticked]))

        XCTAssertEqual(model.contentVersion, versionBefore,
                       "progress ticks must never reconfigure the cell")
        XCTAssertFalse(model.updateOptions.contains(.reload))
    }

    /// Pausing and resuming are both *within* the paused class in one direction only — going
    /// from one paused state to another (pause -> failed) is not a rendered class change and
    /// must stay cheap.
    func testUpdateDoesNotReconfigureBetweenTwoInactiveStates() {
        let channel = makeChannel()
        let model = MessageLayoutModel(
            channel: channel,
            message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .pauseDownloading)]),
            appearance: MessageCell.appearance)
        let versionBefore = model.contentVersion

        model.update(channel: channel,
                     message: makeMediaMessage([makeAttachment(id: 1, type: "video", status: .failedDownloading)]))

        XCTAssertEqual(model.contentVersion, versionBefore)
    }
}
