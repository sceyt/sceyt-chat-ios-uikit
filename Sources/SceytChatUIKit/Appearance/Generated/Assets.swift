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
  internal static let actionCopy = ImageAsset(name: "action_copy")
  internal static let actionDelete = ImageAsset(name: "action_delete")
  internal static let actionEdit = ImageAsset(name: "action_edit")
  internal static let actionForward = ImageAsset(name: "action_forward")
  internal static let actionInfo = ImageAsset(name: "action_info")
  internal static let actionRemove = ImageAsset(name: "action_remove")
  internal static let actionReply = ImageAsset(name: "action_reply")
  internal static let actionReplyThread = ImageAsset(name: "action_reply_thread")
  internal static let actionReport = ImageAsset(name: "action_report")
  internal static let actionSelect = ImageAsset(name: "action_select")
  internal static let actionShare = ImageAsset(name: "action_share")
  internal static let attachmentFile = ImageAsset(name: "attachment_file")
  internal static let attachmentImage = ImageAsset(name: "attachment_image")
  internal static let attachmentVideo = ImageAsset(name: "attachment_video")
  internal static let attachmentVoice = ImageAsset(name: "attachment_voice")
  internal static let audioPlayerCancel = ImageAsset(name: "audio_player_cancel")
  internal static let audioPlayerDelete1 = ImageAsset(name: "audio_player_delete_1")
  internal static let audioPlayerLock1 = ImageAsset(name: "audio_player_lock_1")
  internal static let audioPlayerMic1 = ImageAsset(name: "audio_player_mic_1")
  internal static let audioPlayerMicRecording1 = ImageAsset(name: "audio_player_mic_recording_1")
  internal static let audioPlayerPause1 = ImageAsset(name: "audio_player_pause_1")
  internal static let audioPlayerPauseGrey = ImageAsset(name: "audio_player_pause_grey")
  internal static let audioPlayerPlay1 = ImageAsset(name: "audio_player_play_1")
  internal static let audioPlayerPlayGrey = ImageAsset(name: "audio_player_play_grey")
  internal static let audioPlayerSendLarge1 = ImageAsset(name: "audio_player_send_large_1")
  internal static let audioPlayerStop1 = ImageAsset(name: "audio_player_stop_1")
  internal static let audioPlayerUnlock1 = ImageAsset(name: "audio_player_unlock_1")
  internal static let audioPlayerUnlock2 = ImageAsset(name: "audio_player_unlock_2")
  internal static let audioPlayerUnlock3 = ImageAsset(name: "audio_player_unlock_3")
  internal static let chatActionCamera = ImageAsset(name: "chat_action_camera")
  internal static let chatActionContact = ImageAsset(name: "chat_action_contact")
  internal static let chatActionFile = ImageAsset(name: "chat_action_file")
  internal static let chatActionGallery = ImageAsset(name: "chat_action_gallery")
  internal static let chatActionLocation = ImageAsset(name: "chat_action_location")
  internal static let chatBlock = ImageAsset(name: "chat_block")
  internal static let chatClear = ImageAsset(name: "chat_clear")
  internal static let chatDelete = ImageAsset(name: "chat_delete")
  internal static let chatEdit = ImageAsset(name: "chat_edit")
  internal static let chatForward = ImageAsset(name: "chat_forward")
  internal static let chatLeave = ImageAsset(name: "chat_leave")
  internal static let chatPin = ImageAsset(name: "chat_pin")
  internal static let chatRevoke = ImageAsset(name: "chat_revoke")
  internal static let chatSavePhoto = ImageAsset(name: "chat_save_photo")
  internal static let chatShare = ImageAsset(name: "chat_share")
  internal static let chatUnblock = ImageAsset(name: "chat_unblock")
  internal static let chatUnpin = ImageAsset(name: "chat_unpin")
  internal static let createPrivateChannel = ImageAsset(name: "create_private_channel")
  internal static let createPublicChannel = ImageAsset(name: "create_public_channel")
  internal static let newChannel = ImageAsset(name: "new_channel")
  internal static let emojiActivities = ImageAsset(name: "emoji_activities")
  internal static let emojiAnimalNature = ImageAsset(name: "emoji_animal_nature")
  internal static let emojiFlags = ImageAsset(name: "emoji_flags")
  internal static let emojiFoodDrink = ImageAsset(name: "emoji_food_drink")
  internal static let emojiObjects = ImageAsset(name: "emoji_objects")
  internal static let emojiRecent = ImageAsset(name: "emoji_recent")
  internal static let emojiSmileys = ImageAsset(name: "emoji_smileys")
  internal static let emojiSymbols = ImageAsset(name: "emoji_symbols")
  internal static let emojiTravel = ImageAsset(name: "emoji_travel")
  internal static let videoPlayerBack = ImageAsset(name: "video_player_back")
  internal static let videoPlayerShare = ImageAsset(name: "video_player_share")
  internal static let videoPlayerThumb = ImageAsset(name: "video_player_thumb")
  internal static let addMember1 = ImageAsset(name: "addMember_1")
  internal static let attach = ImageAsset(name: "attach")
  internal static let avatar = ImageAsset(name: "avatar")
  internal static let brokenImagePlaceholderIcon = ImageAsset(name: "broken_image_placeholder_icon")
  internal static let channelPin = ImageAsset(name: "channel_pin")
  internal static let channelProfileAdmins1 = ImageAsset(name: "channel_profile_admins_1")
  internal static let channelProfileAutoDeleteMessages1 = ImageAsset(name: "channel_profile_auto_delete_messages_1")
  internal static let channelProfileBell1 = ImageAsset(name: "channel_profile_bell_1")
  internal static let channelProfileEditAvatar = ImageAsset(name: "channel_profile_edit_avatar")
  internal static let channelProfileMembers1 = ImageAsset(name: "channel_profile_members_1")
  internal static let channelProfileMore = ImageAsset(name: "channel_profile_more")
  internal static let channelProfileQr = ImageAsset(name: "channel_profile_qr")
  internal static let channelProfileUri1 = ImageAsset(name: "channel_profile_uri_1")
  internal static let channelReply1 = ImageAsset(name: "channel_reply_1")
  internal static let channelUnreadBubble1 = ImageAsset(name: "channel_unread_bubble_1")
  internal static let chevron = ImageAsset(name: "chevron")
  internal static let chevronDown = ImageAsset(name: "chevron_down")
  internal static let chevronUp = ImageAsset(name: "chevron_up")
  internal static let circleBackground20 = ImageAsset(name: "circle_background_20")
  internal static let circleBackground24 = ImageAsset(name: "circle_background_24")
  internal static let circleBackground32 = ImageAsset(name: "circle_background_32")
  internal static let circleBackground34 = ImageAsset(name: "circle_background_34")
  internal static let circleBackground36 = ImageAsset(name: "circle_background_36")
  internal static let circleBackground40 = ImageAsset(name: "circle_background_40")
  internal static let circleBackground42 = ImageAsset(name: "circle_background_42")
  internal static let circleBackground44 = ImageAsset(name: "circle_background_44")
  internal static let circleBackground56 = ImageAsset(name: "circle_background_56")
  internal static let circleBackground70 = ImageAsset(name: "circle_background_70")
  internal static let circleBackground72 = ImageAsset(name: "circle_background_72")
  internal static let closeCircle1 = ImageAsset(name: "close_circle_1")
  internal static let closeCircle2 = ImageAsset(name: "close_circle_2")
  internal static let closeIcon = ImageAsset(name: "close_icon")
  internal static let deletedUser = ImageAsset(name: "deleted_user")
  internal static let downloadStart = ImageAsset(name: "download_start")
  internal static let downloadStop = ImageAsset(name: "download_stop")
  internal static let editAvatar1 = ImageAsset(name: "edit_avatar_1")
  internal static let eye = ImageAsset(name: "eye")
  internal static let failed = ImageAsset(name: "failed")
  internal static let file2 = ImageAsset(name: "file_2")
  internal static let fileDownload = ImageAsset(name: "file_download")
  internal static let fileTransferPause = ImageAsset(name: "file_transfer_pause")
  internal static let fileUpload = ImageAsset(name: "file_upload")
  internal static let galleryVideoAsset = ImageAsset(name: "gallery_video_asset")
  internal static let link2 = ImageAsset(name: "link_2")
  internal static let messageFile1 = ImageAsset(name: "message_file_1")
  internal static let messageForward = ImageAsset(name: "message_forward")
  internal static let messageTickDisplayed = ImageAsset(name: "message_tick_displayed")
  internal static let messageTickPending = ImageAsset(name: "message_tick_pending")
  internal static let messageTickReceived = ImageAsset(name: "message_tick_received")
  internal static let messageTickSent = ImageAsset(name: "message_tick_sent")
  internal static let mute = ImageAsset(name: "mute")
  internal static let noChannels = ImageAsset(name: "no_channels")
  internal static let noMember = ImageAsset(name: "no_member")
  internal static let noMessages = ImageAsset(name: "no_messages")
  internal static let noResultsSearch = ImageAsset(name: "no_results_search")
  internal static let online1 = ImageAsset(name: "online_1")
  internal static let online2 = ImageAsset(name: "online_2")
  internal static let plus = ImageAsset(name: "plus")
  internal static let plusRounded = ImageAsset(name: "plus_rounded")
  internal static let radioCircle1 = ImageAsset(name: "radio_circle_1")
  internal static let radioSelected = ImageAsset(name: "radio_selected")
  internal static let replyPlay = ImageAsset(name: "reply_play")
  internal static let roundedRectangle40 = ImageAsset(name: "rounded_rectangle_40")
  internal static let searchFill1 = ImageAsset(name: "search_fill_1")
  internal static let searchIcon = ImageAsset(name: "search_icon")
  internal static let send1 = ImageAsset(name: "send_1")
  internal static let videoPause1 = ImageAsset(name: "video_pause_1")
  internal static let videoPlay1 = ImageAsset(name: "video_play_1")
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
