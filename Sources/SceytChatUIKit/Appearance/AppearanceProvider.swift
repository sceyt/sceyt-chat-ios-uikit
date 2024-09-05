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
        public var tabBarItemBadgeColor: UIColor? = .stateError
        public var connectionIndicatorColor: UIColor? = .primaryAccent
        public var navigationBarBackgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension ChannelCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var separatorColor: UIColor? = .border
        
        public var unreadCountBackgroundColor: UIColor? = UIColor.primaryAccent
        public var unreadCountMutedBackgroundColor: UIColor? = .surface3
        public var unreadCountFont: UIFont? = Fonts.semiBold.withSize(14)
        public var unreadCountTextColor: UIColor? = .textOnPrimary
        
        public var subjectLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var subjectLabelTextColor: UIColor? = UIColor.primaryText
        
        public var senderLabelFont: UIFont? = Fonts.regular.withSize(15)
        public var senderLabelTextColor: UIColor? = UIColor.primaryText
        
        public var messageLabelFont: UIFont? = Fonts.regular.withSize(15)
        public var messageLabelTextColor: UIColor? = UIColor.secondaryText
        
        public var deletedMessageFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(15)
        public var deletedMessageColor: UIColor? = UIColor.secondaryText
        
        public var draftMessageTitleFont: UIFont? = Fonts.regular.withSize(15)
        public var draftMessageTitleColor: UIColor? = UIColor.stateError
        
        public var draftMessageContentFont: UIFont? = Fonts.regular.withSize(15)
        public var draftMessageContentColor: UIColor? = UIColor.footnoteText
        
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(14)
        public var dateLabelTextColor: UIColor? = UIColor.secondaryText
        
        public var typingFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(15)
        public var typingTextColor: UIColor? = UIColor.secondaryText
        
        public var mentionFont: UIFont? = Fonts.bold.withSize(15)
        public var mentionColor: UIColor? = UIColor.secondaryText
        
        public var linkColor: UIColor? = UIColor.secondaryText
        public var linkFont: UIFont? = Fonts.regular.withSize(15)
        
        public var ticksViewTintColor: UIColor? = .primaryAccent
        public var ticksViewDisabledTintColor: UIColor? = UIColor.secondaryText
        public var ticksViewErrorTintColor: UIColor? = UIColor.stateError
        
        public init() {}
    }
}

extension ChannelSwipeActionsConfiguration: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public static var deleteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.delete,
            backgroundColor: .stateError)
        public static var leaveContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.leave,
            backgroundColor: .surface3
        )
        public static var readContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.read,
            backgroundColor: .quaternaryAccent
        )
        public static var unreadContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unread,
            backgroundColor: .quaternaryAccent
        )
        public static var muteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.mute,
            backgroundColor: .secondaryAccent
        )
        public static var unmuteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unmute,
            backgroundColor: .secondaryAccent
        )
        public static var pinContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.pin,
            backgroundColor: .tertiaryAccent
        )
        public static var unpinContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unpin,
            backgroundColor: .tertiaryAccent
        )
        
        public init() {}
    }
}

extension ChannelVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var coverViewBackgroundColor: UIColor? = .clear
        public var navigationBarBackgroundColor: UIColor? = .background
        public var searchBarBackgroundColor: UIColor? = .surface1
        public var searchBarActivityIndicatorColor: UIColor? = .iconInactive
        
        public var joinFont: UIFont? = Fonts.semiBold.withSize(16)
        public var joinColor: UIColor? = .primaryAccent
        public var joinBackgroundColor: UIColor? = .surface1
        
        public init() {}
    }
}

extension ChannelVC.TitleView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var titleColor: UIColor? = UIColor.primaryText
        public var titleFont: UIFont? = Fonts.semiBold.withSize(19)
        
        public var subtitleColor: UIColor? = UIColor.primaryText
        public var subtitleFont: UIFont? = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension ChannelUnreadCountView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var unreadCountFont: UIFont? = Fonts.regular.withSize(12)
        public var unreadCountTextColor: UIColor? = .textOnPrimary
        public var unreadCountBackgroundColor: UIColor? = UIColor.primaryAccent
        
        public init() {}
    }
}

extension MessageCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public static var bubbleOutgoing: UIColor = Colors.bubbleOutgoing
        public static var bubbleOutgoingX: UIColor = Colors.bubbleOutgoingX
        public static var bubbleIncoming: UIColor = Colors.bubbleIncoming
        public static var bubbleIncomingX: UIColor = Colors.bubbleIncomingX
        
        public var backgroundColor: UIColor? = .clear
        public var titleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var titleColor: UIColor? = nil // initials random
        public var messageFont: UIFont? = Fonts.regular.withSize(16)
        public var messageColor: UIColor? = UIColor.primaryText
        public var deletedMessageFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(16)
        public var deletedMessageColor: UIColor? = UIColor.secondaryText
        public var bubbleColor: (in: UIColor?, out: UIColor?) = (Appearance.bubbleIncoming,
                                                                 Appearance.bubbleOutgoing)
        public var highlightedBubbleColor: (in: UIColor?, out: UIColor?) = (UIColor.secondaryText.withAlphaComponent(0.4), UIColor.secondaryText.withAlphaComponent(0.4))
        
        public var highlightedSearchResultColor: (in: UIColor?, out: UIColor?) = (
            Appearance.bubbleIncomingX,
            Appearance.bubbleOutgoingX
        )
        public var highlightedOverlayColor: (in: UIColor?, out: UIColor?) = (UIColor(hex: "#17191C", alpha: 0.4), UIColor(hex: "#17191C", alpha: 0.4))
        public var linkColor: UIColor? = UIColor.primaryAccent
        public var linkFont: UIFont? = Fonts.regular.withSize(16)
        public var linkTitleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var linkTitleColor: UIColor? = UIColor.primaryText
        public var linkDescriptionFont: UIFont? = Fonts.regular.withSize(13)
        public var linkDescriptionColor: UIColor? = UIColor.secondaryText
        public var linkPreviewBackgroundColor: (in: UIColor?, out: UIColor?) = (Appearance.bubbleIncomingX,
                                                                                Appearance.bubbleOutgoingX)
        public var highlightedLinkBackgroundColor: UIColor? = UIColor.footnoteText
        public var mentionUserColor: UIColor? = UIColor.primaryAccent
        public var dateTickBackgroundViewColor: UIColor? = .overlayBackground2
        
        public var separatorViewBackgroundColor: UIColor? = .clear
        public var separatorViewTextBackgroundColor: UIColor? = .overlayBackground1
        public var separatorViewFont: UIFont? = Fonts.semiBold.withSize(13)
        public var separatorViewTextColor: UIColor? = .textOnPrimary
        public var separatorViewTextBorderColor: UIColor? = .clear
        
        public var newMessagesSeparatorViewBackgroundColor: UIColor? = Appearance.bubbleIncoming
        public var newMessagesSeparatorViewFont: UIFont? = Fonts.semiBold.withSize(14)
        public var newMessagesSeparatorViewTextColor: UIColor? = .secondaryText
        
        public var infoViewStateFont: UIFont? = Fonts.regular.with(traits: .traitItalic).withSize(12)
        public var infoViewStateTextColor: UIColor? = UIColor.secondaryText
        public var infoViewStateWithBackgroundTextColor = UIColor.textOnPrimary
        public var infoViewDateFont: UIFont? = Fonts.regular.withSize(12)
        public var infoViewDateTextColor: UIColor? = UIColor.secondaryText
        public var infoViewRevertColorOnBackgroundView: UIColor? = .textOnPrimary
        
        public var replyCountTextColor: UIColor? = UIColor.primaryAccent
        public var replyCountTextFont: UIFont? = Fonts.semiBold.withSize(12)
        public var replyArrowStrokeColor: UIColor? = UIColor.border
        public var replyUserTitleColor: UIColor? = UIColor.primaryAccent
        public var replyUserTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        public var replyMessageColor: UIColor? = UIColor.primaryText
        public var replyMessageVoiceDurationColor: UIColor? = UIColor.primaryAccent
        public var replyMessageFont: UIFont? = Fonts.regular.withSize(14)
        public var replyMessageBorderColor: UIColor? = UIColor.primaryAccent
        public var replyBackgroundColor: (in: UIColor?, out: UIColor?) = (Appearance.bubbleIncomingX,
                                                                          Appearance.bubbleOutgoingX)
        public var forwardTitleColor: UIColor? = UIColor.primaryAccent
        public var forwardTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        
        public var reactionContainerBackgroundColor: UIColor = .backgroundSections
        public var reactionCommonScoreFont: UIFont = Fonts.regular.withSize(13)
        public var reactionFont: UIFont? = Fonts.regular.withSize(13)
        public var reactionColor: UIColor? = UIColor.primaryText
        public var reactionBackgroundColor: (in: UIColor?, out: UIColor?) = (Appearance.bubbleIncoming,
                                                                             Appearance.bubbleOutgoing)
        public var reactionBorderColor: (in: UIColor?, out: UIColor?) = (nil, nil)
        
        public var videoTimeTextColor: UIColor? = .textOnPrimary
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .overlayBackground2
        
        public var audioSpeedBackgroundColor: UIColor? = .background
        public var audioSpeedColor: UIColor? = .secondaryText
        public var audioSpeedFont: UIFont? = Fonts.semiBold.withSize(12)
        public var audioDurationColor: UIColor? = .footnoteText
        public var audioDurationFont: UIFont? = Fonts.regular.withSize(11)
        public var audioProgressBackgroundColor: UIColor? = .primaryAccent
        public var audioProgressTrackColor: UIColor? = .clear
        public var audioProgressColor: UIColor? = .textOnPrimary
        
        public var ticksViewTintColor: UIColor? = .primaryAccent
        public var ticksViewDisabledTintColor: UIColor? = UIColor.secondaryText
        public var ticksViewErrorTintColor: UIColor? = UIColor.stateError
        
        public var attachmentFileNameFont: UIFont? = Fonts.semiBold.withSize(16)
        public var attachmentFileNameColor: UIColor? = .primaryText
        public var attachmentFileSizeFont: UIFont? = Fonts.regular.withSize(12)
        public var attachmentFileSizeColor: UIColor? = .secondaryText
        
        public init() {}
    }
}

extension ComposerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var videoAttachmentTimeTextColor: UIColor? = .textOnPrimary
        public var videoAttachmentTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoAttachmentTimeBackgroundColor: UIColor? = .overlayBackground2
        
        public var fileAttachmentTitleTextColor: UIColor? = .primaryText
        public var fileAttachmentTitleTextFont: UIFont? = Fonts.semiBold.withSize(16)
        public var fileAttachmentSubtitleTextColor: UIColor? = .secondaryText
        public var fileAttachmentSubtitleTextFont: UIFont? = Fonts.regular.withSize(11)
        public var fileAttachmentBackgroundColor: UIColor? = .surface1
        
        public var actionViewBackgroundColor: UIColor? = .surface1
        public var actionReplyTitleColor: UIColor? = .primaryAccent
        public var actionReplierTitleColor: UIColor? = .primaryAccent
        public var actionReplyTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        public var actionReplierTitleFont: UIFont? = Fonts.bold.withSize(13)
        public var actionMessageColor: UIColor? = .secondaryText
        public var actionMessageVoiceDurationColor: UIColor? = .primaryAccent
        public var actionMessageFont: UIFont? = Fonts.regular.withSize(13)
        public var actionLinkPreviewTitleFont: UIFont? = Fonts.semiBold.withSize(13)
        public var actionLinkPreviewTitleColor: UIColor? = .primaryAccent
        
        public var mediaViewBackgroundColor: UIColor? = .background
        
        public var dividerColor = UIColor.border
        public var backgroundColor: UIColor? = UIColor.background
        public var recorderBackgroundColor: UIColor? = .background
        public var recorderPlayerBackgroundColor: UIColor? = .surface1
        public var recorderDurationFont: UIFont? = Fonts.regular.withSize(12)
        public var recorderDurationColor: UIColor? = .secondaryText
        public var recorderActiveWaveColor: UIColor = .primaryAccent
        public var recorderInActiveWaveColor: UIColor = .secondaryText
        public var recorderSlideToCancelFont: UIFont? = Fonts.regular.withSize(16)
        public var recorderSlideToCancelColor: UIColor? = .secondaryText
        public var recorderCancelFont: UIFont? = Fonts.regular.withSize(16)
        public var recorderCancelColor: UIColor? = .stateError
        public var recorderRecordingDurationFont: UIFont? = Fonts.regular.withSize(16)
        public var recorderRecordingDurationColor: UIColor? = .primaryText
        public var recorderRecordingDotColor: UIColor? = .stateError
        
        public init() {}
    }
}

extension ComposerVC.InputTextView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var borderColor: UIColor? = .clear
        public var backgroundColor: UIColor? = .surface1
        public var placeholderColor: UIColor? = .footnoteText
        public var textFont: UIFont = Fonts.regular.withSize(16)
        public var textColor: UIColor? = .primaryText
        
        public init() {}
    }
}

extension ChannelProfileVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var titleColor: UIColor? = .primaryText
        public var titleFont: UIFont? = Fonts.bold.withSize(20)
        public var subtitleColor: UIColor? = .secondaryText
        public var subtitleFont: UIFont? = Fonts.regular.withSize(16)
        
        public var descriptionLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var descriptionFont: UIFont? = Fonts.regular.withSize(16)
        public var descriptionLabelColor: UIColor? = .secondaryText
        public var descriptionColor: UIColor? = .primaryText
        
        public var uriColor: UIColor? = .primaryText
        public var uriFont: UIFont? = Fonts.regular.withSize(16)
        
        public var itemColor: UIColor? = .primaryText
        public var itemFont: UIFont? = Fonts.regular.withSize(16)
        public var detailColor: UIColor? = .secondaryText
        public var detailFont: UIFont? = Fonts.regular.withSize(16)
        
        public var backgroundColor: UIColor? = .backgroundSecondary
        
        public var cellSeparatorColor: UIColor? = UIColor.border
        public var cellBackgroundColor: UIColor? = .backgroundSections
        
        public init() {}
    }
}

extension ChannelProfileEditVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var textFieldColor: UIColor? = .primaryText
        public var textFieldFont: UIFont? = Fonts.regular.withSize(16)
        public var textFieldPlaceholderColor: UIColor? = .secondaryText
        public var textFieldBackgroundColor: UIColor? = .backgroundSections
        public var successColor: UIColor? = .stateSuccess
        public var errorColor: UIColor? = .stateError
        public var errorFont: UIFont? = Fonts.regular.withSize(13)
        public var separatorColor: UIColor? = .border
        public var backgroundColor: UIColor? = .backgroundSecondary
        
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
        public var separatorColor: UIColor? = UIColor.border
        
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleLabelTextColor: UIColor? = UIColor.primaryText
        
        public var statusLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var statusLabelTextColor: UIColor? = .secondaryText
        
        public var roleLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var roleLabelTextColor: UIColor? = .secondaryText
        public var roleLabelBackgroundColor: UIColor? = .clear
        
        public init() {}
    }
}

extension ChannelUserCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .clear
        public var separatorColor: UIColor? = UIColor.border
        
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleLabelTextColor: UIColor? = UIColor.primaryText
        
        public var statusLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var statusLabelTextColor: UIColor? = .secondaryText
        
        public init() {}
    }
}

extension ChannelMemberAddCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var titleLabelFont: UIFont? = Fonts.regular.withSize(16)
        public var titleLabelTextColor: UIColor? = UIColor.primaryText
        public var separatorColor: UIColor? = UIColor.border
        
        public init() {}
    }
}

extension PhotosPickerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var toolbarBackgroundColor: UIColor? = .background
        
        public var attachButtonBackgroundColor: UIColor? = .primaryAccent
        
        public var attachTitleColor: UIColor? = .textOnPrimary
        public var attachTitleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var attachTitleBackgroundColor: UIColor? = .clear
        
        public var attachCountTextColor: UIColor? = .primaryAccent
        public var attachCountTextFont: UIFont? = Fonts.semiBold.withSize(14)
        public var attachCountBackgroundColor: UIColor? = .textOnPrimary
        
        public init() {}
    }
}

extension ChannelMediaListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var videoTimeTextColor: UIColor? = .textOnPrimary
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .overlayBackground2
        
        public init() {}
    }
}

extension ChannelFileListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleTextColor: UIColor? = .primaryText
        public var titleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var detailTextColor: UIColor? = .secondaryText
        public var detailFont: UIFont? = Fonts.regular.withSize(13)
        
        public var downloadBackgroundColor: UIColor? = .surface1
        public var progressColor: UIColor? = .primaryAccent
        public var trackColor: UIColor? = .clear
        
        public init() {}
    }
}

extension ChannelLinkListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleLabelTextColor: UIColor? = .primaryText
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var linkLabelTextColor: UIColor? = .primaryAccent
        public var linkLabelFont: UIFont? = Fonts.regular.withSize(14)
        public var detailLabelTextColor: UIColor? = .secondaryText
        public var detailLabelFont: UIFont? = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension ChannelVoiceListView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleLabelTextColor: UIColor? = .primaryText
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var durationLabelTextColor: UIColor? = .primaryText
        public var durationLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var dateLabelTextColor: UIColor? = .secondaryText
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(13)
        
        public var downloadBackgroundColor: UIColor? = .primaryAccent
        public var progressColor: UIColor? = .textOnPrimary
        public var trackColor: UIColor? = .clear
        
        public init() {}
    }
}

extension PhotosPickerCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .surface1
        public var timeTextColor: UIColor? = .textOnPrimary
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .overlayBackground2
        
        public init() {}
    }
}

extension CircularProgressView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var progressColor: UIColor? = .textOnPrimary
        public var trackColor: UIColor? = .clear
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .overlayBackground2
        
        public init() {}
    }
}

extension MentioningUserListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .clear
        public var tableViewBackgroundColor: UIColor? = .backgroundSections
        public var shadowColor: UIColor? = .primaryText.withAlphaComponent(0.16)
        
        public init() {}
    }
}

extension MentioningUserViewCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleLabelTextColor: UIColor? = UIColor.primaryText
        public var backgroundColor: UIColor? = .background
        
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
        color: UIColor = .textOnPrimary,
        size: CGSize = .init(width: 60, height: 60))
    {
        self.color = color
        self.size = size
    }
}

extension PreviewerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = UIColor.backgroundDark
        public var minimumTrackTintColor = UIColor.textOnPrimary
        public var maximumTrackTintColor = UIColor.surface3
        public var tintColor = UIColor.textOnPrimary
        public var controlFont = Fonts.regular.withSize(13)
        public var titleFont = Fonts.bold.withSize(16)
        public var subTitleFont = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension EmojiVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = UIColor.backgroundSections
        public var moreButtonBackgroundColor: UIColor? = UIColor.surface2
        public var selectedBackgroundColor: UIColor? = UIColor.surface2
        
        public init() {}
    }
}

extension MenuController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = UIColor.surface1
        
        public init() {}
    }
}

extension MenuCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .surface1
        public var selectedBackgroundColor: UIColor? = .surface2
        public var separatorColor: UIColor? = .border
        public var imageTintColor: UIColor? = .primaryText
        public var textColor: UIColor? = .primaryText
        public var textFont: UIFont? = Fonts.regular.withSize(16)
        public var destructiveTextColor: UIColor? = .stateError
        public var destructiveImageTintColor: UIColor? = .stateError
        
        public init() {}
    }
}

extension ReactionVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = UIColor.background
        
        public init() {}
    }
}

extension ReactionScoreCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = UIColor.background
        public var selectedBackgroundColor: UIColor? = UIColor.primaryAccent
        public var borderColor: UIColor? = .border
        public var selectedBorderColor: UIColor? = .clear
        public var textColor: UIColor? = UIColor.secondaryText
        public var textFont: UIFont? = Fonts.semiBold.withSize(14)
        public var selectedTextColor: UIColor? = .textOnPrimary
        
        public init() {}
    }
}

extension ActionPresentationController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var dimColor: UIColor? = .overlayBackground1
        
        public init() {}
    }
}

extension EmojiListSectionHeaderView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var textColor: UIColor? = .secondaryText
        public var textFont: UIFont? = Fonts.regular.withSize(12)
        
        public init() {}
    }
}

extension HoldButton: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = UIColor.background
        public var highlightedBackgroundColor = UIColor.background
        public var titleColor = UIColor.primaryText
        public var titleFont = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension ChannelAvatarVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension ChannelVC.SelectingView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = UIColor.background
        public var dividerColor = UIColor.border
        
        public init() {}
    }
}

extension NativeSegmentedController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .backgroundSections
        public var font: UIFont? = Fonts.semiBold.withSize(16)
        public var selectedTextColor: UIColor? = .primaryText
        public var textColor: UIColor? = .secondaryText
        public init() {}
    }
}

extension SheetVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .overlayBackground1
        public var contentBackgroundColor: UIColor? = .background
        public var titleFont: UIFont? = Fonts.semiBold.withSize(20)
        public var titleColor: UIColor? = .secondaryText
        public var doneFont: UIFont? = Fonts.semiBold.withSize(16)
        public var doneColor: UIColor? = .primaryAccent
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension BottomSheet: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColors: (normal: UIColor, highlighted: UIColor)? = (.background,
                                                                                 UIColor.surface2)
        public var titleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var titleColor: UIColor? = .secondaryText
        public var buttonFont: UIFont? = Fonts.regular.withSize(16)
        public var normalTextColor: UIColor? = .primaryText
        public var normalIconColor: UIColor? = .primaryAccent
        public var destructiveTextColor: UIColor? = .stateError
        public var destructiveIconColor: UIColor? = .stateError
        public var cancelFont: UIFont? = Fonts.semiBold.withSize(18)
        public var cancelTextColor: UIColor? = .primaryAccent
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension Alert: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColors: (normal: UIColor, highlighted: UIColor)? = (.background,
                                                                                 .surface2)
        public var titleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var titleColor: UIColor? = .secondaryText
        public var messageFont: UIFont? = Fonts.regular.withSize(13)
        public var messageColor: UIColor? = .secondaryText
        public var buttonFont: UIFont? = Fonts.regular.withSize(16)
        public var preferedButtonFont: UIFont? = Fonts.semiBold.withSize(16)
        public var normalTextColor: UIColor? = .primaryAccent
        public var normalIconColor: UIColor? = .primaryAccent
        public var destructiveTextColor: UIColor? = .stateError
        public var destructiveIconColor: UIColor? = .stateError
        public var cancelTextColor: UIColor? = .primaryText
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension CreateChannelHeaderView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .surface1
        public var textColor: UIColor? = UIColor.secondaryText
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
        public var font: UIFont? = Fonts.regular.withSize(16)
        public var textColor: UIColor? = .primaryText
        public var placeholderColor: UIColor? = .footnoteText
        public var tintColor: UIColor? = .primaryAccent
        
        public init() {}
    }
}

extension NavigationController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var standard = {
            $0.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor.primaryText
            ]
            $0.backgroundColor = .background
            $0.shadowColor = .border
            return $0
        }(UINavigationBarAppearance())
        
        public var tintColor: UIColor? = .primaryAccent
        
        public init() {}
    }
}

extension ChannelProfileFileHeaderView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var headerBackgroundColor: UIColor? = .surface1
        public var headerTextColor: UIColor? = .secondaryText
        public var headerFont: UIFont? = Fonts.semiBold.withSize(13)
        
        public init() {}
    }
}

extension ChannelProfileEditAvatarCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var avatarBackgroundColor: UIColor? = .surface3
        
        public init() {}
    }
}

extension ImageCropperVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var buttonBackgroundColor: UIColor? = .backgroundDark
        public var buttonFont: UIFont? = Fonts.semiBold.withSize(16)
        public var buttonColor: UIColor? = .textOnPrimary
        
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
        public var color: UIColor? = .primaryAccent
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension CreatePrivateChannelProfileView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var avatarBackgroundColor: UIColor? = .surface3
        public var separatorColor: UIColor? = .border
        public var fieldFont: UIFont? = Fonts.regular.withSize(16)
        public var fieldTextColor: UIColor? = .primaryText
        public var fieldPlaceHolderTextColor: UIColor? = .secondaryText
        public var commentFont: UIFont? = Fonts.regular.withSize(13)
        public var commentTextColor: UIColor? = .secondaryText
        public var errorFont: UIFont? = Fonts.regular.withSize(13)
        public var errorTextColor: UIColor? = .stateError
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
        public var textColor: UIColor? = UIColor.primaryText
    }
}

extension UserReactionListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
    }
}

extension UserReactionCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var userLabelFont: UIFont? = Fonts.bold.withSize(16)
        public var reactionLabelFont: UIFont? = Fonts.bold.withSize(24)
        public var userLabelColor: UIColor? = .primaryText
        public var reactionLabelColor: UIColor? = .primaryText
    }
}

extension NoDataView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(20)
        public var messageLabelFont: UIFont? = Fonts.regular.withSize(15)
        public var titleLabelColor: UIColor? = .primaryText
        public var messageLabelColor: UIColor? = .secondaryText
    }
}

extension ChannelCreatedView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var labelBackgroundColor: UIColor? = .overlayBackground1
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(13)
        public var messageLabelFont: UIFont? = Fonts.semiBold.withSize(13)
        public var titleLabelColor: UIColor? = .textOnPrimary
        public var messageLabelColor: UIColor? = .textOnPrimary
    }
}

extension ChannelVC.BottomView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
        public var labelFont: UIFont? = Fonts.regular.withSize(16)
        public var labelColor: UIColor? = .primaryText
        public var iconColor: UIColor? = .primaryAccent
        public var separatorColor: UIColor? = .border
    }
}

extension ChannelVC.SearchControlsView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var separatorColor: UIColor? = .border
        public var backgroundColor: UIColor? = .background
        public var buttonTintColor: UIColor? = .primaryAccent
        public var textColor: UIColor? = .primaryText
        public var textFont: UIFont? = Fonts.regular.withSize(16)
    }
}

extension EmojiSectionToolBar: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
        public var normalColor: UIColor? = .footnoteText
        public var selectedColor: UIColor? = .primaryAccent
    }
}

extension EmojiListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
        public var normalColor: UIColor? = .footnoteText
        public var selectedColor: UIColor? = .primaryAccent
    }
}

extension MessageInfoVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .backgroundSecondary
        public var cellBackgroundColor: UIColor? = .backgroundSections
        
        public var infoFont: UIFont? = Fonts.semiBold.withSize(14)
        public var infoValueFont: UIFont? = Fonts.regular.withSize(14)
        public var infoColor: UIColor? = .primaryText
        public var infoValueColor: UIColor? = .secondaryText
        
        public var headerFont: UIFont? = Fonts.semiBold.withSize(13)
        public var headerColor: UIColor? = .secondaryText
        
        public var nameFont: UIFont? = Fonts.semiBold.withSize(16)
        public var nameColor: UIColor? = .primaryText
        
        public var dateTimeFont: UIFont? = Fonts.regular.withSize(13)
        public var dateTimeColor: UIColor? = .secondaryText
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
