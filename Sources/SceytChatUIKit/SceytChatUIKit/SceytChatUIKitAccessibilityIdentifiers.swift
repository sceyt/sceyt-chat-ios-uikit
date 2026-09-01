//
//  SceytChatUIKitAccessibilityIdentifiers.swift
//  SceytChatUIKit
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

extension SceytChatUIKit {

    /// A central, namespaced registry of `accessibilityIdentifier` values used by
    /// the UIKit views.
    ///
    /// Keeping the identifiers in one place means UI tests and the views that they
    /// drive share a single source of truth — a renamed identifier is a compile-time
    /// change in both places rather than a silently broken string match. The values
    /// double as real accessibility identifiers, so they also benefit assistive
    /// technologies.
    public enum AccessibilityIdentifiers {

        public enum ChannelList {
            public static let tableView = "sceyt_chat_channel_list_table_view"
            public static let newChannelButton = "sceyt_chat_channel_list_new_channel_button"
            public static let searchBar = "sceyt_chat_channel_list_search_bar"
            public static let emptyView = "sceyt_chat_channel_list_empty_view"

            public enum Cell {
                /// Base identifier shared by every channel cell.
                public static let root = "sceyt_chat_channel_list_cell"

                /// Per-row identifier so a specific channel can be addressed
                /// directly, e.g. `app.cells["sceyt_chat_channel_list_cell.42"]`.
                public static func identifier(for id: ChannelId) -> String {
                    "\(root).\(id)"
                }

                public static let avatar = "sceyt_chat_channel_list_cell_avatar"
                public static let subject = "sceyt_chat_channel_list_cell_subject"
                public static let message = "sceyt_chat_channel_list_cell_message"
                public static let date = "sceyt_chat_channel_list_cell_date"
                public static let unreadBadge = "sceyt_chat_channel_list_cell_unread_badge"
                public static let mentionBadge = "sceyt_chat_channel_list_cell_mention_badge"
                public static let muteIcon = "sceyt_chat_channel_list_cell_mute_icon"
                public static let pinIcon = "sceyt_chat_channel_list_cell_pin_icon"
                public static let ticks = "sceyt_chat_channel_list_cell_ticks"

                /// The container holding the leading (Read/Unread, Pin/Unpin)
                /// swipe action buttons.
                public static let swipeActionsLeading = "sceyt_chat_channel_list_cell_swipe_actions_leading"

                /// The container holding the trailing (Delete/Leave, Mute/Unmute)
                /// swipe action buttons.
                public static let swipeActionsTrailing = "sceyt_chat_channel_list_cell_swipe_actions_trailing"

                /// A single swipe action button, addressed by its
                /// locale-independent name, e.g.
                /// `sceyt_chat_channel_list_cell_swipe_action.delete`.
                public static func swipeAction(_ name: String) -> String {
                    "sceyt_chat_channel_list_cell_swipe_action.\(name)"
                }
            }
        }

        /// The message composer (input bar) on the open-channel screen.
        public enum MessageInput {
            /// The text view where a new message is composed.
            public static let inputField = "sceyt_chat_message_input_field"
            /// The button that sends the composed message. Hidden until the
            /// composer holds non-whitespace text.
            public static let sendButton = "sceyt_chat_message_input_send_button"
            /// The button that opens the attachment / media picker.
            public static let attachmentButton = "sceyt_chat_message_input_attachment_button"
            /// The button that opens the camera.
            public static let cameraButton = "sceyt_chat_message_input_camera_button"
            /// The voice-record button (long-press to record).
            public static let voiceButton = "sceyt_chat_message_input_voice_button"
            /// The toggle that marks the next attachment as view-once.
            public static let viewOnceButton = "sceyt_chat_message_input_view_once_button"
            /// The close button on the edit / reply / forward preview shown above
            /// the composer.
            public static let actionCancelButton = "sceyt_chat_message_input_action_cancel_button"
            /// The title of that preview — reads "Reply: <name>" or "Edit: ", so it is what
            /// distinguishes the two modes.
            public static let actionTitleLabel = "sceyt_chat_message_input_action_title_label"

            /// The full-screen voice-recording overlay (`VoiceRecorderView`)
            /// shown while the record button is held.
            public enum Recorder {
                /// The overlay itself.
                public static let root = "sceyt_chat_message_input_recorder"
                /// The lock / stop control above the mic.
                public static let lockButton = "sceyt_chat_message_input_recorder_lock_button"
                /// The mic / send / delete control at the record button's place.
                public static let micButton = "sceyt_chat_message_input_recorder_mic_button"
                /// The view-once toggle shown while locked.
                public static let viewOnceButton = "sceyt_chat_message_input_recorder_view_once_button"
                /// The elapsed-time label.
                public static let duration = "sceyt_chat_message_input_recorder_duration"
                /// The "slide to cancel" / cancel control.
                public static let cancelButton = "sceyt_chat_message_input_recorder_cancel_button"
            }
        }

        /// The open-channel (conversation) screen driven by `ChannelViewController`.
        public enum Channel {
            /// The (mirrored) collection view that renders the message list.
            public static let collectionView = "sceyt_chat_channel_collection_view"
            /// The channel name shown in the navigation-bar header.
            public static let titleLabel = "sceyt_chat_channel_title"
            /// The subtitle (member count / status) shown under the title.
            public static let subtitleLabel = "sceyt_chat_channel_subtitle"
            /// The channel avatar shown in the navigation-bar header.
            public static let avatar = "sceyt_chat_channel_avatar"
            /// The floating "scroll to bottom" button.
            public static let scrollDownButton = "sceyt_chat_channel_scroll_down_button"
            /// The floating "jump to unread mention" button.
            public static let unreadMentionButton = "sceyt_chat_channel_unread_mention_button"
            /// The "Join" button shown for a channel the user has not joined.
            public static let joinButton = "sceyt_chat_channel_join_button"
            /// The empty-state placeholder shown when the channel has no messages.
            public static let emptyView = "sceyt_chat_channel_empty_view"
            /// The in-conversation message search bar.
            public static let searchBar = "sceyt_chat_channel_search_bar"

            /// The in-conversation message-search navigation controls.
            public enum Search {
                /// Moves to the next search result.
                public static let nextButton = "sceyt_chat_channel_search_next_button"
                /// Moves to the previous search result.
                public static let previousButton = "sceyt_chat_channel_search_previous_button"
                /// The "N of M" result counter label.
                public static let resultLabel = "sceyt_chat_channel_search_result_label"
            }

            /// A single message row inside the conversation list.
            public enum Cell {
                /// Base identifier shared by every message cell.
                public static let root = "sceyt_chat_channel_message_cell"

                /// Per-row identifier so a specific message can be addressed
                /// directly, e.g. `app.cells["sceyt_chat_channel_message_cell.42"]`.
                public static func identifier(for id: MessageId) -> String {
                    "\(root).\(id)"
                }

                /// The label rendering the message body text.
                public static let body = "sceyt_chat_channel_message_cell_body"
                /// The timestamp label.
                public static let date = "sceyt_chat_channel_message_cell_date"
                /// The "New messages" separator shown on the last displayed message.
                public static let unreadSeparator = "sceyt_chat_channel_message_cell_unread_separator"
                /// The quoted reply preview; tapping it scrolls to the parent message.
                public static let replyView = "sceyt_chat_channel_message_cell_reply_view"
                /// The sender-name label (group chats).
                public static let senderName = "sceyt_chat_channel_message_cell_sender_name"
                /// The sender avatar (group chats).
                public static let avatar = "sceyt_chat_channel_message_cell_avatar"
                /// The attachments container (image/video/file/voice).
                public static let attachments = "sceyt_chat_channel_message_cell_attachments"
                /// The link-preview view.
                public static let linkPreview = "sceyt_chat_channel_message_cell_link_preview"
                /// The in-bubble poll view.
                public static let poll = "sceyt_chat_channel_message_cell_poll"
                /// A single option row inside the in-bubble poll view, suffixed
                /// with the option's zero-based index — e.g.
                /// `sceyt_chat_channel_message_cell_poll_option.0`. The row's
                /// `accessibilityValue` mirrors its checkbox: `voted` when the
                /// current user's vote sits on this option, `not_voted` otherwise.
                public static let pollOption = "sceyt_chat_channel_message_cell_poll_option"
                /// The reactions summary strip.
                public static let reactions = "sceyt_chat_channel_message_cell_reactions"
                /// The "forwarded from" header.
                public static let forward = "sceyt_chat_channel_message_cell_forward"
                /// The reply-count / thread button.
                public static let replyCount = "sceyt_chat_channel_message_cell_reply_count"
                /// The selection checkbox (multi-select mode).
                public static let checkbox = "sceyt_chat_channel_message_cell_checkbox"
            }
        }

        /// The "New chat" screen driven by `StartChatViewController`, where a
        /// direct chat is started by picking a user, or a group / channel is
        /// created via the action rows on top.
        public enum StartChat {
            /// The cancel bar-button that dismisses the screen.
            public static let cancelButton = "sceyt_chat_start_chat_cancel_button"
            /// The search bar used to filter the user list.
            public static let searchBar = "sceyt_chat_start_chat_search_bar"
            /// The table view listing the users a direct chat can be started with.
            public static let tableView = "sceyt_chat_start_chat_table_view"

            /// The "Create group" action row.
            public static let createGroupButton = "sceyt_chat_start_chat_create_group_button"
            /// The leading icon inside the "Create group" row.
            public static let createGroupIcon = "sceyt_chat_start_chat_create_group_icon"
            /// The title label inside the "Create group" row.
            public static let createGroupLabel = "sceyt_chat_start_chat_create_group_label"

            /// The "Create channel" action row.
            public static let createChannelButton = "sceyt_chat_start_chat_create_channel_button"
            /// The leading icon inside the "Create channel" row.
            public static let createChannelIcon = "sceyt_chat_start_chat_create_channel_icon"
            /// The title label inside the "Create channel" row.
            public static let createChannelLabel = "sceyt_chat_start_chat_create_channel_label"

            /// A single user row inside the list.
            public enum Cell {
                /// Base identifier shared by every user cell.
                public static let root = "sceyt_chat_start_chat_user_cell"

                /// Per-row identifier so a specific user can be addressed
                /// directly, e.g. `app.cells["sceyt_chat_start_chat_user_cell.42"]`.
                public static func identifier(for id: UserId) -> String {
                    "\(root).\(id)"
                }
            }
        }

        /// The channel-info (profile) screen driven by `ChannelInfoViewController`:
        /// the header (avatar / name / subtitle), the description and URI rows, the
        /// notification / members / admins / search option rows, and the
        /// shared-media browser tabs at the bottom.
        public enum ChannelInfo {
            /// The scrollable info table (header + option rows + media browser).
            public static let tableView = "sceyt_chat_channel_info_table_view"
            /// The nav-bar "more actions" button.
            public static let moreButton = "sceyt_chat_channel_info_more_button"

            /// The channel avatar in the header.
            public static let avatar = "sceyt_chat_channel_info_avatar"
            /// The channel name in the header.
            public static let title = "sceyt_chat_channel_info_title"
            /// The header subtitle (member count / presence).
            public static let subtitle = "sceyt_chat_channel_info_subtitle"
            /// The channel description text (or the peer's status for a direct chat).
            public static let description = "sceyt_chat_channel_info_description"
            /// The public-channel URI row.
            public static let uri = "sceyt_chat_channel_info_uri"

            /// An option / item row. The row root gets one of the tag-specific
            /// identifiers below; the labels inside every option row share the
            /// generic `title` / `detail` / `description` identifiers, resolved by
            /// scoping the query to the enclosing cell.
            public enum Option {
                /// The notifications (mute) row, which carries the mute switch.
                public static let notifications = "sceyt_chat_channel_info_option_notifications"
                /// The auto-delete-messages row.
                public static let autoDelete = "sceyt_chat_channel_info_option_auto_delete"
                /// The members / subscribers row.
                public static let members = "sceyt_chat_channel_info_option_members"
                /// The admins row.
                public static let admins = "sceyt_chat_channel_info_option_admins"
                /// The message-search row.
                public static let search = "sceyt_chat_channel_info_option_search"

                /// The row's leading title label.
                public static let title = "sceyt_chat_channel_info_option_title"
                /// The row's trailing detail label (e.g. "On" / "Off").
                public static let detail = "sceyt_chat_channel_info_option_detail"
                /// The row's secondary description label.
                public static let description = "sceyt_chat_channel_info_option_description"
            }

            /// The "Media" tab of the shared-content browser.
            public static let mediaList = "sceyt_chat_channel_info_media_list"
            /// The "Files" tab of the shared-content browser.
            public static let fileList = "sceyt_chat_channel_info_file_list"
            /// The "Voice" tab of the shared-content browser.
            public static let voiceList = "sceyt_chat_channel_info_voice_list"
            /// The "Links" tab of the shared-content browser.
            public static let linkList = "sceyt_chat_channel_info_link_list"
            /// The "Groups in common" tab of the shared-content browser.
            public static let groupList = "sceyt_chat_channel_info_group_list"

            /// A photo / video item in the "Media" tab. Every media cell shares
            /// the `root` identifier; scope label queries to a specific cell.
            public enum MediaCell {
                public static let root = "sceyt_chat_channel_info_media_cell"
                /// The thumbnail image.
                public static let image = "sceyt_chat_channel_info_media_cell_image"
                /// The video-duration badge (video items only).
                public static let duration = "sceyt_chat_channel_info_media_cell_duration"
                /// The download / pause control shown while transferring.
                public static let downloadButton = "sceyt_chat_channel_info_media_cell_download_button"
            }

            /// A row in the "Files" tab.
            public enum FileCell {
                public static let root = "sceyt_chat_channel_info_file_cell"
                /// The file-type icon.
                public static let icon = "sceyt_chat_channel_info_file_cell_icon"
                /// The file name.
                public static let name = "sceyt_chat_channel_info_file_cell_name"
                /// The size / date detail label.
                public static let detail = "sceyt_chat_channel_info_file_cell_detail"
                /// The download / pause control.
                public static let downloadButton = "sceyt_chat_channel_info_file_cell_download_button"
            }

            /// A row in the "Voice" tab.
            public enum VoiceCell {
                public static let root = "sceyt_chat_channel_info_voice_cell"
                /// The play / pause control.
                public static let playButton = "sceyt_chat_channel_info_voice_cell_play_button"
                /// The sender-name label.
                public static let title = "sceyt_chat_channel_info_voice_cell_title"
                /// The date label.
                public static let date = "sceyt_chat_channel_info_voice_cell_date"
                /// The duration label.
                public static let duration = "sceyt_chat_channel_info_voice_cell_duration"
                /// The download / pause control.
                public static let downloadButton = "sceyt_chat_channel_info_voice_cell_download_button"
            }

            /// A row in the "Links" tab.
            public enum LinkCell {
                public static let root = "sceyt_chat_channel_info_link_cell"
                /// The link preview icon.
                public static let icon = "sceyt_chat_channel_info_link_cell_icon"
                /// The link title.
                public static let title = "sceyt_chat_channel_info_link_cell_title"
                /// The URL label.
                public static let url = "sceyt_chat_channel_info_link_cell_url"
                /// The link description label.
                public static let detail = "sceyt_chat_channel_info_link_cell_detail"
            }

            /// A row in the "Groups in common" tab.
            public enum GroupCell {
                public static let root = "sceyt_chat_channel_info_group_cell"
                /// The group avatar.
                public static let avatar = "sceyt_chat_channel_info_group_cell_avatar"
                /// The group name.
                public static let title = "sceyt_chat_channel_info_group_cell_title"
                /// The member-count subtitle.
                public static let subtitle = "sceyt_chat_channel_info_group_cell_subtitle"
            }
        }

        /// The user-picker screen driven by `SelectUsersViewController` — used both
        /// as the "select members" step of private-channel creation and as the base
        /// of the "Add members" screen. Screen-specific bar buttons live in the
        /// subclass namespaces (e.g. `AddMembers`).
        public enum SelectUsers {
            /// The list of users that can be selected.
            public static let tableView = "sceyt_chat_select_users_table_view"
            /// The search bar used to filter the user list.
            public static let searchBar = "sceyt_chat_select_users_search_bar"
            /// The horizontal strip of already-selected users shown on top.
            public static let selectedList = "sceyt_chat_select_users_selected_list"
            /// The "Next" bar button (base flow — advances to channel creation).
            public static let nextButton = "sceyt_chat_select_users_next_button"

            /// A selectable user row in the list.
            public enum Cell {
                /// Base identifier shared by every user row.
                public static let root = "sceyt_chat_select_users_user_cell"

                /// Per-row identifier so a specific user can be addressed
                /// directly, e.g. `app.cells["sceyt_chat_select_users_user_cell.42"]`.
                public static func identifier(for id: UserId) -> String {
                    "\(root).\(id)"
                }

                /// The user avatar.
                public static let avatar = "sceyt_chat_select_users_user_cell_avatar"
                /// The user's display name.
                public static let name = "sceyt_chat_select_users_user_cell_name"
                /// The presence / status label.
                public static let status = "sceyt_chat_select_users_user_cell_status"
                /// The selection checkbox.
                public static let checkbox = "sceyt_chat_select_users_user_cell_checkbox"
            }

            /// A selected-user chip in the top strip.
            public enum SelectedCell {
                /// Base identifier shared by every chip.
                public static let root = "sceyt_chat_select_users_selected_cell"

                /// Per-chip identifier keyed by user id.
                public static func identifier(for id: UserId) -> String {
                    "\(root).\(id)"
                }

                /// The chip avatar.
                public static let avatar = "sceyt_chat_select_users_selected_cell_avatar"
                /// The chip name label.
                public static let name = "sceyt_chat_select_users_selected_cell_name"
                /// The "remove" (✕) button.
                public static let removeButton = "sceyt_chat_select_users_selected_cell_remove_button"
            }
        }

        /// The "Add members" screen driven by `AddMembersViewController`. Inherits
        /// the user-picker elements from `SelectUsers`; these are its own bar
        /// buttons.
        public enum AddMembers {
            /// The cancel bar button that dismisses the screen.
            public static let cancelButton = "sceyt_chat_add_members_cancel_button"
            /// The done bar button that adds the selected members.
            public static let doneButton = "sceyt_chat_add_members_done_button"
        }

        /// The channel members / admins list driven by
        /// `ChannelMemberListViewController`.
        public enum ChannelMembers {
            /// The members list.
            public static let tableView = "sceyt_chat_channel_members_table_view"

            /// The "Add members" action row shown on top of the list.
            public static let addMemberButton = "sceyt_chat_channel_members_add_member_button"
            /// The "Invite via link" action row shown on top of the list.
            public static let inviteLinkButton = "sceyt_chat_channel_members_invite_link_button"
            /// The icon inside an action row.
            public static let actionIcon = "sceyt_chat_channel_members_action_icon"
            /// The title inside an action row.
            public static let actionTitle = "sceyt_chat_channel_members_action_title"

            /// A single member row.
            public enum MemberCell {
                /// Base identifier shared by every member row.
                public static let root = "sceyt_chat_channel_members_member_cell"

                /// Per-row identifier so a specific member can be addressed
                /// directly, e.g. `app.cells["sceyt_chat_channel_members_member_cell.42"]`.
                public static func identifier(for id: UserId) -> String {
                    "\(root).\(id)"
                }

                /// The member avatar.
                public static let avatar = "sceyt_chat_channel_members_member_cell_avatar"
                /// The member's display name.
                public static let name = "sceyt_chat_channel_members_member_cell_name"
                /// The presence / status label.
                public static let status = "sceyt_chat_channel_members_member_cell_status"
                /// The role badge (e.g. "Owner" / "Admin").
                public static let role = "sceyt_chat_channel_members_member_cell_role"
            }
        }

        /// The shared channel details form (avatar / name / about / uri) used by
        /// both the create-group and create-channel screens.
        public enum ChannelForm {
            /// The avatar picker button.
            public static let avatar = "sceyt_chat_channel_form_avatar"
            /// The channel / group name field.
            public static let name = "sceyt_chat_channel_form_name"
            /// The about / description field.
            public static let about = "sceyt_chat_channel_form_about"
            /// The public URI field (public channel only).
            public static let uri = "sceyt_chat_channel_form_uri"
            /// The URI validation error / success label (public channel only).
            public static let uriError = "sceyt_chat_channel_form_uri_error"
        }

        /// The "New channel" (public) screen driven by `CreateChannelViewController`.
        public enum CreateChannel {
            /// The create bar button.
            public static let createButton = "sceyt_chat_create_channel_create_button"
        }

        /// The "New group" (private) screen driven by `CreateGroupViewController`.
        public enum CreateGroup {
            /// The create bar button.
            public static let createButton = "sceyt_chat_create_group_create_button"
            /// The member list.
            public static let tableView = "sceyt_chat_create_group_table_view"

            /// A user row in the member list.
            public enum Cell {
                public static let root = "sceyt_chat_create_group_user_cell"
                public static func identifier(for id: UserId) -> String {
                    "\(root).\(id)"
                }
            }
        }

        /// The "Edit channel" screen driven by `EditChannelViewController`.
        public enum EditChannel {
            /// The edit form table.
            public static let tableView = "sceyt_chat_edit_channel_table_view"
            /// The done bar button.
            public static let doneButton = "sceyt_chat_edit_channel_done_button"
            /// The avatar picker button.
            public static let avatar = "sceyt_chat_edit_channel_avatar"
            /// The name field.
            public static let name = "sceyt_chat_edit_channel_name"
            /// The about / description field.
            public static let about = "sceyt_chat_edit_channel_about"
            /// The public URI field.
            public static let uri = "sceyt_chat_edit_channel_uri"
        }

        /// The channel invite-link screen driven by `ChannelInviteLinkViewController`.
        public enum ChannelInviteLink {
            /// The options table.
            public static let tableView = "sceyt_chat_channel_invite_link_table_view"
            /// The label showing the invite link.
            public static let linkLabel = "sceyt_chat_channel_invite_link_link_label"
            /// The copy-link button.
            public static let copyButton = "sceyt_chat_channel_invite_link_copy_button"
            /// The "show previous messages" toggle.
            public static let showMessagesSwitch = "sceyt_chat_channel_invite_link_show_messages_switch"
            /// The share action row.
            public static let shareButton = "sceyt_chat_channel_invite_link_share_button"
            /// The reset-link action row (private channels).
            public static let resetButton = "sceyt_chat_channel_invite_link_reset_button"
            /// The open-QR-code action row.
            public static let qrButton = "sceyt_chat_channel_invite_link_qr_button"
            /// The title label inside an action row.
            public static let actionTitle = "sceyt_chat_channel_invite_link_action_title"
        }

        /// The channel QR-code screen driven by `QRCodeViewController`.
        public enum QRCode {
            /// The generated QR-code image.
            public static let image = "sceyt_chat_qr_code_image"
            /// The invite-link label under the code.
            public static let link = "sceyt_chat_qr_code_link"
            /// The share button.
            public static let shareButton = "sceyt_chat_qr_code_share_button"
            /// The close button.
            public static let closeButton = "sceyt_chat_qr_code_close_button"
        }

        /// The "Forward to…" screen driven by `ForwardViewController`.
        public enum Forward {
            /// The channel list.
            public static let tableView = "sceyt_chat_forward_table_view"
            /// The strip of already-selected channels.
            public static let selectedList = "sceyt_chat_forward_selected_list"
            /// The cancel bar button.
            public static let cancelButton = "sceyt_chat_forward_cancel_button"
            /// The forward (confirm) bar button.
            public static let forwardButton = "sceyt_chat_forward_forward_button"
        }

        /// A selectable channel row (used by Forward and selectable search results).
        public enum SelectableChannelCell {
            public static let root = "sceyt_chat_selectable_channel_cell"
            public static func identifier(for id: ChannelId) -> String {
                "\(root).\(id)"
            }
            /// The channel avatar.
            public static let avatar = "sceyt_chat_selectable_channel_cell_avatar"
            /// The channel name.
            public static let name = "sceyt_chat_selectable_channel_cell_name"
            /// The selection checkbox.
            public static let checkbox = "sceyt_chat_selectable_channel_cell_checkbox"
        }

        /// The channel search-results list (base of the search result screens).
        public enum SearchResults {
            /// The results table.
            public static let tableView = "sceyt_chat_search_results_table_view"
            /// The empty-state placeholder.
            public static let emptyView = "sceyt_chat_search_results_empty_view"

            /// A (non-selectable) channel result row.
            public enum Cell {
                public static let root = "sceyt_chat_search_result_channel_cell"
                public static func identifier(for id: ChannelId) -> String {
                    "\(root).\(id)"
                }
                /// The channel avatar.
                public static let avatar = "sceyt_chat_search_result_channel_cell_avatar"
                /// The channel name.
                public static let name = "sceyt_chat_search_result_channel_cell_name"
            }
        }

        /// The global search screen driven by `GlobalSearchResultsViewController`.
        public enum GlobalSearch {
            /// The category tab bar (Chats / Channels / Media / …).
            public static let categoryTabBar = "sceyt_chat_global_search_category_tab_bar"
            /// The floating user-filter bar.
            public static let userBar = "sceyt_chat_global_search_user_bar"
            /// The results table shared by the Chats and Channels tabs.
            public static let pageTable = "sceyt_chat_global_search_page_table"
        }

        /// The @mention autocomplete list shown above the composer
        /// (`MessageInputViewController.MentionUsersListViewController`).
        public enum MentionList {
            /// The member suggestions table.
            public static let tableView = "sceyt_chat_mention_list_table_view"
        }

        /// The message delivery/read info screen driven by `MessageInfoViewController`.
        public enum MessageInfo {
            /// The info table.
            public static let tableView = "sceyt_chat_message_info_table_view"
            /// The cancel bar button.
            public static let cancelButton = "sceyt_chat_message_info_cancel_button"
            /// A read/delivered marker row (one per user).
            public static let markerCell = "sceyt_chat_message_info_marker_cell"
        }

        /// The poll-results screen driven by `PollResultsViewController`.
        public enum PollResults {
            /// The results table.
            public static let tableView = "sceyt_chat_poll_results_table_view"
            /// The close button.
            public static let closeButton = "sceyt_chat_poll_results_close_button"
            /// The poll-question row.
            public static let questionCell = "sceyt_chat_poll_results_question_cell"
            /// An answer / option row.
            public static let answerCell = "sceyt_chat_poll_results_answer_cell"
            /// A voter row.
            public static let voterCell = "sceyt_chat_poll_results_voter_cell"
            /// The "show more voters" row.
            public static let showMoreCell = "sceyt_chat_poll_results_show_more_cell"
        }

        /// The single-option voter list driven by `PollOptionDetailViewController`.
        public enum PollOptionDetail {
            /// The voters table.
            public static let tableView = "sceyt_chat_poll_option_detail_table_view"
            /// The vote-count summary row.
            public static let voteCountCell = "sceyt_chat_poll_option_detail_vote_count_cell"
            /// A voter row.
            public static let voterCell = "sceyt_chat_poll_option_detail_voter_cell"
        }

        /// The poll composer driven by `CreatePollViewController`.
        public enum CreatePoll {
            /// The form table.
            public static let tableView = "sceyt_chat_create_poll_table_view"
            /// The cancel bar button.
            public static let cancelButton = "sceyt_chat_create_poll_cancel_button"
            /// The create bar button.
            public static let createButton = "sceyt_chat_create_poll_create_button"
            /// The poll-question field.
            public static let questionField = "sceyt_chat_create_poll_question_field"
            /// An answer-option row.
            public static let optionCell = "sceyt_chat_create_poll_option_cell"
            /// The text field inside an answer-option row.
            public static let optionField = "sceyt_chat_create_poll_option_field"
            /// The "add option" row.
            public static let addOptionButton = "sceyt_chat_create_poll_add_option_button"
            /// The "anonymous poll" toggle.
            public static let anonymousSwitch = "sceyt_chat_create_poll_anonymous_switch"
            /// The "allow multiple answers" toggle.
            public static let multipleAnswersSwitch = "sceyt_chat_create_poll_multiple_answers_switch"
        }

        /// The photo/video attachment picker driven by `MediaPickerViewController`.
        public enum MediaPicker {
            /// The photo grid.
            public static let collectionView = "sceyt_chat_media_picker_collection_view"
            /// The attach (confirm) button in the footer.
            public static let attachButton = "sceyt_chat_media_picker_attach_button"
            /// The cancel bar button.
            public static let cancelButton = "sceyt_chat_media_picker_cancel_button"
        }

        /// The full-screen media viewer (`MediaPreviewerViewController` in a
        /// `MediaPreviewerCarouselViewController`).
        public enum MediaPreviewer {
            /// The zoomable image.
            public static let image = "sceyt_chat_media_previewer_image"
            /// The video play/pause button.
            public static let playButton = "sceyt_chat_media_previewer_play_button"
            /// The video scrubber.
            public static let slider = "sceyt_chat_media_previewer_slider"
            /// The header title (sender name).
            public static let title = "sceyt_chat_media_previewer_title"
            /// The header subtitle (date).
            public static let subtitle = "sceyt_chat_media_previewer_subtitle"
            /// The back bar button.
            public static let backButton = "sceyt_chat_media_previewer_back_button"
            /// The share bar button.
            public static let shareButton = "sceyt_chat_media_previewer_share_button"
            /// The view-once info bar button.
            public static let viewOnceButton = "sceyt_chat_media_previewer_view_once_button"
        }

        /// The channel-avatar full-screen preview (`ImagePreviewViewController`).
        public enum ImagePreview {
            /// The zoomable image.
            public static let image = "sceyt_chat_image_preview_image"
        }

        /// The avatar cropper driven by `ImageCropperViewController`.
        public enum ImageCropper {
            /// The image being cropped.
            public static let image = "sceyt_chat_image_cropper_image"
            /// The confirm button.
            public static let confirmButton = "sceyt_chat_image_cropper_confirm_button"
            /// The cancel button.
            public static let cancelButton = "sceyt_chat_image_cropper_cancel_button"
        }

        /// The "Join channel" preview driven by `JoinGroupViewController`.
        public enum JoinGroup {
            /// The channel avatar.
            public static let avatar = "sceyt_chat_join_group_avatar"
            /// The channel name.
            public static let name = "sceyt_chat_join_group_name"
            /// The channel description.
            public static let description = "sceyt_chat_join_group_description"
            /// The join button.
            public static let joinButton = "sceyt_chat_join_group_join_button"
            /// The close button.
            public static let closeButton = "sceyt_chat_join_group_close_button"
        }

        /// The view-once info sheet driven by `ViewOnceInfoViewController`.
        public enum ViewOnceInfo {
            /// The title label.
            public static let title = "sceyt_chat_view_once_info_title"
            /// The OK button.
            public static let okButton = "sceyt_chat_view_once_info_ok_button"
            /// The close button.
            public static let closeButton = "sceyt_chat_view_once_info_close_button"
        }

        /// The emoji reaction picker driven by `ReactionPickerViewController`.
        public enum ReactionPicker {
            /// The rounded container holding the emoji row.
            public static let container = "sceyt_chat_reaction_picker"
            /// The "more emojis" (+) control.
            public static let moreButton = "sceyt_chat_reaction_picker_more_button"
            /// Per-emoji identifier, e.g. `…_emoji.👍`.
            public static func emoji(_ emoji: String) -> String {
                "sceyt_chat_reaction_picker_emoji.\(emoji)"
            }
        }

        /// The generic bottom/floating sheet container (`SheetViewController`).
        public enum Sheet {
            /// The dimmed background; tapping it dismisses the sheet.
            public static let background = "sceyt_chat_sheet_background"
            /// The sheet title label.
            public static let title = "sceyt_chat_sheet_title"
            /// The done button (shown when the sheet has a done action).
            public static let doneButton = "sceyt_chat_sheet_done_button"
            /// An action row inside a `BottomSheet`. Shared by every non-cancel
            /// action; disambiguate by label or position within the sheet.
            public static let actionButton = "sceyt_chat_sheet_action_button"
            /// The cancel row inside a `BottomSheet`.
            public static let cancelButton = "sceyt_chat_sheet_cancel_button"
        }
    }
}
