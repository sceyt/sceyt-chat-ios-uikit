//
//  ChannelPinnedMessagesUITests.swift
//  SceytDemoAppUITests
//
//  Covers pinning end to end: the context-menu action and its Pin For All / Pin For Me
//  sub-step, the pin beside the timestamp, the banner under the navigation bar, its
//  preview text for each message type, swiping between pins, and the layout the banner
//  leaves behind when the last pin goes away.
//

import XCTest

final class ChannelPinnedMessagesUITests: BaseUITestCase {

    private var screen: ChannelScreen!
    /// The launched app, kept so a test can reach elements the page object does not
    /// wrap — the presented screen's navigation bar, the confirmation alert.
    private var app: XCUIApplication!

    /// The fixture seeded by `--uitest-pinned-messages`. Mirrors `UITestSupport`.
    private enum Pinned {
        static let channelId: UInt64 = 100
        static func messageId(_ index: UInt64) -> UInt64 { channelId * 10_000 + index }

        static var textId: UInt64 { messageId(31) }
        static var videoId: UInt64 { messageId(32) }
        static var pollId: UInt64 { messageId(33) }

        static func rowIdentifier(_ id: UInt64) -> String {
            "sceyt_chat_pinned_message_list_cell.\(id)"
        }

        /// The pinned rows in timeline order — the order the list must show them in.
        static var allRowIdentifiers: [String] {
            [textId, videoId, pollId].map(rowIdentifier)
        }

        static let bannerTitle = "Pinned Messages"
        static let textPreview = "Do you know what time is it?"
        static let videoPreview = "Video"
        static let pollPreview = "Poll: With title"
        /// The poll's question, which is the message's own body — what a bubble shows,
        /// with none of the banner's "Poll: " framing.
        static let pollQuestion = "With title"
    }

    // MARK: - Helpers

    private func openConversation(_ launched: XCUIApplication) {
        app = launched
        let list = ChannelListScreen(app: app)
        screen = ChannelScreen(app: app)

        XCTAssertTrue(list.waitUntilLoaded(), "The channel list should load")
        let listCell = list.cell(Pinned.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10),
                      "The seeded conversation channel should appear in the list")
        listCell.tap()
        XCTAssertTrue(screen.waitUntilReady(), "The channel composer should appear")
    }

    private func openPinnedConversation(single: Bool = false) {
        openConversation(launchApp(pinnedMessages: !single, pinnedMessagesSingle: single))
    }

    /// Opens a conversation with nothing pinned, so a test can pin through the real UI.
    /// `edited` marks the outgoing message as edited, which is the widest the info row
    /// beside the timestamp ever gets.
    private func openPlainConversation(edited: Bool = false) {
        openConversation(launchApp(conversation: true, conversationEdited: edited))
    }

    /// Opens a conversation whose newest message is an outgoing one still in the
    /// `.pending` delivery state.
    private func openConversationWithPendingMessage() {
        openConversation(launchApp(conversation: true, conversationPending: true))
    }

    // MARK: - Banner presence

    func testNoPins_hidesTheBanner() {
        openPlainConversation()

        XCTAssertFalse(screen.pinnedMessagesView.waitForExistence(timeout: 2),
                       "nothing is pinned, so the banner must stay down")
    }

    /// The banner's resting state: up, titled, and showing the *oldest* pin — it has to walk
    /// the conversation forward and stay put while the user scrolls.
    func testSeededPins_showTheBannerOnTheOldestPin() {
        openPinnedConversation()

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "three messages are pinned, so the banner must be up")
        XCTAssertEqual(screen.pinnedMessagesTitle.label, Pinned.bannerTitle)
        XCTAssertTrue(screen.pinnedMessagesButton.exists,
                      "the banner's pin button opens the pinned list")

        // Without this, "showing pin 1 of 3" and "only one pin ever landed" look identical
        // from the preview alone, and every paging assertion could pass vacuously.
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3",
                       "all three seeded pins must have landed")
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.textPreview,
                       "pins are ordered by the conversation, not by when they were pinned")
    }

    // MARK: - Preview formatting

    /// The three shapes `PinnedMessageBodyFormatter` has to get right: a plain body, an
    /// attachment with no caption, and a poll.
    func testBannerPreview_formatsEachMessageType() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.textPreview,
                       "a text message previews as its body")

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(
            waitForPreview(Pinned.videoPreview),
            "a caption-less video must preview as \"Video\", got \"\(screen.pinnedMessagesPreview.label)\""
        )

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(
            waitForPreview(Pinned.pollPreview),
            "a poll must preview as \"Poll: <question>\", got \"\(screen.pinnedMessagesPreview.label)\""
        )
    }

    // MARK: - Paging

    func testSwipingTheBanner_walksThePinsAndWraps() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.textPreview)

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.videoPreview))
        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.pollPreview))

        // Third of three: the next swipe must wrap rather than dead-end.
        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.textPreview),
                      "swiping past the last pin must wrap to the first")
    }

    func testSwipingBack_walksThePinsInReverse() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        // Backwards from the first pin wraps to the last.
        screen.swipeToPreviousPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.pollPreview),
                      "swiping back from the first pin must wrap to the last")
    }

    // MARK: - Tapping the banner

    /// The point of the tap gesture: it hands the banner the *next* pin, so repeated taps
    /// walk the pins without the user ever finding the swipe or the full list.
    func testTappingTheBanner_advancesToTheNextPin() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3")

        screen.tapPinnedBanner()

        XCTAssertTrue(waitForBannerValue("2/3"),
                      "a tap must move the banner on, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(waitForPreview(Pinned.videoPreview))
    }

    func testTappingThroughAllPins_wrapsToTheFirst() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("2/3"))
        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("3/3"))

        // Third of three: the next tap must come back round rather than dead-end.
        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("1/3"),
                      "tapping past the last pin must return to the first")
        XCTAssertTrue(waitForPreview(Pinned.textPreview))
    }

    /// A tap has to move the *list* as well as the banner, and it goes to the pin that was
    /// on screen — not the one the tap advanced to. The multi-pin fixture keeps every pin
    /// scrolled off the top on open, so the cell turning up is the jump.
    func testTappingTheBanner_jumpsTheListToThePinItWasShowing() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3")
        XCTAssertFalse(screen.cell(Pinned.textId).exists,
                       "the oldest pin starts above the visible window")

        screen.tapPinnedBanner()

        XCTAssertTrue(screen.cell(Pinned.textId).waitForExistence(timeout: 10),
                      "the tap must take the list to the pin the banner was showing")
        XCTAssertTrue(waitForBannerValue("2/3"),
                      "and leave the banner on the next pin")
    }

    /// One pin has nowhere to advance to. The tap still jumps, but the banner must not blank
    /// or page onto nothing.
    func testTappingASinglePin_staysOnIt() {
        openPinnedConversation(single: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "1/1")

        screen.tapPinnedBanner()

        // Give the banner a beat to prove it neither moved nor emptied.
        XCTAssertFalse(waitForBannerValue("0/1", timeout: 1),
                       "the banner must never page onto nothing")
        XCTAssertEqual(screen.pinnedMessagesValue, "1/1")
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.textPreview)
    }

    // MARK: - Pinning through the UI

    func testPinningAMessage_marksTheBubbleAndRaisesTheBanner() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertFalse(screen.pinnedIcon(in: cell).exists,
                       "the message starts unpinned")

        screen.pinMessage(cell: cell, forAll: true)

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "pinning must raise the banner")
        XCTAssertEqual(screen.pinnedMessagesPreview.label, ChannelScreen.Conversation.lastText)
        XCTAssertTrue(screen.pinnedIcon(in: cell).waitForExistence(timeout: 5),
                      "the bubble must show a pin beside its timestamp")
    }

    /// Pinning in place has to *re-measure* the bubble's info row, not just reveal the pin.
    /// The icon shares a fixed-width row with the timestamp, the tick and the "edited" mark,
    /// so a width measured before the pin existed leaves them drawn on top of each other —
    /// and reopening the channel builds a fresh layout model, which is exactly why the bug
    /// has to be caught while the cell is still the one that was on screen.
    func testPinningInPlace_reMeasuresTheInfoRow() {
        openPlainConversation(edited: true)

        let cell = screen.cell(ChannelScreen.Conversation.outgoingId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        let date = screen.date(in: cell)
        XCTAssertTrue(date.waitForExistence(timeout: 5))

        screen.pinMessage(cell: cell, forAll: true)
        let pin = screen.pinnedIcon(in: cell)
        XCTAssertTrue(pin.waitForExistence(timeout: 5),
                      "the bubble must show a pin beside its timestamp")

        XCTAssertLessThanOrEqual(
            pin.frame.maxX, date.frame.minX,
            "the pin overlaps the timestamp — the info row kept the width it measured "
                + "before the message was pinned (pin \(pin.frame), date \(date.frame))"
        )
    }

    /// Same invariant as above, one pin later: the banner is already up, so nothing about
    /// the screen changes except the bubble's own info row.
    func testPinningASecondMessage_reMeasuresItsInfoRow() {
        openPinnedConversation(single: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        let cell = screen.cell(ChannelScreen.Conversation.messageId(4))
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "the outgoing filler message must be on screen")
        let date = screen.date(in: cell)
        XCTAssertTrue(date.waitForExistence(timeout: 5))

        screen.pinMessage(cell: cell, forAll: true)
        let pin = screen.pinnedIcon(in: cell)
        XCTAssertTrue(pin.waitForExistence(timeout: 5))

        XCTAssertLessThanOrEqual(
            pin.frame.maxX, date.frame.minX,
            "the pin overlaps the timestamp (pin \(pin.frame), date \(date.frame))"
        )
    }

    func testPinForMe_alsoPinsLocally() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        screen.pinMessage(cell: cell, forAll: false)

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.pinnedIcon(in: cell).waitForExistence(timeout: 5))
    }

    /// A message that has not reached the server yet has no id the other members could
    /// resolve, and the resend allocates a new one — so the menu must not offer Pin on it.
    func testPendingMessage_offersNoPin() {
        openConversationWithPendingMessage()

        let cell = screen.cell(ChannelScreen.Conversation.pendingId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5),
                      "the pending message should be seeded at the bottom of the list")
        XCTAssertTrue(screen.openContextMenu(on: cell, expecting: "reply"),
                      "the context menu should still open on a pending message")
        XCTAssertFalse(screen.contextMenuItem("pin").exists,
                       "a pending message must not offer Pin")
        XCTAssertFalse(screen.contextMenuItem("unpin").exists,
                       "and it is not pinned, so no Unpin either")
    }

    /// A sent message in the same conversation still offers Pin — the guard above is about
    /// the delivery state, not about this fixture.
    func testSentMessage_stillOffersPin() {
        openConversationWithPendingMessage()

        let cell = screen.cell(ChannelScreen.Conversation.outgoingId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openContextMenu(on: cell, expecting: "pin"),
                      "a delivered message must still offer Pin")
    }

    /// An already-pinned message offers Unpin instead of Pin, with no sub-step.
    func testPinnedMessage_offersUnpin() {
        openPinnedConversation(single: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        let cell = screen.cell(Pinned.textId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openContextMenu(on: cell, expecting: "unpin"),
                      "a pinned message must offer Unpin")
        XCTAssertFalse(screen.contextMenuItem("pin").exists,
                       "and must not also offer Pin")
    }

    /// The layout path most likely to regress: removing the last pin has to hide the banner
    /// *and* give the reclaimed space back to the message list.
    func testUnpinningTheLastPin_hidesTheBannerAndRelaysOut() {
        openPinnedConversation(single: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        let cell = screen.cell(Pinned.textId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        let listTopBefore = screen.collectionView.frame.minY

        screen.unpinMessage(cell: cell)

        XCTAssertTrue(waitForBannerToDisappear(),
                      "unpinning the only pin must take the banner away")
        XCTAssertFalse(screen.pinnedIcon(in: cell).exists,
                       "and clear the pin beside the timestamp")
        XCTAssertEqual(screen.collectionView.frame.minY, listTopBefore, accuracy: 1,
                       "the list is overlaid by the banner, never displaced by it")
    }

    // MARK: - The pinned-messages list

    func testPinButton_opensThePinnedMessageList() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        XCTAssertTrue(screen.openPinnedMessageList(),
                      "tapping the banner's pin button must present the pinned-messages list")
        XCTAssertTrue(app.navigationBars[Pinned.bannerTitle].waitForExistence(timeout: 5),
                      "the presented screen is titled like the banner")

        // Every seeded pin must be listed, in the same timeline order the banner pages
        // through — not just "some rows appeared".
        XCTAssertEqual(screen.pinnedListRowIdentifiers, Pinned.allRowIdentifiers)
        // The rows are the conversation's own bubbles, so a pin reads as the message
        // itself: its body, and for the poll its question — never the banner's "Video" /
        // "Poll: …" wording, which is the banner's own formatting. The caption-less video
        // has no text of its own, and a bubble always realizes its body label, so it
        // contributes an empty one.
        XCTAssertEqual(screen.pinnedListBodies,
                       [Pinned.textPreview, "", Pinned.pollQuestion])
    }

    /// The screen is presented, not pushed: it carries an "X" instead of a back button,
    /// and that "X" is what dismisses it — leaving the conversation exactly as it was,
    /// banner and all.
    func testPinnedListCloseButton_dismissesTheListAndLeavesTheBannerAlone() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3")

        XCTAssertTrue(screen.openPinnedMessageList())
        XCTAssertTrue(screen.pinnedListCloseButton.waitForExistence(timeout: 5),
                      "a presented screen closes through its own \"X\"")

        screen.closePinnedMessageList()
        XCTAssertTrue(waitForPinnedListToClose(), "the \"X\" must dismiss the list")
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "the conversation is back, banner included")
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3",
                       "closing picks no pin, so the banner must not move")
    }

    /// The arrow button closes the list, jumps the conversation to that pin, and leaves the
    /// banner on the pin *after* it — the same step a banner tap takes after its own jump,
    /// so the next banner tap walks forward instead of re-jumping to where the user is.
    func testPinnedListNavigateButton_closesTheListAndAdvancesPastThatPin() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3")

        XCTAssertTrue(screen.openPinnedMessageList())
        let videoRow = screen.pinnedListCell(Pinned.videoId)
        XCTAssertTrue(videoRow.waitForExistence(timeout: 5), "the video pin must have a row")
        let navigate = screen.pinnedListNavigateButton(in: videoRow)
        XCTAssertTrue(navigate.waitForExistence(timeout: 5),
                      "every row must carry the arrow that jumps to its message")
        navigate.tap()

        XCTAssertTrue(waitForPinnedListToClose(), "the arrow must close the list")
        XCTAssertTrue(screen.cell(Pinned.videoId).waitForExistence(timeout: 10),
                      "the arrow must take the list to the pin it belongs to")
        // The second of three: the banner lands on the third, not on the one just picked.
        XCTAssertTrue(waitForBannerValue("3/3"),
                      "the banner must move past the picked pin, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(waitForPreview(Pinned.pollPreview))
    }

    /// The last pin has nowhere forward to go, so the banner wraps to the first — the same
    /// way tapping past the last pin does.
    func testPinnedListNavigateButtonOnTheLastPin_wrapsTheBannerToTheFirst() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "1/3")
        // Move off the first pin, so the wrap back onto it is a real change rather than the
        // banner having never moved at all.
        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("2/3"))

        XCTAssertTrue(screen.openPinnedMessageList())
        let pollRow = screen.pinnedListCell(Pinned.pollId)
        XCTAssertTrue(pollRow.waitForExistence(timeout: 5), "the poll pin must have a row")
        screen.pinnedListNavigateButton(in: pollRow).tap()

        XCTAssertTrue(waitForPinnedListToClose(), "the arrow must close the list")
        XCTAssertTrue(waitForBannerValue("1/3"),
                      "past the last pin the banner must come back round, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(waitForPreview(Pinned.textPreview))
    }

    /// The rows are the conversation's own bubbles, so they raise the conversation's own
    /// context menu — and an action that needs nothing but the store runs without leaving
    /// the list, exactly as the swipe action does.
    func testPinnedListLongPress_opensTheConversationMenuAndUnpinsInPlace() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openPinnedMessageList())

        let textRow = screen.pinnedListCell(Pinned.textId)
        XCTAssertTrue(textRow.waitForExistence(timeout: 5))
        screen.unpinMessage(cell: textRow)

        XCTAssertTrue(waitForRowToDisappear(textRow), "the unpinned row must leave the list")
        XCTAssertTrue(screen.pinnedListTable.exists,
                      "unpinning needs nothing from the conversation, so the list must stay up")
        XCTAssertEqual(screen.pinnedListRowIdentifiers,
                       [Pinned.rowIdentifier(Pinned.videoId), Pinned.rowIdentifier(Pinned.pollId)])
    }

    /// The arrow lives on whichever side the bubble leaves free, so it can never cover the
    /// message: the trailing side of an incoming bubble, the leading side of an outgoing
    /// one. Only a pin the user sends can prove the mirrored case, so this one pins
    /// through the conversation first.
    func testPinnedListArrow_sitsOnTheSideTheBubbleLeavesFree() {
        openPlainConversation()

        let outgoing = screen.cell(ChannelScreen.Conversation.outgoingId)
        XCTAssertTrue(outgoing.waitForExistence(timeout: 10),
                      "the seeded outgoing message must be on screen to pin")
        screen.pinMessage(cell: outgoing)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openPinnedMessageList())

        let row = screen.pinnedListCell(ChannelScreen.Conversation.outgoingId)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let arrow = screen.pinnedListNavigateButton(in: row)
        let body = screen.pinnedListBody(in: row)
        XCTAssertTrue(arrow.waitForExistence(timeout: 5))
        XCTAssertTrue(body.exists)
        XCTAssertLessThan(arrow.frame.maxX, body.frame.minX,
                          "an outgoing bubble is right-aligned, so its arrow belongs to its left")

        // And it still jumps: the arrow is the only way off this screen.
        arrow.tap()
        XCTAssertTrue(waitForPinnedListToClose(), "the arrow must close the list")
    }

    /// A tap on the bubble must *not* navigate any more — that is the arrow's job, and the
    /// bubble's touches belong to the message the way they do in the conversation.
    func testPinnedListRowTap_staysOnTheList() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openPinnedMessageList())

        let textRow = screen.pinnedListCell(Pinned.textId)
        XCTAssertTrue(textRow.waitForExistence(timeout: 5))
        screen.pinnedListBody(in: textRow).tap()

        XCTAssertFalse(waitForPinnedListToClose(timeout: 2),
                       "tapping a bubble must leave the list up")
    }

    func testPinnedListSwipe_unpinsOneMessage() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openPinnedMessageList())

        let textRow = screen.pinnedListCell(Pinned.textId)
        XCTAssertTrue(textRow.waitForExistence(timeout: 5))
        textRow.swipeLeft()
        let unpin = app.buttons["Unpin"]
        XCTAssertTrue(unpin.waitForExistence(timeout: 5),
                      "swiping a row must reveal its Unpin action")
        unpin.tap()

        // The row goes away because the list observes the store, not a snapshot handed
        // to it when it opened.
        XCTAssertTrue(waitForRowToDisappear(textRow), "the unpinned row must leave the list")
        XCTAssertEqual(screen.pinnedListRowIdentifiers,
                       [Pinned.rowIdentifier(Pinned.videoId), Pinned.rowIdentifier(Pinned.pollId)])
    }

    /// Emptying the list one pin at a time — there is no Unpin All — must leave the
    /// placeholder up rather than dismiss the screen, and take the banner with it.
    func testUnpinningEveryRow_leavesThePlaceholderAndClearsTheBanner() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.openPinnedMessageList())

        for id in [Pinned.textId, Pinned.videoId, Pinned.pollId] {
            let row = screen.pinnedListCell(id)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "pin \(id) must have a row to unpin")
            screen.unpinMessage(cell: row)
            XCTAssertTrue(waitForRowToDisappear(row), "the unpinned row must leave the list")
        }

        XCTAssertTrue(screen.pinnedListEmptyView.waitForExistence(timeout: 5),
                      "the emptied list shows its placeholder rather than dismissing itself")

        screen.closePinnedMessageList()
        XCTAssertTrue(waitForPinnedListToClose(), "the \"X\" must dismiss the list")
        XCTAssertTrue(waitForBannerToDisappear(),
                      "back in the conversation the banner must be gone too")
    }

    // MARK: - Persistence

    /// The reason pins are stored rather than held in memory: they have to survive a
    /// relaunch with no network.
    func testPins_surviveRelaunch() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        openPinnedConversation()

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 10),
                      "pins must come back from the database")
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.textPreview)
    }

    // MARK: - Pin system message

    /// The text a pin-for-all posts into the conversation. `You` is the owner name the
    /// formatter uses for the current user (`L10n.User.current`).
    private static func pinnedSystemText(_ body: String) -> String {
        "You pinned: \"\(body)\""
    }

    /// Pinning for everyone is a channel event, so it leaves a record in the conversation
    /// the way "joined via invite link" does.
    ///
    /// The text has to be right *immediately*. The system message is built locally with
    /// only a `parentMessageId` — `SCTMessage.parentMessage` is filled in by the server —
    /// so without the parent stitch in `sendPinSystemMessage` this row would first render
    /// as `You pinned: ""` and only correct itself once the echo landed.
    func testPinningForAll_postsASystemMessageNamingThePinnedMessage() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.systemMessages.count, 0, "the conversation starts with no system rows")

        screen.pinMessage(cell: cell, forAll: true)

        let expected = Self.pinnedSystemText(ChannelScreen.Conversation.lastText)
        XCTAssertTrue(screen.systemMessage(expected).waitForExistence(timeout: 5),
                      "pinning for all must post a system message reading \(expected)")
    }

    /// A personal pin is invisible to the other members, so it announces nothing.
    func testPinningForMe_postsNoSystemMessage() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        screen.pinMessage(cell: cell, forAll: false)

        XCTAssertTrue(screen.pinnedIcon(in: cell).waitForExistence(timeout: 5),
                      "the pin itself must still land")
        XCTAssertEqual(screen.systemMessages.count, 0,
                       "a pin for me must not announce itself in the conversation")
    }

    /// Unpinning stays silent, and — the regression that matters — the message that was
    /// pinned stays in the list. Giving the system message a parent puts the pinned message
    /// on the receiving end of a `parent` relationship, and the message list fetches on
    /// `replied == false`; flipping that flag would make the message vanish.
    func testUnpinning_staysSilentAndKeepsThePinnedMessageInTheList() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        screen.pinMessage(cell: cell, forAll: true)

        let expected = Self.pinnedSystemText(ChannelScreen.Conversation.lastText)
        XCTAssertTrue(screen.systemMessage(expected).waitForExistence(timeout: 5))
        XCTAssertTrue(screen.cell(ChannelScreen.Conversation.lastId).exists,
                      "the pinned message must stay in the conversation")

        screen.unpinMessage(cell: screen.cell(ChannelScreen.Conversation.lastId))

        XCTAssertEqual(screen.systemMessages.count, 1,
                       "unpinning must not post a system message of its own")
        XCTAssertTrue(screen.cell(ChannelScreen.Conversation.lastId).waitForExistence(timeout: 5),
                      "the message must survive being unpinned")
    }

    /// Tapping the row takes the list to the message it names, the same jump the pinned
    /// banner performs.
    func testTappingThePinSystemMessage_jumpsToThePinnedMessage() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        screen.pinMessage(cell: cell, forAll: true)

        let expected = Self.pinnedSystemText(ChannelScreen.Conversation.lastText)
        let row = screen.systemMessage(expected)
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Scroll the pinned message off screen, so landing back on it proves the jump ran
        // rather than the message simply having stayed put.
        screen.collectionView.swipeDown()
        screen.collectionView.swipeDown()

        XCTAssertTrue(row.waitForExistence(timeout: 5) || screen.scrollDownButton.exists,
                      "the list must have moved away from the bottom")

        if !row.isHittable {
            screen.collectionView.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(screen.cell(ChannelScreen.Conversation.lastId).waitForExistence(timeout: 10),
                      "tapping the row must bring the pinned message back on screen")
    }

    // MARK: - Waiters

    private func waitForPreview(_ expected: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if screen.pinnedMessagesPreview.exists,
               screen.pinnedMessagesPreview.label == expected {
                return true
            }
            usleep(100_000)
        }
        return false
    }

    private func waitForBannerValue(_ expected: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if screen.pinnedMessagesValue == expected { return true }
            usleep(100_000)
        }
        return false
    }

    private func waitForPinnedListToClose(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !screen.pinnedListTable.exists { return true }
            usleep(100_000)
        }
        return false
    }

    private func waitForRowToDisappear(_ row: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !row.exists { return true }
            usleep(100_000)
        }
        return false
    }

    private func waitForBannerToDisappear(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !screen.pinnedMessagesView.exists { return true }
            usleep(100_000)
        }
        return false
    }
}
