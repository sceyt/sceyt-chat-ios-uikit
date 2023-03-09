//
//  AppearanceProvider.swift
//  SceytChatUIKit
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
        
        public init() {}
    }
}

extension ChannelCell: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor?                = nil
        public var separatorColor: UIColor?                 = Colors.separatorBorder
        
        public var unreadCountBackgroundColor: UIColor?     = Colors.kitBlue
        public var unreadCountFont: UIFont?                 = Fonts.regular.withSize(14)
        public var unreadCountTextColor: UIColor?           = .white
        
        public var subjectLabelFont: UIFont?                = Fonts.medium.withSize(17)
        public var subjectLabelTextColor: UIColor?          = Colors.textBlack
        
        public var messageLabelFont: UIFont?                = Fonts.regular.withSize(15)
        public var messageLabelTextColor: UIColor?          = Colors.textGray
        
        public var draftMessageTitleFont: UIFont?            = Fonts.regular.withSize(15)
        public var draftMessageTitleColor: UIColor?          = Colors.textRed
        
        public var draftMessageContentFont: UIFont?          = Fonts.regular.withSize(15)
        public var draftMessageContentColor: UIColor?        = Colors.textGray2
        
        public var dateLabelFont: UIFont?                   = Fonts.regular.withSize(14)
        public var dateLabelTextColor: UIColor?             = Colors.textGray
        
        public var typingFont: UIFont?                      = Fonts.regularItalic.withSize(15)
        public var typingTextColor: UIColor?                = Colors.textBlack
        
        
        
        public var ticksViewTintColor: UIColor?             = nil
        
        public init() {}
        
    }
}

extension ChannelSwipeActionsConfiguration: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        public static var deleteContextualAction = ContextualActionAppearance(title: L10n.Channel.List.Action.delete, backgroundColor: .textRed)
        public static var leaveContextualAction = ContextualActionAppearance(title: L10n.Channel.List.Action.leave, backgroundColor: .textGray2)
        public static var readContextualAction = ContextualActionAppearance(title: L10n.Channel.List.Action.read, backgroundColor: .textGray2)
        public static var unreadContextualAction = ContextualActionAppearance(title: L10n.Channel.List.Action.unread, backgroundColor: .textRed)
        
        public init() {}
    }
}

extension ChannelVC: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = Colors.background
        public var coverViewBackgroundColor: UIColor? = .clear
        
        public init() {}
    }
}

extension ChannelVC.TitleView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var titleColor: UIColor? = Colors.textBlack
        public var titleFont: UIFont? = Fonts.medium.withSize(19)
        
        public var subtitleColor: UIColor? = Colors.textBlack
        public var subtitleFont: UIFont? = Fonts.regular.withSize(13)
        
        public init() {}
    }
}

extension ChannelVC.BlockView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .white
        public var titleColor: UIColor? = Colors.textBlack
        public var titleFont: UIFont? = Fonts.regular.withSize(14)
        public var borderColor: UIColor? = Colors.separatorBorder
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
        
        public var backgroundColor: UIColor?             = .clear
        public var titleFont: UIFont?                    = Fonts.medium.withSize(12)
        public var titleColor: UIColor?                  = nil //initials random
        public var messageFont: UIFont?                  = Fonts.regular.withSize(16)
        public var messageColor: UIColor?                = Colors.textBlack
        public var deletedMessageFont: UIFont?           = Fonts.regularItalic.withSize(16)
        public var deletedMessageColor: UIColor?         = Colors.textGray
        public var bubbleColor: (in: UIColor?, out: UIColor?)         = (Colors.background2, Colors.background3)
        public var highlightedBubbleColor: (in: UIColor?, out: UIColor?) = (Colors.textGray, Colors.textGray)
        public var linkColor: UIColor?                   = Colors.kitBlue
        public var dateTickBackgroundViewColor: UIColor? = Colors.background5
        
        public var separatorViewBackgroundColor: UIColor?            = .clear
        public var separatorViewTextBackgroundColor: UIColor?        = .clear
        public var separatorViewFont: UIFont?                        = Fonts.medium.withSize(12)
        public var separatorViewTextColor: UIColor?                  = Colors.textGray2
        public var separatorViewTextBorderColor: UIColor?                = Colors.background4
        
        public var newMessagesSeparatorViewBackgroundColor: UIColor?            = .background2
        public var newMessagesSeparatorViewFont: UIFont?                        = Fonts.medium.withSize(14)
        public var newMessagesSeparatorViewTextColor: UIColor?                  = Colors.kitBlue
        
        public var infoViewStateFont: UIFont?               = Fonts.regularItalic.withSize(10)
        public var infoViewStateTextColor: UIColor?         = Colors.textBlack
        public var infoViewStateWithBackgroundTextColor     = UIColor.white
        public var infoViewDateFont: UIFont?                = Fonts.regular.withSize(10)
        public var infoViewDateTextColor: UIColor?          = Colors.textBlack
        public var infoViewRevertColorOnBackgroundView: UIColor? = .white
        
        public var replyCountTextColor: UIColor?            = Colors.kitBlue
        public var replyCountTextFont: UIFont?              = Fonts.medium.withSize(12)
        public var replyArrowStrokeColor: UIColor?          = Colors.background4
        public var replyUserTitleColor: UIColor?            = Colors.kitBlue
        public var replyUserTitleFont: UIFont?              = Fonts.medium.withSize(12)
        public var replyMessageColor: UIColor?              = Colors.textBlack
        public var replyMessageFont: UIFont?                = Fonts.regular.withSize(14)
        public var replyMessageBorderColor: UIColor?        = Colors.kitBlue
        public var forwardTitleColor: UIColor?              = Colors.kitBlue
        public var forwardTitleFont: UIFont?                = Fonts.medium.withSize(13)
        
        public var reactionContainerBackgroundColor: UIColor    = Colors.background
        public var reactionCommonScoreFont: UIFont         = Fonts.regular.withSize(15) 
        public var reactionFont: UIFont?                    = Fonts.regular.withSize(18)
        public var reactionColor: UIColor?                  = Colors.textBlack
        public var reactionBackgroundColor: (in: UIColor?, out: UIColor?)    = (.clear, Colors.info)
        public var reactionBorderColor: (in: UIColor?, out: UIColor?)        = (Colors.background4, Colors.background4)
        
        public var videoTimeTextColor: UIColor? = .white
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .background6.withAlphaComponent(0.4)
        
        public init() {}
    }
    
}

extension ComposerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var videoAttachmentTimeTextColor: UIColor? = .white
        public var videoAttachmentTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoAttachmentTimeBackgroundColor: UIColor? = .background6.withAlphaComponent(0.4)
        
        public var fileAttachmentTitleTextColor: UIColor? = .textBlack
        public var fileAttachmentTitleTextFont: UIFont? = Fonts.semiBold.withSize(16)
        public var fileAttachmentSubtitleTextColor: UIColor? = .textGray
        public var fileAttachmentSubtitleTextFont: UIFont? = Fonts.regular.withSize(11)
        public var fileAttachmentBackgroundColor: UIColor? = .background2
        
        public var actionReplyTitleColor: UIColor? = .kitBlue
        public var actionReplierTitleColor: UIColor? = .kitBlue
        public var actionReplyTitleFont: UIFont? = Fonts.regular.withSize(12)
        public var actionReplierTitleFont: UIFont? = Fonts.bold.withSize(13)
        public var actionMessageColor: UIColor? = .textBlack
        public var actionMessageFont: UIFont? = Fonts.regular.withSize(14)
                
        public var recorderBackgroundColor: UIColor? = .init(light: .white, dark: .black)
        public var recorderPlayerBackgroundColor: UIColor? = UIColor(rgb: 0xF0F2F5)
        public var recorderDurationFont: UIFont = Fonts.regular.withSize(11)
        public var recorderDurationColor: UIColor = .init(light: .textGray, dark: .white)
        public var recorderTimeFont: UIFont = Fonts.regular.withSize(12)
        public var recorderTimeColor: UIColor = .init(light: .textGray, dark: .white)
        public var recorderActiveWaveColor: UIColor = .kitBlue
        public var recorderInActiveWaveColor: UIColor = .init(rgb: 0x757D8B).withAlphaComponent(0.6)
        public var recorderSlideToCancelFont: UIFont = Fonts.regular.withSize(16)
        public var recorderSlideToCancelColor: UIColor = .init(light: .textGray, dark: .white)
        public var recorderCancelFont: UIFont = Fonts.regular.withSize(16)
        public var recorderCancelColor: UIColor = .red
        public var recorderRecordingDurationFont: UIFont = Fonts.regular.withSize(16)
        public var recorderRecordingDurationColor: UIColor = .init(light: .black, dark: .white)
        public var recorderRecordingDotColor: UIColor = .red

        public init() {}
    }
}

extension ComposerVC.InputTextView: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var borderColor: UIColor?     = .clear
        public var backgroundColor: UIColor? = .background2
        public var placeholderColor: UIColor? = .textGray2
        public var textFont: UIFont? = Fonts.regular.withSize(16)
        
        public init() {}
    }
}

extension ChannelProfileVC: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var titleColor: UIColor?     = .textBlack
        public var titleFont: UIFont?       = Fonts.bold.withSize(24)
        public var subtitleColor: UIColor?  = .textGray2
        public var subtitleFont: UIFont?    = Fonts.regular.withSize(13)
        
        public var descriptionColor: UIColor?     = .textBlack
        public var descriptionFont: UIFont?       = Fonts.regular.withSize(16)
        
        public var uriColor: UIColor?     = .textBlack
        public var uriFont: UIFont?       = Fonts.regular.withSize(16)
        
        public var itemColor: UIColor?     = .textBlack
        public var itemFont: UIFont?       = Fonts.regular.withSize(16)
        
        public var backgroundColor: UIColor? = .clear
        public var headerBackgroundColor: UIColor? = .clear
        public var itemsBackgroundColor: UIColor? = .white
        
        public init() {}
    }
}

extension ChannelProfileEditVC: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var textFieldColor: UIColor?     = .textBlack
        public var textFieldFont: UIFont?       = Fonts.regular.withSize(16)
        
        public var separatorColor: UIColor?     = Colors.separatorBorder
        public var backgroundColor: UIColor?    = .clear
        
        public init() {}
    }
}

extension ChannelMemberListVC: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        
        public init() {}
        
    }
}

extension ChannelMemberCell: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor?                = .white
        public var separatorColor: UIColor?                 = Colors.separatorBorder
        
        public var titleLabelFont: UIFont?                = Fonts.medium.withSize(16)
        public var titleLabelTextColor: UIColor?          = Colors.textBlack
        
        public var statusLabelFont: UIFont?                = Fonts.regular.withSize(13)
        public var statusLabelTextColor: UIColor?          = Colors.textGray
        
        public var roleLabelFont: UIFont?                = Fonts.medium.withSize(12)
        public var roleLabelTextColor: UIColor?          = UIColor(rgb: 0x7A6EF6)
        public var roleLabelBackgroundColor: UIColor?    = UIColor(rgb: 0x7A6EF6, alpha: 0.1)
        
        public init() {}
    }
}

extension ChannelMemberAddCell: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor?              = .white
        public var titleLabelFont: UIFont?                = Fonts.regular.withSize(16)
        public var titleLabelTextColor: UIColor?          = Colors.textBlack
        public var separatorColor: UIColor?               = Colors.separatorBorder
        
        public init() {}
    }
}

extension PhotosPickerVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        public var toolbarBackgroundColor: UIColor? = .white
        
        public var attachButtonBackgroundColor: UIColor? = .kitBlue
        
        public var attachTitleColor: UIColor? = .white
        public var attachTitleFont: UIFont? = Fonts.bold.withSize(16)
        public var attachTitleBackgroundColor: UIColor? = .clear
        
        public var attachCountTextColor: UIColor? = .kitBlue
        public var attachCountTextFont: UIFont? = Fonts.bold.withSize(16)
        public var attachCountBackgroundColor: UIColor? = .white
        
        public init() {}
    }
}

extension ChannelMediaListView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        public var videoTimeTextColor: UIColor? = .white
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .background6.withAlphaComponent(0.4)
        
        public init() {}
    }
}

extension ChannelFileListView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        
        public var titleLabelTextColor: UIColor? = .textBlack
        public var titleLabelFont: UIFont? = Fonts.medium.withSize(14)
        public var sizeLabelTextColor: UIColor? = .textBlack
        public var sizeLabelFont: UIFont? = Fonts.regular.withSize(10)
        public var dateLabelTextColor: UIColor? = .textBlack
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(10)
        public var separatorColor: UIColor? = .separatorBorder
        
        public init() {}
    }
}

extension ChannelLinkListView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        
        public var titleLabelTextColor: UIColor? = .textBlack
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var linkLabelTextColor: UIColor? = .textGray
        public var linkLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var separatorColor: UIColor? = .separatorBorder
        
        public init() {}
    }
}

extension ChannelVoiceListView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        
        public var titleLabelTextColor: UIColor? = .textBlack
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var durationLabelTextColor: UIColor? = .textBlack
        public var durationLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var dateLabelTextColor: UIColor? = .textGray
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var separatorColor: UIColor? = .separatorBorder
        
        public init() {}
    }
}


extension PhotosPickerCell: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .white
        public var timeTextColor: UIColor? = .white
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .background6.withAlphaComponent(0.4)
        
        public init() {}
    }
}

extension CircularProgressView: AppearanceProvider {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var progressColor: UIColor = .kitBlue
        public var trackColor: UIColor = .white
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .textGray.withAlphaComponent(0.4)
        
        public init() {}
    }
}

extension MentioningUserListVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = .clear
        public var tableViewBackgroundColor: UIColor? = .white
        
        public init() {}
    }
}

extension MentioningUserViewCell: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var titleLabelFont: UIFont?          = Fonts.medium.withSize(16)
        public var titleLabelTextColor: UIColor?    = Colors.textBlack
        
        public init() {}
    }
}

//Helper
public struct ContextualActionAppearance {
    public var style: UIContextualAction.Style
    public var title: String?
    public var image: UIImage?
    public var backgroundColor: UIColor?
    
    public init(
        style: UIContextualAction.Style = .normal,
        title: String? = nil,
        image: UIImage? = nil,
        backgroundColor: UIColor? = nil) {
            self.style = style
            self.title = title
            self.image = image
            self.backgroundColor = backgroundColor
        }
}

public struct InitialsBuilderAppearance {
    
    public var font: UIFont
    public var color: UIColor
    public var size: CGSize
    
    public var adjustsFontSizeToFitWidth = true
    
    public init(
        font: UIFont = Appearance.Fonts.regular.withSize(18),
        color: UIColor = .white,
        size: CGSize = .init(width: 60, height: 60)) {
            self.font = font
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
        public var controlFont = UIFont.systemFont(ofSize: 13)
        public var titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        public var subTitleFont = UIFont.systemFont(ofSize: 13)

        public init() {}
    }
}

extension EmojiController: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = Colors.background
        public var moreButtonBackgroundColor: UIColor? = Colors.background2
        public var selectedBackgroundColor: UIColor? = Colors.background4
        
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
        
        public var backgroundColor: UIColor? = Colors.background2
        public var selectedBackgroundColor: UIColor? = Colors.background4
        public var separatorColor: UIColor? = Colors.separatorBorder2
        public var imageTintColor: UIColor? = Colors.neutral700
        public var textColor: UIColor? = Colors.neutral700
        public var textFont: UIFont? = Fonts.regular.withSize(16)
        public var destructiveTextColor: UIColor? = Colors.neutralRed
        public var destructiveImageTintColor: UIColor? = Colors.neutralRed
        
        public init() {}
        
    }
}
extension ReactionVC: AppearanceProvider {
    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = Colors.background
        
        public init() {}
    }
}
extension ReactionScoreCell: AppearanceProvider {

    public static var appearance = Appearance()
    
    public struct Appearance {
        
        public var backgroundColor: UIColor? = Colors.background
        public var selectedBackgroundColor: UIColor? = UIColor(hex: "5159F6")
        public var borderColor: UIColor? = Colors.separatorBorder
        public var selectedBorderColor: UIColor? = .clear
        public var textColor: UIColor? = Colors.textGray
        public var textFont: UIFont? = Fonts.semiBold.withSize(14)
        public var selectedTextColor: UIColor? = .white
        
        public init() {}
    }

}
