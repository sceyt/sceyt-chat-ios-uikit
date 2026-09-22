//
//  ChannelListScreen.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import XCTest

/// Page object for the channel list. Keeps element lookups (and the
/// accessibility-identifier strings) in one place so the tests read clearly and
/// an identifier change touches a single file.
struct ChannelListScreen {

    let app: XCUIApplication

    /// Mirror of `SceytChatUIKit.AccessibilityIdentifiers.ChannelList`.
    ///
    /// Mirrored (rather than imported) so the UI-test bundle stays free of the
    /// SDK link dependency. Keep in sync with
    /// `SceytChatUIKitAccessibilityIdentifiers.swift`.
    enum AID {
        static let tableView = "sceyt_chat_channel_list_table_view"
        static let newChannelButton = "sceyt_chat_channel_list_new_channel_button"
        static let searchBar = "sceyt_chat_channel_list_search_bar"
        static let emptyView = "sceyt_chat_channel_list_empty_view"

        static let cellRoot = "sceyt_chat_channel_list_cell"
        static func cell(_ id: UInt64) -> String { "\(cellRoot).\(id)" }

        static let subject = "sceyt_chat_channel_list_cell_subject"
        static let message = "sceyt_chat_channel_list_cell_message"
        static let date = "sceyt_chat_channel_list_cell_date"
        static let unreadBadge = "sceyt_chat_channel_list_cell_unread_badge"
        static let mentionBadge = "sceyt_chat_channel_list_cell_mention_badge"
        static let muteIcon = "sceyt_chat_channel_list_cell_mute_icon"
        static let pinIcon = "sceyt_chat_channel_list_cell_pin_icon"
        static let ticks = "sceyt_chat_channel_list_cell_ticks"

        static let swipeActionsLeading = "sceyt_chat_channel_list_cell_swipe_actions_leading"
        static let swipeActionsTrailing = "sceyt_chat_channel_list_cell_swipe_actions_trailing"
        /// Locale-independent action names, mirroring
        /// `ChannelSwipeActionsConfiguration.Actions.identifierName`.
        static func swipeAction(_ name: String) -> String {
            "sceyt_chat_channel_list_cell_swipe_action.\(name)"
        }

        // Test-only message injector buttons (see UITestSupport, --uitest-inject).
        static let injectShort = "uitest.injectShort"
        static let injectLong = "uitest.injectLong"
        static let markUnread = "uitest.markUnread"
        static let forceReload = "uitest.forceReload"
    }

    /// Mirror of the texts injected by `UITestSupport` so assertions can match them.
    enum InjectedText {
        static let short = "Quick hello"
        static let long = "This is a deliberately long preview message that should wrap across two lines in the channel list to verify the two-line layout."
    }

    // MARK: - Top-level elements

    var table: XCUIElement { app.tables[AID.tableView] }
    var newChannelButton: XCUIElement { app.buttons[AID.newChannelButton] }
    var searchField: XCUIElement { app.searchFields.firstMatch }
    var injectShortButton: XCUIElement { app.buttons[AID.injectShort] }
    var injectLongButton: XCUIElement { app.buttons[AID.injectLong] }
    var markUnreadButton: XCUIElement { app.buttons[AID.markUnread] }
    var forceReloadButton: XCUIElement { app.buttons[AID.forceReload] }

    /// All visible channel cells, in display order.
    var visibleCells: [XCUIElement] {
        app.cells.allElementsBoundByIndex.filter {
            $0.identifier.hasPrefix(AID.cellRoot)
        }
    }

    func cell(_ id: UInt64) -> XCUIElement { app.cells[AID.cell(id)] }

    // MARK: - Within a cell

    func subject(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.subject] }
    func message(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.message] }
    func date(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.date] }
    func unreadBadge(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.unreadBadge] }
    func mentionBadge(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.mentionBadge] }

    /// Status icons are image views, so resolve them across any element type to
    /// avoid depending on XCUITest's element-type classification.
    func muteIcon(in cell: XCUIElement) -> XCUIElement { cell.anyDescendant(AID.muteIcon) }
    func pinIcon(in cell: XCUIElement) -> XCUIElement { cell.anyDescendant(AID.pinIcon) }
    func ticks(in cell: XCUIElement) -> XCUIElement { cell.anyDescendant(AID.ticks) }

    // MARK: - Swipe actions

    /// A swipe action button inside a specific row, e.g. `swipeAction("delete", in: cell(1))`.
    func swipeAction(_ name: String, in cell: XCUIElement) -> XCUIElement {
        cell.anyDescendant(AID.swipeAction(name))
    }

    /// A swipe action button anywhere on screen. Only one row can be open at a
    /// time, so this is unambiguous.
    func swipeAction(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: AID.swipeAction(name)).firstMatch
    }

    // MARK: - Waiting

    @discardableResult
    func waitUntilLoaded(timeout: TimeInterval = 15) -> Bool {
        table.waitForExistence(timeout: timeout)
    }
}

extension XCUIElement {
    /// First descendant (of any type) matching `identifier`.
    func anyDescendant(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
