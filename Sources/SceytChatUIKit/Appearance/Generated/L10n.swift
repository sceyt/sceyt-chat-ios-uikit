// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum L10n {
  public enum Alert {
    public enum Ask {
      /// Are you sure you want to delete this chat?
      /// This cannot be undone.
      public static let delete = L10n.tr("Localizable", "alert.ask.delete", fallback: "Are you sure you want to delete this chat?\nThis cannot be undone.")
    }
    public enum Button {
      /// Cancel
      public static let cancel = L10n.tr("Localizable", "alert.button.cancel", fallback: "Cancel")
      /// Delete
      public static let delete = L10n.tr("Localizable", "alert.button.delete", fallback: "Delete")
      /// Discard
      public static let discard = L10n.tr("Localizable", "alert.button.discard", fallback: "Discard")
      /// Ok
      public static let ok = L10n.tr("Localizable", "alert.button.ok", fallback: "Ok")
      /// Camera
      public static let openCamera = L10n.tr("Localizable", "alert.button.open-camera", fallback: "Camera")
      /// File
      public static let openFiles = L10n.tr("Localizable", "alert.button.open-files", fallback: "File")
      /// Gallery
      public static let openGallery = L10n.tr("Localizable", "alert.button.open-gallery", fallback: "Gallery")
    }
    public enum Error {
      /// Error
      public static let title = L10n.tr("Localizable", "alert.error.title", fallback: "Error")
    }
  }
  public enum Attachment {
    /// File
    public static let file = L10n.tr("Localizable", "attachment.file", fallback: "File")
    /// Photo
    public static let image = L10n.tr("Localizable", "attachment.image", fallback: "Photo")
    /// Video
    public static let video = L10n.tr("Localizable", "attachment.video", fallback: "Video")
    /// Voice
    public static let voice = L10n.tr("Localizable", "attachment.voice", fallback: "Voice")
  }
  public enum Capture {
    /// Select Photo
    public static let selectPhoto = L10n.tr("Localizable", "capture.selectPhoto", fallback: "Select Photo")
    /// Camera
    public static let takePhoto = L10n.tr("Localizable", "capture.takePhoto", fallback: "Camera")
  }
  public enum Channel {
    /// Join
    public static let join = L10n.tr("Localizable", "channel.join", fallback: "Join")
    public enum Add {
      public enum Admins {
        /// Add Admins
        public static let title = L10n.tr("Localizable", "channel.add.admins.title", fallback: "Add Admins")
      }
      public enum Members {
        /// Add Members
        public static let title = L10n.tr("Localizable", "channel.add.members.title", fallback: "Add Members")
      }
      public enum Subscribers {
        /// Add Subscribers
        public static let title = L10n.tr("Localizable", "channel.add.subscribers.title", fallback: "Add Subscribers")
      }
    }
    public enum Avatar {
      /// Name the chat and upload a photo if you want
      public static let comment = L10n.tr("Localizable", "channel.avatar.comment", fallback: "Name the chat and upload a photo if you want")
    }
    public enum BlockedUser {
      /// You blocked this user.
      public static let message = L10n.tr("Localizable", "channel.blockedUser.message", fallback: "You blocked this user.")
    }
    public enum Create {
      /// Give a URL to your channel so you can share it with others inviting them to join.
      /// 
      /// Choose a name from the allowed range: a-z, 0-9, and _(underscores) between %d-%d characters.
      public static func comment(_ p1: Int, _ p2: Int) -> String {
        return L10n.tr("Localizable", "channel.create.comment", p1, p2, fallback: "Give a URL to your channel so you can share it with others inviting them to join.\n\nChoose a name from the allowed range: a-z, 0-9, and _(underscores) between %d-%d characters.")
      }
      public enum Uri {
        /// chn12
        public static let placeholder = L10n.tr("Localizable", "channel.create.uri.placeholder", fallback: "chn12")
        public enum Error {
          /// The URL already exists. Please provide another one.
          public static let exist = L10n.tr("Localizable", "channel.create.uri.error.exist", fallback: "The URL already exists. Please provide another one.")
          /// The name should be %d-%d characters long.
          public static func range(_ p1: Int, _ p2: Int) -> String {
            return L10n.tr("Localizable", "channel.create.uri.error.range", p1, p2, fallback: "The name should be %d-%d characters long.")
          }
          /// The name is invalid. Please provide a name from the allowed range of characters.
          public static let regex = L10n.tr("Localizable", "channel.create.uri.error.regex", fallback: "The name is invalid. Please provide a name from the allowed range of characters.")
          /// Success! This URL is free to use.
          public static let success = L10n.tr("Localizable", "channel.create.uri.error.success", fallback: "Success! This URL is free to use.")
        }
      }
    }
    public enum Created {
      /// Add subscribers so they can join
      /// the channel.
      public static let message = L10n.tr("Localizable", "channel.created.message", fallback: "Add subscribers so they can join\nthe channel.")
      /// You created a channel
      public static let title = L10n.tr("Localizable", "channel.created.title", fallback: "You created a channel")
    }
    public enum DeletedUser {
      /// This user has been deleted.
      public static let message = L10n.tr("Localizable", "channel.deletedUser.message", fallback: "This user has been deleted.")
    }
    public enum Empty {
      /// Create channel
      public static let createNew = L10n.tr("Localizable", "channel.empty.create-new", fallback: "Create channel")
      /// You have no channels created yet, create one and send messages
      public static let description = L10n.tr("Localizable", "channel.empty.description", fallback: "You have no channels created yet, create one and send messages")
      /// No Channels
      public static let title = L10n.tr("Localizable", "channel.empty.title", fallback: "No Channels")
    }
    public enum Forward {
      /// Channels
      public static let channels = L10n.tr("Localizable", "channel.forward.channels", fallback: "Channels")
      /// Chats & Groups
      public static let chatsGroups = L10n.tr("Localizable", "channel.forward.chatsGroups", fallback: "Chats & Groups")
      /// Select Chat
      public static let title = L10n.tr("Localizable", "channel.forward.title", fallback: "Select Chat")
    }
    public enum Info {
      /// About
      public static let about = L10n.tr("Localizable", "channel.info.about", fallback: "About")
      /// Notifications
      public static let notifications = L10n.tr("Localizable", "channel.info.notifications", fallback: "Notifications")
      /// Subject
      public static let subject = L10n.tr("Localizable", "channel.info.subject", fallback: "Subject")
      /// Info
      public static let title = L10n.tr("Localizable", "channel.info.title", fallback: "Info")
      public enum Action {
        /// Block User
        public static let block = L10n.tr("Localizable", "channel.info.action.block", fallback: "Block User")
        /// Block & Kick Member
        public static let blockAndKickMember = L10n.tr("Localizable", "channel.info.action.block-and-kick-member", fallback: "Block & Kick Member")
        /// Change member’s role
        public static let changeRole = L10n.tr("Localizable", "channel.info.action.change-role", fallback: "Change member’s role")
        /// Clear History
        public static let clearHistory = L10n.tr("Localizable", "channel.info.action.clear-history", fallback: "Clear History")
        /// join
        public static let join = L10n.tr("Localizable", "channel.info.action.join", fallback: "join")
        /// more
        public static let more = L10n.tr("Localizable", "channel.info.action.more", fallback: "more")
        /// mute
        public static let mute = L10n.tr("Localizable", "channel.info.action.mute", fallback: "mute")
        /// Remove
        public static let remove = L10n.tr("Localizable", "channel.info.action.remove", fallback: "Remove")
        /// report
        public static let report = L10n.tr("Localizable", "channel.info.action.report", fallback: "report")
        /// Set Owner
        public static let setOwner = L10n.tr("Localizable", "channel.info.action.set-owner", fallback: "Set Owner")
        /// Unblock User
        public static let unblock = L10n.tr("Localizable", "channel.info.action.unblock", fallback: "Unblock User")
        /// unmute
        public static let unmute = L10n.tr("Localizable", "channel.info.action.unmute", fallback: "unmute")
        public enum Channel {
          /// Block and Leave Channel
          public static let blockAndLeave = L10n.tr("Localizable", "channel.info.action.channel.block-and-leave", fallback: "Block and Leave Channel")
          /// Delete Channel
          public static let delete = L10n.tr("Localizable", "channel.info.action.channel.delete", fallback: "Delete Channel")
          /// Once you delete this channel it will be permanently removed along with its entire history for all the channel subscribers.
          public static let deleteMessage = L10n.tr("Localizable", "channel.info.action.channel.deleteMessage", fallback: "Once you delete this channel it will be permanently removed along with its entire history for all the channel subscribers.")
          /// Edit Channel
          public static let edit = L10n.tr("Localizable", "channel.info.action.channel.edit", fallback: "Edit Channel")
          /// Leave Channel
          public static let leave = L10n.tr("Localizable", "channel.info.action.channel.leave", fallback: "Leave Channel")
          /// Pin Channel
          public static let pin = L10n.tr("Localizable", "channel.info.action.channel.pin", fallback: "Pin Channel")
          /// Unpin Channel
          public static let unpin = L10n.tr("Localizable", "channel.info.action.channel.unpin", fallback: "Unpin Channel")
        }
        public enum Chat {
          /// Delete Chat
          public static let delete = L10n.tr("Localizable", "channel.info.action.chat.delete", fallback: "Delete Chat")
          /// Once you delete this chat it will be removed from the chat list with its message history.
          public static let deleteMessage = L10n.tr("Localizable", "channel.info.action.chat.deleteMessage", fallback: "Once you delete this chat it will be removed from the chat list with its message history.")
          /// Pin Chat
          public static let pin = L10n.tr("Localizable", "channel.info.action.chat.pin", fallback: "Pin Chat")
          /// Unpin Chat
          public static let unpin = L10n.tr("Localizable", "channel.info.action.chat.unpin", fallback: "Unpin Chat")
        }
        public enum Group {
          /// Block and Leave Group
          public static let blockAndLeave = L10n.tr("Localizable", "channel.info.action.group.block-and-leave", fallback: "Block and Leave Group")
          /// Delete Group
          public static let delete = L10n.tr("Localizable", "channel.info.action.group.delete", fallback: "Delete Group")
          /// Once you delete this group it will be permanently removed along with its entire history for all the group members.
          public static let deleteMessage = L10n.tr("Localizable", "channel.info.action.group.deleteMessage", fallback: "Once you delete this group it will be permanently removed along with its entire history for all the group members.")
          /// Edit Group
          public static let edit = L10n.tr("Localizable", "channel.info.action.group.edit", fallback: "Edit Group")
          /// Leave Group
          public static let leave = L10n.tr("Localizable", "channel.info.action.group.leave", fallback: "Leave Group")
          /// Pin Group
          public static let pin = L10n.tr("Localizable", "channel.info.action.group.pin", fallback: "Pin Group")
          /// Unpin Group
          public static let unpin = L10n.tr("Localizable", "channel.info.action.group.unpin", fallback: "Unpin Group")
        }
        public enum RemoveMember {
          /// Are you sure to remove %@ from this group?
          public static func message(_ p1: Any) -> String {
            return L10n.tr("Localizable", "channel.info.action.removeMember.message", String(describing: p1), fallback: "Are you sure to remove %@ from this group?")
          }
          /// Remove Member
          public static let title = L10n.tr("Localizable", "channel.info.action.removeMember.title", fallback: "Remove Member")
        }
        public enum RemoveSubscriber {
          /// Are you sure to remove %@ from this channel?
          public static func message(_ p1: Any) -> String {
            return L10n.tr("Localizable", "channel.info.action.removeSubscriber.message", String(describing: p1), fallback: "Are you sure to remove %@ from this channel?")
          }
          /// Remove Subscriber
          public static let title = L10n.tr("Localizable", "channel.info.action.removeSubscriber.title", fallback: "Remove Subscriber")
        }
        public enum RevokeAdmin {
          /// Revoke
          public static let action = L10n.tr("Localizable", "channel.info.action.revokeAdmin.action", fallback: "Revoke")
          /// Are you sure you want to revoke “Admin” rights from user: %@?
          public static func message(_ p1: Any) -> String {
            return L10n.tr("Localizable", "channel.info.action.revokeAdmin.message", String(describing: p1), fallback: "Are you sure you want to revoke “Admin” rights from user: %@?")
          }
          /// Revoke Admin
          public static let title = L10n.tr("Localizable", "channel.info.action.revokeAdmin.title", fallback: "Revoke Admin")
        }
      }
      public enum Admins {
        /// Admins
        public static let title = L10n.tr("Localizable", "channel.info.admins.title", fallback: "Admins")
      }
      public enum AutoDelete {
        /// Custom
        public static let custom = L10n.tr("Localizable", "channel.info.autoDelete.custom", fallback: "Custom")
        /// Off
        public static let off = L10n.tr("Localizable", "channel.info.autoDelete.off", fallback: "Off")
        /// 1 day
        public static let oneDay = L10n.tr("Localizable", "channel.info.autoDelete.oneDay", fallback: "1 day")
        /// 1 hour
        public static let oneHour = L10n.tr("Localizable", "channel.info.autoDelete.oneHour", fallback: "1 hour")
        /// 1 month
        public static let oneMonth = L10n.tr("Localizable", "channel.info.autoDelete.oneMonth", fallback: "1 month")
        /// 1 week
        public static let oneWeek = L10n.tr("Localizable", "channel.info.autoDelete.oneWeek", fallback: "1 week")
        /// Disappearing Messages
        public static let title = L10n.tr("Localizable", "channel.info.autoDelete.title", fallback: "Disappearing Messages")
      }
      public enum Item {
        public enum Title {
          /// Admins
          public static let admins = L10n.tr("Localizable", "channel.info.item.title.admins", fallback: "Admins")
          /// Disappearing Messages
          public static let autoDeleteMessages = L10n.tr("Localizable", "channel.info.item.title.autoDeleteMessages", fallback: "Disappearing Messages")
          /// Members
          public static let members = L10n.tr("Localizable", "channel.info.item.title.members", fallback: "Members")
          /// Message Search
          public static let messageSearch = L10n.tr("Localizable", "channel.info.item.title.messageSearch", fallback: "Message Search")
          /// Subscribers
          public static let subscribers = L10n.tr("Localizable", "channel.info.item.title.subscribers", fallback: "Subscribers")
        }
      }
      public enum Members {
        /// Members
        public static let title = L10n.tr("Localizable", "channel.info.members.title", fallback: "Members")
      }
      public enum Mute {
        /// For %d days
        public static func days(_ p1: Int) -> String {
          return L10n.tr("Localizable", "channel.info.mute.days", p1, fallback: "For %d days")
        }
        /// Forever
        public static let forever = L10n.tr("Localizable", "channel.info.mute.forever", fallback: "Forever")
        /// For %d hours
        public static func hours(_ p1: Int) -> String {
          return L10n.tr("Localizable", "channel.info.mute.hours", p1, fallback: "For %d hours")
        }
        /// For 1 day
        public static let oneDay = L10n.tr("Localizable", "channel.info.mute.one-day", fallback: "For 1 day")
        /// For 1 hour
        public static let oneHour = L10n.tr("Localizable", "channel.info.mute.one-hour", fallback: "For 1 hour")
        /// Mute Chat:
        public static let title = L10n.tr("Localizable", "channel.info.mute.title", fallback: "Mute Chat:")
      }
      public enum Segment {
        /// Files
        public static let files = L10n.tr("Localizable", "channel.info.segment.files", fallback: "Files")
        /// Groups
        public static let groups = L10n.tr("Localizable", "channel.info.segment.groups", fallback: "Groups")
        /// Links
        public static let links = L10n.tr("Localizable", "channel.info.segment.links", fallback: "Links")
        /// Media
        public static let medias = L10n.tr("Localizable", "channel.info.segment.medias", fallback: "Media")
        /// Members
        public static let members = L10n.tr("Localizable", "channel.info.segment.members", fallback: "Members")
        /// Voice
        public static let voice = L10n.tr("Localizable", "channel.info.segment.voice", fallback: "Voice")
        public enum Files {
          /// No Files
          public static let noItems = L10n.tr("Localizable", "channel.info.segment.files.noItems", fallback: "No Files")
          /// Shared files will appear here.
          public static let noItemsSubTitle = L10n.tr("Localizable", "channel.info.segment.files.noItemsSubTitle", fallback: "Shared files will appear here.")
        }
        public enum Groups {
          /// No groups in common
          public static let noItems = L10n.tr("Localizable", "channel.info.segment.groups.noItems", fallback: "No groups in common")
          /// Groups in common will appear here.
          public static let noItemsSubTitle = L10n.tr("Localizable", "channel.info.segment.groups.noItemsSubTitle", fallback: "Groups in common will appear here.")
        }
        public enum Links {
          /// No links
          public static let noItems = L10n.tr("Localizable", "channel.info.segment.links.noItems", fallback: "No links")
          /// Shared links will appear here.
          public static let noItemsSubTitle = L10n.tr("Localizable", "channel.info.segment.links.noItemsSubTitle", fallback: "Shared links will appear here.")
        }
        public enum Medias {
          /// No Media
          public static let noItems = L10n.tr("Localizable", "channel.info.segment.medias.noItems", fallback: "No Media")
          /// Shared media will appear here.
          public static let noItemsSubTitle = L10n.tr("Localizable", "channel.info.segment.medias.noItemsSubTitle", fallback: "Shared media will appear here.")
        }
        public enum Voice {
          /// No voice messages
          public static let noItems = L10n.tr("Localizable", "channel.info.segment.voice.noItems", fallback: "No voice messages")
          /// Shared voice messages will appear here.
          public static let noItemsSubTitle = L10n.tr("Localizable", "channel.info.segment.voice.noItemsSubTitle", fallback: "Shared voice messages will appear here.")
        }
      }
    }
    public enum Intro {
      /// New Channel
      public static let title = L10n.tr("Localizable", "channel.intro.title", fallback: "New Channel")
    }
    public enum InviteLink {
      /// Cancel
      public static let cancel = L10n.tr("Localizable", "channel.inviteLink.cancel", fallback: "Cancel")
      /// You can invite anyone to the chat using this link
      public static let description = L10n.tr("Localizable", "channel.inviteLink.description", fallback: "You can invite anyone to the chat using this link")
      /// Link copied to clipboard
      public static let linkCopied = L10n.tr("Localizable", "channel.inviteLink.linkCopied", fallback: "Link copied to clipboard")
      /// Message history is visible to new members
      public static let messagesDescription = L10n.tr("Localizable", "channel.inviteLink.messagesDescription", fallback: "Message history is visible to new members")
      /// Open QR Code
      public static let openQRCode = L10n.tr("Localizable", "channel.inviteLink.openQRCode", fallback: "Open QR Code")
      /// Reset
      public static let reset = L10n.tr("Localizable", "channel.inviteLink.reset", fallback: "Reset")
      /// Are you sure you want to reset the group link? Anyone with the existing link will no longer be able to use it to join.
      public static let resetAlertMessage = L10n.tr("Localizable", "channel.inviteLink.resetAlertMessage", fallback: "Are you sure you want to reset the group link? Anyone with the existing link will no longer be able to use it to join.")
      /// Reset Link
      public static let resetAlertTitle = L10n.tr("Localizable", "channel.inviteLink.resetAlertTitle", fallback: "Reset Link")
      /// Reset Link
      public static let resetLink = L10n.tr("Localizable", "channel.inviteLink.resetLink", fallback: "Reset Link")
      /// Share
      public static let share = L10n.tr("Localizable", "channel.inviteLink.share", fallback: "Share")
      /// Show Previous Messages
      public static let showPreviousMessages = L10n.tr("Localizable", "channel.inviteLink.showPreviousMessages", fallback: "Show Previous Messages")
      /// Invite Link
      public static let title = L10n.tr("Localizable", "channel.inviteLink.title", fallback: "Invite Link")
    }
    public enum List {
      /// Search for channels
      public static let search = L10n.tr("Localizable", "channel.list.search", fallback: "Search for channels")
      /// Chats
      public static let title = L10n.tr("Localizable", "channel.list.title", fallback: "Chats")
      public enum Action {
        /// Delete
        public static let delete = L10n.tr("Localizable", "channel.list.action.delete", fallback: "Delete")
        /// Leave
        public static let leave = L10n.tr("Localizable", "channel.list.action.leave", fallback: "Leave")
        /// Mute
        public static let mute = L10n.tr("Localizable", "channel.list.action.mute", fallback: "Mute")
        /// Pin
        public static let pin = L10n.tr("Localizable", "channel.list.action.pin", fallback: "Pin")
        /// Read
        public static let read = L10n.tr("Localizable", "channel.list.action.read", fallback: "Read")
        /// Unmute
        public static let unmute = L10n.tr("Localizable", "channel.list.action.unmute", fallback: "Unmute")
        /// Unpin
        public static let unpin = L10n.tr("Localizable", "channel.list.action.unpin", fallback: "Unpin")
        /// Unread
        public static let unread = L10n.tr("Localizable", "channel.list.action.unread", fallback: "Unread")
      }
      public enum NoMessages {
        /// You haven’t created channels yet, create one for sending messages.
        public static let message = L10n.tr("Localizable", "channel.list.noMessages.message", fallback: "You haven’t created channels yet, create one for sending messages.")
        /// No Chats yet
        public static let title = L10n.tr("Localizable", "channel.list.noMessages.title", fallback: "No Chats yet")
      }
    }
    public enum Member {
      /// Deleted User
      public static let deleted = L10n.tr("Localizable", "channel.member.deleted", fallback: "Deleted User")
      /// Inactive User
      public static let inactive = L10n.tr("Localizable", "channel.member.inactive", fallback: "Inactive User")
      /// recording
      public static let recording = L10n.tr("Localizable", "channel.member.recording", fallback: "recording")
      /// typing
      public static let typing = L10n.tr("Localizable", "channel.member.typing", fallback: "typing")
      public enum Role {
        /// Change Role
        public static let title = L10n.tr("Localizable", "channel.member.role.title", fallback: "Change Role")
      }
    }
    public enum MembersCount {
      /// %d members
      public static func more(_ p1: Int) -> String {
        return L10n.tr("Localizable", "channel.members-count.more", p1, fallback: "%d members")
      }
      /// 1 member
      public static let one = L10n.tr("Localizable", "channel.members-count.one", fallback: "1 member")
    }
    public enum Message {
      /// Attachment
      public static let attachment = L10n.tr("Localizable", "channel.message.attachment", fallback: "Attachment")
      /// Draft
      public static let draft = L10n.tr("Localizable", "channel.message.draft", fallback: "Draft")
      /// Reacted %@ to:
      public static func lastReaction(_ p1: Any) -> String {
        return L10n.tr("Localizable", "channel.message.lastReaction", String(describing: p1), fallback: "Reacted %@ to:")
      }
    }
    public enum New {
      /// New Group
      public static let createPrivate = L10n.tr("Localizable", "channel.new.createPrivate", fallback: "New Group")
      /// New Channel
      public static let createPublic = L10n.tr("Localizable", "channel.new.createPublic", fallback: "New Channel")
      /// Start Chat
      public static let title = L10n.tr("Localizable", "channel.new.title", fallback: "Start Chat")
      /// Users
      public static let userSectionTitle = L10n.tr("Localizable", "channel.new.userSectionTitle", fallback: "Users")
    }
    public enum NoMessages {
      /// No messages yet, start the chat
      public static let message = L10n.tr("Localizable", "channel.noMessages.message", fallback: "No messages yet, start the chat")
      /// No Messages yet
      public static let title = L10n.tr("Localizable", "channel.noMessages.title", fallback: "No Messages yet")
    }
    public enum Private {
      /// Members
      public static let sectionTitle = L10n.tr("Localizable", "channel.private.sectionTitle", fallback: "Members")
    }
    public enum Profile {
      /// Show or send this to anyone who wants to join this channel
      public static let qrCodeDescription = L10n.tr("Localizable", "channel.profile.qrCodeDescription", fallback: "Show or send this to anyone who wants to join this channel")
      /// Share QR Code
      public static let qrCodeShare = L10n.tr("Localizable", "channel.profile.qrCodeShare", fallback: "Share QR Code")
      /// QR Code for Invites
      public static let qrCodeTitle = L10n.tr("Localizable", "channel.profile.qrCodeTitle", fallback: "QR Code for Invites")
    }
    public enum ReadOnly {
      /// Read Only.
      public static let message = L10n.tr("Localizable", "channel.readOnly.message", fallback: "Read Only.")
    }
    public enum Search {
      /// %d of %d
      public static func foundIndex(_ p1: Int, _ p2: Int) -> String {
        return L10n.tr("Localizable", "channel.search.found-index", p1, p2, fallback: "%d of %d")
      }
      /// Not found
      public static let notFound = L10n.tr("Localizable", "channel.search.not-found", fallback: "Not found")
      /// Search
      public static let search = L10n.tr("Localizable", "channel.search.search", fallback: "Search")
    }
    public enum Selecting {
      /// Clear Messages
      public static let clearChat = L10n.tr("Localizable", "channel.selecting.clearChat", fallback: "Clear Messages")
      /// %d Selected
      public static func selected(_ p1: Int) -> String {
        return L10n.tr("Localizable", "channel.selecting.selected", p1, fallback: "%d Selected")
      }
      public enum ClearChat {
        /// Clear
        public static let clear = L10n.tr("Localizable", "channel.selecting.clearChat.clear", fallback: "Clear")
        /// Once you clear the messages in this chat will be permanently removed for you.
        public static let message = L10n.tr("Localizable", "channel.selecting.clearChat.message", fallback: "Once you clear the messages in this chat will be permanently removed for you.")
        public enum Channel {
          /// Once you clear the messages in this channel will be permanently removed for all the subscribers.
          public static let message = L10n.tr("Localizable", "channel.selecting.clearChat.channel.message", fallback: "Once you clear the messages in this channel will be permanently removed for all the subscribers.")
        }
      }
    }
    public enum `Self` {
      /// message yourself
      public static let hint = L10n.tr("Localizable", "channel.self.hint", fallback: "message yourself")
      /// Me
      public static let title = L10n.tr("Localizable", "channel.self.title", fallback: "Me")
    }
    public enum StopRecording {
      /// Are you sure you want to stop recording and discard your voice message?
      public static let message = L10n.tr("Localizable", "channel.stopRecording.message", fallback: "Are you sure you want to stop recording and discard your voice message?")
    }
    public enum Subject {
      /// About
      public static let descriptionPlaceholder = L10n.tr("Localizable", "channel.subject.descriptionPlaceholder", fallback: "About")
      public enum Channel {
        /// Channel Name
        public static let placeholder = L10n.tr("Localizable", "channel.subject.channel.placeholder", fallback: "Channel Name")
      }
      public enum Group {
        /// Group Name
        public static let placeholder = L10n.tr("Localizable", "channel.subject.group.placeholder", fallback: "Group Name")
      }
    }
    public enum SubscriberCount {
      /// %d subscribers
      public static func more(_ p1: Int) -> String {
        return L10n.tr("Localizable", "channel.subscriber-count.more", p1, fallback: "%d subscribers")
      }
      /// 1 subscriber
      public static let one = L10n.tr("Localizable", "channel.subscriber-count.one", fallback: "1 subscriber")
    }
  }
  public enum Common {
    /// Off
    public static let off = L10n.tr("Localizable", "common.off", fallback: "Off")
    /// Localizable.strings
    ///   SceytChatUIKit
    /// 
    ///   Created by Hovsep on 5/27/22.
    ///   Copyright © 2022 Sceyt LLC. All rights reserved.
    public static let on = L10n.tr("Localizable", "common.on", fallback: "On")
  }
  public enum Connection {
    /// Try Again
    public static let tryAgain = L10n.tr("Localizable", "connection.tryAgain", fallback: "Try Again")
    public enum Error {
      /// Network Error
      public static let networkLost = L10n.tr("Localizable", "connection.error.networkLost", fallback: "Network Error")
      public enum Try {
        /// We’re unable to complete your request. Please try again.
        public static let again = L10n.tr("Localizable", "connection.error.try.again", fallback: "We’re unable to complete your request. Please try again.")
      }
    }
    public enum State {
      /// Connected
      public static let connected = L10n.tr("Localizable", "connection.state.connected", fallback: "Connected")
      /// Connecting
      public static let connecting = L10n.tr("Localizable", "connection.state.connecting", fallback: "Connecting")
      /// Disconnected
      public static let disconnected = L10n.tr("Localizable", "connection.state.disconnected", fallback: "Disconnected")
      /// Connection Failed
      public static let failed = L10n.tr("Localizable", "connection.state.failed", fallback: "Connection Failed")
      /// Connecting
      public static let reconnecting = L10n.tr("Localizable", "connection.state.reconnecting", fallback: "Connecting")
    }
  }
  public enum Emoji {
    /// Frequently used
    public static let recent = L10n.tr("Localizable", "emoji.recent", fallback: "Frequently used")
  }
  public enum Error {
    /// Maximum 20 items allowed
    public static let max20Items = L10n.tr("Localizable", "error.max20Items", fallback: "Maximum 20 items allowed")
    /// Maximum %d items allowed
    public static func maxValueItems(_ p1: Int) -> String {
      return L10n.tr("Localizable", "error.maxValueItems", p1, fallback: "Maximum %d items allowed")
    }
  }
  public enum ImageCropper {
    /// Move and Scale
    public static let moveAndScale = L10n.tr("Localizable", "imageCropper.moveAndScale", fallback: "Move and Scale")
  }
  public enum ImagePicker {
    /// Gallery
    public static let title = L10n.tr("Localizable", "imagePicker.title", fallback: "Gallery")
    public enum Attach {
      public enum Button {
        /// Attach
        public static let title = L10n.tr("Localizable", "imagePicker.attach.button.title", fallback: "Attach")
      }
    }
    public enum ManageAccess {
      /// Manage
      public static let action = L10n.tr("Localizable", "imagePicker.manageAccess.action", fallback: "Manage")
      /// Change Settings
      public static let change = L10n.tr("Localizable", "imagePicker.manageAccess.change", fallback: "Change Settings")
      /// Select More
      public static let more = L10n.tr("Localizable", "imagePicker.manageAccess.more", fallback: "Select More")
    }
  }
  public enum Input {
    /// Edit message
    public static let edit = L10n.tr("Localizable", "input.edit", fallback: "Edit message")
    /// Reply
    public static let reply = L10n.tr("Localizable", "input.reply", fallback: "Reply")
  }
  public enum JoinGroup {
    public enum Button {
      /// Join Group
      public static let join = L10n.tr("Localizable", "joinGroup.button.join", fallback: "Join Group")
      /// Joining...
      public static let joining = L10n.tr("Localizable", "joinGroup.button.joining", fallback: "Joining...")
    }
    public enum Description {
      /// Group Chat Invite
      public static let `default` = L10n.tr("Localizable", "joinGroup.description.default", fallback: "Group Chat Invite")
    }
    public enum Error {
      /// Invalid invite link
      public static let invalidLink = L10n.tr("Localizable", "joinGroup.error.invalidLink", fallback: "Invalid invite link")
    }
    public enum Members {
      /// %@ and %@
      public static func format(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "joinGroup.members.format", String(describing: p1), String(describing: p2), fallback: "%@ and %@")
      }
      /// 1 other
      public static let oneOther = L10n.tr("Localizable", "joinGroup.members.one-other", fallback: "1 other")
      /// %d others
      public static func others(_ p1: Int) -> String {
        return L10n.tr("Localizable", "joinGroup.members.others", p1, fallback: "%d others")
      }
    }
  }
  public enum Link {
    /// Copy link
    public static let copy = L10n.tr("Localizable", "link.copy", fallback: "Copy link")
    /// Open in ...
    public static let openIn = L10n.tr("Localizable", "link.openIn", fallback: "Open in ...")
  }
  public enum Message {
    /// Message was deleted.
    public static let deleted = L10n.tr("Localizable", "message.deleted", fallback: "Message was deleted.")
    /// Read more
    public static let readMore = L10n.tr("Localizable", "message.readMore", fallback: "Read more")
    public enum Action {
      public enum Subtitle {
        /// Delete For All
        public static let deleteAll = L10n.tr("Localizable", "message.action.subtitle.deleteAll", fallback: "Delete For All")
        /// Delete For Me
        public static let deleteMe = L10n.tr("Localizable", "message.action.subtitle.deleteMe", fallback: "Delete For Me")
      }
      public enum Title {
        /// Add
        public static let add = L10n.tr("Localizable", "message.action.title.add", fallback: "Add")
        /// Audio Call
        public static let audioCall = L10n.tr("Localizable", "message.action.title.audioCall", fallback: "Audio Call")
        /// Call
        public static let call = L10n.tr("Localizable", "message.action.title.call", fallback: "Call")
        /// Chat
        public static let chat = L10n.tr("Localizable", "message.action.title.chat", fallback: "Chat")
        /// Copy
        public static let copy = L10n.tr("Localizable", "message.action.title.copy", fallback: "Copy")
        /// Copy Number
        public static let copyNumber = L10n.tr("Localizable", "message.action.title.copyNumber", fallback: "Copy Number")
        /// Delete
        public static let delete = L10n.tr("Localizable", "message.action.title.delete", fallback: "Delete")
        /// Edit
        public static let edit = L10n.tr("Localizable", "message.action.title.edit", fallback: "Edit")
        /// Forward
        public static let forward = L10n.tr("Localizable", "message.action.title.forward", fallback: "Forward")
        /// Info
        public static let info = L10n.tr("Localizable", "message.action.title.info", fallback: "Info")
        /// React
        public static let react = L10n.tr("Localizable", "message.action.title.react", fallback: "React")
        /// Remove
        public static let remove = L10n.tr("Localizable", "message.action.title.remove", fallback: "Remove")
        /// Reply
        public static let reply = L10n.tr("Localizable", "message.action.title.reply", fallback: "Reply")
        /// Reply in thread
        public static let replyInThread = L10n.tr("Localizable", "message.action.title.reply-in-thread", fallback: "Reply in thread")
        /// Report
        public static let report = L10n.tr("Localizable", "message.action.title.report", fallback: "Report")
        /// Select
        public static let select = L10n.tr("Localizable", "message.action.title.select", fallback: "Select")
        /// Video Call
        public static let videoCall = L10n.tr("Localizable", "message.action.title.videoCall", fallback: "Video Call")
      }
    }
    public enum Alert {
      public enum Delete {
        /// Are you sure you want to delete this message?
        public static let description = L10n.tr("Localizable", "message.alert.delete.description", fallback: "Are you sure you want to delete this message?")
        /// Delete message?
        public static let title = L10n.tr("Localizable", "message.alert.delete.title", fallback: "Delete message?")
      }
    }
    public enum Attachment {
      /// File
      public static let file = L10n.tr("Localizable", "message.attachment.file", fallback: "File")
      /// Photo
      public static let image = L10n.tr("Localizable", "message.attachment.image", fallback: "Photo")
      /// Link
      public static let link = L10n.tr("Localizable", "message.attachment.link", fallback: "Link")
      /// Video
      public static let video = L10n.tr("Localizable", "message.attachment.video", fallback: "Video")
      /// Voice
      public static let voice = L10n.tr("Localizable", "message.attachment.voice", fallback: "Voice")
    }
    public enum Forward {
      /// Forwarded message
      public static let title = L10n.tr("Localizable", "message.forward.title", fallback: "Forwarded message")
    }
    public enum Info {
      /// Delivered to
      public static let deliveredTo = L10n.tr("Localizable", "message.info.deliveredTo", fallback: "Delivered to")
      /// edited
      public static let edited = L10n.tr("Localizable", "message.info.edited", fallback: "edited")
      /// Played by
      public static let playedBy = L10n.tr("Localizable", "message.info.playedBy", fallback: "Played by")
      /// Seen by
      public static let readBy = L10n.tr("Localizable", "message.info.readBy", fallback: "Seen by")
      /// Sent:
      public static let sent = L10n.tr("Localizable", "message.info.sent", fallback: "Sent:")
      /// Size:
      public static let size = L10n.tr("Localizable", "message.info.size", fallback: "Size:")
      /// Message Info
      public static let title = L10n.tr("Localizable", "message.info.title", fallback: "Message Info")
    }
    public enum Input {
      /// Write a message...
      public static let placeholder = L10n.tr("Localizable", "message.input.placeholder", fallback: "Write a message...")
    }
    public enum List {
      /// Today
      public static let bordersToday = L10n.tr("Localizable", "message.list.borders-today", fallback: "Today")
      /// New Messages
      public static let unread = L10n.tr("Localizable", "message.list.unread", fallback: "New Messages")
    }
    public enum Reply {
      /// %d Replies
      public static func count(_ p1: Int) -> String {
        return L10n.tr("Localizable", "message.reply.count", p1, fallback: "%d Replies")
      }
    }
    public enum Unsupported {
      /// This message is not supported.
      public static let text = L10n.tr("Localizable", "message.unsupported.text", fallback: "This message is not supported.")
    }
  }
  public enum Nav {
    public enum Bar {
      /// Add
      public static let add = L10n.tr("Localizable", "nav.bar.add", fallback: "Add")
      /// Cancel
      public static let cancel = L10n.tr("Localizable", "nav.bar.cancel", fallback: "Cancel")
      /// Close
      public static let close = L10n.tr("Localizable", "nav.bar.close", fallback: "Close")
      /// Confirm
      public static let confirm = L10n.tr("Localizable", "nav.bar.confirm", fallback: "Confirm")
      /// Create
      public static let create = L10n.tr("Localizable", "nav.bar.create", fallback: "Create")
      /// Done
      public static let done = L10n.tr("Localizable", "nav.bar.done", fallback: "Done")
      /// Edit
      public static let edit = L10n.tr("Localizable", "nav.bar.edit", fallback: "Edit")
      /// Forward
      public static let forward = L10n.tr("Localizable", "nav.bar.forward", fallback: "Forward")
      /// Next
      public static let next = L10n.tr("Localizable", "nav.bar.next", fallback: "Next")
      /// Update
      public static let update = L10n.tr("Localizable", "nav.bar.update", fallback: "Update")
    }
  }
  public enum Poll {
    /// Anonymous poll
    public static let anonymousPoll = L10n.tr("Localizable", "poll.anonymousPoll", fallback: "Anonymous poll")
    /// Can't retract votes
    public static let cantRetractVotes = L10n.tr("Localizable", "poll.cantRetractVotes", fallback: "Can't retract votes")
    /// Multiple votes
    public static let multipleVotes = L10n.tr("Localizable", "poll.multipleVotes", fallback: "Multiple votes")
    /// Poll
    public static let title = L10n.tr("Localizable", "poll.title", fallback: "Poll")
    public enum Button {
      /// Cancel
      public static let cancel = L10n.tr("Localizable", "poll.button.cancel", fallback: "Cancel")
      /// Send
      public static let send = L10n.tr("Localizable", "poll.button.send", fallback: "Send")
    }
    public enum Discard {
      public enum Alert {
        /// Discard
        public static let discard = L10n.tr("Localizable", "poll.discard.alert.discard", fallback: "Discard")
        /// Cancel
        public static let keepEditing = L10n.tr("Localizable", "poll.discard.alert.keepEditing", fallback: "Cancel")
        /// Are you sure you want to discard your poll?
        public static let message = L10n.tr("Localizable", "poll.discard.alert.message", fallback: "Are you sure you want to discard your poll?")
      }
    }
    public enum EndPoll {
      public enum Alert {
        /// End
        public static let end = L10n.tr("Localizable", "poll.endPoll.alert.end", fallback: "End")
        /// Are you sure you want to end this poll? People will no longer be able to vote.
        public static let message = L10n.tr("Localizable", "poll.endPoll.alert.message", fallback: "Are you sure you want to end this poll? People will no longer be able to vote.")
        /// End Poll
        public static let title = L10n.tr("Localizable", "poll.endPoll.alert.title", fallback: "End Poll")
      }
    }
    public enum Option {
      /// Add an option
      public static let add = L10n.tr("Localizable", "poll.option.add", fallback: "Add an option")
      /// Add
      public static let placeholder = L10n.tr("Localizable", "poll.option.placeholder", fallback: "Add")
    }
    public enum OptionDetail {
      /// Close
      public static let close = L10n.tr("Localizable", "poll.optionDetail.close", fallback: "Close")
      /// Poll Option
      public static let title = L10n.tr("Localizable", "poll.optionDetail.title", fallback: "Poll Option")
    }
    public enum Options {
      /// OPTIONS
      public static let header = L10n.tr("Localizable", "poll.options.header", fallback: "OPTIONS")
    }
    public enum Parameters {
      /// PARAMETERS
      public static let header = L10n.tr("Localizable", "poll.parameters.header", fallback: "PARAMETERS")
    }
    public enum Question {
      /// QUESTION
      public static let header = L10n.tr("Localizable", "poll.question.header", fallback: "QUESTION")
      /// Add question
      public static let placeholder = L10n.tr("Localizable", "poll.question.placeholder", fallback: "Add question")
    }
    public enum Results {
      /// Show All
      public static let showMore = L10n.tr("Localizable", "poll.results.showMore", fallback: "Show All")
      /// Poll Results
      public static let title = L10n.tr("Localizable", "poll.results.title", fallback: "Poll Results")
      /// View Results
      public static let viewResults = L10n.tr("Localizable", "poll.results.viewResults", fallback: "View Results")
    }
    public enum Types {
      /// Anonymous poll
      public static let anonymous = L10n.tr("Localizable", "poll.types.anonymous", fallback: "Anonymous poll")
      /// Poll finished
      public static let finished = L10n.tr("Localizable", "poll.types.finished", fallback: "Poll finished")
      /// Multiple Votes
      public static let multipleVotes = L10n.tr("Localizable", "poll.types.multipleVotes", fallback: "Multiple Votes")
      /// Single Vote
      public static let singleVote = L10n.tr("Localizable", "poll.types.singleVote", fallback: "Single Vote")
    }
  }
  public enum Previewer {
    /// Forward
    public static let forward = L10n.tr("Localizable", "previewer.forward", fallback: "Forward")
    /// Your photo was successfully saved
    public static let photoSaved = L10n.tr("Localizable", "previewer.photoSaved", fallback: "Your photo was successfully saved")
    /// Save Photo
    public static let savePhoto = L10n.tr("Localizable", "previewer.savePhoto", fallback: "Save Photo")
    /// Save Video
    public static let saveVideo = L10n.tr("Localizable", "previewer.saveVideo", fallback: "Save Video")
    /// Share Photo
    public static let sharePhoto = L10n.tr("Localizable", "previewer.sharePhoto", fallback: "Share Photo")
    /// Share Video
    public static let shareVideo = L10n.tr("Localizable", "previewer.shareVideo", fallback: "Share Video")
    /// Your video was successfully saved
    public static let videoSaved = L10n.tr("Localizable", "previewer.videoSaved", fallback: "Your video was successfully saved")
  }
  public enum Recorder {
    /// Cancel
    public static let cancel = L10n.tr("Localizable", "recorder.cancel", fallback: "Cancel")
    /// < Slide to cancel
    public static let slideToCancel = L10n.tr("Localizable", "recorder.slideToCancel", fallback: "< Slide to cancel")
  }
  public enum Report {
    /// Report
    public static let title = L10n.tr("Localizable", "report.title", fallback: "Report")
    public enum Additional {
      /// Additional details
      public static let details = L10n.tr("Localizable", "report.additional.details", fallback: "Additional details")
      /// Please enter any additional details
      public static let title = L10n.tr("Localizable", "report.additional.title", fallback: "Please enter any additional details")
    }
  }
  public enum Search {
    public enum Category {
      /// Chats
      public static let chats = L10n.tr("Localizable", "search.category.chats", fallback: "Chats")
      /// Channels
      public static let channels = L10n.tr("Localizable", "search.category.channels", fallback: "Channels")
      /// Media
      public static let media = L10n.tr("Localizable", "search.category.media", fallback: "Media")
      /// Voice
      public static let voice = L10n.tr("Localizable", "search.category.voice", fallback: "Voice")
      /// Files
      public static let files = L10n.tr("Localizable", "search.category.files", fallback: "Files")
      /// Links
      public static let links = L10n.tr("Localizable", "search.category.links", fallback: "Links")
      /// Messages
      public static let messages = L10n.tr("Localizable", "search.category.messages", fallback: "Messages")
    }
    public enum NoResults {
      /// There were no results found.
      public static let message = L10n.tr("Localizable", "search.noResults.message", fallback: "There were no results found.")
      /// No Results
      public static let title = L10n.tr("Localizable", "search.noResults.title", fallback: "No Results")
    }
  }
  public enum SearchBar {
    /// Search
    public static let placeholder = L10n.tr("Localizable", "searchBar.placeholder", fallback: "Search")
  }
  public enum System {
    public enum Message {
      /// %@ added %@
      public static func addGroupMember(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "system.message.addGroupMember", String(describing: p1), String(describing: p2), fallback: "%@ added %@")
      }
      /// %@ created the channel
      public static func createChannel(_ p1: Any) -> String {
        return L10n.tr("Localizable", "system.message.createChannel", String(describing: p1), fallback: "%@ created the channel")
      }
      /// %@ created the group
      public static func createGroup(_ p1: Any) -> String {
        return L10n.tr("Localizable", "system.message.createGroup", String(describing: p1), fallback: "%@ created the group")
      }
      /// %@ disabled disappearing messages
      public static func disableDisappearingMessages(_ p1: Any) -> String {
        return L10n.tr("Localizable", "system.message.disableDisappearingMessages", String(describing: p1), fallback: "%@ disabled disappearing messages")
      }
      /// %@ joined via invite link
      public static func joinByInviteLink(_ p1: Any) -> String {
        return L10n.tr("Localizable", "system.message.joinByInviteLink", String(describing: p1), fallback: "%@ joined via invite link")
      }
      /// %@ left the group
      public static func leaveGroup(_ p1: Any) -> String {
        return L10n.tr("Localizable", "system.message.leaveGroup", String(describing: p1), fallback: "%@ left the group")
      }
      /// %@ removed %@
      public static func removeGroupMember(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "system.message.removeGroupMember", String(describing: p1), String(describing: p2), fallback: "%@ removed %@")
      }
      /// %@ set the disappearing messages timer to %@
      public static func setDisappearingMessageTime(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "system.message.setDisappearingMessageTime", String(describing: p1), String(describing: p2), fallback: "%@ set the disappearing messages timer to %@")
      }
    }
  }
  public enum Time {
    public enum Interval {
      /// Off
      public static let off = L10n.tr("Localizable", "time.interval.off", fallback: "Off")
      public enum Day {
        /// %d days
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.day.multiple", p1, fallback: "%d days")
        }
        /// 1 day
        public static let one = L10n.tr("Localizable", "time.interval.day.one", fallback: "1 day")
      }
      public enum Format {
        /// %@ and %@
        public static func end(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "time.interval.format.end", String(describing: p1), String(describing: p2), fallback: "%@ and %@")
        }
        /// %@, %@
        public static func middle(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "time.interval.format.middle", String(describing: p1), String(describing: p2), fallback: "%@, %@")
        }
      }
      public enum Hour {
        /// %d hours
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.hour.multiple", p1, fallback: "%d hours")
        }
        /// 1 hour
        public static let one = L10n.tr("Localizable", "time.interval.hour.one", fallback: "1 hour")
      }
      public enum Minute {
        /// %d minutes
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.minute.multiple", p1, fallback: "%d minutes")
        }
        /// 1 minute
        public static let one = L10n.tr("Localizable", "time.interval.minute.one", fallback: "1 minute")
      }
      public enum Month {
        /// %d months
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.month.multiple", p1, fallback: "%d months")
        }
        /// 1 month
        public static let one = L10n.tr("Localizable", "time.interval.month.one", fallback: "1 month")
      }
      public enum Second {
        /// %d seconds
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.second.multiple", p1, fallback: "%d seconds")
        }
        /// 1 second
        public static let one = L10n.tr("Localizable", "time.interval.second.one", fallback: "1 second")
      }
      public enum Week {
        /// %d weeks
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.week.multiple", p1, fallback: "%d weeks")
        }
        /// 1 week
        public static let one = L10n.tr("Localizable", "time.interval.week.one", fallback: "1 week")
      }
      public enum Year {
        /// %d years
        public static func multiple(_ p1: Int) -> String {
          return L10n.tr("Localizable", "time.interval.year.multiple", p1, fallback: "%d years")
        }
        /// 1 year
        public static let one = L10n.tr("Localizable", "time.interval.year.one", fallback: "1 year")
      }
    }
  }
  public enum Upload {
    /// Preparing...
    public static let preparing = L10n.tr("Localizable", "upload.preparing", fallback: "Preparing...")
  }
  public enum User {
    /// You
    public static let current = L10n.tr("Localizable", "user.current", fallback: "You")
    /// Deleted user
    public static let deleted = L10n.tr("Localizable", "user.deleted", fallback: "Deleted user")
    /// Inactive user
    public static let inactive = L10n.tr("Localizable", "user.inactive", fallback: "Inactive user")
    public enum Last {
      /// last seen %@
      public static func seen(_ p1: Any) -> String {
        return L10n.tr("Localizable", "user.last.seen", String(describing: p1), fallback: "last seen %@")
      }
      public enum Seen {
        /// last seen %@ at %@
        public static func at(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.at", String(describing: p1), String(describing: p2), fallback: "last seen %@ at %@")
        }
        /// last seen %@ minute ago
        public static func minAgo(_ p1: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.minAgo", String(describing: p1), fallback: "last seen %@ minute ago")
        }
        /// last seen %@ minutes ago
        public static func minsAgo(_ p1: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.minsAgo", String(describing: p1), fallback: "last seen %@ minutes ago")
        }
        /// Yesterday
        public static let yesterday = L10n.tr("Localizable", "user.last.seen.yesterday", fallback: "Yesterday")
      }
    }
    public enum Presence {
      /// away
      public static let away = L10n.tr("Localizable", "user.presence.away", fallback: "away")
      /// DND
      public static let dnd = L10n.tr("Localizable", "user.presence.dnd", fallback: "DND")
      /// offline
      public static let offline = L10n.tr("Localizable", "user.presence.offline", fallback: "offline")
      /// online
      public static let online = L10n.tr("Localizable", "user.presence.online", fallback: "online")
    }
  }
  public enum ViewOnce {
    /// Message self-destructed
    public static let selfDestructed = L10n.tr("Localizable", "viewOnce.selfDestructed", fallback: "Message self-destructed")
    /// Self-destructed %@
    public static func selfDestructedAttachment(_ p1: Any) -> String {
      return L10n.tr("Localizable", "viewOnce.selfDestructedAttachment", String(describing: p1), fallback: "Self-destructed %@")
    }
    public enum Info {
      /// Any photo, video, or voice message you send will disappear from the chat after it's been opened.
      /// To keep your content private, recipients won't be able to share, forward, copy, save, or take screenshots.
      public static let description = L10n.tr("Localizable", "viewOnce.info.description", fallback: "Any photo, video, or voice message you send will disappear from the chat after it's been opened.\nTo keep your content private, recipients won't be able to share, forward, copy, save, or take screenshots.")
      /// View once messages
      public static let title = L10n.tr("Localizable", "viewOnce.info.title", fallback: "View once messages")
    }
    public enum Screenshot {
      public enum Alert {
        /// Screen capture has been restricted to ensure user privacy.
        public static let message = L10n.tr("Localizable", "viewOnce.screenshot.alert.message", fallback: "Screen capture has been restricted to ensure user privacy.")
        /// Screenshot Blocked
        public static let title = L10n.tr("Localizable", "viewOnce.screenshot.alert.title", fallback: "Screenshot Blocked")
      }
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
