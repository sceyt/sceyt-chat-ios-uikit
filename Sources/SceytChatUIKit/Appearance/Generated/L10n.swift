// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Alert {
    internal enum Ask {
      /// Are you sure you want to delete this chat?
      /// This cannot be undone.
      internal static let delete = L10n.tr("Localizable", "alert.ask.delete", fallback: "Are you sure you want to delete this chat?\nThis cannot be undone.")
    }
    internal enum Button {
      /// Cancel
      internal static let cancel = L10n.tr("Localizable", "alert.button.cancel", fallback: "Cancel")
      /// Delete
      internal static let delete = L10n.tr("Localizable", "alert.button.delete", fallback: "Delete")
      /// Discard
      internal static let discard = L10n.tr("Localizable", "alert.button.discard", fallback: "Discard")
      /// Ok
      internal static let ok = L10n.tr("Localizable", "alert.button.ok", fallback: "Ok")
      /// Camera
      internal static let openCamera = L10n.tr("Localizable", "alert.button.open-camera", fallback: "Camera")
      /// File
      internal static let openFiles = L10n.tr("Localizable", "alert.button.open-files", fallback: "File")
      /// Gallery
      internal static let openGallery = L10n.tr("Localizable", "alert.button.open-gallery", fallback: "Gallery")
    }
    internal enum Error {
      /// Error
      internal static let title = L10n.tr("Localizable", "alert.error.title", fallback: "Error")
    }
  }
  internal enum Attachment {
    /// File
    internal static let file = L10n.tr("Localizable", "attachment.file", fallback: "File")
    /// Photo
    internal static let image = L10n.tr("Localizable", "attachment.image", fallback: "Photo")
    /// Video
    internal static let video = L10n.tr("Localizable", "attachment.video", fallback: "Video")
    /// Voice
    internal static let voice = L10n.tr("Localizable", "attachment.voice", fallback: "Voice")
  }
  internal enum Capture {
    /// Select Photo
    internal static let selectPhoto = L10n.tr("Localizable", "capture.selectPhoto", fallback: "Select Photo")
    /// Camera
    internal static let takePhoto = L10n.tr("Localizable", "capture.takePhoto", fallback: "Camera")
  }
  internal enum Channel {
    /// Join
    internal static let join = L10n.tr("Localizable", "channel.join", fallback: "Join")
    internal enum Add {
      internal enum Admins {
        /// Add Admins
        internal static let title = L10n.tr("Localizable", "channel.add.admins.title", fallback: "Add Admins")
      }
      internal enum Members {
        /// Add Members
        internal static let title = L10n.tr("Localizable", "channel.add.members.title", fallback: "Add Members")
      }
      internal enum Subscribers {
        /// Add Subscribers
        internal static let title = L10n.tr("Localizable", "channel.add.subscribers.title", fallback: "Add Subscribers")
      }
    }
    internal enum Avatar {
      /// Name the chat and upload a photo if you want
      internal static let comment = L10n.tr("Localizable", "channel.avatar.comment", fallback: "Name the chat and upload a photo if you want")
    }
    internal enum BlockedUser {
      /// You blocked this user.
      internal static let message = L10n.tr("Localizable", "channel.blockedUser.message", fallback: "You blocked this user.")
    }
    internal enum Create {
      /// Give a URL to your channel so you can share it with others inviting them to join.
      /// 
      /// Choose a name from the allowed range: a-z, 0-9, and _(underscores) between %d-%d characters.
      internal static func comment(_ p1: Int, _ p2: Int) -> String {
        return L10n.tr("Localizable", "channel.create.comment", p1, p2, fallback: "Give a URL to your channel so you can share it with others inviting them to join.\n\nChoose a name from the allowed range: a-z, 0-9, and _(underscores) between %d-%d characters.")
      }
      internal enum Uri {
        /// chn12
        internal static let placeholder = L10n.tr("Localizable", "channel.create.uri.placeholder", fallback: "chn12")
        internal enum Error {
          /// The URL already exists. Please provide another one.
          internal static let exist = L10n.tr("Localizable", "channel.create.uri.error.exist", fallback: "The URL already exists. Please provide another one.")
          /// The name should be %d-%d characters long.
          internal static func range(_ p1: Int, _ p2: Int) -> String {
            return L10n.tr("Localizable", "channel.create.uri.error.range", p1, p2, fallback: "The name should be %d-%d characters long.")
          }
          /// The name is invalid. Please provide a name from the allowed range of characters.
          internal static let regex = L10n.tr("Localizable", "channel.create.uri.error.regex", fallback: "The name is invalid. Please provide a name from the allowed range of characters.")
          /// Success! This URL is free to use.
          internal static let success = L10n.tr("Localizable", "channel.create.uri.error.success", fallback: "Success! This URL is free to use.")
        }
      }
    }
    internal enum Created {
      /// Add subscribers so they can join
      /// the channel.
      internal static let message = L10n.tr("Localizable", "channel.created.message", fallback: "Add subscribers so they can join\nthe channel.")
      /// You created a channel
      internal static let title = L10n.tr("Localizable", "channel.created.title", fallback: "You created a channel")
    }
    internal enum DeletedUser {
      /// This user has been deleted.
      internal static let message = L10n.tr("Localizable", "channel.deletedUser.message", fallback: "This user has been deleted.")
    }
    internal enum Empty {
      /// Create channel
      internal static let createNew = L10n.tr("Localizable", "channel.empty.create-new", fallback: "Create channel")
      /// You have no channels created yet, create one and send messages
      internal static let description = L10n.tr("Localizable", "channel.empty.description", fallback: "You have no channels created yet, create one and send messages")
      /// No Channels
      internal static let title = L10n.tr("Localizable", "channel.empty.title", fallback: "No Channels")
    }
    internal enum Forward {
      /// Channels
      internal static let channels = L10n.tr("Localizable", "channel.forward.channels", fallback: "Channels")
      /// Chats & Groups
      internal static let chatsGroups = L10n.tr("Localizable", "channel.forward.chatsGroups", fallback: "Chats & Groups")
      /// Select Chat
      internal static let title = L10n.tr("Localizable", "channel.forward.title", fallback: "Select Chat")
    }
    internal enum Intro {
      /// New Channel
      internal static let title = L10n.tr("Localizable", "channel.intro.title", fallback: "New Channel")
    }
    internal enum List {
      /// Search for channels
      internal static let search = L10n.tr("Localizable", "channel.list.search", fallback: "Search for channels")
      /// Chats
      internal static let title = L10n.tr("Localizable", "channel.list.title", fallback: "Chats")
      internal enum Action {
        /// Delete
        internal static let delete = L10n.tr("Localizable", "channel.list.action.delete", fallback: "Delete")
        /// Leave
        internal static let leave = L10n.tr("Localizable", "channel.list.action.leave", fallback: "Leave")
        /// Mute
        internal static let mute = L10n.tr("Localizable", "channel.list.action.mute", fallback: "Mute")
        /// Pin
        internal static let pin = L10n.tr("Localizable", "channel.list.action.pin", fallback: "Pin")
        /// Read
        internal static let read = L10n.tr("Localizable", "channel.list.action.read", fallback: "Read")
        /// Unmute
        internal static let unmute = L10n.tr("Localizable", "channel.list.action.unmute", fallback: "Unmute")
        /// Unpin
        internal static let unpin = L10n.tr("Localizable", "channel.list.action.unpin", fallback: "Unpin")
        /// Unread
        internal static let unread = L10n.tr("Localizable", "channel.list.action.unread", fallback: "Unread")
      }
    }
    internal enum Member {
      /// Deleted User
      internal static let deleted = L10n.tr("Localizable", "channel.member.deleted", fallback: "Deleted User")
      /// Inactive User
      internal static let inactive = L10n.tr("Localizable", "channel.member.inactive", fallback: "Inactive User")
      /// typing
      internal static let typing = L10n.tr("Localizable", "channel.member.typing", fallback: "typing")
      internal enum Role {
        /// Change Role
        internal static let title = L10n.tr("Localizable", "channel.member.role.title", fallback: "Change Role")
      }
    }
    internal enum MembersCount {
      /// %d members
      internal static func more(_ p1: Int) -> String {
        return L10n.tr("Localizable", "channel.members-count.more", p1, fallback: "%d members")
      }
      /// 1 member
      internal static let one = L10n.tr("Localizable", "channel.members-count.one", fallback: "1 member")
    }
    internal enum Message {
      /// Attachment
      internal static let attachment = L10n.tr("Localizable", "channel.message.attachment", fallback: "Attachment")
      /// Draft
      internal static let draft = L10n.tr("Localizable", "channel.message.draft", fallback: "Draft")
      /// Reacted %@ to:
      internal static func lastReaction(_ p1: Any) -> String {
        return L10n.tr("Localizable", "channel.message.lastReaction", String(describing: p1), fallback: "Reacted %@ to:")
      }
    }
    internal enum New {
      /// New Group
      internal static let createPrivate = L10n.tr("Localizable", "channel.new.createPrivate", fallback: "New Group")
      /// New Channel
      internal static let createPublic = L10n.tr("Localizable", "channel.new.createPublic", fallback: "New Channel")
      /// Start Chat
      internal static let title = L10n.tr("Localizable", "channel.new.title", fallback: "Start Chat")
      /// Users
      internal static let userSectionTitle = L10n.tr("Localizable", "channel.new.userSectionTitle", fallback: "Users")
    }
    internal enum NoMessages {
      /// No messages yet, start the chat
      internal static let message = L10n.tr("Localizable", "channel.noMessages.message", fallback: "No messages yet, start the chat")
      /// No Messages yet
      internal static let title = L10n.tr("Localizable", "channel.noMessages.title", fallback: "No Messages yet")
    }
    internal enum Private {
      /// Members
      internal static let sectionTitle = L10n.tr("Localizable", "channel.private.sectionTitle", fallback: "Members")
    }
    internal enum Profile {
      /// About
      internal static let about = L10n.tr("Localizable", "channel.profile.about", fallback: "About")
      /// Notifications
      internal static let notifications = L10n.tr("Localizable", "channel.profile.notifications", fallback: "Notifications")
      /// Subject
      internal static let subject = L10n.tr("Localizable", "channel.profile.subject", fallback: "Subject")
      /// Info
      internal static let title = L10n.tr("Localizable", "channel.profile.title", fallback: "Info")
      internal enum Action {
        /// Block User
        internal static let block = L10n.tr("Localizable", "channel.profile.action.block", fallback: "Block User")
        /// Block & Kick Member
        internal static let blockAndKickMember = L10n.tr("Localizable", "channel.profile.action.block-and-kick-member", fallback: "Block & Kick Member")
        /// Change member’s role
        internal static let changeRole = L10n.tr("Localizable", "channel.profile.action.change-role", fallback: "Change member’s role")
        /// Clear History
        internal static let clearHistory = L10n.tr("Localizable", "channel.profile.action.clear-history", fallback: "Clear History")
        /// join
        internal static let join = L10n.tr("Localizable", "channel.profile.action.join", fallback: "join")
        /// more
        internal static let more = L10n.tr("Localizable", "channel.profile.action.more", fallback: "more")
        /// mute
        internal static let mute = L10n.tr("Localizable", "channel.profile.action.mute", fallback: "mute")
        /// Remove
        internal static let remove = L10n.tr("Localizable", "channel.profile.action.remove", fallback: "Remove")
        /// report
        internal static let report = L10n.tr("Localizable", "channel.profile.action.report", fallback: "report")
        /// Set Owner
        internal static let setOwner = L10n.tr("Localizable", "channel.profile.action.set-owner", fallback: "Set Owner")
        /// Unblock User
        internal static let unblock = L10n.tr("Localizable", "channel.profile.action.unblock", fallback: "Unblock User")
        /// unmute
        internal static let unmute = L10n.tr("Localizable", "channel.profile.action.unmute", fallback: "unmute")
        internal enum Channel {
          /// Block and Leave Channel
          internal static let blockAndLeave = L10n.tr("Localizable", "channel.profile.action.channel.block-and-leave", fallback: "Block and Leave Channel")
          /// Delete Channel
          internal static let delete = L10n.tr("Localizable", "channel.profile.action.channel.delete", fallback: "Delete Channel")
          /// Once you delete this channel it will be permanently removed along with its entire history for all the channel subscribers.
          internal static let deleteMessage = L10n.tr("Localizable", "channel.profile.action.channel.deleteMessage", fallback: "Once you delete this channel it will be permanently removed along with its entire history for all the channel subscribers.")
          /// Edit Channel
          internal static let edit = L10n.tr("Localizable", "channel.profile.action.channel.edit", fallback: "Edit Channel")
          /// Leave Channel
          internal static let leave = L10n.tr("Localizable", "channel.profile.action.channel.leave", fallback: "Leave Channel")
          /// Pin Channel
          internal static let pin = L10n.tr("Localizable", "channel.profile.action.channel.pin", fallback: "Pin Channel")
          /// Unpin Channel
          internal static let unpin = L10n.tr("Localizable", "channel.profile.action.channel.unpin", fallback: "Unpin Channel")
        }
        internal enum Chat {
          /// Delete Chat
          internal static let delete = L10n.tr("Localizable", "channel.profile.action.chat.delete", fallback: "Delete Chat")
          /// Once you delete this chat it will be removed from the chat list with its message history.
          internal static let deleteMessage = L10n.tr("Localizable", "channel.profile.action.chat.deleteMessage", fallback: "Once you delete this chat it will be removed from the chat list with its message history.")
          /// Pin Chat
          internal static let pin = L10n.tr("Localizable", "channel.profile.action.chat.pin", fallback: "Pin Chat")
          /// Unpin Chat
          internal static let unpin = L10n.tr("Localizable", "channel.profile.action.chat.unpin", fallback: "Unpin Chat")
        }
        internal enum Group {
          /// Block and Leave Group
          internal static let blockAndLeave = L10n.tr("Localizable", "channel.profile.action.group.block-and-leave", fallback: "Block and Leave Group")
          /// Delete Group
          internal static let delete = L10n.tr("Localizable", "channel.profile.action.group.delete", fallback: "Delete Group")
          /// Once you delete this group it will be permanently removed along with its entire history for all the group members.
          internal static let deleteMessage = L10n.tr("Localizable", "channel.profile.action.group.deleteMessage", fallback: "Once you delete this group it will be permanently removed along with its entire history for all the group members.")
          /// Edit Group
          internal static let edit = L10n.tr("Localizable", "channel.profile.action.group.edit", fallback: "Edit Group")
          /// Leave Group
          internal static let leave = L10n.tr("Localizable", "channel.profile.action.group.leave", fallback: "Leave Group")
          /// Pin Group
          internal static let pin = L10n.tr("Localizable", "channel.profile.action.group.pin", fallback: "Pin Group")
          /// Unpin Group
          internal static let unpin = L10n.tr("Localizable", "channel.profile.action.group.unpin", fallback: "Unpin Group")
        }
        internal enum RemoveMember {
          /// Are you sure to remove %@ from this group?
          internal static func message(_ p1: Any) -> String {
            return L10n.tr("Localizable", "channel.profile.action.removeMember.message", String(describing: p1), fallback: "Are you sure to remove %@ from this group?")
          }
          /// Remove Member
          internal static let title = L10n.tr("Localizable", "channel.profile.action.removeMember.title", fallback: "Remove Member")
        }
        internal enum RemoveSubscriber {
          /// Are you sure to remove %@ from this channel?
          internal static func message(_ p1: Any) -> String {
            return L10n.tr("Localizable", "channel.profile.action.removeSubscriber.message", String(describing: p1), fallback: "Are you sure to remove %@ from this channel?")
          }
          /// Remove Subscriber
          internal static let title = L10n.tr("Localizable", "channel.profile.action.removeSubscriber.title", fallback: "Remove Subscriber")
        }
        internal enum RevokeAdmin {
          /// Revoke
          internal static let action = L10n.tr("Localizable", "channel.profile.action.revokeAdmin.action", fallback: "Revoke")
          /// Are you sure you want to revoke “Admin” rights from user: %@?
          internal static func message(_ p1: Any) -> String {
            return L10n.tr("Localizable", "channel.profile.action.revokeAdmin.message", String(describing: p1), fallback: "Are you sure you want to revoke “Admin” rights from user: %@?")
          }
          /// Revoke Admin
          internal static let title = L10n.tr("Localizable", "channel.profile.action.revokeAdmin.title", fallback: "Revoke Admin")
        }
      }
      internal enum Admins {
        /// Admins
        internal static let title = L10n.tr("Localizable", "channel.profile.admins.title", fallback: "Admins")
      }
      internal enum AutoDelete {
        /// Off
        internal static let off = L10n.tr("Localizable", "channel.profile.autoDelete.off", fallback: "Off")
        /// 1 day
        internal static let oneDay = L10n.tr("Localizable", "channel.profile.autoDelete.oneDay", fallback: "1 day")
        /// 1 hour
        internal static let oneHour = L10n.tr("Localizable", "channel.profile.autoDelete.oneHour", fallback: "1 hour")
        /// 1 min
        internal static let oneMin = L10n.tr("Localizable", "channel.profile.autoDelete.oneMin", fallback: "1 min")
        /// Auto-Delete messages:
        internal static let title = L10n.tr("Localizable", "channel.profile.autoDelete.title", fallback: "Auto-Delete messages:")
      }
      internal enum Item {
        internal enum Title {
          /// Admins
          internal static let admins = L10n.tr("Localizable", "channel.profile.item.title.admins", fallback: "Admins")
          /// Auto-Delete messages
          internal static let autoDeleteMessages = L10n.tr("Localizable", "channel.profile.item.title.autoDeleteMessages", fallback: "Auto-Delete messages")
          /// Members
          internal static let members = L10n.tr("Localizable", "channel.profile.item.title.members", fallback: "Members")
          /// Message Search
          internal static let messageSearch = L10n.tr("Localizable", "channel.profile.item.title.messageSearch", fallback: "Message Search")
          /// Subscribers
          internal static let subscribers = L10n.tr("Localizable", "channel.profile.item.title.subscribers", fallback: "Subscribers")
        }
      }
      internal enum Members {
        /// Members
        internal static let title = L10n.tr("Localizable", "channel.profile.members.title", fallback: "Members")
      }
      internal enum Mute {
        /// For %d days
        internal static func days(_ p1: Int) -> String {
          return L10n.tr("Localizable", "channel.profile.mute.days", p1, fallback: "For %d days")
        }
        /// Forever
        internal static let forever = L10n.tr("Localizable", "channel.profile.mute.forever", fallback: "Forever")
        /// For %d hours
        internal static func hours(_ p1: Int) -> String {
          return L10n.tr("Localizable", "channel.profile.mute.hours", p1, fallback: "For %d hours")
        }
        /// For 1 day
        internal static let oneDay = L10n.tr("Localizable", "channel.profile.mute.one-day", fallback: "For 1 day")
        /// For 1 hour
        internal static let oneHour = L10n.tr("Localizable", "channel.profile.mute.one-hour", fallback: "For 1 hour")
        /// Mute Chat:
        internal static let title = L10n.tr("Localizable", "channel.profile.mute.title", fallback: "Mute Chat:")
      }
      internal enum Segment {
        /// Files
        internal static let files = L10n.tr("Localizable", "channel.profile.segment.files", fallback: "Files")
        /// Links
        internal static let links = L10n.tr("Localizable", "channel.profile.segment.links", fallback: "Links")
        /// Media
        internal static let medias = L10n.tr("Localizable", "channel.profile.segment.medias", fallback: "Media")
        /// Members
        internal static let members = L10n.tr("Localizable", "channel.profile.segment.members", fallback: "Members")
        /// Voice
        internal static let voice = L10n.tr("Localizable", "channel.profile.segment.voice", fallback: "Voice")
        internal enum Files {
          /// No file items yet
          internal static let noItems = L10n.tr("Localizable", "channel.profile.segment.files.noItems", fallback: "No file items yet")
        }
        internal enum Links {
          /// No link items yet
          internal static let noItems = L10n.tr("Localizable", "channel.profile.segment.links.noItems", fallback: "No link items yet")
        }
        internal enum Medias {
          /// No media items yet
          internal static let noItems = L10n.tr("Localizable", "channel.profile.segment.medias.noItems", fallback: "No media items yet")
        }
        internal enum Voice {
          /// No voice items yet
          internal static let noItems = L10n.tr("Localizable", "channel.profile.segment.voice.noItems", fallback: "No voice items yet")
        }
      }
    }
    internal enum ReadOnly {
      /// Read Only.
      internal static let message = L10n.tr("Localizable", "channel.readOnly.message", fallback: "Read Only.")
    }
    internal enum Search {
      /// %d of %d
      internal static func foundIndex(_ p1: Int, _ p2: Int) -> String {
        return L10n.tr("Localizable", "channel.search.found-index", p1, p2, fallback: "%d of %d")
      }
      /// Not found
      internal static let notFound = L10n.tr("Localizable", "channel.search.not-found", fallback: "Not found")
      /// Search
      internal static let search = L10n.tr("Localizable", "channel.search.search", fallback: "Search")
    }
    internal enum Selecting {
      /// Clear Messages
      internal static let clearChat = L10n.tr("Localizable", "channel.selecting.clearChat", fallback: "Clear Messages")
      /// %d Selected
      internal static func selected(_ p1: Int) -> String {
        return L10n.tr("Localizable", "channel.selecting.selected", p1, fallback: "%d Selected")
      }
      internal enum ClearChat {
        /// Clear
        internal static let clear = L10n.tr("Localizable", "channel.selecting.clearChat.clear", fallback: "Clear")
        /// Once you clear the messages in this chat will be permanently removed for you.
        internal static let message = L10n.tr("Localizable", "channel.selecting.clearChat.message", fallback: "Once you clear the messages in this chat will be permanently removed for you.")
        internal enum Channel {
          /// Once you clear the messages in this channel will be permanently removed for all the subscribers.
          internal static let message = L10n.tr("Localizable", "channel.selecting.clearChat.channel.message", fallback: "Once you clear the messages in this channel will be permanently removed for all the subscribers.")
        }
      }
    }
    internal enum `Self` {
      /// message yourself
      internal static let hint = L10n.tr("Localizable", "channel.self.hint", fallback: "message yourself")
      /// Me
      internal static let title = L10n.tr("Localizable", "channel.self.title", fallback: "Me")
    }
    internal enum StopRecording {
      /// Are you sure you want to stop recording and discard your voice message?
      internal static let message = L10n.tr("Localizable", "channel.stopRecording.message", fallback: "Are you sure you want to stop recording and discard your voice message?")
    }
    internal enum Subject {
      /// About
      internal static let descriptionPlaceholder = L10n.tr("Localizable", "channel.subject.descriptionPlaceholder", fallback: "About")
      internal enum Channel {
        /// Channel Name
        internal static let placeholder = L10n.tr("Localizable", "channel.subject.channel.placeholder", fallback: "Channel Name")
      }
      internal enum Group {
        /// Group Name
        internal static let placeholder = L10n.tr("Localizable", "channel.subject.group.placeholder", fallback: "Group Name")
      }
    }
    internal enum SubscriberCount {
      /// %d subscribers
      internal static func more(_ p1: Int) -> String {
        return L10n.tr("Localizable", "channel.subscriber-count.more", p1, fallback: "%d subscribers")
      }
      /// 1 subscriber
      internal static let one = L10n.tr("Localizable", "channel.subscriber-count.one", fallback: "1 subscriber")
    }
  }
  internal enum Common {
    /// Off
    internal static let off = L10n.tr("Localizable", "common.off", fallback: "Off")
    /// Localizable.strings
    ///   SceytChatUIKit
    /// 
    ///   Created by Hovsep on 5/27/22.
    ///   Copyright © 2022 Sceyt LLC. All rights reserved.
    internal static let on = L10n.tr("Localizable", "common.on", fallback: "On")
  }
  internal enum Composer {
    /// Edit message
    internal static let edit = L10n.tr("Localizable", "composer.edit", fallback: "Edit message")
    /// Reply
    internal static let reply = L10n.tr("Localizable", "composer.reply", fallback: "Reply")
  }
  internal enum Connection {
    internal enum State {
      /// Connected
      internal static let connected = L10n.tr("Localizable", "connection.state.connected", fallback: "Connected")
      /// Connecting
      internal static let connecting = L10n.tr("Localizable", "connection.state.connecting", fallback: "Connecting")
      /// Disconnected
      internal static let disconnected = L10n.tr("Localizable", "connection.state.disconnected", fallback: "Disconnected")
      /// Connection Failed
      internal static let failed = L10n.tr("Localizable", "connection.state.failed", fallback: "Connection Failed")
      /// Connecting
      internal static let reconnecting = L10n.tr("Localizable", "connection.state.reconnecting", fallback: "Connecting")
    }
  }
  internal enum Emoji {
    /// Frequently used
    internal static let recent = L10n.tr("Localizable", "emoji.recent", fallback: "Frequently used")
  }
  internal enum Error {
    /// Maximum 20 items allowed
    internal static let max20Items = L10n.tr("Localizable", "error.max20Items", fallback: "Maximum 20 items allowed")
    /// Maximum %d items allowed
    internal static func maxValueItems(_ p1: Int) -> String {
      return L10n.tr("Localizable", "error.maxValueItems", p1, fallback: "Maximum %d items allowed")
    }
  }
  internal enum ImageCropper {
    /// Move and Scale
    internal static let moveAndScale = L10n.tr("Localizable", "imageCropper.moveAndScale", fallback: "Move and Scale")
  }
  internal enum ImagePicker {
    /// Gallery
    internal static let title = L10n.tr("Localizable", "imagePicker.title", fallback: "Gallery")
    internal enum Attach {
      internal enum Button {
        /// Attach
        internal static let title = L10n.tr("Localizable", "imagePicker.attach.button.title", fallback: "Attach")
      }
    }
    internal enum ManageAccess {
      /// Manage
      internal static let action = L10n.tr("Localizable", "imagePicker.manageAccess.action", fallback: "Manage")
      /// Change Settings
      internal static let change = L10n.tr("Localizable", "imagePicker.manageAccess.change", fallback: "Change Settings")
      /// Select More
      internal static let more = L10n.tr("Localizable", "imagePicker.manageAccess.more", fallback: "Select More")
    }
  }
  internal enum Link {
    /// Copy link
    internal static let copy = L10n.tr("Localizable", "link.copy", fallback: "Copy link")
    /// Open in ...
    internal static let openIn = L10n.tr("Localizable", "link.openIn", fallback: "Open in ...")
  }
  internal enum Message {
    /// Message was deleted.
    internal static let deleted = L10n.tr("Localizable", "message.deleted", fallback: "Message was deleted.")
    internal enum Action {
      internal enum Subtitle {
        /// Delete For All
        internal static let deleteAll = L10n.tr("Localizable", "message.action.subtitle.deleteAll", fallback: "Delete For All")
        /// Delete For Me
        internal static let deleteMe = L10n.tr("Localizable", "message.action.subtitle.deleteMe", fallback: "Delete For Me")
      }
      internal enum Title {
        /// Add
        internal static let add = L10n.tr("Localizable", "message.action.title.add", fallback: "Add")
        /// Copy
        internal static let copy = L10n.tr("Localizable", "message.action.title.copy", fallback: "Copy")
        /// Delete
        internal static let delete = L10n.tr("Localizable", "message.action.title.delete", fallback: "Delete")
        /// Edit
        internal static let edit = L10n.tr("Localizable", "message.action.title.edit", fallback: "Edit")
        /// Forward
        internal static let forward = L10n.tr("Localizable", "message.action.title.forward", fallback: "Forward")
        /// Info
        internal static let info = L10n.tr("Localizable", "message.action.title.info", fallback: "Info")
        /// React
        internal static let react = L10n.tr("Localizable", "message.action.title.react", fallback: "React")
        /// Remove
        internal static let remove = L10n.tr("Localizable", "message.action.title.remove", fallback: "Remove")
        /// Reply
        internal static let reply = L10n.tr("Localizable", "message.action.title.reply", fallback: "Reply")
        /// Reply in thread
        internal static let replyInThread = L10n.tr("Localizable", "message.action.title.reply-in-thread", fallback: "Reply in thread")
        /// Report
        internal static let report = L10n.tr("Localizable", "message.action.title.report", fallback: "Report")
        /// Select
        internal static let select = L10n.tr("Localizable", "message.action.title.select", fallback: "Select")
      }
    }
    internal enum Alert {
      internal enum Delete {
        /// Are you sure you want to delete this message?
        internal static let description = L10n.tr("Localizable", "message.alert.delete.description", fallback: "Are you sure you want to delete this message?")
        /// Delete message?
        internal static let title = L10n.tr("Localizable", "message.alert.delete.title", fallback: "Delete message?")
      }
    }
    internal enum Attachment {
      /// File
      internal static let file = L10n.tr("Localizable", "message.attachment.file", fallback: "File")
      /// Photo
      internal static let image = L10n.tr("Localizable", "message.attachment.image", fallback: "Photo")
      /// Link
      internal static let link = L10n.tr("Localizable", "message.attachment.link", fallback: "Link")
      /// Video
      internal static let video = L10n.tr("Localizable", "message.attachment.video", fallback: "Video")
      /// Voice
      internal static let voice = L10n.tr("Localizable", "message.attachment.voice", fallback: "Voice")
    }
    internal enum Forward {
      /// Forwarded message
      internal static let title = L10n.tr("Localizable", "message.forward.title", fallback: "Forwarded message")
    }
    internal enum Info {
      /// Delivered to
      internal static let deliveredTo = L10n.tr("Localizable", "message.info.deliveredTo", fallback: "Delivered to")
      /// edited
      internal static let edited = L10n.tr("Localizable", "message.info.edited", fallback: "edited")
        /// Played by
        internal static let playedBy = L10n.tr("Localizable", "message.info.playedBy", fallback: "Played by")
        /// Seen by
        internal static let readBy = L10n.tr("Localizable", "message.info.readBy", fallback: "Seen by")
      /// Sent:
      internal static let sent = L10n.tr("Localizable", "message.info.sent", fallback: "Sent:")
      /// Size:
      internal static let size = L10n.tr("Localizable", "message.info.size", fallback: "Size:")
      /// Message Info
      internal static let title = L10n.tr("Localizable", "message.info.title", fallback: "Message Info")
    }
    internal enum Input {
      /// Write a message...
      internal static let placeholder = L10n.tr("Localizable", "message.input.placeholder", fallback: "Write a message...")
    }
    internal enum List {
      /// Today
      internal static let separatorToday = L10n.tr("Localizable", "message.list.separator-today", fallback: "Today")
      /// New Messages
      internal static let unread = L10n.tr("Localizable", "message.list.unread", fallback: "New Messages")
    }
    internal enum Reply {
      /// %d Replies
      internal static func count(_ p1: Int) -> String {
        return L10n.tr("Localizable", "message.reply.count", p1, fallback: "%d Replies")
      }
    }
  }
  internal enum Nav {
    internal enum Bar {
      /// Add
      internal static let add = L10n.tr("Localizable", "nav.bar.add", fallback: "Add")
      /// Cancel
      internal static let cancel = L10n.tr("Localizable", "nav.bar.cancel", fallback: "Cancel")
      /// Close
      internal static let close = L10n.tr("Localizable", "nav.bar.close", fallback: "Close")
      /// Confirm
      internal static let confirm = L10n.tr("Localizable", "nav.bar.confirm", fallback: "Confirm")
      /// Create
      internal static let create = L10n.tr("Localizable", "nav.bar.create", fallback: "Create")
      /// Done
      internal static let done = L10n.tr("Localizable", "nav.bar.done", fallback: "Done")
      /// Edit
      internal static let edit = L10n.tr("Localizable", "nav.bar.edit", fallback: "Edit")
      /// Forward
      internal static let forward = L10n.tr("Localizable", "nav.bar.forward", fallback: "Forward")
      /// Next
      internal static let next = L10n.tr("Localizable", "nav.bar.next", fallback: "Next")
      /// Update
      internal static let update = L10n.tr("Localizable", "nav.bar.update", fallback: "Update")
    }
  }
  internal enum Previewer {
    /// Forward
    internal static let forward = L10n.tr("Localizable", "previewer.forward", fallback: "Forward")
    /// Your photo was successfully saved
    internal static let photoSaved = L10n.tr("Localizable", "previewer.photoSaved", fallback: "Your photo was successfully saved")
    /// Save Photo
    internal static let savePhoto = L10n.tr("Localizable", "previewer.savePhoto", fallback: "Save Photo")
    /// Save Video
    internal static let saveVideo = L10n.tr("Localizable", "previewer.saveVideo", fallback: "Save Video")
    /// Share Photo
    internal static let sharePhoto = L10n.tr("Localizable", "previewer.sharePhoto", fallback: "Share Photo")
    /// Share Video
    internal static let shareVideo = L10n.tr("Localizable", "previewer.shareVideo", fallback: "Share Video")
    /// Your video was successfully saved
    internal static let videoSaved = L10n.tr("Localizable", "previewer.videoSaved", fallback: "Your video was successfully saved")
  }
  internal enum Recorder {
    /// Cancel
    internal static let cancel = L10n.tr("Localizable", "recorder.cancel", fallback: "Cancel")
    /// < Slide to cancel
    internal static let slideToCancel = L10n.tr("Localizable", "recorder.slideToCancel", fallback: "< Slide to cancel")
  }
  internal enum Report {
    /// Report
    internal static let title = L10n.tr("Localizable", "report.title", fallback: "Report")
    internal enum Additional {
      /// Additional details
      internal static let details = L10n.tr("Localizable", "report.additional.details", fallback: "Additional details")
      /// Please enter any additional details
      internal static let title = L10n.tr("Localizable", "report.additional.title", fallback: "Please enter any additional details")
    }
  }
  internal enum Search {
    internal enum NoResults {
      /// There were no results found.
      internal static let message = L10n.tr("Localizable", "search.noResults.message", fallback: "There were no results found.")
      /// No Results
      internal static let title = L10n.tr("Localizable", "search.noResults.title", fallback: "No Results")
    }
  }
  internal enum SearchBar {
    /// Search
    internal static let placeholder = L10n.tr("Localizable", "searchBar.placeholder", fallback: "Search")
  }
  internal enum Upload {
    /// Preparing...
    internal static let preparing = L10n.tr("Localizable", "upload.preparing", fallback: "Preparing...")
  }
  internal enum User {
    /// You
    internal static let current = L10n.tr("Localizable", "user.current", fallback: "You")
    /// Deleted user
    internal static let deleted = L10n.tr("Localizable", "user.deleted", fallback: "Deleted user")
    /// Inactive user
    internal static let inactive = L10n.tr("Localizable", "user.inactive", fallback: "Inactive user")
    internal enum Last {
      /// last seen %@
      internal static func seen(_ p1: Any) -> String {
        return L10n.tr("Localizable", "user.last.seen", String(describing: p1), fallback: "last seen %@")
      }
      internal enum Seen {
        /// last seen %@ at %@
        internal static func at(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.at", String(describing: p1), String(describing: p2), fallback: "last seen %@ at %@")
        }
        /// last seen %@ minute ago
        internal static func minAgo(_ p1: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.minAgo", String(describing: p1), fallback: "last seen %@ minute ago")
        }
        /// last seen %@ minutes ago
        internal static func minsAgo(_ p1: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.minsAgo", String(describing: p1), fallback: "last seen %@ minutes ago")
        }
        /// Yesterday
        internal static let yesterday = L10n.tr("Localizable", "user.last.seen.yesterday", fallback: "Yesterday")
      }
    }
    internal enum Presence {
      /// away
      internal static let away = L10n.tr("Localizable", "user.presence.away", fallback: "away")
      /// DND
      internal static let dnd = L10n.tr("Localizable", "user.presence.dnd", fallback: "DND")
      /// offline
      internal static let offline = L10n.tr("Localizable", "user.presence.offline", fallback: "offline")
      /// online
      internal static let online = L10n.tr("Localizable", "user.presence.online", fallback: "online")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = SCL10nBundleClass.resourcesBundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
