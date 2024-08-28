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
        
        public static var emptyChannelList: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.noChannels.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var edit: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.edit.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var mute: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.mute.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var online: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.online1.image,
                                                     renderingMode: .template(.background)),
                                         .init(image: Assets.online2.image,
                                               renderingMode: .template(.stateSuccess)))!
        }()
        public static var closeCircle: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground20.image,
                                                     renderingMode: .template(.surface3)),
                                         .init(image: Assets.closeCircle1.image,
                                               renderingMode: .template(.background)),
                                         .init(image: Assets.closeCircle2.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var file: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.file1.image,
                                                     renderingMode: .template(.surface1)),
                                         .init(image: Assets.file2.image,
                                               renderingMode: .template(.primaryAccent)))!
        }()
        public static var link: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.link1.image,
                                                     renderingMode: .template(.surface1)),
                                         .init(image: Assets.link2.image,
                                               renderingMode: .template(.primaryAccent)))!
        }()
        public static var camera: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.camera.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var warning: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.warning.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var eye: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.eye.image,
                                                     renderingMode: .template(.secondaryText)))!
        }()
        public static var chevron: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chevron.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var chevronUp: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chevronUp.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chevronDown: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chevronDown.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var deletedUser: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground36.image,
                                                     renderingMode: .template(.surface3)),
                                         .init(image: Assets.deletedUser1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var attachment: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.attach.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var addMember: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.surface1)),
                                         .init(image: Assets.addMember1.image,
                                               renderingMode: .template(.primaryAccent)))!
        }()
        public static var moreMember: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.memberMore.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelNotification: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelNotification.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
#warning("check later")
        public static var radio: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.radioCircle1.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var radioGray: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground24.image,
                                                     renderingMode: .template(.overlayBackground50)),
                                         .init(image: Assets.radioCircle1.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var radioSelected: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.radioSelected.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var galleryVidepAsset: UIImage = { Assets.galleryVideoAsset.image }()
        public static var editAvatar: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground72.image,
                                                     renderingMode: .template(.surface2)),
                                         .init(image: Assets.editAvatar1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        
        public static var pendingMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickPending.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var sentMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickSent.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var deliveredMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickDelivered.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var readMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickRead.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var failedMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.failed.image,
                                                     renderingMode: .template(.stateError)))!
        }()
        public static var forwardedMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageForward.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
        public static var messageActionInfo: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionInfo.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionEdit: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionEdit.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionReply: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionReply.image,
                                                     renderingMode: .template(.primaryText)))!}()
        public static var messageActionReplyInThread: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionReplyThread.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionForward: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionForward.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionShare: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionShare.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionCopy: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionCopy.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionReact: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionReact.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var messageActionDelete: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionDelete.image,
                                                     renderingMode: .template(.stateError)))!
        }()
        public static var messageActionSelect: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionSelect.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionRemove: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionRemove.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var messageActionReport: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionReport.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageSendAction: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground34.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.send1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var messageActionMoreReactions: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.plus.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var attachmentTransferPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.fileTransferPause.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var attachmentUpload: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.fileUpload.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var attachmentDownload: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.fileDownload.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        
        public static var videoPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground56.image,
                                                     renderingMode: .template(.overlayBackground50)),
                                         .init(image: Assets.videoPlay1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var videoPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground56.image,
                                                     renderingMode: .template(.overlayBackground50)),
                                         .init(image: Assets.videoPause1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var videoPlayerPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPause1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var videoPlayerPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlay1.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var messageVideoMute: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoMute.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var messageVideoUnmute: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoUnmute.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        
        public static var composerEditMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.composerEdit.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var composerReplyMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.composerReply.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
        public static var channelNew: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.newChannel.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelCreatePublic: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.createPublicChannel.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelCreatePrivate: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.createPrivateChannel.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelUnreadBubble: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground44.image,
                                                     renderingMode: .template(.backgroundSecondary)),
                                         .init(image: Assets.channelUnreadBubble1.image,
                                               renderingMode: .template(.secondaryText)))!
        }()
        public static var channelProfileURI: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.tertiaryAccent)),
                                         .init(image: Assets.channelProfileUri1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelProfileQR: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileQr.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelProfileMute: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileMute.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelProfileUnmute: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileUnmute.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelProfileBell: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.secondaryAccent)),
                                         .init(image: Assets.channelProfileBell1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelProfileReport: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileReport.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelProfileJoin: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileJoin.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelProfileMore: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileMore.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var channelProfileAutoDeleteMessages: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.tertiaryAccent)),
                                         .init(image: Assets.channelProfileAutoDeleteMessages1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelProfileMembers: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.quaternaryAccent)),
                                         .init(image: Assets.channelProfileMembers1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelProfileAdmins: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.quinaryAccent)),
                                         .init(image: Assets.channelProfileAdmins1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelProfileEditAvatar: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileEditAvatar.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelReply: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.surface3)),
                                         .init(image: Assets.channelReply1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var channelCreated: UIImage = {
            Assets.channelCreated.image
        }()
        public static var channelPin: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelPin.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        
        public static var audioPlayerCancel: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerCancel.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var audioPlayerDelete: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground70.image,
                                                     renderingMode: .template(.stateError)),
                                         .init(image: Assets.audioPlayerDelete1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var audioPlayerLock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground42.image,
                                                     renderingMode: .template(.background)),
                                         .init(image: Assets.audioPlayerLock1.image,
                                               renderingMode: .template(.primaryAccent)))!
        }()
        public static var audioPlayerMic: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground34.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.audioPlayerMic1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var audioPlayerMicGreen: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground70.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.audioPlayerMicRecording1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var audioPlayerPauseGrey: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerPauseGrey.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var audioPlayerPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.audioPlayerPause1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var audioPlayerPlayGrey: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerPlayGrey.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var audioPlayerPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.audioPlayerPlay1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var audioPlayerSendLarge: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground70.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.audioPlayerSendLarge1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        public static var audioPlayerStop: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground42.image,
                                                     renderingMode: .template(.background)),
                                         .init(image: Assets.audioPlayerStop1.image,
                                               renderingMode: .template(.primaryAccent)))!
        }()
        public static var audioPlayerUnlock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerUnlock1.image,
                                                     renderingMode: .template(.background)),
                                         .init(image: Assets.audioPlayerUnlock2.image,
                                               renderingMode: .template(.primaryAccent.withAlphaComponent(0.4)),
                                               anchor: .bottom(.init(x: 0, y: -15.5))),
                                         .init(image: Assets.audioPlayerUnlock2.image,
                                               renderingMode: .template(.primaryAccent.withAlphaComponent(0.8)),
                                               anchor: .bottom(.init(x: 0, y: -22))),
                                         .init(image: Assets.audioPlayerUnlock3.image,
                                               renderingMode: .template(.iconInactive),
                                               anchor: .top(.init(x: 0, y: 10))))!
        }()
        
        public static var avatar: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.avatar.image,
                                                     renderingMode: .original))!
        }()
        
        public static var attachmentFile: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.attachmentFile.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var attachmentImage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.attachmentImage.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var attachmentVideo: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.attachmentVideo.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var attachmentVoice: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.attachmentVoice.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        
        public static var videoPlayerThumb: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlayerThumb.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var videoPlayerShare: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlayerShare.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var videoPlayerBack: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlayerBack.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        
        public static var emojiActivities: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiActivities.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiAnimalNature: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiAnimalNature.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiFlags: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiFlags.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiFoodDrink: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiFoodDrink.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiObjects: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiObjects.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiRecent: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiRecent.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiSmileys: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiSmileys.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiSymbols: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiSymbols.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var emojiTravel: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.emojiTravel.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
                
        public static var chatPin: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatPin.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatUnpin: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatUnpin.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatBlock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatBlock.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatUnBlock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatUnblock.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatClear: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatClear.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatDelete: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatDelete.image,
                                                     renderingMode: .template(.stateError)))!
        }()
        public static var chatLeave: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatLeave.image,
                                                     renderingMode: .template(.stateError)))!
        }()
        public static var chatSavePhoto: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatSavePhoto.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatForward: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatForward.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatShare: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatShare.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatEdit: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatEdit.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatRevoke: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatRevoke.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
        public static var chatActionCamera: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionCamera.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatActionGallery: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionGallery.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatActionFile: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionFile.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatActionContact: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionContact.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var chatActionLocation: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionLocation.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
        public static var searchIcon: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.searchIcon.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var searchFill: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.searchFill1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        
        public static var downloadStart: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.downloadStart.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var downloadStop: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.downloadStop.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
        public static var replyPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.replyPlay.image,
                                                     renderingMode: .template(.textOnPrimary)))!
        }()
        public static var replyX: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.replyX.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        
        public static var messageFile: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.primaryAccent)),
                                         .init(image: Assets.messageFile1.image,
                                               renderingMode: .template(.textOnPrimary)))!
        }()
        
        public static var noResultsSearch: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.noResultsSearch.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        public static var noMessages: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.noMessages.image,
                                                     renderingMode: .template(.primaryAccent)))!
        }()
        
        public init() { }
        
    }
}

extension UIImage {
    static var emptyChannelList: UIImage { Images.emptyChannelList }
    static var edit: UIImage { Images.edit }
    static var mute: UIImage { Images.mute }
    static var online: UIImage { Images.online }
    static var closeCircle: UIImage { Images.closeCircle }
    static var file: UIImage { Images.file }
    static var link: UIImage { Images.link }
    static var camera: UIImage { Images.camera }
    static var avatar: UIImage { Images.avatar }
    static var warning: UIImage { Images.warning }
    static var eye: UIImage { Images.eye }
    static var chevron: UIImage { Images.chevron }
    static var chevronUp: UIImage { Images.chevronUp }
    static var chevronDown: UIImage { Images.chevronDown }
    static var deletedUser: UIImage { Images.deletedUser }
    static var attachment: UIImage { Images.attachment }
    static var addMember: UIImage { Images.addMember }
    static var moreMember: UIImage { Images.moreMember }
    static var channelNotification: UIImage { Images.channelNotification }
    static var radio: UIImage { Images.radio }
    static var radioGray: UIImage { Images.radioGray }
    static var radioSelected: UIImage { Images.radioSelected }
    static var galleryVideoAsset: UIImage { Images.galleryVidepAsset }
    static var forwardedMessage: UIImage { Images.forwardedMessage }
    static var editAvatar: UIImage { Images.editAvatar }
    
    static var pendingMessage: UIImage { Images.pendingMessage }
    static var sentMessage: UIImage { Images.sentMessage }
    static var deliveredMessage: UIImage { Images.deliveredMessage }
    static var readMessage: UIImage { Images.readMessage }
    static var failedMessage: UIImage { Images.failedMessage }
    
    static var messageActionInfo: UIImage { Images.messageActionInfo }
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
    
    static var videoPlay: UIImage { Images.videoPlay }
    static var videoPause: UIImage { Images.videoPause }
    static var videoPlayerPause: UIImage { Images.videoPlayerPause }
    static var videoPlayerPlay: UIImage { Images.videoPlayerPlay }
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
    static var searchFill: UIImage { Images.searchFill }
    
    static var downloadStart: UIImage { Images.downloadStart }
    static var downloadStop: UIImage { Images.downloadStop }
    
    static var replyPlay: UIImage { Images.replyPlay }
    static var replyX: UIImage { Images.replyX }
    static var messageFile: UIImage { Images.messageFile }
}
