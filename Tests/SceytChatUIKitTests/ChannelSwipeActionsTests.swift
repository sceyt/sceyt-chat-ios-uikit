//
//  ChannelSwipeActionsTests.swift
//  SceytChatUIKitTests
//
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//
//  Covers the pure parts of the channel list's in-cell swipe actions: the
//  `Actions` -> appearance resolution, the button layout order, and the drag
//  geometry. The end-to-end "an open swipe survives a channel reorder" behaviour
//  is covered by `ChannelListSwipeUITests`.
//

import XCTest
@testable import SceytChatUIKit

final class ChannelSwipeActionsTests: XCTestCase {

    private typealias Config = ChannelSwipeActionsConfiguration
    private typealias Cell = ChannelListViewController.ChannelCell

    // MARK: - Action resolution

    func test_trailingActionItems_preserveOrderAndResolveAppearances() {
        // A group channel owned by the user offers delete, leave, then mute.
        let channel = makeChannel(type: "group", userRole: "owner")
        let items = Config.trailingActionItems(chatChannel: channel)

        XCTAssertEqual(items.map(\.action), [.delete, .leave, .mute],
                       "The item list must preserve trailingActions(chatChannel:)'s order")
        XCTAssertEqual(items.map(\.appearance.title),
                       [Config.Appearance.deleteContextualAction.title,
                        Config.Appearance.leaveContextualAction.title,
                        Config.Appearance.muteContextualAction.title],
                       "Each action must resolve to its own configured appearance")
    }

    func test_leadingActionItems_reflectUnreadAndPinnedState() {
        let unreadUnpinned = makeChannel(newMessageCount: 3)
        XCTAssertEqual(Config.leadingActionItems(chatChannel: unreadUnpinned).map(\.action),
                       [.read, .pin])

        let readPinned = makeChannel(pinnedAt: Date())
        XCTAssertEqual(Config.leadingActionItems(chatChannel: readPinned).map(\.action),
                       [.unread, .unpin])
    }

    func test_trailingActionItems_forDirectChannel_offerDeleteNotLeave() {
        let direct = makeChannel(type: "direct")
        XCTAssertEqual(Config.trailingActionItems(chatChannel: direct).map(\.action),
                       [.delete, .mute])
    }

    func test_trailingActionItems_forMutedChannel_offerUnmute() {
        let muted = makeChannel(type: "direct", muted: true)
        XCTAssertEqual(Config.trailingActionItems(chatChannel: muted).map(\.action),
                       [.delete, .unmute])
    }

    /// The identifier name is what UI tests address the buttons by, so it must
    /// stay locale-independent and stable.
    func test_actionIdentifierNames_areStableAndUnique() {
        let names = Config.Actions.allCases.map(\.identifierName)
        XCTAssertEqual(names,
                       ["delete", "leave", "read", "unread", "mute", "unmute", "pin", "unpin"])
        XCTAssertEqual(Set(names).count, names.count, "Identifier names must be unique")
    }

    // MARK: - Button layout

    func test_fullRevealWidth_isTheSumOfButtonWidths() {
        let view = ChannelSwipeActionsView()
        view.side = .trailing
        let items = Config.trailingActionItems(chatChannel: makeChannel(type: "direct"))
        view.configure(items: items)

        let expected = items.reduce(CGFloat(0)) { $0 + view.naturalWidth(for: $1) }
        XCTAssertEqual(view.fullRevealWidth, expected, accuracy: 0.5)
        XCTAssertEqual(view.buttons.count, items.count)
    }

    func test_naturalWidth_respectsTheMinimum() {
        let view = ChannelSwipeActionsView()
        let blank = Config.ActionItem(action: .pin,
                                     appearance: ContextualActionAppearance(title: ""))
        XCTAssertEqual(view.naturalWidth(for: blank),
                       ChannelSwipeActionsView.Layouts.minimumWidth,
                       "A short title must not shrink the button below the tappable minimum")
    }

    /// `items[0]` is the action closest to the swiped edge — the one a full swipe
    /// would fire. On the trailing side that edge is the last position in reading
    /// order, so the buttons are laid out reversed.
    func test_trailingSide_laysOutTheFirstActionClosestToTheSwipedEdge() {
        let view = ChannelSwipeActionsView()
        view.side = .trailing
        view.configure(items: [
            Config.ActionItem(action: .delete, appearance: Config.appearance(for: .delete)),
            Config.ActionItem(action: .mute, appearance: Config.appearance(for: .mute))
        ])
        XCTAssertEqual(view.buttons.compactMap { $0.item?.action }, [.mute, .delete],
                       "The trailing side renders items reversed, so delete sits outermost")
    }

    func test_leadingSide_laysOutTheFirstActionFirst() {
        let view = ChannelSwipeActionsView()
        view.side = .leading
        view.configure(items: [
            Config.ActionItem(action: .read, appearance: Config.appearance(for: .read)),
            Config.ActionItem(action: .pin, appearance: Config.appearance(for: .pin))
        ])
        XCTAssertEqual(view.buttons.compactMap { $0.item?.action }, [.read, .pin])
    }

    func test_configure_replacesPreviousButtons() {
        let view = ChannelSwipeActionsView()
        view.side = .trailing
        view.configure(items: Config.trailingActionItems(chatChannel: makeChannel(type: "direct")))
        XCTAssertEqual(view.buttons.compactMap { $0.item?.action }, [.mute, .delete])

        // A mute -> unmute flip must swap the button, not append one.
        view.configure(items: Config.trailingActionItems(
            chatChannel: makeChannel(type: "direct", muted: true)))
        XCTAssertEqual(view.buttons.compactMap { $0.item?.action }, [.unmute, .delete])
    }

    func test_emptyActions_giveNoRevealWidth() {
        let view = ChannelSwipeActionsView()
        view.configure(items: [])
        XCTAssertEqual(view.fullRevealWidth, 0,
                       "A side with no actions must not be openable")
        XCTAssertTrue(view.buttons.isEmpty)
    }

    // MARK: - Drag geometry

    func test_clampedSwipeOffset_rubberBandsPastTheFullReveal() {
        // Within the reveal, the drag is followed exactly.
        XCTAssertEqual(Cell.clampedSwipeOffset(-80, fullLeading: 100, fullTrailing: 150,
                                               rubberBandFactor: 0.35),
                       -80, accuracy: 0.001)
        // Past it, the excess is resisted.
        XCTAssertEqual(Cell.clampedSwipeOffset(-200, fullLeading: 100, fullTrailing: 150,
                                               rubberBandFactor: 0.35),
                       -(150 + 50 * 0.35), accuracy: 0.001)
    }

    func test_clampedSwipeOffset_hardStopsAtASideWithNoActions() {
        XCTAssertEqual(Cell.clampedSwipeOffset(-120, fullLeading: 100, fullTrailing: 0,
                                               rubberBandFactor: 0.35),
                       0, "A side with no actions must not open at all")
        XCTAssertEqual(Cell.clampedSwipeOffset(120, fullLeading: 0, fullTrailing: 150,
                                               rubberBandFactor: 0.35),
                       0)
    }

    func test_settleTarget_opensPastTheThresholdAndClosesBelowIt() {
        // Dragged well past half the reveal, released still.
        XCTAssertEqual(Cell.settleTarget(offset: -120, velocity: 0,
                                         fullLeading: 100, fullTrailing: 150,
                                         openThreshold: 0.5),
                       -150, accuracy: 0.001)
        // Barely dragged, released still.
        XCTAssertEqual(Cell.settleTarget(offset: -20, velocity: 0,
                                         fullLeading: 100, fullTrailing: 150,
                                         openThreshold: 0.5),
                       0, accuracy: 0.001)
    }

    func test_settleTarget_honoursReleaseVelocity() {
        // A short drag flicked hard toward the trailing edge should still open:
        // the projection (offset + velocity * 0.15) carries it past the threshold.
        let target = Cell.settleTarget(offset: -20, velocity: -2000,
                                       fullLeading: 100, fullTrailing: 150,
                                       openThreshold: 0.5)
        XCTAssertEqual(target, -150, accuracy: 0.001,
                       "A fast flick should open the row even from a short drag")

        // And a long drag flicked back toward closed should close.
        let closing = Cell.settleTarget(offset: -120, velocity: 2000,
                                        fullLeading: 100, fullTrailing: 150,
                                        openThreshold: 0.5)
        XCTAssertEqual(closing, 0, accuracy: 0.001,
                       "A flick back toward the edge should close the row")
    }

    func test_settleTarget_neverOpensASideWithNoActions() {
        for velocity in [CGFloat(-4000), 0, 4000] {
            XCTAssertEqual(Cell.settleTarget(offset: -140, velocity: velocity,
                                             fullLeading: 100, fullTrailing: 0,
                                             openThreshold: 0.5),
                           0, "Trailing has no actions, so it can never settle open")
            XCTAssertEqual(Cell.settleTarget(offset: 140, velocity: velocity,
                                             fullLeading: 0, fullTrailing: 150,
                                             openThreshold: 0.5),
                           0, "Leading has no actions, so it can never settle open")
        }
    }

    // MARK: - Icons

    /// Integrators supply their own artwork per action. The icon is laid out at
    /// `Layouts.iconSize` (scaled for Dynamic Type) rather than at whatever
    /// intrinsic size the asset happens to have, so a large asset cannot blow the
    /// button's width out.
    func test_naturalWidth_sizesFromLayoutsIconSize_notTheAssetSize() {
        let view = ChannelSwipeActionsView()
        let huge = Config.ActionItem(
            action: .pin,
            appearance: ContextualActionAppearance(title: "", image: image(size: 512)))
        XCTAssertEqual(view.naturalWidth(for: huge),
                       ChannelSwipeActionsView.Layouts.minimumWidth,
                       "A 512pt asset must not widen the button; it is drawn at iconSize")
    }

    func test_naturalWidth_accountsForAWideIcon() {
        let previous = ChannelSwipeActionsView.Layouts.iconSize
        defer { ChannelSwipeActionsView.Layouts.iconSize = previous }
        ChannelSwipeActionsView.Layouts.iconSize = 200

        let view = ChannelSwipeActionsView()
        let item = Config.ActionItem(
            action: .pin,
            appearance: ContextualActionAppearance(title: "", image: image(size: 24)))
        XCTAssertGreaterThanOrEqual(
            view.naturalWidth(for: item),
            200 + ChannelSwipeActionsView.Layouts.horizontalPadding * 2,
            "A wider iconSize must widen the button to fit it")
    }

    func test_naturalWidth_ignoresIconSizeWhenThereIsNoImage() {
        let previous = ChannelSwipeActionsView.Layouts.iconSize
        defer { ChannelSwipeActionsView.Layouts.iconSize = previous }
        ChannelSwipeActionsView.Layouts.iconSize = 200

        let view = ChannelSwipeActionsView()
        let titleOnly = Config.ActionItem(
            action: .pin,
            appearance: ContextualActionAppearance(title: "Pin"))
        XCTAssertEqual(view.naturalWidth(for: titleOnly),
                       ChannelSwipeActionsView.Layouts.minimumWidth,
                       "A title-only action must not reserve room for an absent icon")
    }

    func test_scaledIconSize_matchesLayoutsAtTheDefaultCategory() {
        let size = ChannelSwipeActionsView.scaledIconSize(
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        XCTAssertEqual(size, ChannelSwipeActionsView.Layouts.iconSize, accuracy: 0.5)
    }

    func test_scaledIconSize_growsWithDynamicType() {
        let base = ChannelSwipeActionsView.scaledIconSize(
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let large = ChannelSwipeActionsView.scaledIconSize(
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        XCTAssertGreaterThan(large, base,
                             "The icon must scale alongside the title at accessibility sizes")
    }

    /// The button hides the icon when an action carries no artwork, so the
    /// SDK's own title-only defaults keep rendering exactly as before.
    func test_button_hidesTheIconForATitleOnlyAction() {
        let button = ChannelSwipeActionButton()
        button.configure(with: Config.ActionItem(
            action: .pin, appearance: ContextualActionAppearance(title: "Pin")))
        XCTAssertTrue(button.iconView.isHidden)
        XCTAssertFalse(button.actionTitleLabel.isHidden)

        button.configure(with: Config.ActionItem(
            action: .pin,
            appearance: ContextualActionAppearance(title: "Pin", image: image(size: 24))))
        XCTAssertFalse(button.iconView.isHidden)
        XCTAssertNotNil(button.iconView.image)
    }

    func test_button_appliesTheActionBackgroundColour() {
        let button = ChannelSwipeActionButton()
        button.configure(with: Config.ActionItem(
            action: .pin,
            appearance: ContextualActionAppearance(title: "Pin", backgroundColor: .systemPink)))
        XCTAssertEqual(button.backgroundColor, .systemPink,
                       "Each action paints its own background")
    }

    // MARK: - Full swipe

    /// With full swipe armed the drag past the reveal must follow the finger.
    /// Resisted, the trigger threshold lands beyond the width of the screen and
    /// the gesture can never fire — the flag would look wired up but do nothing.
    func test_fullSwipeThreshold_isReachableOnlyWithoutResistance() {
        let rowWidth: CGFloat = 390
        let threshold = rowWidth * 0.6          // fullSwipeThresholdFraction
        let reveal: CGFloat = 148               // two ~74pt buttons

        // Solve for the raw drag that produces an offset at the threshold.
        func rawDrag(toReach offset: CGFloat, factor: CGFloat) -> CGFloat {
            reveal + (offset - reveal) / factor
        }
        XCTAssertGreaterThan(rawDrag(toReach: threshold, factor: 0.35), rowWidth,
                             "Resisted, the threshold sits off-screen")
        XCTAssertLessThan(rawDrag(toReach: threshold, factor: 1), rowWidth,
                          "Unresisted, the threshold is within the row")
    }

    func test_clampedSwipeOffset_followsTheFingerWhenUnresisted() {
        XCTAssertEqual(Cell.clampedSwipeOffset(-300,
                                               fullLeading: 100,
                                               fullTrailing: 148,
                                               rubberBandFactor: 1),
                       -300, accuracy: 0.001,
                       "A factor of 1 tracks the drag exactly past the reveal")
    }

    func test_effectiveRubberBandFactor_tracksTheFullSwipeFlag() {
        let cell = makeCell(layoutDirection: .forceLeftToRight)
        XCTAssertEqual(cell.effectiveRubberBandFactor,
                       ChannelSwipeActionsConfiguration.Appearance.rubberBandFactor,
                       "Off by default, the row resists past the reveal")
        cell.performsFirstActionWithFullSwipe = true
        XCTAssertEqual(cell.effectiveRubberBandFactor, 1,
                       "Armed, the row follows the finger so the trigger is reachable")
    }

    /// The action a full swipe fires is `Actions[0]` — the one drawn nearest the
    /// swiped edge — on both sides.
    func test_fullSwipeAction_isTheOutermostAction() {
        let cell = makeCell(layoutDirection: .forceLeftToRight)
        cell.performsFirstActionWithFullSwipe = true
        // WAAFI's trailing rule: Mute first, then Delete.
        cell.trailingActionsView.configure(items: [
            Config.ActionItem(action: .mute, appearance: Config.appearance(for: .mute)),
            Config.ActionItem(action: .delete, appearance: Config.appearance(for: .delete))
        ])
        cell.leadingActionsView.configure(items: [
            Config.ActionItem(action: .read, appearance: Config.appearance(for: .read)),
            Config.ActionItem(action: .pin, appearance: Config.appearance(for: .pin))
        ])
        let past = cell.bounds.width * cell.fullSwipeThresholdFraction + 1

        XCTAssertEqual(cell.fullSwipeAction(for: -past), .mute,
                       "A full trailing swipe fires the first trailing action")
        XCTAssertEqual(cell.fullSwipeAction(for: past), .read,
                       "A full leading swipe fires the first leading action")
        XCTAssertNil(cell.fullSwipeAction(for: -10),
                     "A short drag fires nothing")
    }

    // MARK: - Full-swipe haptic

    /// `UISwipeActionsConfiguration` bumps *while* dragging, the moment a full
    /// swipe becomes armed — that is what tells you releasing will perform the
    /// action. So the feedback is driven from the drag, once per crossing.
    func test_fullSwipeHaptic_firesOnceWhenTheThresholdIsCrossed() {
        let cell = makeFullSwipeCell()
        let past = -(cell.bounds.width * cell.fullSwipeThresholdFraction + 1)

        cell.updateFullSwipeActivation(for: -10)
        XCTAssertEqual(cell.thresholdCrossings, 0, "Short drags must not buzz")

        cell.updateFullSwipeActivation(for: past)
        XCTAssertEqual(cell.thresholdCrossings, 1, "Crossing the threshold buzzes once")

        // Still dragging past it — the latch must hold.
        cell.updateFullSwipeActivation(for: past - 20)
        cell.updateFullSwipeActivation(for: past - 40)
        XCTAssertEqual(cell.thresholdCrossings, 1,
                       "Continuing past the threshold must not buzz on every touch move")
    }

    func test_fullSwipeHaptic_reArmsAfterFallingBackBelowTheThreshold() {
        let cell = makeFullSwipeCell()
        let past = -(cell.bounds.width * cell.fullSwipeThresholdFraction + 1)

        cell.updateFullSwipeActivation(for: past)
        cell.updateFullSwipeActivation(for: -10)
        XCTAssertEqual(cell.thresholdCrossings, 1,
                       "Dragging back out is silent, as it is natively")

        cell.updateFullSwipeActivation(for: past)
        XCTAssertEqual(cell.thresholdCrossings, 2, "Crossing again buzzes again")
    }

    func test_fullSwipeHaptic_isSilentWhenFullSwipeIsOff() {
        let cell = makeFullSwipeCell()
        cell.performsFirstActionWithFullSwipe = false
        cell.updateFullSwipeActivation(for: -(cell.bounds.width))
        XCTAssertEqual(cell.thresholdCrossings, 0,
                       "No full swipe means no armed state to announce")
    }

    /// The leading side arms — and therefore buzzes — on its own actions.
    func test_fullSwipeHaptic_appliesToTheLeadingSideToo() {
        let cell = makeFullSwipeCell()
        cell.updateFullSwipeActivation(for: cell.bounds.width * cell.fullSwipeThresholdFraction + 1)
        XCTAssertEqual(cell.thresholdCrossings, 1)
    }

    private func makeFullSwipeCell() -> CountingCell {
        let cell = CountingCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 72)
        cell.performsFirstActionWithFullSwipe = true
        cell.trailingActionsView.configure(items: [
            Config.ActionItem(action: .mute, appearance: Config.appearance(for: .mute)),
            Config.ActionItem(action: .delete, appearance: Config.appearance(for: .delete))
        ])
        cell.leadingActionsView.configure(items: [
            Config.ActionItem(action: .read, appearance: Config.appearance(for: .read))
        ])
        cell.layoutIfNeeded()
        return cell
    }

    // MARK: - Customization seam

    /// Integrators change *which* actions a channel offers by subclassing
    /// `ChannelSwipeActionsConfiguration`, overriding `trailingActions` /
    /// `leadingActions`, and injecting it via `Components`. That only works if
    /// `…ActionItems` — which lives in an extension — still dispatches
    /// dynamically to the override.
    func test_actionItems_dispatchToASubclassOverride() {
        let channel = makeChannel(type: "group", userRole: "owner")

        // The SDK default offers a Leave button for an owned group.
        XCTAssertEqual(Config.trailingActionItems(chatChannel: channel).map(\.action),
                       [.delete, .leave, .mute])

        // A subclass that drops Leave and puts Mute first must be honoured.
        XCTAssertEqual(TestSwipeActionsConfiguration.trailingActionItems(chatChannel: channel).map(\.action),
                       [.mute, .delete],
                       "trailingActionItems must dispatch to the subclass's trailingActions")
        XCTAssertEqual(TestSwipeActionsConfiguration.leadingActionItems(chatChannel: channel).map(\.action),
                       [],
                       "leadingActionItems must dispatch to the subclass's leadingActions")
    }

    /// An integrator that drops `.leave` must lose it for *every* channel shape,
    /// not just the one it happened to test — the SDK offers Leave on any
    /// non-direct channel, and to non-owners it is the only destructive action.
    func test_subclassDroppingLeave_neverOffersItForAnyChannelShape() {
        let shapes: [(String, ChatChannel)] = [
            ("direct", makeChannel(type: "direct")),
            ("group owner", makeChannel(type: "group", userRole: "owner")),
            ("group member", makeChannel(type: "group", userRole: "participant")),
            ("group no role", makeChannel(type: "group")),
            ("broadcast owner", makeChannel(type: "broadcast", userRole: "owner")),
            ("broadcast member", makeChannel(type: "broadcast", userRole: "subscriber"))
        ]
        for (label, channel) in shapes {
            let actions = TestSwipeActionsConfiguration.trailingActionItems(chatChannel: channel)
                .map(\.action)
            XCTAssertFalse(actions.contains(.leave), "\(label) should not offer Leave")
            XCTAssertEqual(actions, [channel.muted ? .unmute : .mute, .delete],
                           "\(label) should offer exactly Mute and Delete")
            // The SDK default, by contrast, does surface Leave off a direct chat.
            let sdkActions = Config.trailingActions(chatChannel: channel)
            XCTAssertEqual(sdkActions.contains(.leave), channel.channelType != .direct,
                           "\(label): the SDK default offers Leave on any non-direct channel")
        }
    }

    /// The same, through the `Components` metatype the cell actually calls.
    func test_actionItems_dispatchThroughTheComponentsRegistry() {
        let previous = Components.channelSwipeActionsConfiguration
        defer { Components.channelSwipeActionsConfiguration = previous }
        Components.channelSwipeActionsConfiguration = TestSwipeActionsConfiguration.self

        let channel = makeChannel(type: "group", userRole: "owner")
        let injected = Components.channelSwipeActionsConfiguration
        XCTAssertEqual(injected.trailingActionItems(chatChannel: channel).map(\.action),
                       [.mute, .delete],
                       "The cell resolves actions through Components, so injection must take effect")
    }

    // MARK: - Layout direction

    /// `swipeOffset` is leading-relative — negative always means "trailing
    /// actions showing" — and exactly one place turns it into physical pixels.
    /// These assert that the mirroring happens there, so RTL needs no sign flips
    /// anywhere else.
    func test_setSwipeOffset_translatesTowardTheTrailingEdge_leftToRight() {
        let cell = makeCell(layoutDirection: .forceLeftToRight)
        cell.setSwipeOffset(-100, animated: false)

        XCTAssertEqual(cell.swipeOffset, -100, accuracy: 0.001)
        XCTAssertEqual(cell.swipeContentView.transform.tx, -100, accuracy: 0.001,
                       "In LTR the trailing actions are revealed by moving content left")
        XCTAssertEqual(cell.trailingActionsView.transform.tx, -100, accuracy: 0.001,
                       "The actions must travel with the content, not lag behind it")
        XCTAssertEqual(cell.leadingActionsView.transform.tx, -100, accuracy: 0.001)
    }

    func test_setSwipeOffset_translatesTowardTheTrailingEdge_rightToLeft() {
        let cell = makeCell(layoutDirection: .forceRightToLeft)
        cell.setSwipeOffset(-100, animated: false)

        XCTAssertEqual(cell.swipeOffset, -100, accuracy: 0.001,
                       "The stored offset stays leading-relative regardless of direction")
        XCTAssertEqual(cell.swipeContentView.transform.tx, 100, accuracy: 0.001,
                       "In RTL the trailing edge is on the left, so the same leading-relative offset moves content right")
        XCTAssertEqual(cell.trailingActionsView.transform.tx, 100, accuracy: 0.001)
    }

    func test_setSwipeOffset_zero_resetsTheTransform() {
        let cell = makeCell(layoutDirection: .forceRightToLeft)
        cell.setSwipeOffset(-100, animated: false)
        cell.setSwipeOffset(0, animated: false)

        XCTAssertEqual(cell.swipeOffset, 0)
        XCTAssertEqual(cell.swipeContentView.transform, .identity)
        XCTAssertEqual(cell.leadingActionsView.transform, .identity)
        XCTAssertEqual(cell.trailingActionsView.transform, .identity)
    }

    /// An action set that shrinks — mute becoming unmute with a shorter title, or
    /// a role change dropping a button — must not leave the row open wider than
    /// its buttons.
    func test_clampSwipeOffsetToFullReveal_shrinksToTheNewRevealWidth() {
        let cell = makeCell(layoutDirection: .forceLeftToRight)
        cell.trailingActionsView.configure(items: [
            Config.ActionItem(action: .delete, appearance: Config.appearance(for: .delete)),
            Config.ActionItem(action: .mute, appearance: Config.appearance(for: .mute))
        ])
        cell.setSwipeOffset(-cell.trailingActionsView.fullRevealWidth, animated: false)
        let openedWidth = -cell.swipeOffset
        XCTAssertGreaterThan(openedWidth, 0)

        // Drop to a single action, then re-clamp.
        cell.trailingActionsView.configure(items: [
            Config.ActionItem(action: .delete, appearance: Config.appearance(for: .delete))
        ])
        cell.clampSwipeOffsetToFullReveal()

        XCTAssertEqual(-cell.swipeOffset, cell.trailingActionsView.fullRevealWidth, accuracy: 0.5,
                       "The offset must shrink to the new reveal width")
        XCTAssertLessThan(-cell.swipeOffset, openedWidth)
    }

    // MARK: - Helpers


    private func makeCell(layoutDirection: UISemanticContentAttribute) -> Cell {
        let cell = Cell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 72)
        cell.semanticContentAttribute = layoutDirection
        cell.swipeContentView.semanticContentAttribute = layoutDirection
        cell.layoutIfNeeded()
        return cell
    }


    private func image(size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in }
    }

    private func makeChannel(type: String = "group",
                             newMessageCount: UInt64 = 0,
                             unread: Bool = false,
                             muted: Bool = false,
                             pinnedAt: Date? = nil,
                             userRole: String? = nil) -> ChatChannel {
        ChatChannel(id: 42,
                    type: type,
                    newMessageCount: newMessageCount,
                    unread: unread,
                    muted: muted,
                    pinnedAt: pinnedAt,
                    uri: "swipe-actions-test",
                    userRole: userRole)
    }
}

/// Stands in for an integrator's own swipe configuration: no Leave action, mute
/// first, and no leading actions at all.
private final class TestSwipeActionsConfiguration: ChannelSwipeActionsConfiguration {
    override class func trailingActions(chatChannel: ChatChannel) -> [Actions] {
        [chatChannel.muted ? .unmute : .mute, .delete]
    }

    override class func leadingActions(chatChannel: ChatChannel) -> [Actions] {
        []
    }
}

/// Counts full-swipe threshold crossings instead of buzzing, so the latch can be
/// asserted without a Taptic Engine.
private final class CountingCell: ChannelListViewController.ChannelCell {
    var thresholdCrossings = 0

    override func fullSwipeThresholdDidCross() {
        thresholdCrossings += 1
    }
}
