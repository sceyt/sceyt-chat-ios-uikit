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

        /// The pinned rows in the order the list must show them in: **newest pin first**,
        /// which is the reverse of the banner's segment bar.
        ///
        /// The fixture seeds no server pin ids, so every row ties on the primary
        /// `serverPinId` descriptor and the timeline tiebreakers decide — which is why this is
        /// still timeline order, just read backwards. `--uitest-pinned-messages-pin-order` is
        /// the fixture that exercises real pin ids.
        static var allRowIdentifiers: [String] {
            [pollId, videoId, textId].map(rowIdentifier)
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

    /// Opens the three-pin fixture whose server pin ids run *against* timeline order.
    private func openPinOrderConversation() {
        openConversation(launchApp(pinnedMessagesPinOrder: true))
    }

    /// Opens a conversation with nothing pinned, so a test can pin through the real UI.
    /// `edited` marks the outgoing message as edited, which is the widest the info row
    /// beside the timestamp ever gets.
    private func openPlainConversation(edited: Bool = false) {
        openConversation(launchApp(conversation: true, conversationEdited: edited))
    }

    /// Opens a conversation with nothing pinned where pin requests are **never acked**, so a
    /// pin behaves exactly as it does with no connection.
    private func openConversationWithPinsStayingPending() {
        openConversation(launchApp(conversation: true, pinsStayPending: true))
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

    /// The banner's resting state: up, titled, and showing the *newest* pin — the bottom
    /// segment of the bar, which is where the walk up through the older pins starts.
    func testSeededPins_showTheBannerOnTheNewestPin() {
        openPinnedConversation()

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "three messages are pinned, so the banner must be up")
        XCTAssertEqual(screen.pinnedMessagesTitle.label, Pinned.bannerTitle)
        XCTAssertTrue(screen.pinnedMessagesButton.exists,
                      "the banner's pin button opens the pinned list")

        // Without this, "showing pin 1 of 3" and "only one pin ever landed" look identical
        // from the preview alone, and every paging assertion could pass vacuously.
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3",
                       "all three seeded pins must have landed, and the banner rests on the last")
        // The fixture assigns no server pin ids, so all three tie on the primary descriptor
        // and the timeline tiebreakers order them — the poll is the newest.
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.pollPreview,
                       "pins with no server id fall back to conversation order")
    }

    /// The primary sort key is the server's pin id, not the message's timestamp.
    ///
    /// This fixture pins poll -> text -> video (ids 100, 200, 300) while their timeline order
    /// is text -> video -> poll. The banner rests on the highest pin id, so it can only start
    /// on the video if it is genuinely reading `serverPinId` — by timeline it would start on
    /// the poll.
    func testSeededPinsWithServerPinIds_areOrderedByPinIdNotTimeline() {
        openPinOrderConversation()

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "three messages are pinned, so the banner must be up")
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3",
                       "all three seeded pins must have landed")
        XCTAssertTrue(
            waitForPreview(Pinned.videoPreview),
            "the highest pin id rests at the bottom segment, even though its message is not the newest — got \"\(screen.pinnedMessagesPreview.label)\""
        )

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.textPreview),
                      "pin id 200 comes next, walking up the bar")

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.pollPreview),
                      "pin id 100 ends the walk, at the top segment")
    }

    // MARK: - Preview formatting

    /// The three shapes `PinnedMessageBodyFormatter` has to get right: a plain body, an
    /// attachment with no caption, and a poll.
    func testBannerPreview_formatsEachMessageType() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.pollPreview,
                       "the banner opens on the newest pin, and a poll previews as \"Poll: <question>\"")

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(
            waitForPreview(Pinned.videoPreview),
            "a caption-less video must preview as \"Video\", got \"\(screen.pinnedMessagesPreview.label)\""
        )

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(
            waitForPreview(Pinned.textPreview),
            "a text message must preview as its body, got \"\(screen.pinnedMessagesPreview.label)\""
        )
    }

    // MARK: - Paging

    func testSwipingTheBanner_walksThePinsAndWraps() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.pollPreview)

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.videoPreview))
        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.textPreview))

        // The top segment: the next swipe must wrap rather than dead-end.
        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.pollPreview),
                      "swiping past the oldest pin must wrap round to the newest")
    }

    func testSwipingBack_walksThePinsInReverse() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        // Backwards from the newest pin — where the banner rests — wraps to the oldest.
        screen.swipeToPreviousPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.textPreview),
                      "swiping back from the newest pin must wrap to the oldest")
    }

    // MARK: - Tapping the banner

    /// The point of the tap gesture: it hands the banner the *next* pin — the older one, a
    /// segment up — so repeated taps walk the pins without the user ever finding the swipe
    /// or the full list.
    func testTappingTheBanner_advancesToTheNextPin() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3")

        screen.tapPinnedBanner()

        XCTAssertTrue(waitForBannerValue("2/3"),
                      "a tap must move the banner on, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(waitForPreview(Pinned.videoPreview))
    }

    func testTappingThroughAllPins_wrapsToTheNewest() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("2/3"))
        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("1/3"))

        // The top segment: the next tap must come back round rather than dead-end.
        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("3/3"),
                      "tapping past the oldest pin must return to the newest")
        XCTAssertTrue(waitForPreview(Pinned.pollPreview))
    }

    /// A tap has to move the *list* as well as the banner, and it goes to the pin that was
    /// on screen — not the one the tap advanced to. The multi-pin fixture keeps every pin
    /// scrolled off the top on open, so the cell turning up is the jump.
    func testTappingTheBanner_jumpsTheListToThePinItWasShowing() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3")
        XCTAssertFalse(screen.cell(Pinned.pollId).exists,
                       "every pin, the newest included, starts above the visible window")

        screen.tapPinnedBanner()

        XCTAssertTrue(screen.cell(Pinned.pollId).waitForExistence(timeout: 10),
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

        // Every seeded pin must be listed, newest pin first — not just "some rows appeared".
        XCTAssertEqual(screen.pinnedListRowIdentifiers, Pinned.allRowIdentifiers)
        // The rows are the conversation's own bubbles, so a pin reads as the message
        // itself: its body, and for the poll its question — never the banner's "Video" /
        // "Poll: …" wording, which is the banner's own formatting. The caption-less video
        // has no text of its own, and a bubble always realizes its body label, so it
        // contributes an empty one.
        XCTAssertEqual(screen.pinnedListBodies,
                       [Pinned.pollQuestion, "", Pinned.textPreview])
    }

    /// The screen is presented, not pushed: it carries an "X" instead of a back button,
    /// and that "X" is what dismisses it — leaving the conversation exactly as it was,
    /// banner and all.
    func testPinnedListCloseButton_dismissesTheListAndLeavesTheBannerAlone() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3")

        XCTAssertTrue(screen.openPinnedMessageList())
        XCTAssertTrue(screen.pinnedListCloseButton.waitForExistence(timeout: 5),
                      "a presented screen closes through its own \"X\"")

        screen.closePinnedMessageList()
        XCTAssertTrue(waitForPinnedListToClose(), "the \"X\" must dismiss the list")
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "the conversation is back, banner included")
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3",
                       "closing picks no pin, so the banner must not move")
    }

    /// The arrow button closes the list, jumps the conversation to that pin, and leaves the
    /// banner on the pin *after* it — the same step a banner tap takes after its own jump,
    /// so the next banner tap walks forward instead of re-jumping to where the user is.
    func testPinnedListNavigateButton_closesTheListAndAdvancesPastThatPin() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3")

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
        // The second of three: the banner lands on the first — the older pin one segment up
        // — not on the one just picked.
        XCTAssertTrue(waitForBannerValue("1/3"),
                      "the banner must move past the picked pin, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(waitForPreview(Pinned.textPreview))
    }

    /// The oldest pin has nowhere further up to go, so the banner wraps round to the newest —
    /// the same way tapping past the oldest pin does.
    func testPinnedListNavigateButtonOnTheOldestPin_wrapsTheBannerToTheNewest() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.pinnedMessagesValue, "3/3")
        // Move off the newest pin, so the wrap back onto it is a real change rather than the
        // banner having never moved at all.
        screen.tapPinnedBanner()
        XCTAssertTrue(waitForBannerValue("2/3"))

        XCTAssertTrue(screen.openPinnedMessageList())
        let textRow = screen.pinnedListCell(Pinned.textId)
        XCTAssertTrue(textRow.waitForExistence(timeout: 5), "the text pin must have a row")
        screen.pinnedListNavigateButton(in: textRow).tap()

        XCTAssertTrue(waitForPinnedListToClose(), "the arrow must close the list")
        XCTAssertTrue(waitForBannerValue("3/3"),
                      "past the oldest pin the banner must come back round, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(waitForPreview(Pinned.pollPreview))
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
                       [Pinned.rowIdentifier(Pinned.pollId), Pinned.rowIdentifier(Pinned.videoId)])
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
                       [Pinned.rowIdentifier(Pinned.pollId), Pinned.rowIdentifier(Pinned.videoId)])
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
        XCTAssertEqual(screen.pinnedMessagesPreview.label, Pinned.pollPreview)
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

    // MARK: - Pending pins (no connection)

    /// The offline contract: the pin lands locally and stays visible, so the user sees their
    /// action took effect — but nothing is announced, because the server has not accepted it.
    func testPinningWithNoConnection_keepsThePinAndAnnouncesNothing() {
        openConversationWithPinsStayingPending()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.systemMessages.count, 0, "the conversation starts with no system rows")

        screen.pinMessage(cell: cell, forAll: true)

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "an unsent pin must still raise the banner")
        XCTAssertTrue(screen.pinnedIcon(in: cell).waitForExistence(timeout: 5),
                      "and mark the bubble")
        XCTAssertEqual(screen.pinnedMessagesPreview.label, ChannelScreen.Conversation.lastText)

        let announcement = Self.pinnedSystemText(ChannelScreen.Conversation.lastText)
        XCTAssertFalse(
            screen.systemMessage(announcement).waitForExistence(timeout: 3),
            "nothing may be announced until the server has accepted the pin"
        )
        XCTAssertEqual(screen.systemMessages.count, 0)
    }

    /// Unpinning a pin the server never saw needs no round trip: it simply disappears.
    func testUnpinningAnUnsentPin_removesItImmediately() {
        openConversationWithPinsStayingPending()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        screen.pinMessage(cell: cell, forAll: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        screen.unpinMessage(cell: cell)

        XCTAssertTrue(waitForBannerToDisappear(),
                      "cancelling an unsent pin must take the banner away")
        XCTAssertTrue(waitForPinToDisappear(in: cell))
    }

    /// Unpinning a pin the server **has** accepted needs a round trip, but the UI must not wait
    /// for it: the removal is queued and the pin disappears at once.
    ///
    /// The pin-order fixture is the one seeded with real server pin ids, so its rows start
    /// `.synced` — which is what puts this on the queued-removal path rather than the
    /// cancel-an-unsent-pin one.
    func testUnpinningAnAckedPinWithNoConnection_hidesItAtOnce() {
        openConversation(launchApp(pinnedMessagesPinOrder: true, pinsStayPending: true))
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForBannerValue("3/3"))

        XCTAssertTrue(screen.openPinnedMessageList())
        let row = screen.pinnedListCell(Pinned.pollId)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        screen.unpinMessage(cell: row)
        XCTAssertTrue(waitForRowToDisappear(row),
                      "a queued removal must leave the list immediately")
        screen.closePinnedMessageList()
        XCTAssertTrue(waitForPinnedListToClose())

        XCTAssertTrue(waitForBannerValueMatchingOneOf(["1/2", "2/2"]),
                      "and the banner must drop to two pins, got \(screen.pinnedMessagesValue)")
    }

    /// With the server acking, the same unpin completes rather than staying queued.
    func testUnpinningAnAckedPin_completesWhenTheServerAgrees() {
        openPinOrderConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForBannerValue("3/3"))

        XCTAssertTrue(screen.openPinnedMessageList())
        let row = screen.pinnedListCell(Pinned.pollId)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        screen.unpinMessage(cell: row)
        XCTAssertTrue(waitForRowToDisappear(row))
        screen.closePinnedMessageList()
        XCTAssertTrue(waitForPinnedListToClose())

        XCTAssertTrue(waitForBannerValueMatchingOneOf(["1/2", "2/2"]))
    }

    // MARK: - Rapid interaction / stress
    //
    // Pinning is a two-phase write — an optimistic local row, then the server's answer stamped
    // onto it — so the interesting failures are the ones that need a *second* action to land
    // before the first has settled. These drive the real UI as fast as XCUITest allows and
    // assert the app is still alive and self-consistent afterwards.

    /// Toggling the same message pin/unpin/pin/unpin. Every step is a local write plus a
    /// network round trip, so a stale completion landing after the next toggle would leave the
    /// banner and the bubble disagreeing.
    func testRapidPinUnpinToggling_settlesOnTheLastAction() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        for round in 1 ... 3 {
            screen.pinMessage(cell: cell, forAll: true)
            XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                          "round \(round): pinning must raise the banner")
            XCTAssertTrue(screen.pinnedIcon(in: cell).waitForExistence(timeout: 5),
                          "round \(round): the bubble must be marked")

            screen.unpinMessage(cell: cell)
            XCTAssertTrue(waitForBannerToDisappear(),
                          "round \(round): unpinning the only pin must take the banner away")
            XCTAssertTrue(waitForPinToDisappear(in: cell),
                          "round \(round): and unmark the bubble")
        }

        // Finish pinned, and assert both sides agree on that.
        screen.pinMessage(cell: cell, forAll: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForBannerValue("1/1"),
                      "a toggle storm must not leave phantom pins behind, got \(screen.pinnedMessagesValue)")
        XCTAssertTrue(screen.pinnedIcon(in: cell).exists)
    }

    /// Alternating scopes on the same message. `.forAll` also posts a system message and
    /// `.forMe` does not, so this is the path where a scope read from the wrong write would show.
    func testAlternatingPinScopesOnTheSameMessage_keepsOnePin() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        screen.pinMessage(cell: cell, forAll: true)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        screen.unpinMessage(cell: cell)
        XCTAssertTrue(waitForBannerToDisappear())

        screen.pinMessage(cell: cell, forAll: false)
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5),
                      "a personal pin raises the banner too")
        XCTAssertTrue(waitForBannerValue("1/1"),
                      "re-pinning must reuse the row, not add a second one — got \(screen.pinnedMessagesValue)")
    }

    /// Three pins taken back to back with no wait between them. The banner's count is the
    /// assertion that every optimistic row survived the next one being written.
    func testPinningSeveralMessagesInQuickSuccession_countsThemAll() {
        openPlainConversation()

        let ids = [
            ChannelScreen.Conversation.lastId,
            ChannelScreen.Conversation.outgoingId
        ]
        for id in ids {
            let cell = screen.cell(id)
            XCTAssertTrue(cell.waitForExistence(timeout: 5), "message \(id) should be on screen")
            screen.pinMessage(cell: cell, forAll: true)
        }

        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        // The denominator is the assertion: both optimistic rows survived the other being
        // written. The *index* is deliberately not asserted — the banner holds its place on the
        // message it was already showing, so pinning an older message moves that one to 2/2
        // rather than resetting to 1/2.
        XCTAssertTrue(
            waitForBannerValueMatchingOneOf(["1/\(ids.count)", "2/\(ids.count)"]),
            "every pin must land, got \(screen.pinnedMessagesValue)"
        )
    }

    /// Unpinning every pin one after another from the seeded fixture. The banner has to shrink
    /// in step and then go away — a stale index here is what makes the banner page onto nothing.
    func testUnpinningEveryPinInQuickSuccession_takesTheBannerAway() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForBannerValue("3/3"))

        XCTAssertTrue(screen.openPinnedMessageList(), "the pinned list should open")

        for (index, id) in [Pinned.textId, Pinned.videoId, Pinned.pollId].enumerated() {
            let row = screen.pinnedListCell(id)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "row \(id) should be listed")
            // Through the row's context menu rather than the swipe action: swipe-to-reveal is
            // flaky for a row whose content is an embedded message cell.
            screen.unpinMessage(cell: row)
            XCTAssertTrue(waitForRowToDisappear(row),
                          "row \(id) must leave the list (step \(index + 1) of 3)")
        }

        screen.closePinnedMessageList()
        XCTAssertTrue(waitForPinnedListToClose())
        XCTAssertTrue(waitForBannerToDisappear(),
                      "with nothing pinned the banner must come down")
    }

    /// Swiping the banner far faster than its paging animation. Whatever it lands on, the value
    /// and the preview have to be consistent with each other and inside the real range.
    func testRapidBannerSwiping_neverPagesOntoNothing() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        for _ in 0 ..< 12 {
            screen.swipeToNextPinnedMessage()
        }
        for _ in 0 ..< 12 {
            screen.swipeToPreviousPinnedMessage()
        }

        XCTAssertTrue(screen.pinnedMessagesView.exists, "the banner must survive the storm")
        XCTAssertTrue(
            waitForBannerValueMatchingOneOf(["1/3", "2/3", "3/3"]),
            "the banner settled on \(screen.pinnedMessagesValue), which is outside 1...3 of 3"
        )
        XCTAssertTrue(
            waitForPreviewMatchingOneOf([Pinned.textPreview, Pinned.videoPreview, Pinned.pollPreview]),
            "the preview settled on \"\(screen.pinnedMessagesPreview.label)\", which is not one of the three pins"
        )
    }

    /// Paging the banner while the pin set is changing underneath it. The banner holds its place
    /// by message tid rather than by index for exactly this case.
    func testSwipingWhileUnpinning_keepsTheBannerAndTheSetInStep() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForPreview(Pinned.videoPreview),
                      "one step up from the newest pin the banner opens on")

        // Unpin a *different* pin than the one on show.
        let cell = screen.cell(Pinned.textId)
        if cell.exists {
            screen.unpinMessage(cell: cell)
        } else {
            XCTAssertTrue(screen.openPinnedMessageList())
            let row = screen.pinnedListCell(Pinned.textId)
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            screen.unpinMessage(cell: row)
            XCTAssertTrue(waitForRowToDisappear(row))
            screen.closePinnedMessageList()
            XCTAssertTrue(waitForPinnedListToClose())
        }

        XCTAssertTrue(waitForBannerValueMatchingOneOf(["1/2", "2/2"]),
                      "the banner must drop to two pins, got \(screen.pinnedMessagesValue)")
        screen.swipeToNextPinnedMessage()
        XCTAssertTrue(waitForBannerValueMatchingOneOf(["1/2", "2/2"]),
                      "and keep paging inside the smaller set, got \(screen.pinnedMessagesValue)")
    }

    /// Opening and closing the pinned list repeatedly. Each open starts a pin sweep and a
    /// second `DatabaseObserver` on the same table, so a slot that is never released or an
    /// observer that is never stopped shows up here.
    func testOpeningAndClosingThePinnedListRepeatedly_staysHealthy() {
        openPinnedConversation()
        XCTAssertTrue(screen.pinnedMessagesView.waitForExistence(timeout: 5))

        for round in 1 ... 4 {
            XCTAssertTrue(screen.openPinnedMessageList(),
                          "round \(round): the pinned list should open")
            XCTAssertEqual(screen.pinnedListBodies.isEmpty, false,
                           "round \(round): the list must still show its rows")
            screen.closePinnedMessageList()
            XCTAssertTrue(waitForPinnedListToClose(),
                          "round \(round): the list should close")
        }

        XCTAssertTrue(screen.pinnedMessagesView.exists)
        XCTAssertTrue(waitForBannerValue("3/3"),
                      "reopening the list must not disturb the pin set, got \(screen.pinnedMessagesValue)")
    }

    /// A pin/unpin storm mixed with banner paging and list navigation — a smoke test whose only
    /// real assertion is that the app is still running and the composer still responds.
    func testPinUnpinStormMixedWithNavigation_doesNotCrash() {
        openPlainConversation()

        let cell = screen.cell(ChannelScreen.Conversation.lastId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        for round in 0 ..< 4 {
            screen.pinMessage(cell: cell, forAll: true)
            if screen.pinnedMessagesView.waitForExistence(timeout: 5) {
                screen.swipeToNextPinnedMessage()
            }
            if round.isMultiple(of: 2), screen.openPinnedMessageList(timeout: 3) {
                screen.closePinnedMessageList()
                _ = waitForPinnedListToClose()
            }
            screen.unpinMessage(cell: cell)
            _ = waitForBannerToDisappear()
        }

        XCTAssertEqual(app.state, .runningForeground, "the app must survive a pin/unpin storm")
        XCTAssertTrue(screen.waitUntilReady(), "and the conversation must still be usable")
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

    private func waitForPinToDisappear(in cell: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !screen.pinnedIcon(in: cell).exists { return true }
            usleep(100_000)
        }
        return false
    }

    /// For the rapid-paging tests, where *which* pin the banner settles on is genuinely up to
    /// timing — only "one of the real ones" is a meaningful assertion.
    private func waitForBannerValueMatchingOneOf(
        _ expected: [String],
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if expected.contains(screen.pinnedMessagesValue) { return true }
            usleep(100_000)
        }
        return false
    }

    private func waitForPreviewMatchingOneOf(
        _ expected: [String],
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if screen.pinnedMessagesPreview.exists,
               expected.contains(screen.pinnedMessagesPreview.label) {
                return true
            }
            usleep(100_000)
        }
        return false
    }
}
