//
//  Appearance+Images.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

typealias Images = Appearance.Images

public extension Appearance {
    struct Images {
        
        public static var emptyChannelList: UIImage = { Assets.noChannels.image }()
        public static var edit: UIImage = { Assets.edit.image }()
        public static var mute: UIImage = { Assets.mute.image }()
        public static var online: UIImage = { Assets.online.image }()
        public static var close: UIImage = { Assets.close.image }()
        public static var closeCircle: UIImage = { Assets.closeCircle.image }()
        public static var file: UIImage = { Assets.file.image }()
        public static var link: UIImage = { Assets.link.image }()
        public static var camera: UIImage = { Assets.camera.image }()
        public static var warning: UIImage = { Assets.warning.image }()
        public static var eye: UIImage = { Assets.eye.image }()
        public static var chevron: UIImage = { Assets.chevron.image }()
        public static var deletedUser: UIImage = { Assets.deletedUser.image }()
        public static var attachment: UIImage = { Assets.attach.image }()
        public static var swipeIndicator: UIImage = { Assets.swipeIndicator.image }()
        public static var addMember: UIImage = { Assets.addMember.image }()
        public static var moreMember: UIImage = { Assets.memberMore.image }()
        public static var channelNotification: UIImage = { Assets.channelNotification.image }()
        public static var radio: UIImage = { Assets.radio.image }()
        public static var radioGray: UIImage = { Assets.radioGray.image }()
        public static var radioSelected: UIImage = { Assets.radioSelected.image }()
        public static var galleryAssetSelect: UIImage = { Assets.galleryAssetSelect.image }()
        public static var galleryAssetUnselect: UIImage = { Assets.galleryAssetUnselect.image }()
        public static var galleryVidepAsset: UIImage = { Assets.galleryVideoAsset.image }()
        public static var editAvatar: UIImage = { Assets.editAvatar.image }()
        
        public static var pendingMessage: UIImage = { Assets.messageTickPending.image }()
        public static var sentMessage: UIImage = { Assets.messageTickSent.image }()
        public static var deliveredMessage: UIImage = { Assets.messageTickDelivered.image }()
        public static var readMessage: UIImage = { Assets.messageTickRead.image }()
        public static var failedMessage: UIImage = { Assets.failed.image }()
        public static var forwardedMessage: UIImage = { Assets.messageForward.image }()
        
        public static var messageActionInfo: UIImage = { Assets.actionInfo.image }()
        public static var messageActionAdd: UIImage = { Assets.actionAdd.image }()
        public static var messageActionEdit: UIImage = { Assets.actionEdit.image }()
        public static var messageActionReply: UIImage = { Assets.actionReply.image }()
        public static var messageActionReplyInThread: UIImage = { Assets.actionReplyThread.image }()
        public static var messageActionForward: UIImage = { Assets.actionForward.image }()
        public static var messageActionShare: UIImage = { Assets.actionShare.image }()
        public static var messageActionCopy: UIImage = { Assets.actionCopy.image }()
        public static var messageActionReact: UIImage = { Assets.actionReact.image }()
        public static var messageActionDelete: UIImage = { Assets.actionDelete.image }()
        public static var messageActionSelect: UIImage = { Assets.actionSelect.image }()
        public static var messageActionRemove: UIImage = { Assets.actionRemove.image }()
        public static var messageActionReport: UIImage = { Assets.actionReport.image }()
        public static var messageSendAction: UIImage = { Assets.send.image }()
        public static var messageActionMoreReactions: UIImage = { Assets.plus.image }()
        public static var attachmentTransferPause: UIImage = { Assets.fileTransferPause.image }()
        public static var attachmentUpload: UIImage = { Assets.fileUpload.image }()
        public static var attachmentDownload: UIImage = { Assets.fileDownload.image }()
        
        public static var messageVideoPlay: UIImage = { Assets.videoPlay.image }()
        public static var messageVideoPause: UIImage = { Assets.videoPause.image }()
        public static var messageVideoMute: UIImage = { Assets.videoMute.image }()
        public static var messageVideoUnmute: UIImage = { Assets.videoUnmute.image }()
        
        public static var composerEditMessage: UIImage = { Assets.composerEdit.image }()
        public static var composerReplyMessage: UIImage = { Assets.composerReply.image }()
        
        public static var channelNew: UIImage = { Assets.newChannel.image }()
        public static var channelCreatePublic: UIImage = { Assets.createPublicChannel.image }()
        public static var channelCreatePrivate: UIImage = { Assets.createPrivateChannel.image }()
        public static var channelUnreadBubble: UIImage = { Assets.channelUnreadBubble.image }()
        public static var channelProfileURI: UIImage = { Assets.channelProfileUri.image }()
        public static var channelProfileQR: UIImage = { Assets.channelProfileQr.image }()
        public static var channelProfileMute: UIImage = { Assets.channelProfileMute.image }()
        public static var channelProfileUnmute: UIImage = { Assets.channelProfileUnmute.image }()
        public static var channelProfileBell: UIImage = { Assets.channelProfileBell.image }()
        public static var channelProfileReport: UIImage = { Assets.channelProfileReport.image }()
        public static var channelProfileJoin: UIImage = { Assets.channelProfileJoin.image }()
        public static var channelProfileMore: UIImage = { Assets.channelProfileMore.image }()
        public static var channelProfileAutoDeleteMessages: UIImage = { Assets.channelProfileAutoDeleteMessages.image }()
        public static var channelProfileMembers: UIImage = { Assets.channelProfileMembers.image }()
        public static var channelProfileAdmins: UIImage = { Assets.channelProfileAdmins.image }()
        public static var channelProfileEditAvatar: UIImage = { Assets.channelProfileEditAvatar.image }()
        public static var channelReply: UIImage = { Assets.channelReply.image }()
        public static var channelCreated: UIImage = { Assets.channelCreated.image }()
        public static var channelPin: UIImage = { Assets.channelPin.image }()

        public static var audioPlayerCancel: UIImage = { Assets.audioPlayerCancel.image }()
        public static var audioPlayerDelete: UIImage = { Assets.audioPlayerDelete.image }()
        public static var audioPlayerLock: UIImage = { Assets.audioPlayerLock.image }()
        public static var audioPlayerMic: UIImage = { Assets.audioPlayerMic.image }()
        public static var audioPlayerMicGreen: UIImage = { Assets.audioPlayerMicGreen.image }()
        public static var audioPlayerPauseGrey: UIImage = { Assets.audioPlayerPauseGrey.image }()
        public static var audioPlayerPause: UIImage = { Assets.audioPlayerPause.image }()
        public static var audioPlayerPlayGrey: UIImage = { Assets.audioPlayerPlayGrey.image }()
        public static var audioPlayerPlay: UIImage = { Assets.audioPlayerPlay.image }()
        public static var audioPlayerSend: UIImage = { Assets.audioPlayerSend.image }()
        public static var audioPlayerSendLarge: UIImage = { Assets.audioPlayerSendLarge.image }()
        public static var audioPlayerStop: UIImage = { Assets.audioPlayerStop.image }()
        public static var audioPlayerUnlock: UIImage = { Assets.audioPlayerUnlock.image }()
        
        public static var attachmentFile: UIImage = { Assets.attachmentFile.image }()
        public static var attachmentImage: UIImage = { Assets.attachmentImage.image }()
        public static var attachmentVideo: UIImage = { Assets.attachmentVideo.image }()
        public static var attachmentVoice: UIImage = { Assets.attachmentVoice.image }()

        public static var videoPlayerPause: UIImage = { Assets.videoPlayerPause.image }()
        public static var videoPlayerPlay: UIImage = { Assets.videoPlayerPlay.image }()
        public static var videoPlayerThumb: UIImage = { Assets.videoPlayerThumb.image }()
        public static var videoPlayerShare: UIImage = { Assets.videoPlayerShare.image }()
        public static var videoPlayerBack: UIImage = { Assets.videoPlayerBack.image }()
    
        public static var emojiActivities: UIImage = { Assets.emojiActivities.image }()
        public static var emojiAnimalNature: UIImage = { Assets.emojiAnimalNature.image }()
        public static var emojiFlags: UIImage = { Assets.emojiFlags.image }()
        public static var emojiFoodDrink: UIImage = { Assets.emojiFoodDrink.image }()
        public static var emojiObjects: UIImage = { Assets.emojiObjects.image }()
        public static var emojiRecent: UIImage = { Assets.emojiRecent.image }()
        public static var emojiSmileys: UIImage = { Assets.emojiSmileys.image }()
        public static var emojiSymbols: UIImage = { Assets.emojiSymbols.image }()
        public static var emojiTravel: UIImage = { Assets.emojiTravel.image }()

        public static var manangeAccessGallery: UIImage = { Assets.manangeAccessGallery.image }()
        
        public static var chatPin: UIImage = { Assets.chatPin.image }()
        public static var chatUnpin: UIImage = { Assets.chatUnpin.image }()
        public static var chatBlock: UIImage = { Assets.chatBlock.image }()
        public static var chatUnBlock: UIImage = { Assets.chatUnblock.image }()
        public static var chatClear: UIImage = { Assets.chatClear.image }()
        public static var chatDelete: UIImage = { Assets.chatDelete.image }()
        public static var chatLeave: UIImage = { Assets.chatLeave.image }()
        public static var chatSavePhoto: UIImage = { Assets.chatSavePhoto.image }()
        public static var chatForward: UIImage = { Assets.chatForward.image }()
        public static var chatShare: UIImage = { Assets.chatShare.image }()
        public static var chatEdit: UIImage = { Assets.chatEdit.image }()
        public static var chatRevoke: UIImage = { Assets.chatRevoke.image }()

        public static var chatActionCamera: UIImage = { Assets.chatActionCamera.image }()
        public static var chatActionGallery: UIImage = { Assets.chatActionGallery.image }()
        public static var chatActionFile: UIImage = { Assets.chatActionFile.image }()
        public static var chatActionContact: UIImage = { Assets.chatActionContact.image }()
        public static var chatActionLocation: UIImage = { Assets.chatActionLocation.image }()

        public static var searchIcon: UIImage = { Assets.searchIcon.image }()
        public static var searchBackground: UIImage = { Assets.searchBackground.image }()
        
        public static var downloadStart: UIImage = { Assets.downloadStart.image }()
        public static var downloadStop: UIImage = { Assets.downloadStop.image }()
        
        public static var replyX: UIImage = { Assets.replyX.image }()
        public static var replyVoice: UIImage = { Assets.replyVoice.image }()
        public static var replyFile: UIImage = { Assets.replyFile.image }()
        public static var messageFile: UIImage = { Assets.messageFile.image }()

        public static var noResultsSearch: UIImage = { Assets.noResultsSearch.image }()
        public static var noMessages: UIImage = { Assets.noMessages.image }()
        
        public init() { }
        
    }
}

extension UIImage {
    static var emptyChannelList: UIImage { Images.emptyChannelList }
    static var edit: UIImage { Images.edit }
    static var mute: UIImage { Images.mute }
    static var online: UIImage { Images.online }
    static var close: UIImage { Images.close }
    static var closeCircle: UIImage { Images.closeCircle }
    static var file: UIImage { Images.file }
    static var link: UIImage { Images.link }
    static var camera: UIImage { Images.camera }
    static var warning: UIImage { Images.warning }
    static var eye: UIImage { Images.eye }
    static var chevron: UIImage { Images.chevron }
    static var deletedUser: UIImage { Images.deletedUser }
    static var attachment: UIImage { Images.attachment }
    static var swipeIndicator: UIImage { Images.swipeIndicator }
    static var addMember: UIImage { Images.addMember }
    static var moreMember: UIImage { Images.moreMember }
    static var channelNotification: UIImage { Images.channelNotification }
    static var radio: UIImage { Images.radio }
    static var radioGray: UIImage { Images.radioGray }
    static var radioSelected: UIImage { Images.radioSelected }
    static var galleryAssetSelect: UIImage { Images.galleryAssetSelect }
    static var galleryAssetUnselect: UIImage { Images.galleryAssetUnselect }
    static var galleryVideoAsset: UIImage { Images.galleryVidepAsset }
    static var forwardedMessage: UIImage { Images.forwardedMessage }
    static var editAvatar: UIImage { Images.editAvatar }
    
    static var pendingMessage: UIImage { Images.pendingMessage }
    static var sentMessage: UIImage { Images.sentMessage }
    static var deliveredMessage: UIImage { Images.deliveredMessage }
    static var readMessage: UIImage { Images.readMessage }
    static var failedMessage: UIImage { Images.failedMessage }
    
    static var messageActionInfo: UIImage { Images.messageActionInfo }
    static var messageActionAdd: UIImage { Images.messageActionAdd }
    static var messageActionEdit: UIImage { Images.messageActionEdit }
    static var messageActionReply: UIImage { Images.messageActionReply }
    static var messageActionReplyInThread: UIImage { Images.messageActionReplyInThread }
    static var messageActionForward: UIImage { Images.messageActionForward }
    static var messageActionShare: UIImage { Images.messageActionShare }
    static var messageActionCopy: UIImage { Images.messageActionCopy }
    static var messageActionReact: UIImage { Images.messageActionReact }
    static var messageActionDelete: UIImage { Images.messageActionDelete }
    static var messageActionSelect: UIImage { Images.messageActionSelect }
    static var messageActionRemove: UIImage { Images.messageActionRemove }
    static var messageActionReport: UIImage { Images.messageActionReport }
    static var attachmentTransferPause: UIImage { Images.attachmentTransferPause }
    static var attachmentUpload: UIImage { Images.attachmentUpload }
    static var attachmentDownload: UIImage { Images.attachmentDownload }
    
    static var messageVideoPlay: UIImage { Images.messageVideoPlay }
    static var messageVideoPause: UIImage { Images.messageVideoPause }
    static var messageVideoMute: UIImage { Images.messageVideoMute }
    static var messageVideoUnmute: UIImage { Images.messageVideoUnmute }
    
    static var messageSendAction: UIImage { Images.messageSendAction }
    
    static var composerEditMessage: UIImage { Images.composerEditMessage }
    static var composerReplyMessage: UIImage { Images.composerReplyMessage }
    
    static var channelNew: UIImage { Images.channelNew }
    static var channelCreatePublic: UIImage { Images.channelCreatePublic }
    static var channelCreatePrivate: UIImage { Images.channelCreatePrivate }
    
    static var channelUnreadBubble: UIImage { Images.channelUnreadBubble }
    static var channelProfileURI: UIImage { Images.channelProfileURI }
    static var channelProfileQR: UIImage { Images.channelProfileQR }
    static var channelProfileMute: UIImage { Images.channelProfileMute }
    static var channelProfileUnmute: UIImage { Images.channelProfileUnmute }
    static var channelProfileBell: UIImage { Images.channelProfileBell }
    static var channelProfileReport: UIImage { Images.channelProfileReport }
    static var channelProfileJoin: UIImage { Images.channelProfileJoin }
    static var channelProfileMore: UIImage { Images.channelProfileMore }
    static var channelProfileAutoDeleteMessages: UIImage { Images.channelProfileAutoDeleteMessages }
    static var channelProfileMembers: UIImage { Images.channelProfileMembers }
    static var channelProfileAdmins: UIImage { Images.channelProfileAdmins }
    static var channelProfileEditAvatar: UIImage { Images.channelProfileEditAvatar }
    static var channelReply: UIImage { Images.channelReply }
    
    static var audioPlayerCancel: UIImage { Images.audioPlayerCancel }
    static var audioPlayerDelete: UIImage { Images.audioPlayerDelete }
    static var audioPlayerLock: UIImage { Images.audioPlayerLock }
    static var audioPlayerMic: UIImage { Images.audioPlayerMic }
    static var audioPlayerMicGreen: UIImage { Images.audioPlayerMicGreen }
    static var audioPlayerPauseGrey: UIImage { Images.audioPlayerPauseGrey }
    static var audioPlayerPause: UIImage { Images.audioPlayerPause }
    static var audioPlayerPlayGrey: UIImage { Images.audioPlayerPlayGrey }
    static var audioPlayerPlay: UIImage { Images.audioPlayerPlay }
    static var audioPlayerSend: UIImage { Images.audioPlayerSend }
    static var audioPlayerSendLarge: UIImage { Images.audioPlayerSendLarge }
    static var audioPlayerStop: UIImage { Images.audioPlayerStop }
    static var audioPlayerUnlock: UIImage { Images.audioPlayerUnlock }
    
    static var chatPin: UIImage { Images.chatPin }
    static var chatUnpin: UIImage { Images.chatUnpin }
    static var chatBlock: UIImage { Images.chatBlock }
    static var chatUnBlock: UIImage { Images.chatUnBlock }
    static var chatClear: UIImage { Images.chatClear }
    static var chatDelete: UIImage { Images.chatDelete }
    static var chatLeave: UIImage { Images.chatLeave }
    static var chatSavePhoto: UIImage { Images.chatSavePhoto }
    static var chatForward: UIImage { Images.chatForward }
    static var chatShare: UIImage { Images.chatShare }
    static var chatEdit: UIImage { Images.chatEdit }
    static var chatRevoke: UIImage { Images.chatRevoke }

    static var chatActionCamera: UIImage { Images.chatActionCamera }
    static var chatActionGallery: UIImage { Images.chatActionGallery }
    static var chatActionFile: UIImage { Images.chatActionFile }
    static var chatActionContact: UIImage { Images.chatActionContact }
    static var chatActionLocation: UIImage { Images.chatActionLocation }
    
    static var searchIcon: UIImage { Images.searchIcon }
    static var searchBackground: UIImage { Images.searchBackground }
    
    static var downloadStart: UIImage { Images.downloadStart }
    static var downloadStop: UIImage { Images.downloadStop }
        
    static var replyX: UIImage { Images.replyX }
    static var replyVoice: UIImage { Images.replyVoice }
    static var replyFile: UIImage { Images.replyFile }
    static var messageFile: UIImage { Images.messageFile }
}

