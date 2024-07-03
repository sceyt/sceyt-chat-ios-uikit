//
//  AppearanceProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol AppearanceProvider {
    associatedtype AppearanceType
    static var appearance: AppearanceType { get set }
    var appearance: AppearanceType { get }
}

public extension AppearanceProvider {
    var appearance: AppearanceType {
        Self.appearance
    }
}

extension ChannelListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var tabBarItemBadgeColor: UIColor? = .kitRed
        public var connectionIndicatorColor: UIColor? = .kitBlue
        public var navigationBarBackgroundColor: UIColor? = .init(light: 0xFFFFFF, dark: 0x19191B)
        
        public init() {}
    }
}

extension ChannelCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var separatorColor: UIColor? = .separator
        
        public var unreadCountBackgroundColor: UIColor? = Colors.kitBlue
        public var unreadCountMutedBackgroundColor: UIColor? = .init(light: 0xA0A1B0, dark: 0x3B3B3D)
        public var unreadCountFont: UIFont? = Fonts.semiBold.withSize(14)
        public var unreadCountTextColor: UIColor? = .white
        
        public var subjectLabelFont: UIFont? = Fonts.semiBold.withSize(17)
        public var subjectLabelTextColor: UIColor? = Colors.textBlack
        
        public var senderLabelFont: UIFont? = Fonts.regular.withSize(15)
        public var senderLabelTextColor: UIColor? = Colors.textBlack
        
        public var messageLabelFont: UIFont? = Fonts.regular.withSize(15)
        public var messageLabelTextColor: UIColor? = Colors.textGray
        
        public var deletedMessageFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(15)
        public var deletedMessageColor: UIColor? = Colors.textGray
        
        public var draftMessageTitleFont: UIFont? = Fonts.regular.withSize(15)
        public var draftMessageTitleColor: UIColor? = Colors.textRed
        
        public var draftMessageContentFont: UIFont? = Fonts.regular.withSize(15)
        public var draftMessageContentColor: UIColor? = Colors.textGray2
        
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(14)
        public var dateLabelTextColor: UIColor? = Colors.textGray
        
        public var typingFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(15)
        public var typingTextColor: UIColor? = Colors.textGray
        
        public var mentionFont: UIFont? = Fonts.bold.withSize(15)
        public var mentionColor: UIColor? = Colors.textGray
        
        public var linkColor: UIColor? = Colors.textGray
        public var linkFont: UIFont? = Fonts.regular.withSize(15)
        
        public var ticksViewTintColor: UIColor? = .init(rgb: 0x6B72FF)
        public var ticksViewDisabledTintColor: UIColor? = Colors.textGray
        public var ticksViewErrorTintColor: UIColor? = Colors.textRed

        public init() {}
    }
}

extension ChannelSwipeActionsConfiguration: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public static var deleteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.delete,
            backgroundColor: .textRed)
        public static var leaveContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.leave,
            backgroundColor: .init(light: 0xA0A1B0, dark: 0x3B3B3D)
        )
        public static var readContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.read,
            backgroundColor: .init(rgb: 0x63AFFF)
        )
        public static var unreadContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unread, 
            backgroundColor: .init(rgb: 0x63AFFF)
        )
        public static var muteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.mute, 
            backgroundColor: .init(rgb: 0xFBB019)
        )
        public static var unmuteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unmute,
            backgroundColor: .init(rgb: 0xFBB019)
        )
        public static var pinContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.pin,
            backgroundColor: .init(rgb: 0xB463E7)
        )
        public static var unpinContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unpin, 
            backgroundColor: .init(rgb: 0xB463E7)
        )

        public init() {}
    }
}

extension ChannelVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var coverViewBackgroundColor: UIColor? = .clear
        public var navigationBarBackgroundColor: UIColor? = .init(light: 0xFFFFFF, dark: 0x19191B)
        public var searchBarBackgroundColor: UIColor? = .init(
            light: 0xF1F2F6,
            dark: 0x232324
        )
        public var searchBarActivityIndicatorColor: UIColor? = .init(
            light: 0xA0A1B0,
            dark: 0x969A9F
        )
        
        public var joinFont: UIFont? = Fonts.semiBold.withSize(16)
        public var joinColor: UIColor? = .kitBlue
        public var joinBackgroundColor: UIColor? = .background2

        public init() {}
    }
}

extension ChannelVC.TitleView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var titleColor: UIColor? = Colors.textBlack
        public var titleFont: UIFont? = Fonts.semiBold.withSize(19)
        
        public var subtitleColor: UIColor? = Colors.textBlack
        public var subtitleFont: UIFont? = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension ChannelUnreadCountView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var unreadCountFont: UIFont? = Fonts.regular.withSize(12)
        public var unreadCountTextColor: UIColor? = .white
        public var unreadCountBackgroundColor: UIColor? = Colors.kitBlue
        
        public init() {}
    }
}

extension MessageCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .clear
        public var titleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var titleColor: UIColor? = nil // initials random
        public var messageFont: UIFont? = Fonts.regular.withSize(16)
        public var messageColor: UIColor? = Colors.textBlack
        public var deletedMessageFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(16)
        public var deletedMessageColor: UIColor? = Colors.textGray
        public var bubbleColor: (in: UIColor?, out: UIColor?) = (.background2,
                                                                 .init(light: 0xE3E7FF, dark: 0x212239))
        public var highlightedBubbleColor: (in: UIColor?, out: UIColor?) = (Colors.textGray.withAlphaComponent(0.4), Colors.textGray.withAlphaComponent(0.4))
        public var highlightedSearchResultColor: (in: UIColor?, out: UIColor?) = (
            .init(light: 0xE4E6EE, dark: 0x303032),
            .init(light: 0xD1D8FF, dark: 0x2E3052)
        )
        public var highlightedOverlayColor: (in: UIColor?, out: UIColor?) = (UIColor(hex: "#17191C", alpha: 0.4), UIColor(hex: "#17191C", alpha: 0.4))
        public var linkColor: UIColor? = Colors.kitBlue
        public var linkFont: UIFont? = Fonts.regular.withSize(16)
        public var linkTitleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var linkTitleColor: UIColor? = Colors.textBlack
        public var linkDescriptionFont: UIFont? = Fonts.regular.withSize(13)
        public var linkDescriptionColor: UIColor? = Colors.textGray
        public var linkPreviewBackgroundColor: (in: UIColor?, out: UIColor?) = (.init(light: 0xE4E6EE, dark: 0xC9D1FF),
                                                                                .init(light: 0xD1D8FF, dark: 0x212239))
        public var highlightedLinkBackgroundColor: UIColor? = Colors.textGray2
        public var mentionUserColor: UIColor? = Colors.kitBlue
        public var dateTickBackgroundViewColor: UIColor? = Colors.backgroundTransparent
        
        public var separatorViewBackgroundColor: UIColor? = .clear
        public var separatorViewTextBackgroundColor: UIColor? = .backgroundTransparent
        public var separatorViewFont: UIFont? = Fonts.semiBold.withSize(13)
        public var separatorViewTextColor: UIColor? = .textWhite
        public var separatorViewTextBorderColor: UIColor? = .clear
        
        public var newMessagesSeparatorViewBackgroundColor: UIColor? = .background2
        public var newMessagesSeparatorViewFont: UIFont? = Fonts.semiBold.withSize(14)
        public var newMessagesSeparatorViewTextColor: UIColor? = .textGray
        
        public var infoViewStateFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(12)
        public var infoViewStateTextColor: UIColor? = Colors.textGray
        public var infoViewStateWithBackgroundTextColor = UIColor.white
        public var infoViewDateFont: UIFont? = Fonts.regular.withSize(12)
        public var infoViewDateTextColor: UIColor? = Colors.textGray
        public var infoViewRevertColorOnBackgroundView: UIColor? = .white
        
        public var replyCountTextColor: UIColor? = Colors.kitBlue
        public var replyCountTextFont: UIFont? = Fonts.semiBold.withSize(12)
        public var replyArrowStrokeColor: UIColor? = Colors.separator
        public var replyUserTitleColor: UIColor? = Colors.kitBlue
        public var replyUserTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        public var replyMessageColor: UIColor? = Colors.textBlack
        public var replyMessageVoiceDurationColor: UIColor? = Colors.kitBlue
        public var replyMessageFont: UIFont? = Fonts.regular.withSize(14)
        public var replyMessageBorderColor: UIColor? = Colors.kitBlue
        public var forwardTitleColor: UIColor? = Colors.kitBlue
        public var forwardTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        
        public var reactionContainerBackgroundColor: UIColor = .init(light: 0xFFFFFF, dark: 0x303032)
        public var reactionCommonScoreFont: UIFont = Fonts.regular.withSize(13)
        public var reactionFont: UIFont? = Fonts.regular.withSize(13)
        public var reactionColor: UIColor? = Colors.textBlack
        public var reactionBackgroundColor: (in: UIColor?, out: UIColor?) = (.background2,
                                                                             .init(light: 0xE3E7FF, dark: 0x212239))
        public var reactionBorderColor: (in: UIColor?, out: UIColor?) = (nil, nil)
        
        public var videoTimeTextColor: UIColor? = .white
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .backgroundTransparent
        
        public var audioSpeedBackgroundColor: UIColor? = .init(light: .white, dark: .init(rgb: 0x757D8B))
        public var audioSpeedColor: UIColor? = .init(light: .init(rgb: 0x757D8B), dark: .white)
        public var audioSpeedFont: UIFont? = Fonts.semiBold.withSize(12)
        public var audioDurationColor: UIColor? = .init(light: .init(rgb: 0x757D8B), dark: .white)
        public var audioDurationFont: UIFont? = Fonts.regular.withSize(11)
        public var audioProgressBackgroundColor: UIColor? = .kitBlue
        public var audioProgressTrackColor: UIColor? = .white.withAlphaComponent(0.3)
        public var audioProgressColor: UIColor? = .white
        
        public var ticksViewTintColor: UIColor? = .init(rgb: 0x6B72FF)
        public var ticksViewDisabledTintColor: UIColor? = Colors.textGray
        public var ticksViewErrorTintColor: UIColor? = Colors.textRed
        
        public var attachmentFileNameFont: UIFont? = Fonts.semiBold.withSize(16)
        public var attachmentFileNameColor: UIColor? = .textBlack
        public var attachmentFileSizeFont: UIFont? = Fonts.regular.withSize(12)
        public var attachmentFileSizeColor: UIColor? = .textGray

        public init() {}
    }
}

extension ComposerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var videoAttachmentTimeTextColor: UIColor? = .white
        public var videoAttachmentTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoAttachmentTimeBackgroundColor: UIColor? = .backgroundTransparent
        
        public var fileAttachmentTitleTextColor: UIColor? = .textBlack
        public var fileAttachmentTitleTextFont: UIFont? = Fonts.semiBold.withSize(16)
        public var fileAttachmentSubtitleTextColor: UIColor? = .textGray
        public var fileAttachmentSubtitleTextFont: UIFont? = Fonts.regular.withSize(11)
        public var fileAttachmentBackgroundColor: UIColor? = .background2
        
        public var actionViewBackgroundColor: UIColor? = .background2
        public var actionReplyTitleColor: UIColor? = .kitBlue
        public var actionReplierTitleColor: UIColor? = .kitBlue
        public var actionReplyTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        public var actionReplierTitleFont: UIFont? = Fonts.bold.withSize(13)
        public var actionMessageColor: UIColor? = .textGray
        public var actionMessageVoiceDurationColor: UIColor? = .kitBlue
        public var actionMessageFont: UIFont? = Fonts.regular.withSize(13)
        public var actionLinkPreviewTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        public var actionLinkPreviewTitleColor: UIColor? = .kitBlue
        
        public var mediaViewBackgroundColor: UIColor? = .background

        public var dividerColor = Colors.separator
        public var backgroundColor: UIColor? = Colors.background
        public var recorderBackgroundColor: UIColor? = .background
        public var recorderPlayerBackgroundColor: UIColor? = .background2
        public var recorderDurationFont: UIFont? = Fonts.regular.withSize(12)
        public var recorderDurationColor: UIColor? = .init(light: .textGray, dark: .white)
        public var recorderTimeFont: UIFont? = Fonts.regular.withSize(12)
        public var recorderTimeColor: UIColor? = .init(light: .textGray, dark: .white)
        public var recorderActiveWaveColor: UIColor = .kitBlue
        public var recorderInActiveWaveColor: UIColor = .init(rgb: 0x757D8B).withAlphaComponent(0.6)
        public var recorderSlideToCancelFont: UIFont? = Fonts.regular.withSize(16)
        public var recorderSlideToCancelColor: UIColor? = .init(light: .textGray, dark: .white)
        public var recorderCancelFont: UIFont? = Fonts.regular.withSize(16)
        public var recorderCancelColor: UIColor? = .textRed
        public var recorderRecordingDurationFont: UIFont? = Fonts.regular.withSize(16)
        public var recorderRecordingDurationColor: UIColor? = .init(light: .black, dark: .white)
        public var recorderRecordingDotColor: UIColor? = .red

        public init() {}
    }
}

extension ComposerVC.InputTextView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var borderColor: UIColor? = .clear
        public var backgroundColor: UIColor? = .background2
        public var placeholderColor: UIColor? = .textGray2
        public var textFont: UIFont = Fonts.regular.withSize(16)
        public var textColor: UIColor? = .init(light: .darkText, dark: .white)

        public init() {}
    }
}

extension ChannelProfileVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var titleColor: UIColor? = .textBlack
        public var titleFont: UIFont? = Fonts.bold.withSize(20)
        public var subtitleColor: UIColor? = .textGray
        public var subtitleFont: UIFont? = Fonts.regular.withSize(16)
        
        public var descriptionLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var descriptionFont: UIFont? = Fonts.regular.withSize(16)
        public var descriptionLabelColor: UIColor? = .textGray
        public var descriptionColor: UIColor? = .textBlack

        public var uriColor: UIColor? = .textBlack
        public var uriFont: UIFont? = Fonts.regular.withSize(16)
        
        public var itemColor: UIColor? = .textBlack
        public var itemFont: UIFont? = Fonts.regular.withSize(16)
        public var detailColor: UIColor? = .textGray
        public var detailFont: UIFont? = Fonts.regular.withSize(16)
        
        public var backgroundColor: UIColor? = .background4
        
        public var cellSeparatorColor: UIColor? = Colors.separator
        public var cellBackgroundColor: UIColor? = .background3

        public init() {}
    }
}

extension ChannelProfileEditVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var textFieldColor: UIColor? = .textBlack
        public var textFieldFont: UIFont? = Fonts.regular.withSize(16)
        public var textFieldPlaceholderColor: UIColor? = .textGray
        public var textFieldBackgroundColor: UIColor? = .background3
        public var successColor: UIColor? = .kitBlue
        public var errorColor: UIColor? = .textRed
        public var errorFont: UIFont? = Fonts.regular.withSize(13)
        public var separatorColor: UIColor? = .separator
        public var backgroundColor: UIColor? = .background4
        
        public init() {}
    }
}

extension ChannelMemberListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background

        public init() {}
    }
}

extension ChannelMemberCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var separatorColor: UIColor? = Colors.separator
        
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleLabelTextColor: UIColor? = Colors.textBlack
        
        public var statusLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var statusLabelTextColor: UIColor? = .textGray
        
        public var roleLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var roleLabelTextColor: UIColor? = .textGray
        public var roleLabelBackgroundColor: UIColor? = .clear
        
        public init() {}
    }
}

extension ChannelUserCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .clear
        public var separatorColor: UIColor? = Colors.separator
        
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleLabelTextColor: UIColor? = Colors.textBlack
        
        public var statusLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var statusLabelTextColor: UIColor? = .textGray
        
        public init() {}
    }
}

extension ChannelMemberAddCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var titleLabelFont: UIFont? = Fonts.regular.withSize(16)
        public var titleLabelTextColor: UIColor? = Colors.textBlack
        public var separatorColor: UIColor? = Colors.separator
        
        public init() {}
    }
}

extension PhotosPickerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var toolbarBackgroundColor: UIColor? = .background
        
        public var attachButtonBackgroundColor: UIColor? = .kitBlue
        
        public var attachTitleColor: UIColor? = .white
        public var attachTitleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var attachTitleBackgroundColor: UIColor? = .clear
        
        public var attachCountTextColor: UIColor? = .kitBlue
        public var attachCountTextFont: UIFont? = Fonts.semiBold.withSize(14)
        public var attachCountBackgroundColor: UIColor? = .white

        public init() {}
    }
}

extension ChannelMediaListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background

        public var videoTimeTextColor: UIColor? = .white
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .backgroundTransparent
        
        public init() {}
    }
}

extension ChannelFileListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleTextColor: UIColor? = .textBlack
        public var titleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var detailTextColor: UIColor? = .textGray
        public var detailFont: UIFont? = Fonts.regular.withSize(13)
        
        public var downloadBackgroundColor: UIColor? = .background2
        public var progressColor: UIColor? = .kitBlue
        public var trackColor: UIColor? = .clear

        public init() {}
    }
}

extension ChannelLinkListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background

        public var titleLabelTextColor: UIColor? = .textBlack
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var linkLabelTextColor: UIColor? = .kitBlue
        public var linkLabelFont: UIFont? = Fonts.regular.withSize(14)
        public var detailLabelTextColor: UIColor? = .textGray
        public var detailLabelFont: UIFont? = Fonts.regular.withSize(13)

        public init() {}
    }
}

extension ChannelVoiceListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background

        public var titleLabelTextColor: UIColor? = .textBlack
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var durationLabelTextColor: UIColor? = .textBlack
        public var durationLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var dateLabelTextColor: UIColor? = .textGray
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(13)
        
        public var downloadBackgroundColor: UIColor? = .kitBlue
        public var progressColor: UIColor? = .white
        public var trackColor: UIColor? = .clear
        
        public init() {}
    }
}

extension PhotosPickerCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background4
        public var timeTextColor: UIColor? = .white
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .backgroundTransparent
        
        public init() {}
    }
}

extension CircularProgressView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var progressColor: UIColor? = .white
        public var trackColor: UIColor? = .clear
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .textGray.withAlphaComponent(0.4)
        
        public init() {}
    }
}

extension MentioningUserListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .clear
        public var tableViewBackgroundColor: UIColor? = .background3
        public var shadowColor: UIColor? = .init(rgb: 0x111539, alpha: 0.16)

        public init() {}
    }
}

extension MentioningUserViewCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleLabelTextColor: UIColor? = Colors.textBlack
        public var backgroundColor: UIColor? = .background3

        public init() {}
    }
}

// Helper
public struct ContextualActionAppearance {
    public var style: UIContextualAction.Style
    public var title: String?
    public var image: UIImage?
    public var backgroundColor: UIColor?
    
    public init(
        style: UIContextualAction.Style = .normal,
        title: String? = nil,
        image: UIImage? = nil,
        backgroundColor: UIColor? = nil)
    {
        self.style = style
        self.title = title
        self.image = image
        self.backgroundColor = backgroundColor
    }
}

public struct InitialsBuilderAppearance {
    public var font: UIFont {
        let font = Fonts.semiBold
        switch size.minSide {
        case 72...:
            return font.withSize(size.minSide * 24 / 72)
        case 46...:
            return font.withSize(20)
        default:
            return font.withSize(16)
        }
    }
    public var color: UIColor
    public var size: CGSize
    
    public var adjustsFontSizeToFitWidth = true
    
    public init(
        color: UIColor = .white,
        size: CGSize = .init(width: 60, height: 60))
    {
        self.color = color
        self.size = size
    }
}

extension PreviewerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = UIColor(rgb: 0x17191C)
        public var minimumTrackTintColor = UIColor.white
        public var maximumTrackTintColor = UIColor(rgb: 0x757D8B)
        public var tintColor = UIColor.white
        public var controlFont = Fonts.regular.withSize(13)
        public var titleFont = Fonts.bold.withSize(16)
        public var subTitleFont = Fonts.regular.withSize(13)

        public init() {}
    }
}

extension EmojiVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = Colors.background
        public var moreButtonBackgroundColor: UIColor? = Colors.background2
        public var selectedBackgroundColor: UIColor? = Colors.highlighted
        
        public init() {}
    }
}

extension MenuController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = Colors.background2
        
        public init() {}
    }
}

extension MenuCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background2
        public var selectedBackgroundColor: UIColor? = .init(light: 0xD9D9DF, dark: 0x303032)
        public var separatorColor: UIColor? = .separator
        public var imageTintColor: UIColor? = .textBlack
        public var textColor: UIColor? = .textBlack
        public var textFont: UIFont? = Fonts.regular.withSize(16)
        public var destructiveTextColor: UIColor? = .textRed
        public var destructiveImageTintColor: UIColor? = .textRed
        
        public init() {}
    }
}

extension ReactionVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = Colors.background3
        
        public init() {}
    }
}

extension ReactionScoreCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = Colors.background3
        public var selectedBackgroundColor: UIColor? = Colors.kitBlue
        public var borderColor: UIColor? = .separator
        public var selectedBorderColor: UIColor? = .clear
        public var textColor: UIColor? = Colors.textGray
        public var textFont: UIFont? = Fonts.semiBold.withSize(14)
        public var selectedTextColor: UIColor? = .white
        
        public init() {}
    }
}

extension ActionPresentationController: AppearanceProvider {
    public static var appearance = Appearance()

    public struct Appearance {
        public var dimColor: UIColor? = UIColor(light: .init(rgb: 0x000000, alpha: 0.2),
                                                dark: .init(rgb: 0x141000, alpha: 0.2))
        
        public init() {}
    }
}

extension EmojiListSectionHeaderView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var textColor: UIColor? = .textGray
        public var textFont: UIFont? = Fonts.regular.withSize(12)
        
        public init() {}
    }
}

extension HoldButton: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = UIColor.white
        public var highlightedBackgroundColor = UIColor.white
        public var titleColor = Colors.textBlack
        public var titleFont = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension ChannelAvatarVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var separatorColor: UIColor? = .separator

        public init() {}
    }
}

extension ChannelVC.SelectingView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = Colors.background
        public var dividerColor = Colors.separator

        public init() {}
    }
}

extension NativeSegmentedController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background3
        public var font: UIFont? = Fonts.semiBold.withSize(16)
        public var selectedTextColor: UIColor? = .textBlack
        public var textColor: UIColor? = .textGray
        public init() {}
    }
}

extension SheetVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .black.withAlphaComponent(0.5)
        public var contentBackgroundColor: UIColor? = .background3
        public var titleFont: UIFont? = Fonts.semiBold.withSize(20)
        public var titleColor: UIColor? = .textGray
        public var doneFont: UIFont? = Fonts.semiBold.withSize(16)
        public var doneColor: UIColor? = .kitBlue
        public var separatorColor: UIColor? = .separator
        
        public init() {}
    }
}

extension BottomSheet: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColors: (normal: UIColor, highlighted: UIColor)? = (.background3,
                                                                                 Colors.highlighted)
        public var titleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var titleColor: UIColor? = .textGray
        public var buttonFont: UIFont? = Fonts.regular.withSize(16)
        public var normalTextColor: UIColor? = .textBlack
        public var normalIconColor: UIColor? = .kitBlue
        public var destructiveTextColor: UIColor? = .textRed
        public var destructiveIconColor: UIColor? = .textRed
        public var cancelFont: UIFont? = Fonts.semiBold.withSize(18)
        public var cancelTextColor: UIColor? = .kitBlue
        public var separatorColor: UIColor? = .separator
        
        public init() {}
    }
}

extension Alert: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColors: (normal: UIColor, highlighted: UIColor)? = (.background3,
                                                                                 .init(light: 0xE8E9EE, dark: 0x303032))
        public var titleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleColor: UIColor? = .textGray
        public var messageFont: UIFont? = Fonts.regular.withSize(13)
        public var messageColor: UIColor? = .textGray
        public var buttonFont: UIFont? = Fonts.regular.withSize(16)
        public var preferedButtonFont: UIFont? = Fonts.semiBold.withSize(16)
        public var normalTextColor: UIColor? = .kitBlue
        public var normalIconColor: UIColor? = .kitBlue
        public var destructiveTextColor: UIColor? = .textRed
        public var destructiveIconColor: UIColor? = .textRed
        public var cancelTextColor: UIColor? = .textBlack
        public var separatorColor: UIColor? = .separator
        
        public init() {}
    }
}

extension CreateChannelHeaderView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background2
        public var textColor: UIColor? = Colors.textGray
        public var font: UIFont? = Fonts.semiBold.withSize(13)
        public var textAlignment: NSTextAlignment = .left

        public init() {}
    }
}

extension SelectChannelMembersVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension SearchController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var backgroundImage: UIImage? = .searchBackground
        public var font: UIFont? = Fonts.regular.withSize(16)
        public var textColor: UIColor? = .textBlack
        public var placeholderColor: UIColor? = .init(light: 0xA0A1B0, dark: 0x76787A)
        public var tintColor: UIColor? = .kitBlue

        public init() {}
    }
}

extension NavigationController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var standard = {
            $0.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor(light: 0x111539, dark: 0xE1E3E6)
            ]
            $0.backgroundColor = .init(light: 0xFFFFFF, dark: 0x19191B)
            $0.shadowColor = .separator
            return $0
        }(UINavigationBarAppearance())
        
        public var tintColor: UIColor? = .kitBlue
        
        public init() {}
    }
}

extension ChannelProfileFileHeaderView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var headerBackgroundColor: UIColor? = .background2
        public var headerTextColor: UIColor? = .textGray
        public var headerFont: UIFont? = Fonts.semiBold.withSize(13)
        
        public init() {}
    }
}

extension ChannelProfileEditAvatarCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var avatarBackgroundColor: UIColor? = .init(light: 0x979A9A, dark: 0x303032)

        public init() {}
    }
}

extension ImageCropperVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .init(rgb: 0x19191B)
        public var buttonBackgroundColor: UIColor? = .init(rgb: 0x19191B)
        public var buttonFont: UIFont? = Fonts.semiBold.withSize(16)
        public var buttonColor: UIColor? = .white

        public init() {}
    }
}

extension CreateNewChannelVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension CreateChatActionsView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var font: UIFont? = Fonts.regular.withSize(16)
        public var color: UIColor? = .kitBlue
        public var separatorColor: UIColor? = .separator

        public init() {}
    }
}

extension CreatePrivateChannelProfileView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var avatarBackgroundColor: UIColor? = .init(light: 0x979A9A, dark: 0x303032)
        public var separatorColor: UIColor? = .separator
        public var fieldFont: UIFont? = Fonts.regular.withSize(16)
        public var fieldTextColor: UIColor? = .textBlack
        public var fieldPlaceHolderTextColor: UIColor? = .textGray
        public var commentFont: UIFont? = Fonts.regular.withSize(13)
        public var commentTextColor: UIColor? = .textGray
        public var errorFont: UIFont? = Fonts.regular.withSize(13)
        public var errorTextColor: UIColor? = .textRed
    }
}

extension CreatePrivateChannelVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension SelectedUserCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}

        public var font: UIFont? = Fonts.regular.withSize(13)
        public var textColor: UIColor? = Colors.textBlack
    }
}

extension UserReactionListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}

        public var backgroundColor: UIColor? = .background3
    }
}

extension UserReactionCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var userLabelFont: UIFont? = Fonts.bold.withSize(16)
        public var reactionLabelFont: UIFont? = Fonts.bold.withSize(24)
        public var userLabelColor: UIColor? = .textBlack
        public var reactionLabelColor: UIColor? = .textBlack
    }
}

extension NoDataView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(20)
        public var messageLabelFont: UIFont? = Fonts.regular.withSize(15)
        public var titleLabelColor: UIColor? = .textBlack
        public var messageLabelColor: UIColor? = .textGray
    }
}

extension ChannelCreatedView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var labelBackgroundColor: UIColor? = .backgroundTransparent
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(13)
        public var messageLabelFont: UIFont? = Fonts.semiBold.withSize(13)
        public var titleLabelColor: UIColor? = .textWhite
        public var messageLabelColor: UIColor? = .textWhite
    }
}

extension ChannelVC.BottomView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
        public var labelFont: UIFont? = Fonts.regular.withSize(16)
        public var labelColor: UIColor? = .textBlack
        public var iconColor: UIColor? = .kitBlue
        public var separatorColor: UIColor? = .separator
    }
}

extension ChannelVC.SearchControlsView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var separatorColor: UIColor? = .init(light: 0xE8E9EE, dark: 0x303032)
        public var backgroundColor: UIColor? = .background
        public var buttonTintColor: UIColor? = .kitBlue
        public var textColor: UIColor? = .init(light: 0x000000, dark: 0xFFFFFF)
        public var textFont: UIFont? = Fonts.regular.withSize(16)
    }
}

extension EmojiSectionToolBar: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background3
        public var normalColor: UIColor? = .textGray3
        public var selectedColor: UIColor? = .kitBlue
    }
}

extension EmojiListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background3
        public var normalColor: UIColor? = .textGray3
        public var selectedColor: UIColor? = .kitBlue
    }
}

extension MessageInfoVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background4
        public var cellBackgroundColor: UIColor? = .background3
        
        public var infoFont: UIFont? = Fonts.semiBold.withSize(14)
        public var infoValueFont: UIFont? = Fonts.regular.withSize(14)
        public var infoColor: UIColor? = .textBlack
        public var infoValueColor: UIColor? = .textGray
        
        public var headerFont: UIFont? = Fonts.semiBold.withSize(13)
        public var headerColor: UIColor? = .textGray
        
        public var nameFont: UIFont? = Fonts.semiBold.withSize(16)
        public var nameColor: UIColor? = .textBlack

        public var dateTimeFont: UIFont? = Fonts.regular.withSize(13)
        public var dateTimeColor: UIColor? = .textGray
    }
}

extension ChannelForwardVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
    }
}

extension ChannelSearchResultsVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
    }
}
