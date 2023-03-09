// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Alert {
    internal enum Button {
      /// Cancel
      internal static let cancel = L10n.tr("Localizable", "alert.button.cancel", fallback: "Cancel")
      /// Delete
      internal static let delete = L10n.tr("Localizable", "alert.button.delete", fallback: "Delete")
      /// Ok
      internal static let ok = L10n.tr("Localizable", "alert.button.ok", fallback: "Ok")
      /// Camera
      internal static let openCamera = L10n.tr("Localizable", "alert.button.open-camera", fallback: "Camera")
      /// Upload from Files
      internal static let openFiles = L10n.tr("Localizable", "alert.button.open-files", fallback: "Upload from Files")
      /// Upload from Gallery
      internal static let openGallery = L10n.tr("Localizable", "alert.button.open-gallery", fallback: "Upload from Gallery")
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
    /// Take Photo
    internal static let takePhoto = L10n.tr("Localizable", "capture.takePhoto", fallback: "Take Photo")
  }
  internal enum Channel {
    /// JOIN
    internal static let join = L10n.tr("Localizable", "channel.join", fallback: "JOIN")
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
    internal enum Admin {
      /// Add admins
      internal static let add = L10n.tr("Localizable", "channel.admin.add", fallback: "Add admins")
    }
    internal enum Avatar {
      /// Name the chat and upload a photo if you want
      internal static let comment = L10n.tr("Localizable", "channel.avatar.comment", fallback: "Name the chat and upload a photo if you want")
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
    internal enum Empty {
      /// Create channel
      internal static let createNew = L10n.tr("Localizable", "channel.empty.create-new", fallback: "Create channel")
      /// You have no channels created yet, create one and send messages
      internal static let description = L10n.tr("Localizable", "channel.empty.description", fallback: "You have no channels created yet, create one and send messages")
      /// Localizable.strings
      ///   SceytChatUIKit
      /// 
      ///   Created by Hovsep on 5/27/22.
      internal static let title = L10n.tr("Localizable", "channel.empty.title", fallback: "No Channels")
    }
    internal enum Intro {
      /// New Channel
      internal static let title = L10n.tr("Localizable", "channel.intro.title", fallback: "New Channel")
    }
    internal enum List {
      /// Search for channels
      internal static let search = L10n.tr("Localizable", "channel.list.search", fallback: "Search for channels")
      /// Channels
      internal static let title = L10n.tr("Localizable", "channel.list.title", fallback: "Channels")
      internal enum Action {
        /// Delete
        internal static let delete = L10n.tr("Localizable", "channel.list.action.delete", fallback: "Delete")
        /// Leave
        internal static let leave = L10n.tr("Localizable", "channel.list.action.leave", fallback: "Leave")
        /// Read
        internal static let read = L10n.tr("Localizable", "channel.list.action.read", fallback: "Read")
        /// Unread
        internal static let unread = L10n.tr("Localizable", "channel.list.action.unread", fallback: "Unread")
      }
    }
    internal enum Member {
      /// Add members
      internal static let add = L10n.tr("Localizable", "channel.member.add", fallback: "Add members")
      /// Deleted User
      internal static let deleted = L10n.tr("Localizable", "channel.member.deleted", fallback: "Deleted User")
      /// Inactive User
      internal static let inactive = L10n.tr("Localizable", "channel.member.inactive", fallback: "Inactive User")
      /// typing
      internal static let typing = L10n.tr("Localizable", "channel.member.typing", fallback: "typing")
      internal enum Role {
        /// Change role
        internal static let title = L10n.tr("Localizable", "channel.member.role.title", fallback: "Change role")
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
    }
    internal enum New {
      /// New Group
      internal static let createPrivate = L10n.tr("Localizable", "channel.new.createPrivate", fallback: "New Group")
      /// Create Channel
      internal static let createPublic = L10n.tr("Localizable", "channel.new.createPublic", fallback: "Create Channel")
      /// Start Chat
      internal static let title = L10n.tr("Localizable", "channel.new.title", fallback: "Start Chat")
      /// Users
      internal static let userSectionTitle = L10n.tr("Localizable", "channel.new.userSectionTitle", fallback: "Users")
    }
    internal enum Peer {
      /// You blocked this user
      internal static let blocked = L10n.tr("Localizable", "channel.peer.blocked", fallback: "You blocked this user")
    }
    internal enum Private {
      /// Members
      internal static let sectionTitle = L10n.tr("Localizable", "channel.private.sectionTitle", fallback: "Members")
    }
    internal enum Profile {
      /// Subject
      internal static let subject = L10n.tr("Localizable", "channel.profile.subject", fallback: "Subject")
      internal enum Action {
        /// Block user
        internal static let block = L10n.tr("Localizable", "channel.profile.action.block", fallback: "Block user")
        /// Block & Kick member
        internal static let blockAndKickMember = L10n.tr("Localizable", "channel.profile.action.block-and-kick-member", fallback: "Block & Kick member")
        /// Change member’s role
        internal static let changeRole = L10n.tr("Localizable", "channel.profile.action.change-role", fallback: "Change member’s role")
        /// Clear History
        internal static let clearHistory = L10n.tr("Localizable", "channel.profile.action.clear-history", fallback: "Clear History")
        /// join
        internal static let join = L10n.tr("Localizable", "channel.profile.action.join", fallback: "join")
        /// Kick member
        internal static let kickMember = L10n.tr("Localizable", "channel.profile.action.kick-member", fallback: "Kick member")
        /// more
        internal static let more = L10n.tr("Localizable", "channel.profile.action.more", fallback: "more")
        /// mute
        internal static let mute = L10n.tr("Localizable", "channel.profile.action.mute", fallback: "mute")
        /// report
        internal static let report = L10n.tr("Localizable", "channel.profile.action.report", fallback: "report")
        /// Set owner
        internal static let setOwner = L10n.tr("Localizable", "channel.profile.action.set-owner", fallback: "Set owner")
        /// Unblock user
        internal static let unblock = L10n.tr("Localizable", "channel.profile.action.unblock", fallback: "Unblock user")
        /// unmute
        internal static let unmute = L10n.tr("Localizable", "channel.profile.action.unmute", fallback: "unmute")
        internal enum Channel {
          /// Block & leave channel
          internal static let blockAndLeave = L10n.tr("Localizable", "channel.profile.action.channel.block-and-leave", fallback: "Block & leave channel")
          /// Delete channel
          internal static let delete = L10n.tr("Localizable", "channel.profile.action.channel.delete", fallback: "Delete channel")
          /// Leave Channel
          internal static let leave = L10n.tr("Localizable", "channel.profile.action.channel.leave", fallback: "Leave Channel")
        }
        internal enum Chat {
          /// Delete chat
          internal static let delete = L10n.tr("Localizable", "channel.profile.action.chat.delete", fallback: "Delete chat")
        }
        internal enum Group {
          /// Block & leave group
          internal static let blockAndLeave = L10n.tr("Localizable", "channel.profile.action.group.block-and-leave", fallback: "Block & leave group")
          /// Delete channel
          internal static let delete = L10n.tr("Localizable", "channel.profile.action.group.delete", fallback: "Delete channel")
          /// Leave Group
          internal static let leave = L10n.tr("Localizable", "channel.profile.action.group.leave", fallback: "Leave Group")
        }
      }
      internal enum Admins {
        /// Admins
        internal static let title = L10n.tr("Localizable", "channel.profile.admins.title", fallback: "Admins")
      }
      internal enum Item {
        internal enum Title {
          /// Admins
          internal static let admins = L10n.tr("Localizable", "channel.profile.item.title.admins", fallback: "Admins")
          /// Members
          internal static let members = L10n.tr("Localizable", "channel.profile.item.title.members", fallback: "Members")
          /// Subscribers
          internal static let subscribers = L10n.tr("Localizable", "channel.profile.item.title.subscribers", fallback: "Subscribers")
        }
      }
      internal enum Members {
        /// Members
        internal static let title = L10n.tr("Localizable", "channel.profile.members.title", fallback: "Members")
      }
      internal enum Mute {
        /// Mute for %d days
        internal static func days(_ p1: Int) -> String {
          return L10n.tr("Localizable", "channel.profile.mute.days", p1, fallback: "Mute for %d days")
        }
        /// Mute Forever
        internal static let forever = L10n.tr("Localizable", "channel.profile.mute.forever", fallback: "Mute Forever")
        /// Mute for %d hours
        internal static func hours(_ p1: Int) -> String {
          return L10n.tr("Localizable", "channel.profile.mute.hours", p1, fallback: "Mute for %d hours")
        }
        /// Mute for 1 day
        internal static let oneDay = L10n.tr("Localizable", "channel.profile.mute.one-day", fallback: "Mute for 1 day")
        /// Mute for 1 hour
        internal static let oneHour = L10n.tr("Localizable", "channel.profile.mute.one-hour", fallback: "Mute for 1 hour")
        /// Mute Chat:
        internal static let title = L10n.tr("Localizable", "channel.profile.mute.title", fallback: "Mute Chat:")
      }
      internal enum Segment {
        /// Files
        internal static let files = L10n.tr("Localizable", "channel.profile.segment.files", fallback: "Files")
        /// Links
        internal static let links = L10n.tr("Localizable", "channel.profile.segment.links", fallback: "Links")
        /// Medias
        internal static let medias = L10n.tr("Localizable", "channel.profile.segment.medias", fallback: "Medias")
        /// Members
        internal static let members = L10n.tr("Localizable", "channel.profile.segment.members", fallback: "Members")
        /// Voice
        internal static let voice = L10n.tr("Localizable", "channel.profile.segment.voice", fallback: "Voice")
      }
    }
    internal enum Subject {
      /// Description
      internal static let descriptionPlaceholder = L10n.tr("Localizable", "channel.subject.descriptionPlaceholder", fallback: "Description")
      /// Subject
      internal static let placeholder = L10n.tr("Localizable", "channel.subject.placeholder", fallback: "Subject")
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
  internal enum Error {
    /// Maximum 20 items allowed
    internal static let max20Items = L10n.tr("Localizable", "error.max20Items", fallback: "Maximum 20 items allowed")
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
  }
  internal enum Message {
    /// Message was deleted.
    internal static let deleted = L10n.tr("Localizable", "message.deleted", fallback: "Message was deleted.")
    internal enum Action {
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
        /// React
        internal static let react = L10n.tr("Localizable", "message.action.title.react", fallback: "React")
        /// Remove
        internal static let remove = L10n.tr("Localizable", "message.action.title.remove", fallback: "Remove")
        /// Reply
        internal static let reply = L10n.tr("Localizable", "message.action.title.reply", fallback: "Reply")
        /// Reply in thread
        internal static let replyInThread = L10n.tr("Localizable", "message.action.title.reply-in-thread", fallback: "Reply in thread")
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
      /// edited
      internal static let edited = L10n.tr("Localizable", "message.info.edited", fallback: "edited")
    }
    internal enum Input {
      /// Message
      internal static let placeholder = L10n.tr("Localizable", "message.input.placeholder", fallback: "Message")
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
  internal enum User {
    /// You
    internal static let current = L10n.tr("Localizable", "user.current", fallback: "You")
    /// Deleted user
    internal static let deleted = L10n.tr("Localizable", "user.deleted", fallback: "Deleted user")
    /// Inactive user
    internal static let inactive = L10n.tr("Localizable", "user.inactive", fallback: "Inactive user")
    internal enum Last {
      /// Last seen %@
      internal static func seen(_ p1: Any) -> String {
        return L10n.tr("Localizable", "user.last.seen", String(describing: p1), fallback: "Last seen %@")
      }
      internal enum Seen {
        /// Last seen %@ at %@
        internal static func at(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.at", String(describing: p1), String(describing: p2), fallback: "Last seen %@ at %@")
        }
        /// Last seen %@ minute ago
        internal static func minAgo(_ p1: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.minAgo", String(describing: p1), fallback: "Last seen %@ minute ago")
        }
        /// Last seen %@ minutes ago
        internal static func minsAgo(_ p1: Any) -> String {
          return L10n.tr("Localizable", "user.last.seen.minsAgo", String(describing: p1), fallback: "Last seen %@ minutes ago")
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
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
