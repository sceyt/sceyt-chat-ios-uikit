// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Assets {
  internal static let createPrivateChannel = ImageAsset(name: "create_private_channel")
  internal static let createPublicChannel = ImageAsset(name: "create_public_channel")
  internal static let newChannel = ImageAsset(name: "new_channel")
  internal static let actionAdd = ImageAsset(name: "action_add")
  internal static let actionCopy = ImageAsset(name: "action_copy")
  internal static let actionDelete = ImageAsset(name: "action_delete")
  internal static let actionEdit = ImageAsset(name: "action_edit")
  internal static let actionForward = ImageAsset(name: "action_forward")
  internal static let actionInfo = ImageAsset(name: "action_info")
  internal static let actionReact = ImageAsset(name: "action_react")
  internal static let actionRemove = ImageAsset(name: "action_remove")
  internal static let actionReport = ImageAsset(name: "action_report")
  internal static let actionSelect = ImageAsset(name: "action_select")
  internal static let actionShare = ImageAsset(name: "action_share")
  internal static let addMember = ImageAsset(name: "addMember")
  internal static let attach = ImageAsset(name: "attach")
  internal static let attachmentFile = ImageAsset(name: "attachment.file")
  internal static let attachmentImage = ImageAsset(name: "attachment.image")
  internal static let attachmentVideo = ImageAsset(name: "attachment.video")
  internal static let attachmentVoice = ImageAsset(name: "attachment.voice")
  internal static let audioPlayerCancel = ImageAsset(name: "audioPlayer.cancel")
  internal static let audioPlayerDelete = ImageAsset(name: "audioPlayer.delete")
  internal static let audioPlayerLock = ImageAsset(name: "audioPlayer.lock")
  internal static let audioPlayerMicGreen = ImageAsset(name: "audioPlayer.mic.green")
  internal static let audioPlayerMic = ImageAsset(name: "audioPlayer.mic")
  internal static let audioPlayerPauseGrey = ImageAsset(name: "audioPlayer.pause.grey")
  internal static let audioPlayerPause = ImageAsset(name: "audioPlayer.pause")
  internal static let audioPlayerPlayGrey = ImageAsset(name: "audioPlayer.play.grey")
  internal static let audioPlayerPlay = ImageAsset(name: "audioPlayer.play")
  internal static let audioPlayerSend = ImageAsset(name: "audioPlayer.send")
  internal static let audioPlayerSendLarge = ImageAsset(name: "audioPlayer.send_large")
  internal static let audioPlayerStop = ImageAsset(name: "audioPlayer.stop")
  internal static let audioPlayerUnlock = ImageAsset(name: "audioPlayer.unlock")
  internal static let avatar = ImageAsset(name: "avatar")
  internal static let camera = ImageAsset(name: "camera")
  internal static let channelCreated = ImageAsset(name: "channel-created")
  internal static let channelNotification = ImageAsset(name: "channelNotification")
  internal static let channelProfileAdmins = ImageAsset(name: "channel_profile_admins")
  internal static let channelProfileAutoDeleteMessages = ImageAsset(name: "channel_profile_autoDeleteMessages")
  internal static let channelProfileBell = ImageAsset(name: "channel_profile_bell")
  internal static let channelProfileEditAvatar = ImageAsset(name: "channel_profile_edit_avatar")
  internal static let channelProfileJoin = ImageAsset(name: "channel_profile_join")
  internal static let channelProfileMembers = ImageAsset(name: "channel_profile_members")
  internal static let channelProfileMore = ImageAsset(name: "channel_profile_more")
  internal static let channelProfileMute = ImageAsset(name: "channel_profile_mute")
  internal static let channelProfileQr = ImageAsset(name: "channel_profile_qr")
  internal static let channelProfileReport = ImageAsset(name: "channel_profile_report")
  internal static let channelProfileUnmute = ImageAsset(name: "channel_profile_unmute")
  internal static let channelProfileUri = ImageAsset(name: "channel_profile_uri")
  internal static let channelReply = ImageAsset(name: "channel_reply")
  internal static let channelUnreadBubble = ImageAsset(name: "channel_unread_bubble")
  internal static let channelsSelected = ImageAsset(name: "channelsSelected")
  internal static let chatActionCamera = ImageAsset(name: "chat-action-camera")
  internal static let chatActionContact = ImageAsset(name: "chat-action-contact")
  internal static let chatActionFile = ImageAsset(name: "chat-action-file")
  internal static let chatActionGallery = ImageAsset(name: "chat-action-gallery")
  internal static let chatActionLocation = ImageAsset(name: "chat-action-location")
  internal static let chatBlock = ImageAsset(name: "chat-block")
  internal static let chatClear = ImageAsset(name: "chat-clear")
  internal static let chatDelete = ImageAsset(name: "chat-delete")
  internal static let chatEdit = ImageAsset(name: "chat-edit")
  internal static let chatForward = ImageAsset(name: "chat-forward")
  internal static let chatLeave = ImageAsset(name: "chat-leave")
  internal static let chatPin = ImageAsset(name: "chat-pin")
  internal static let chatRevoke = ImageAsset(name: "chat-revoke")
  internal static let chatSavePhoto = ImageAsset(name: "chat-save-photo")
  internal static let chatShare = ImageAsset(name: "chat-share")
  internal static let chatUnblock = ImageAsset(name: "chat-unblock")
  internal static let chatUnpin = ImageAsset(name: "chat-unpin")
  internal static let check = ImageAsset(name: "check")
  internal static let chevron = ImageAsset(name: "chevron")
  internal static let close = ImageAsset(name: "close")
  internal static let closeCircle = ImageAsset(name: "closeCircle")
  internal static let composerEdit = ImageAsset(name: "composer_edit")
  internal static let composerReply = ImageAsset(name: "composer_reply")
  internal static let delete = ImageAsset(name: "delete")
  internal static let deletedUser = ImageAsset(name: "deleted_user")
  internal static let downloadStart = ImageAsset(name: "download-start")
  internal static let downloadStop = ImageAsset(name: "download-stop")
  internal static let edit = ImageAsset(name: "edit")
  internal static let editAvatar = ImageAsset(name: "edit_avatar")
  internal static let emojiActivities = ImageAsset(name: "emoji_activities")
  internal static let emojiAnimalNature = ImageAsset(name: "emoji_animal_nature")
  internal static let emojiFlags = ImageAsset(name: "emoji_flags")
  internal static let emojiFoodDrink = ImageAsset(name: "emoji_food_drink")
  internal static let emojiObjects = ImageAsset(name: "emoji_objects")
  internal static let emojiRecent = ImageAsset(name: "emoji_recent")
  internal static let emojiSmileys = ImageAsset(name: "emoji_smileys")
  internal static let emojiSymbols = ImageAsset(name: "emoji_symbols")
  internal static let emojiTravel = ImageAsset(name: "emoji_travel")
  internal static let eye = ImageAsset(name: "eye")
  internal static let failed = ImageAsset(name: "failed")
  internal static let file = ImageAsset(name: "file")
  internal static let fileDownload = ImageAsset(name: "file_download")
  internal static let fileTransferPause = ImageAsset(name: "file_transfer_pause")
  internal static let fileUpload = ImageAsset(name: "file_upload")
  internal static let galleryAssetSelect = ImageAsset(name: "gallery_asset_select")
  internal static let galleryAssetUnselect = ImageAsset(name: "gallery_asset_unselect")
  internal static let galleryVideoAsset = ImageAsset(name: "gallery_video_asset")
  internal static let link = ImageAsset(name: "link")
  internal static let manangeAccessGallery = ImageAsset(name: "manangeAccessGallery")
  internal static let memberMore = ImageAsset(name: "member_more")
  internal static let messageFile = ImageAsset(name: "message-file")
  internal static let messageForward = ImageAsset(name: "message_forward")
  internal static let messageTickDelivered = ImageAsset(name: "message_tick_delivered")
  internal static let messageTickPending = ImageAsset(name: "message_tick_pending")
  internal static let messageTickRead = ImageAsset(name: "message_tick_read")
  internal static let messageTickSent = ImageAsset(name: "message_tick_sent")
  internal static let mute = ImageAsset(name: "mute")
  internal static let ngMember = ImageAsset(name: "ng_member")
  internal static let noMessages = ImageAsset(name: "no-messages")
  internal static let noResultsSearch = ImageAsset(name: "no-results-search")
  internal static let noChannels = ImageAsset(name: "noChannels")
  internal static let notification = ImageAsset(name: "notification")
  internal static let online = ImageAsset(name: "online")
  internal static let plus = ImageAsset(name: "plus")
  internal static let plusRounded = ImageAsset(name: "plusRounded")
  internal static let profile = ImageAsset(name: "profile")
  internal static let radioGray = ImageAsset(name: "radio-gray")
  internal static let radio = ImageAsset(name: "radio")
  internal static let radioSelected = ImageAsset(name: "radioSelected")
  internal static let react = ImageAsset(name: "react")
  internal static let replyFile = ImageAsset(name: "reply-file")
  internal static let replyVoice = ImageAsset(name: "reply-voice")
  internal static let reply = ImageAsset(name: "reply")
  internal static let replyInThread = ImageAsset(name: "replyInThread")
  internal static let replyX = ImageAsset(name: "replyX")
  internal static let searchBackground = ImageAsset(name: "search-background")
  internal static let searchIcon = ImageAsset(name: "search-icon")
  internal static let select = ImageAsset(name: "select")
  internal static let send = ImageAsset(name: "send")
  internal static let swipeIndicator = ImageAsset(name: "swipeIndicator")
  internal static let unselect = ImageAsset(name: "unselect")
  internal static let user = ImageAsset(name: "user")
  internal static let videoPlayerBack = ImageAsset(name: "videoPlayer.back")
  internal static let videoPlayerPause = ImageAsset(name: "videoPlayer.pause")
  internal static let videoPlayerPlay = ImageAsset(name: "videoPlayer.play")
  internal static let videoPlayerShare = ImageAsset(name: "videoPlayer.share")
  internal static let videoPlayerThumb = ImageAsset(name: "videoPlayer.thumb")
  internal static let videoMute = ImageAsset(name: "video_mute")
  internal static let videoPause = ImageAsset(name: "video_pause")
  internal static let videoPlay = ImageAsset(name: "video_play")
  internal static let videoUnmute = ImageAsset(name: "video_unmute")
  internal static let warning = ImageAsset(name: "warning")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = SCAssetsBundleClass.resourcesBundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = SCAssetsBundleClass.resourcesBundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = SCAssetsBundleClass.resourcesBundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = SCAssetsBundleClass.resourcesBundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = SCAssetsBundleClass.resourcesBundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = SCAssetsBundleClass.resourcesBundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif
