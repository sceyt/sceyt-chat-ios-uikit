//
//  PinnedEditedInfoRowTests.swift
//  SceytChatUIKitTests
//
//  Reported (Sept 2026): a pinned message that is then edited renders the bubble with a gap
//  where the "edited" mark belongs, and no mark in it — pin, time and tick only.
//
//  The row (`MessageCell.InfoView`) is laid out to a fixed width, and the bubble is measured
//  from `MessageLayoutModel.infoViewMeasure`, so a measure taken for a different message
//  *state* than the one being rendered is spent on empty space (measure ahead of the render)
//  or squeezes the row (render ahead of the measure). `updateOptions` accumulates until a cell
//  binds, so once `.body` is in the set a later state change used to diff as "no change" and
//  never remeasure — that is the drift these tests pin down.
//

@testable import SceytChatUIKit
import SceytChat
import UIKit
import XCTest

final class PinnedEditedInfoRowTests: XCTestCase {

    /// Hosts must outlive the test method: a cell whose superview is deallocated stops
    /// binding (`data`'s setter is gated on `superview != nil`).
    private var hosts = [UIView]()

    private let channelId: ChannelId = 500
    private let messageId: MessageId = 5001

    private func makeMessage(
        body: String = "The most recent",
        edited: Bool,
        pinned: Bool
    ) -> ChatMessage {
        ChatMessage(
            id: messageId,
            tid: Int64(messageId),
            channelId: channelId,
            body: body,
            type: "text",
            createdAt: Date(),
            incoming: false,
            state: edited ? .edited : .none,
            deliveryStatus: .sent,
            user: ChatUser(id: "me"),
            pinDetails: pinned ? PinDetails(isPinned: true) : nil
        )
    }

    private func makeModel(_ message: ChatMessage) -> MessageLayoutModel {
        MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "pin-edit"),
            message: message,
            appearance: MessageCell.appearance
        )
    }

    /// A cell bound the way the list binds it: added to a host of the collection's width
    /// first, then handed the model (`data`'s setter runs bind + makeConstraints).
    @discardableResult
    private func bind(_ model: MessageLayoutModel, to existing: MessageCell? = nil) -> MessageCell {
        let cell = existing ?? {
            let cell = ChannelViewController.OutgoingMessageCell(
                frame: .init(x: 0, y: 0, width: 390, height: 200))
            let host = UIView(frame: .init(x: 0, y: 0, width: 390, height: 200))
            hosts.append(host)
            host.addSubview(cell)
            return cell
        }()
        cell.data = model
        cell.superview?.setNeedsLayout()
        cell.superview?.layoutIfNeeded()
        return cell
    }

    /// The row's own constant slack: `InfoView.measure` reserves 4pt of trailing padding
    /// that the live stack has no item for, plus sub-point font rounding. Anything past this
    /// is a whole item — the 15pt pin slot, or the ~40pt "edited" one — reserved and not drawn.
    private let rowPadding: CGFloat = 6

    /// The empty space the bubble spends in front of the row — what the report shows.
    ///
    /// Never zero, see `rowPadding`. What matters is that a row reached by drift carries no
    /// *more* slack than the same row built from scratch, which is what `matchesFresh` checks.
    private func rowSlack(_ cell: MessageCell) -> CGFloat {
        cell.infoView.frame.width - cell.infoView.contentWidth
    }

    /// The same message, laid out by a model that never drifted.
    private func matchesFresh(
        _ cell: MessageCell,
        _ message: ChatMessage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let fresh = bind(makeModel(message))
        XCTAssertEqual(rowSlack(cell), rowSlack(fresh), accuracy: 0.5,
                       "row reserve: \(describe(cell)) vs fresh \(describe(fresh))",
                       file: file, line: line)
        XCTAssertEqual(cell.bubbleView.frame.width, fresh.bubbleView.frame.width, accuracy: 0.5,
                       "bubble width: \(describe(cell)) vs fresh \(describe(fresh))",
                       file: file, line: line)
        XCTAssertEqual(cell.infoView.stateLabel.isHidden, fresh.infoView.stateLabel.isHidden,
                       "edited mark: \(describe(cell)) vs fresh \(describe(fresh))",
                       file: file, line: line)
    }

    private func describe(_ cell: MessageCell) -> String {
        let info = cell.infoView
        return """
        options=\(cell.data.contentOptions.rawValue) bubble=\(cell.bubbleView.frame.width) \
        text=\(cell.textLabel.frame.width) info=\(info.frame.width) live=\(info.contentWidth) \
        measure=\(cell.data.infoViewMeasure.width) editedShown=\(!info.stateLabel.isHidden) \
        pinShown=\(!info.pinView.isHidden)
        """
    }

    // MARK: - Static: pinned + edited from the start

    func testPinnedEditedRowRendersTheMark() {
        let cell = bind(makeModel(makeMessage(edited: true, pinned: true)))

        XCTAssertFalse(cell.infoView.stateLabel.isHidden, "the edited mark must be visible")
        XCTAssertGreaterThan(cell.infoView.stateLabel.frame.width, 1, "the mark must have a slot")
        XCTAssertFalse(cell.infoView.pinView.isHidden, "the pin must be visible")
        XCTAssertLessThanOrEqual(rowSlack(cell), rowPadding, describe(cell))
    }

    // MARK: - The reported sequence: pinned, then edited

    func testEditingAPinnedMessageShowsTheMark() {
        let model = makeModel(makeMessage(body: "The most recent message", edited: false, pinned: true))
        let cell = bind(model)

        // What the store -> observer path does: the same model gets the edited message.
        let edited = makeMessage(body: "The most recen", edited: true, pinned: true)
        model.update(channel: model.channel, message: edited)
        bind(model, to: cell)

        XCTAssertFalse(cell.infoView.stateLabel.isHidden, "the edited mark must be visible")
        matchesFresh(cell, edited)
    }

    /// The same sequence with `updateOptions` already carrying `.body` — an off-screen cell
    /// never clears it (`bind` does), so a second body/state change diffs as "no change".
    func testEditingAPinnedMessageWithAccumulatedUpdateOptions() {
        let model = makeModel(makeMessage(body: "one", edited: false, pinned: true))
        model.update(channel: model.channel,
                     message: makeMessage(body: "two", edited: false, pinned: true))
        XCTAssertTrue(model.updateOptions.contains(.body), "precondition: .body is stuck on")

        let edited = makeMessage(body: "two", edited: true, pinned: true)
        model.update(channel: model.channel, message: edited)

        XCTAssertEqual(model.infoViewMeasure.width,
                       MessageCell.InfoView.measure(channel: model.channel,
                                                    message: model.message,
                                                    appearance: MessageCell.appearance).width,
                       accuracy: 0.5,
                       "the cached info measure must track the message's current state")
        matchesFresh(bind(model), edited)
    }

    /// The report's own picture: the row was measured while the message was edited and the
    /// message is not edited any more. The bubble must not keep paying for the mark.
    func testMessageThatStopsBeingEditedDropsTheMarksReserve() {
        let model = makeModel(makeMessage(body: "The most recen", edited: true, pinned: true))
        let editedMeasure = model.infoViewMeasure.width
        let cell = bind(model)
        XCTAssertFalse(cell.infoView.stateLabel.isHidden, "precondition: the mark is up")

        // An echo/ack that carries the message back without its edited state.
        let plain = makeMessage(body: "The most recen", edited: false, pinned: true)
        model.update(channel: model.channel, message: plain)
        bind(model, to: cell)

        XCTAssertLessThan(model.infoViewMeasure.width, editedMeasure,
                          "the info measure must shrink back once the mark is gone")
        matchesFresh(cell, plain)
    }

    /// The seam the field logs caught: the model is updated **in place** (from a background
    /// queue) and the cell is laid out again without being re-bound — `messageListOrder` is
    /// one such path. The row rendered the state before the edit while the bubble was already
    /// measured for the mark, which is the empty slot in the report.
    func testLayoutWithoutARebindStillRendersTheCurrentState() {
        let model = makeModel(makeMessage(body: "The most recen", edited: false, pinned: true))
        let cell = bind(model)
        XCTAssertTrue(cell.infoView.stateLabel.isHidden, "precondition: no mark yet")

        model.update(channel: model.channel,
                     message: makeMessage(body: "The most recen", edited: true, pinned: true))
        // No `cell.data = model` — only a constraints pass.
        cell.messageListOrder = .newestAtTop
        cell.superview?.layoutIfNeeded()

        XCTAssertFalse(cell.infoView.stateLabel.isHidden,
                       "the row must render the state it is laid out from: \(describe(cell))")
        XCTAssertLessThanOrEqual(rowSlack(cell), rowPadding, describe(cell))
    }

    /// The same for a pin arriving on a bound cell — the 13:34:43 lines in the field log,
    /// where the row was 15pt (the pin's slot) short of what it was laid out to.
    func testPinArrivingWithoutARebindStillDrawsThePin() {
        let model = makeModel(makeMessage(edited: false, pinned: false))
        let cell = bind(model)
        XCTAssertTrue(cell.infoView.pinView.isHidden, "precondition: not pinned yet")

        model.update(channel: model.channel, message: makeMessage(edited: false, pinned: true))
        cell.messageListOrder = .newestAtTop
        cell.superview?.layoutIfNeeded()

        XCTAssertFalse(cell.infoView.pinView.isHidden, describe(cell))
        XCTAssertLessThanOrEqual(rowSlack(cell), rowPadding, describe(cell))
    }

    /// Pin and edit landing in the same update, on a model that has already accumulated
    /// `.body`: both marks have to be measured for.
    func testPinAndEditInTheSameUpdate() {
        let model = makeModel(makeMessage(body: "one", edited: false, pinned: false))
        model.update(channel: model.channel,
                     message: makeMessage(body: "two", edited: false, pinned: false))

        let pinnedAndEdited = makeMessage(body: "two", edited: true, pinned: true)
        model.update(channel: model.channel, message: pinnedAndEdited)
        let cell = bind(model)

        XCTAssertFalse(cell.infoView.stateLabel.isHidden, describe(cell))
        XCTAssertFalse(cell.infoView.pinView.isHidden, describe(cell))
        matchesFresh(cell, pinnedAndEdited)
    }
}
