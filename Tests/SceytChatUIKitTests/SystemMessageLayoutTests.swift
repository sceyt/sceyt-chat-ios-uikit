//
//  SystemMessageLayoutTests.swift
//  SceytChatUIKitTests
//
//  Covers the measurement of a system-message row whose text is rendered from another
//  message. A pin system message ("X pinned: …") shows the PINNED message's body, so
//  editing that message changes this row's text and, once the text wraps differently, its
//  height — and `MessageLayoutModel` has to re-measure rather than reuse the size it
//  calculated for the old text.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import UIKit
import XCTest

final class SystemMessageLayoutTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    private let channelId: ChannelId = 77
    private let channel = ChatChannel(id: 77, type: "group", uri: "system-message-layout")

    /// Short enough to render on a single line.
    private let shortBody = "See you at 6"
    /// Long enough that "You pinned: …" has to wrap onto more than one line.
    private let longBody = String(repeating: "wrap me across several lines ", count: 4)

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        let (channel, _) = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        try? ctx.save()
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func seedMessage(
        id: MessageId,
        body: String,
        type: String = "text"
    ) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: id, tid: Int64(id), channelId: Int64(channelId), context: ctx)
        message.id = Int64(id)
        message.tid = Int64(id)
        message.channelId = Int64(channelId)
        message.body = body
        message.type = type
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    /// A pin system message linked to `parent`, the way
    /// `ChannelPinnedMessageProvider.sendPinSystemMessage` stores it.
    private func seedPinSystemMessage(id: MessageId, parent: MessageDTO) -> MessageDTO {
        let message = seedMessage(
            id: id,
            body: ChatMessage.SystemMessageType.pinnedMessage,
            type: ChatMessage.MessageType.system
        )
        message.metadata = SystemMessageMetadata.PinnedMessage(id: MessageId(parent.id)).toJSONString()
        message.parent = parent
        try? ctx.save()
        return message
    }

    private func makeModel(_ dto: MessageDTO) -> MessageLayoutModel {
        MessageLayoutModel(
            channel: channel,
            message: ChatMessage(dto: dto),
            appearance: MessageCell.appearance
        )
    }

    private func text(_ model: MessageLayoutModel) -> String {
        SceytChatUIKit.shared.formatters.systemMessageBodyFormatter.format(model.message)
    }

    // MARK: - Tests

    /// The premise the rest of the file rests on: the two bodies really do measure to
    /// different heights, so a stale height is detectable at all.
    func testTheTwoBodiesMeasureToDifferentHeights() {
        let shortParent = seedMessage(id: 1, body: shortBody)
        let shortModel = makeModel(seedPinSystemMessage(id: 2, parent: shortParent))

        let longParent = seedMessage(id: 3, body: longBody)
        let longModel = makeModel(seedPinSystemMessage(id: 4, parent: longParent))

        XCTAssertGreaterThan(
            longModel.measureSize.height, shortModel.measureSize.height,
            "the fixture bodies must wrap to different line counts for this suite to mean anything"
        )
    }

    /// Editing the pinned message must re-measure the row that quotes it.
    func testEditingTheParent_reMeasuresTheRow() {
        let parent = seedMessage(id: 1, body: shortBody)
        let system = seedPinSystemMessage(id: 2, parent: parent)
        let model = makeModel(system)

        let shortHeight = model.measureSize.height
        XCTAssertTrue(text(model).contains(shortBody), "sanity: the row renders the parent's body")

        parent.body = longBody
        parent.state = Int16(ChatMessage.State.edited.intValue)
        try? ctx.save()

        XCTAssertTrue(model.update(channel: channel, message: ChatMessage(dto: system)))

        XCTAssertTrue(text(model).contains("wrap me"), "the row must render the edited body")
        XCTAssertGreaterThan(
            model.measureSize.height, shortHeight,
            "the row must grow to fit the wrapped text"
        )
    }

    /// The regression this guards: `MessageLayoutModel.updateOptions` accumulates across
    /// updates, so once `.parentMessageBody` is in the set the plain options diff reads as
    /// "no change" on every LATER edit. A second edit therefore has to be detected by
    /// something other than that diff, or the row keeps the first edit's height forever.
    func testASecondEditOfTheParent_stillReMeasuresTheRow() {
        let parent = seedMessage(id: 1, body: shortBody)
        let system = seedPinSystemMessage(id: 2, parent: parent)
        let model = makeModel(system)

        // First edit — grows the row. This is the one that works off the options diff
        // alone, because `.parentMessageBody` is not in the set yet.
        parent.body = longBody
        parent.state = Int16(ChatMessage.State.edited.intValue)
        try? ctx.save()
        XCTAssertTrue(model.update(channel: channel, message: ChatMessage(dto: system)))
        let grownHeight = model.measureSize.height
        XCTAssertGreaterThan(grownHeight, 0)

        // Second edit — back to a one-line body. `.parentMessageBody` is already set now.
        parent.body = shortBody
        try? ctx.save()
        XCTAssertTrue(model.update(channel: channel, message: ChatMessage(dto: system)))

        XCTAssertTrue(text(model).contains(shortBody), "the row must render the second edit")
        XCTAssertLessThan(
            model.measureSize.height, grownHeight,
            "the row must shrink back — a second edit must re-measure too"
        )
    }

    // MARK: - Two-font rendering

    /// "You pinned: …" draws the actor's name in the emphasized font and the rest of the
    /// sentence in the lighter one.
    func testThePinRow_drawsTheActorsNameApartFromTheRest() {
        let parent = seedMessage(id: 1, body: shortBody)
        let model = makeModel(seedPinSystemMessage(id: 2, parent: parent))
        let appearance = MessageCell.appearance
        XCTAssertNotEqual(
            appearance.systemMessageFont, appearance.systemMessageBodyFont,
            "sanity: the two fonts have to differ for this test to mean anything"
        )

        let attributed = ChannelViewController.SystemMessageCell
            .attributedText(for: model.message, appearance: appearance)
        let nameRange = (attributed.string as NSString).range(of: L10n.User.current)
        XCTAssertNotEqual(nameRange.location, NSNotFound, "sanity: the row names the actor")

        XCTAssertEqual(
            attributed.attribute(.font, at: nameRange.location, effectiveRange: nil) as? UIFont,
            appearance.systemMessageFont,
            "the name keeps the emphasized font"
        )
        XCTAssertEqual(
            attributed.attribute(.font, at: NSMaxRange(nameRange), effectiveRange: nil) as? UIFont,
            appearance.systemMessageBodyFont,
            "everything past the name drops to the lighter font"
        )
    }

    /// Only the rows that name an actor are split in two — every other type stays the one
    /// uniform run it has always been.
    func testANonPinSystemRow_drawsAsOneRun() {
        let leave = seedMessage(id: 1, body: "LG", type: ChatMessage.MessageType.system)
        let model = makeModel(leave)
        let appearance = MessageCell.appearance

        let attributed = ChannelViewController.SystemMessageCell
            .attributedText(for: model.message, appearance: appearance)
        XCTAssertGreaterThan(attributed.length, 0, "sanity: the row renders text")

        var effective = NSRange()
        let font = attributed.attribute(.font, at: 0, effectiveRange: &effective) as? UIFont
        XCTAssertEqual(font, appearance.systemMessageFont)
        XCTAssertEqual(effective, NSRange(location: 0, length: attributed.length),
                       "one font across the whole sentence")
    }

    /// The height has to be calculated from the two-font string the label actually draws: a
    /// regular run is narrower than a semibold one, so measuring either font across the
    /// whole sentence puts the wrap in the wrong place and the row ends up short or tall.
    func testThePinRowHeight_matchesWhatTheLabelDraws() {
        let parent = seedMessage(id: 1, body: longBody)
        let model = makeModel(seedPinSystemMessage(id: 2, parent: parent))

        let insets = ChannelViewController.SystemMessageCell.titleContentInsets
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = ChannelViewController.SystemMessageCell
            .attributedText(for: model.message, appearance: MessageCell.appearance)
        let drawn = label.sizeThatFits(
            .init(
                width: UIScreen.main.bounds.width - 48 - 48 - insets.left - insets.right,
                height: .greatestFiniteMagnitude
            )
        ).height

        // Loose by a point: `sizeThatFits` and the layout manager's used rect round a
        // fraction differently, and the row is padded by the title insets on top of it.
        XCTAssertEqual(
            model.measureSize.height,
            ceil(drawn) + insets.top + insets.bottom,
            accuracy: 2,
            "the measured row must be as tall as the label draws it"
        )
    }

    // MARK: - Re-measurement

    /// A row whose text did not change must not be reported as updated, or every unrelated
    /// message write would reconfigure every system row on screen.
    func testAnUnchangedParent_doesNotGrowTheRow() {
        let parent = seedMessage(id: 1, body: shortBody)
        let system = seedPinSystemMessage(id: 2, parent: parent)
        let model = makeModel(system)

        let height = model.measureSize.height
        XCTAssertTrue(model.update(channel: channel, message: ChatMessage(dto: system)))

        XCTAssertEqual(model.measureSize.height, height, "an idle update must leave the height alone")
    }
}
