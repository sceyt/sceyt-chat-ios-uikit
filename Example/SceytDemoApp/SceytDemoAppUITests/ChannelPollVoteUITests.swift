//
//  ChannelPollVoteUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//
//  Black-box UI tests for voting on a poll message in the open conversation.
//
//  The app is launched in `--uitest --uitest-poll` mode, which seeds channel 100
//  ("UITest Chat") with a short history whose newest message is a SINGLE-CHOICE
//  poll ("Which option do you pick?", three options, no votes yet) — see
//  `UITestSupport` in the app target. Single-choice means the invariant these
//  tests defend: no matter how the vote moves, at most ONE option may ever render
//  as voted.
//
//  Each option row publishes what it renders through its accessibility value
//  (`sceyt_chat_channel_message_cell_poll_option.<index>` → `voted` /
//  `not_voted`), assigned right where the row sets its checkbox image — so a test
//  reads exactly the state a user sees.
//

import XCTest

final class ChannelPollVoteUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    private var optionCount: Int { Convo.pollOptionTexts.count }

    /// Launches the poll fixture and opens the channel screen on the poll message.
    private func openPollConversation(multipleChoice: Bool = false,
                                      doubleVoteGapMs: Int? = nil) {
        app = launchApp(poll: true,
                        pollAllowsMultipleVotes: multipleChoice,
                        pollDoubleVoteGapMs: doubleVoteGapMs)
        list = ChannelListScreen(app: app)
        screen = ChannelScreen(app: app)

        XCTAssertTrue(list.waitUntilLoaded(), "The channel list should load")
        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10),
                      "The seeded conversation channel should appear in the list")
        listCell.tap()

        XCTAssertTrue(screen.waitUntilReady(), "The channel composer should appear")
        XCTAssertTrue(screen.pollView.waitForExistence(timeout: 10),
                      "The poll message should render its in-bubble poll view")
        for index in 0..<optionCount {
            XCTAssertTrue(screen.pollOption(index).waitForExistence(timeout: 5),
                          "Poll option row \(index) should render")
        }

        // Nothing is voted yet, and the rows really do publish their state — if the
        // value were missing, every later assertion would pass vacuously.
        for index in 0..<optionCount {
            XCTAssertEqual(screen.pollOption(index).value as? String,
                           ChannelScreen.AID.pollOptionNotVoted,
                           "Poll option row \(index) should start out not voted")
        }
    }

    // MARK: - Changing a vote in a single-choice poll

    /// The reported bug: tap the first option, then *immediately* switch to the
    /// second one, and both rows keep showing a filled radio — even though a
    /// single-choice poll can only hold one vote.
    ///
    /// The two votes are driven from the app side (`--uitest-poll-double-vote`),
    /// because XCUITest cannot deliver two taps inside the sub-second window the
    /// gesture spans: it waits for app quiescence between events, and the poll cell
    /// animates on every vote. The button reports how many votes it dispatched, so a
    /// swallowed vote fails as a harness problem rather than hiding the bug.
    func test_quicklyChangingVote_inSingleChoicePoll_leavesOnlyOneOptionVoted() {
        openPollConversation(doubleVoteGapMs: 80)

        let driver = screen.pollDoubleVoteButton
        XCTAssertTrue(driver.waitForExistence(timeout: 10),
                      "The rapid-vote-change driver button should be installed")
        driver.tap()

        XCTAssertTrue(waitFor(timeout: 10) { (driver.value as? String) == "2" },
                      "Both votes should have been dispatched (option 1, then option 2 "
                          + "80ms later); the driver reported "
                          + "\((driver.value as? String) ?? "<nothing>")")

        // Let every animation the two votes kicked off finish, so this asserts on the
        // state the user is left looking at, not on a frame mid-transition.
        XCTAssertTrue(waitFor(timeout: 5) { self.screen.pollOptionIsVoted(1) },
                      "The second option — the last one voted for — should render as voted; "
                          + "was: \(screen.pollVoteStateDescription(optionCount: optionCount))")
        _ = waitFor(timeout: 2) { false }

        let voted = screen.votedPollOptionIndexes(upTo: optionCount)
        XCTAssertEqual(voted, [1],
                       "A single-choice poll must show exactly one voted option — the last "
                           + "one tapped (option 1). Voted rows: \(voted); "
                           + "\(screen.pollVoteStateDescription(optionCount: optionCount))")
    }

    /// The same invariant at the gesture level: two real taps, as fast as XCUITest
    /// can deliver them. Slower than the driver above, so it may well miss the race
    /// — it is here to catch the case where an ordinary vote change breaks too.
    func test_tappingASecondOption_inSingleChoicePoll_movesTheVote() {
        openPollConversation()

        screen.pollOption(0).tap()
        screen.pollOption(1).tap()

        XCTAssertTrue(waitFor(timeout: 5) { self.screen.pollOptionIsVoted(1) },
                      "The second option should render as voted after being tapped; "
                          + "was: \(screen.pollVoteStateDescription(optionCount: optionCount))")
        _ = waitFor(timeout: 2) { false }

        let voted = screen.votedPollOptionIndexes(upTo: optionCount)
        XCTAssertEqual(voted, [1],
                       "Voting for a second option in a single-choice poll must move the "
                           + "vote, not add one. Voted rows: \(voted); "
                           + "\(screen.pollVoteStateDescription(optionCount: optionCount))")
    }

    /// Baseline: a single vote lands on exactly the option that was tapped. If this
    /// fails, the fixture or the vote path is broken and the tests above say nothing
    /// about the rapid-change bug.
    func test_votingOnce_inSingleChoicePoll_marksOnlyThatOption() {
        openPollConversation()

        screen.pollOption(0).tap()

        XCTAssertTrue(waitFor(timeout: 5) { self.screen.pollOptionIsVoted(0) },
                      "The tapped option should render as voted; "
                          + "was: \(screen.pollVoteStateDescription(optionCount: optionCount))")

        let voted = screen.votedPollOptionIndexes(upTo: optionCount)
        XCTAssertEqual(voted, [0],
                       "Only the tapped option should be voted. Voted rows: \(voted); "
                           + "\(screen.pollVoteStateDescription(optionCount: optionCount))")
    }

    /// Pressing the radio itself, rather than the option text, must cast the vote
    /// through the row's tap handler — the radio does not answer for itself, or it
    /// could fill in without a vote behind it.
    func test_tappingTheRadio_castsTheVote() {
        openPollConversation()

        // The radio sits at the leading edge of the row, 22pt square against a row
        // ~230pt wide, so this offset lands on it rather than on the option text.
        screen.pollOption(0)
            .coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.3))
            .tap()

        XCTAssertTrue(waitFor(timeout: 5) { self.screen.pollOptionIsVoted(0) },
                      "Pressing the radio should cast the vote for that option; was: "
                          + "\(screen.pollVoteStateDescription(optionCount: optionCount))")

        let voted = screen.votedPollOptionIndexes(upTo: optionCount)
        XCTAssertEqual(voted, [0],
                       "Only the pressed option should be voted. Voted rows: \(voted); "
                           + "\(screen.pollVoteStateDescription(optionCount: optionCount))")
    }

    // MARK: - Multiple-choice polls

    /// The mirror image of the bug: in a poll that *does* allow several answers,
    /// two votes cast in quick succession must both stick. Keeps a fix for the
    /// single-choice case from over-correcting into "only the newest vote shows".
    func test_quicklyVotingTwice_inMultipleChoicePoll_keepsBothOptionsVoted() {
        openPollConversation(multipleChoice: true, doubleVoteGapMs: 80)

        let driver = screen.pollDoubleVoteButton
        XCTAssertTrue(driver.waitForExistence(timeout: 10),
                      "The rapid-vote driver button should be installed")
        driver.tap()

        XCTAssertTrue(waitFor(timeout: 10) { (driver.value as? String) == "2" },
                      "Both votes should have been dispatched; the driver reported "
                          + "\((driver.value as? String) ?? "<nothing>")")

        XCTAssertTrue(waitFor(timeout: 5) { self.screen.pollOptionIsVoted(1) },
                      "The second option should render as voted; was: "
                          + "\(screen.pollVoteStateDescription(optionCount: optionCount))")
        _ = waitFor(timeout: 2) { false }

        let voted = screen.votedPollOptionIndexes(upTo: optionCount)
        XCTAssertEqual(voted, [0, 1],
                       "A multiple-choice poll must keep every option voted for. "
                           + "Voted rows: \(voted); "
                           + "\(screen.pollVoteStateDescription(optionCount: optionCount))")
    }

    // MARK: - Helpers

    /// Polls `condition` until it is true or `timeout` elapses. Passing a condition
    /// that never holds simply idles for `timeout`, letting in-flight animations
    /// settle before an assertion.
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
