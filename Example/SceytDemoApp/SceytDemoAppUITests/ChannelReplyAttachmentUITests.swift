//
//  ChannelReplyAttachmentUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  Black-box UI tests for the thumbnail a reply preview shows when the message it
//  quotes carries an image that has not been downloaded yet.
//
//  The reported bug: an image arrives and a reply quoting it arrives too. Both the
//  bubble and the reply preview correctly start out blurred (the low-res `thumbHash`
//  placeholder decoded from the attachment's metadata). The image then downloads,
//  the bubble swaps to the sharp picture — and the reply preview stays blurred,
//  sometimes forever.
//
//  The app is launched in `--uitest --uitest-reply-attachment` mode, which seeds
//  channel 100 ("UITest Chat") with a short history, then an incoming image message
//  with a remote url, a thumbHash in its metadata and NO local file, then an incoming
//  reply quoting it — see `UITestSupport` in the app target.
//
//  Both thumbnail slots publish what they actually paint through their accessibility
//  value (`thumbnail_blurred` / `thumbnail_sharp` / `thumbnail_none`), computed on
//  read straight from the layout the view is bound to — so a test reads exactly the
//  state a user is looking at, however many asynchronous paths raced to produce it.
//
//  The download is landed by a floating button that writes the real bytes to the path
//  the file storage resolves for the attachment and commits `filePath` + `.done` to
//  the database: the same two rows a genuine transfer writes, and nothing else. No
//  layout, view, relay or progress observer is touched, so everything downstream has
//  to heal off the database write alone — exactly as it does in production.
//

import XCTest

final class ChannelReplyAttachmentUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    private var imageCell: XCUIElement { screen.cell(Convo.imageMessageId) }
    private var replyCell: XCUIElement { screen.cell(Convo.imageReplyMessageId) }

    // MARK: - Fixture

    /// Launches the reply-to-image fixture and leaves both messages on screen with
    /// their previews confirmed blurred.
    private func openConversationWithBlurredImage() {
        app = launchApp(replyAttachment: true)
        list = ChannelListScreen(app: app)
        screen = ChannelScreen(app: app)

        XCTAssertTrue(list.waitUntilLoaded(), "The channel list should load")
        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10),
                      "The seeded conversation channel should appear in the list")
        listCell.tap()

        XCTAssertTrue(screen.waitUntilReady(), "The channel composer should appear")
        XCTAssertTrue(imageCell.waitForExistence(timeout: 10),
                      "The incoming image message should be on screen")
        XCTAssertTrue(replyCell.waitForExistence(timeout: 10),
                      "The reply quoting the image should be on screen")

        // The starting state, asserted rather than assumed: if either slot were
        // already sharp (a leftover file from a previous run) or published nothing
        // at all, every assertion below would pass vacuously.
        XCTAssertTrue(waitFor(timeout: 10) {
            self.screen.attachmentThumbnailState(in: self.imageCell) == ChannelScreen.AID.thumbnailBlurred
        }, "The image bubble should start on the blurred thumbHash placeholder; was: \(stateDescription())")

        XCTAssertTrue(waitFor(timeout: 10) {
            self.screen.replyThumbnailState(in: self.replyCell) == ChannelScreen.AID.thumbnailBlurred
        }, "The reply preview should start on the blurred thumbHash placeholder; was: \(stateDescription())")
    }

    /// Taps the download driver and confirms the bytes and the database rows really
    /// landed, so a swallowed tap fails as a harness problem rather than hiding the
    /// bug under test.
    private func completeTheDownload() {
        let driver = screen.completeAttachmentDownloadButton
        XCTAssertTrue(driver.waitForExistence(timeout: 10),
                      "The attachment-download driver button should be installed")
        driver.tap()

        XCTAssertTrue(waitFor(timeout: 10) { (driver.value as? String) == "ok" },
                      "The download should have landed (bytes written, rows committed); "
                          + "the driver reported \((driver.value as? String) ?? "<nothing>")")
    }

    // MARK: - The bug

    /// The reported bug. Once the image is on disk, the reply preview quoting it must
    /// swap to the sharp picture — just like the bubble does.
    ///
    /// Nothing rebuilds a reply's layout when its *parent's* attachment downloads: the
    /// message observer refreshes a row for `attachments.status` / `attachments.filePath`
    /// (which reaches the image's own message) but has no key path that reaches the
    /// message quoting it. So the reply preview has to heal itself, and when it does
    /// not, this fails while `test_afterTheImageDownloads_theBubbleGoesSharp` passes —
    /// which is exactly the shape the user reported.
    func test_afterTheImageDownloads_theReplyPreviewGoesSharp() {
        openConversationWithBlurredImage()
        completeTheDownload()

        // The bubble first: it heals through a full rebind, so it is the fastest
        // confirmation that the download really is visible to the UI at all. If this
        // times out the fixture is broken, not the reply preview.
        XCTAssertTrue(waitFor(timeout: 10) {
            self.screen.attachmentThumbnailState(in: self.imageCell) == ChannelScreen.AID.thumbnailSharp
        }, "The image bubble should render the downloaded image; was: \(stateDescription())")

        XCTAssertTrue(waitFor(timeout: 10) {
            self.screen.replyThumbnailState(in: self.replyCell) == ChannelScreen.AID.thumbnailSharp
        }, "The reply preview quoting the image must swap to the downloaded image once it "
            + "is on disk, instead of staying on the blurred placeholder; was: \(stateDescription())")
    }

    /// The same expectation after the reply cell has been scrolled out of view and back
    /// while the download lands. A preview that heals only on a fresh bind passes the
    /// test above by luck and fails here — or the other way round, which is just as
    /// useful to know.
    func test_afterTheImageDownloadsOffScreen_theReplyPreviewGoesSharpOnReturn() {
        openConversationWithBlurredImage()

        // Scroll the two newest messages away, land the download while they are off
        // screen, then come back.
        screen.collectionView.swipeDown()
        screen.collectionView.swipeDown()
        completeTheDownload()
        _ = waitFor(timeout: 2) { false }
        screen.collectionView.swipeUp()
        screen.collectionView.swipeUp()

        XCTAssertTrue(replyCell.waitForExistence(timeout: 10),
                      "The reply message should be back on screen")

        XCTAssertTrue(waitFor(timeout: 10) {
            self.screen.replyThumbnailState(in: self.replyCell) == ChannelScreen.AID.thumbnailSharp
        }, "A reply preview rebound after the download must render the downloaded image; "
            + "was: \(stateDescription())")
    }

    // MARK: - Baselines

    /// The bubble's own path, on its own. If this fails, the fixture or the download
    /// driver is broken and the tests above say nothing about the reply preview.
    func test_afterTheImageDownloads_theBubbleGoesSharp() {
        openConversationWithBlurredImage()
        completeTheDownload()

        XCTAssertTrue(waitFor(timeout: 10) {
            self.screen.attachmentThumbnailState(in: self.imageCell) == ChannelScreen.AID.thumbnailSharp
        }, "The image bubble should render the downloaded image once it is on disk; "
            + "was: \(stateDescription())")
    }

    /// Guards the fixture itself: before anything is downloaded, BOTH slots must be
    /// blurred. A fix that made the reply preview sharp too early — say by adopting a
    /// thumbnail from somewhere it does not belong — would show up here.
    func test_beforeTheDownload_bothPreviewsAreBlurred() {
        openConversationWithBlurredImage()

        // Give every asynchronous thumbnail path a chance to land something wrong.
        _ = waitFor(timeout: 3) { false }

        XCTAssertEqual(screen.attachmentThumbnailState(in: imageCell),
                       ChannelScreen.AID.thumbnailBlurred,
                       "The bubble must stay blurred until the image is downloaded; "
                           + "was: \(stateDescription())")
        XCTAssertEqual(screen.replyThumbnailState(in: replyCell),
                       ChannelScreen.AID.thumbnailBlurred,
                       "The reply preview must stay blurred until the image is downloaded; "
                           + "was: \(stateDescription())")
    }

    // MARK: - Helpers

    /// Both thumbnail states in one string, for failure messages — a reply stuck on
    /// `thumbnail_blurred` next to a bubble reading `thumbnail_sharp` is the whole
    /// diagnosis.
    private func stateDescription() -> String {
        let bubble = screen.attachmentThumbnailState(in: imageCell) ?? "<not on screen>"
        let reply = screen.replyThumbnailState(in: replyCell) ?? "<not on screen>"
        return "bubble=\(bubble) reply=\(reply)"
    }

    /// Polls `condition` until it is true or `timeout` elapses. Passing a condition
    /// that never holds simply idles for `timeout`, letting in-flight work settle
    /// before an assertion.
    private func waitFor(timeout: TimeInterval = 5,
                         _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
