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
                                                     renderingMode: .template(.accent)))!
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
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var file: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.roundedRectangle40.image,
                                                     renderingMode: .template(.surface1)),
                                         .init(image: Assets.file2.image,
                                               renderingMode: .template(.accent)))!
        }()
        public static var link: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.roundedRectangle40.image,
                                                     renderingMode: .template(.surface1)),
                                         .init(image: Assets.link2.image,
                                               renderingMode: .template(.accent)))!
        }()
        public static var warning: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.warning.image,
                                                     renderingMode: .template(.accent)))!
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
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chevronDown: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chevronDown.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var deletedUser: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.deletedUser.image,
                                                     renderingMode: .original))!
        }()
        public static var attachment: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.attach.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var addMember: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.surface1)),
                                         .init(image: Assets.addMember1.image,
                                               renderingMode: .template(.accent)))!
        }()
        public static var radio: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.radioCircle1.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var radioGray: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground24.image,
                                                     renderingMode: .template(.overlayBackground1)),
                                         .init(image: Assets.radioCircle1.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var radioSelected: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.radioSelected.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var galleryVidepAsset: UIImage = { Assets.galleryVideoAsset.image }()
        public static var editAvatar: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground72.image,
                                                     renderingMode: .template(.surface2)),
                                         .init(image: Assets.editAvatar1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        
        public static var pendingMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickPending.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var sentMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickSent.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var receivedMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickReceived.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var displayedMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageTickDisplayed.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var failedMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.failed.image,
                                                     renderingMode: .template(.stateWarning)))!
        }()
        public static var forwardedMessage: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.messageForward.image,
                                                     renderingMode: .template(.accent)))!
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
        public static var messageActionDelete: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionDelete.image,
                                                     renderingMode: .template(.stateWarning)))!
        }()
        public static var messageActionSelect: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionSelect.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageActionRemove: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionRemove.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var messageActionReport: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.actionReport.image,
                                                     renderingMode: .template(.primaryText)))!
        }()
        public static var messageSendAction: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground34.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.send1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var messageActionMoreReactions: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.surface2)),
                                         .init(image: Assets.plus.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var attachmentTransferPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.fileTransferPause.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var attachmentUpload: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.fileUpload.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var attachmentDownload: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.fileDownload.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        
        public static var videoPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground56.image,
                                                     renderingMode: .template(.overlayBackground2)),
                                         .init(image: Assets.videoPlay1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var videoPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground56.image,
                                                     renderingMode: .template(.overlayBackground2)),
                                         .init(image: Assets.videoPause1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var videoPlayerPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPause1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var videoPlayerPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlay1.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
                
        public static var channelNew: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.newChannel.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var channelCreatePublic: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.createPublicChannel.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var channelCreatePrivate: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.createPrivateChannel.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var channelUnreadBubble: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground44.image,
                                                     renderingMode: .template(.backgroundSections)),
                                         .init(image: Assets.channelUnreadBubble1.image,
                                               renderingMode: .template(.secondaryText)))!
        }()
        public static var channelProfileURI: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.accent3)),
                                         .init(image: Assets.channelProfileUri1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var channelProfileQR: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileQr.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var channelProfileBell: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.accent2)),
                                         .init(image: Assets.channelProfileBell1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var channelProfileMore: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileMore.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var channelProfileAutoDeleteMessages: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.accent3)),
                                         .init(image: Assets.channelProfileAutoDeleteMessages1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var channelProfileMembers: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.accent4)),
                                         .init(image: Assets.channelProfileMembers1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var channelProfileAdmins: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.accent5)),
                                         .init(image: Assets.channelProfileAdmins1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var channelProfileEditAvatar: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.channelProfileEditAvatar.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var channelReply: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.surface3)),
                                         .init(image: Assets.channelReply1.image,
                                               renderingMode: .template(.onPrimary)))!
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
                                                     renderingMode: .template(.stateWarning)),
                                         .init(image: Assets.audioPlayerDelete1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var audioPlayerLock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground42.image,
                                                     renderingMode: .template(.backgroundSections)),
                                         .init(image: Assets.audioPlayerLock1.image,
                                               renderingMode: .template(.accent)))!
        }()
        public static var audioPlayerMic: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground34.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.audioPlayerMic1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var audioPlayerMicGreen: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground70.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.audioPlayerMicRecording1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var audioPlayerPauseGrey: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerPauseGrey.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var audioPlayerPause: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.audioPlayerPause1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var audioPlayerPlayGrey: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerPlayGrey.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var audioPlayerPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.audioPlayerPlay1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var audioPlayerSendLarge: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground70.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.audioPlayerSendLarge1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        public static var audioPlayerStop: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground42.image,
                                                     renderingMode: .template(.backgroundSections)),
                                         .init(image: Assets.audioPlayerStop1.image,
                                               renderingMode: .template(.accent)))!
        }()
        public static var audioPlayerUnlock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.audioPlayerUnlock1.image,
                                                     renderingMode: .template(.backgroundSections)),
                                         .init(image: Assets.audioPlayerUnlock2.image,
                                               renderingMode: .template(.accent.withAlphaComponent(0.4)),
                                               anchor: .bottom(.init(x: 0, y: -15.5))),
                                         .init(image: Assets.audioPlayerUnlock2.image,
                                               renderingMode: .template(.accent.withAlphaComponent(0.8)),
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
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var videoPlayerShare: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlayerShare.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var videoPlayerBack: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.videoPlayerBack.image,
                                                     renderingMode: .template(.onPrimary)))!
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
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatUnpin: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatUnpin.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatBlock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatBlock.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatUnBlock: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatUnblock.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatClear: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatClear.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatDelete: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatDelete.image,
                                                     renderingMode: .template(.stateWarning)))!
        }()
        public static var chatLeave: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatLeave.image,
                                                     renderingMode: .template(.stateWarning)))!
        }()
        public static var chatSavePhoto: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatSavePhoto.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatForward: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatForward.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatShare: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatShare.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatEdit: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatEdit.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatRevoke: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatRevoke.image,
                                                     renderingMode: .template(.accent)))!
        }()
        
        public static var chatActionCamera: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionCamera.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatActionGallery: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionGallery.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatActionFile: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionFile.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatActionContact: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionContact.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var chatActionLocation: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.chatActionLocation.image,
                                                     renderingMode: .template(.accent)))!
        }()
        
        public static var searchIcon: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.searchIcon.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        public static var searchFill: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground32.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.searchFill1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        
        public static var downloadStart: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.downloadStart.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var downloadStop: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.downloadStop.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        
        public static var replyPlay: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.replyPlay.image,
                                                     renderingMode: .template(.onPrimary)))!
        }()
        public static var closeIcon: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.closeIcon.image,
                                                     renderingMode: .template(.iconInactive)))!
        }()
        
        public static var messageFile: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.circleBackground40.image,
                                                     renderingMode: .template(.accent)),
                                         .init(image: Assets.messageFile1.image,
                                               renderingMode: .template(.onPrimary)))!
        }()
        
        public static var noResultsSearch: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.noResultsSearch.image,
                                                     renderingMode: .template(.accent)))!
        }()
        public static var noMessages: UIImage = {
            AssetComposer.shared.compose(from: .init(image: Assets.noMessages.image,
                                                     renderingMode: .template(.accent)))!
        }()
        
        public init() { }
        
    }
}

extension UIImage {
    public static var emptyChannelList: UIImage { Images.emptyChannelList }
    public static var noMessages: UIImage { Images.noMessages }
    public static var noResultsSearch: UIImage { Images.noResultsSearch }
    public static var mute: UIImage { Images.mute }
    public static var channelPin: UIImage { Images.channelPin }
    public static var online: UIImage { Images.online }
    public static var closeCircle: UIImage { Images.closeCircle }
    public static var file: UIImage { Images.file }
    public static var link: UIImage { Images.link }
    public static var avatar: UIImage { Images.avatar }
    public static var warning: UIImage { Images.warning }
    public static var eye: UIImage { Images.eye }
    public static var chevron: UIImage { Images.chevron }
    public static var chevronUp: UIImage { Images.chevronUp }
    public static var chevronDown: UIImage { Images.chevronDown }
    public static var deletedUser: UIImage { Images.deletedUser }
    public static var attachment: UIImage { Images.attachment }
    public static var addMember: UIImage { Images.addMember }
    public static var radio: UIImage { Images.radio }
    public static var radioGray: UIImage { Images.radioGray }
    public static var radioSelected: UIImage { Images.radioSelected }
    public static var galleryVideoAsset: UIImage { Images.galleryVidepAsset }
    public static var forwardedMessage: UIImage { Images.forwardedMessage }
    public static var editAvatar: UIImage { Images.editAvatar }
    
    public static var pendingMessage: UIImage { Images.pendingMessage }
    public static var sentMessage: UIImage { Images.sentMessage }
    public static var receivedMessage: UIImage { Images.receivedMessage }
    public static var displayedMessage: UIImage { Images.displayedMessage }
    public static var failedMessage: UIImage { Images.failedMessage }
    
    public static var messageActionInfo: UIImage { Images.messageActionInfo }
    public static var messageActionEdit: UIImage { Images.messageActionEdit }
    public static var messageActionReply: UIImage { Images.messageActionReply }
    public static var messageActionReplyInThread: UIImage { Images.messageActionReplyInThread }
    public static var messageActionForward: UIImage { Images.messageActionForward }
    public static var messageActionShare: UIImage { Images.messageActionShare }
    public static var messageActionCopy: UIImage { Images.messageActionCopy }
    public static var messageActionDelete: UIImage { Images.messageActionDelete }
    public static var messageActionSelect: UIImage { Images.messageActionSelect }
    public static var messageActionRemove: UIImage { Images.messageActionRemove }
    public static var messageActionReport: UIImage { Images.messageActionReport }
    public static var attachmentTransferPause: UIImage { Images.attachmentTransferPause }
    public static var attachmentUpload: UIImage { Images.attachmentUpload }
    public static var attachmentDownload: UIImage { Images.attachmentDownload }
    
    public static var attachmentVoice: UIImage { Images.attachmentVoice }
    public static var attachmentVideo: UIImage { Images.attachmentVideo }
    public static var attachmentImage: UIImage { Images.attachmentImage }
    public static var attachmentFile: UIImage { Images.attachmentFile }
    
    public static var videoPlay: UIImage { Images.videoPlay }
    public static var videoPause: UIImage { Images.videoPause }
    public static var videoPlayerPause: UIImage { Images.videoPlayerPause }
    public static var videoPlayerPlay: UIImage { Images.videoPlayerPlay }
    public static var messageSendAction: UIImage { Images.messageSendAction }
    public static var messageActionMoreReactions: UIImage { Images.messageActionMoreReactions }
    
        
    public static var channelNew: UIImage { Images.channelNew }
    public static var channelCreatePublic: UIImage { Images.channelCreatePublic }
    public static var channelCreatePrivate: UIImage { Images.channelCreatePrivate }
    
    public static var channelUnreadBubble: UIImage { Images.channelUnreadBubble }
    public static var channelProfileURI: UIImage { Images.channelProfileURI }
    public static var channelProfileQR: UIImage { Images.channelProfileQR }
    public static var channelProfileBell: UIImage { Images.channelProfileBell }
    public static var channelProfileMore: UIImage { Images.channelProfileMore }
    public static var channelProfileAutoDeleteMessages: UIImage { Images.channelProfileAutoDeleteMessages }
    public static var channelProfileMembers: UIImage { Images.channelProfileMembers }
    public static var channelProfileAdmins: UIImage { Images.channelProfileAdmins }
    public static var channelProfileEditAvatar: UIImage { Images.channelProfileEditAvatar }
    public static var channelReply: UIImage { Images.channelReply }
    
    public static var audioPlayerCancel: UIImage { Images.audioPlayerCancel }
    public static var audioPlayerDelete: UIImage { Images.audioPlayerDelete }
    public static var audioPlayerLock: UIImage { Images.audioPlayerLock }
    public static var audioPlayerMic: UIImage { Images.audioPlayerMic }
    public static var audioPlayerMicGreen: UIImage { Images.audioPlayerMicGreen }
    public static var audioPlayerPauseGrey: UIImage { Images.audioPlayerPauseGrey }
    public static var audioPlayerPause: UIImage { Images.audioPlayerPause }
    public static var audioPlayerPlayGrey: UIImage { Images.audioPlayerPlayGrey }
    public static var audioPlayerPlay: UIImage { Images.audioPlayerPlay }
    public static var audioPlayerSendLarge: UIImage { Images.audioPlayerSendLarge }
    public static var audioPlayerStop: UIImage { Images.audioPlayerStop }
    public static var audioPlayerUnlock: UIImage { Images.audioPlayerUnlock }
    
    public static var chatPin: UIImage { Images.chatPin }
    public static var chatUnpin: UIImage { Images.chatUnpin }
    public static var chatBlock: UIImage { Images.chatBlock }
    public static var chatUnBlock: UIImage { Images.chatUnBlock }
    public static var chatClear: UIImage { Images.chatClear }
    public static var chatDelete: UIImage { Images.chatDelete }
    public static var chatLeave: UIImage { Images.chatLeave }
    public static var chatSavePhoto: UIImage { Images.chatSavePhoto }
    public static var chatForward: UIImage { Images.chatForward }
    public static var chatShare: UIImage { Images.chatShare }
    public static var chatEdit: UIImage { Images.chatEdit }
    public static var chatRevoke: UIImage { Images.chatRevoke }
    
    public static var chatActionCamera: UIImage { Images.chatActionCamera }
    public static var chatActionGallery: UIImage { Images.chatActionGallery }
    public static var chatActionFile: UIImage { Images.chatActionFile }
    public static var chatActionContact: UIImage { Images.chatActionContact }
    public static var chatActionLocation: UIImage { Images.chatActionLocation }
    
    public static var searchIcon: UIImage { Images.searchIcon }
    public static var searchFill: UIImage { Images.searchFill }
    
    public static var downloadStart: UIImage { Images.downloadStart }
    public static var downloadStop: UIImage { Images.downloadStop }
    
    public static var replyPlay: UIImage { Images.replyPlay }
    public static var closeIcon: UIImage { Images.closeIcon }
    public static var messageFile: UIImage { Images.messageFile }
}
