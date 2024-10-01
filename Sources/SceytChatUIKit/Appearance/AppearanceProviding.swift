//
//  AppearanceProviding.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

/// A protocol that defines a type providing appearance configurations.
///
/// Types conforming to this protocol can supply appearance settings through
/// both static and instance-level properties. Additionally, they can inherit
/// appearance configurations from a parent appearance.
public protocol AppearanceProviding: AnyObject {
    /// The type representing the appearance configuration.
    associatedtype AppearanceType
    
    /// The default appearance configuration shared across all instances.
    ///
    /// This static property allows setting a global appearance that applies
    /// to all instances unless overridden by a parent appearance.
    static var appearance: AppearanceType { get set }
    
    /// The instance's appearance configuration.
    ///
    /// If a `parentAppearance` is set, this property returns the parent's
    /// appearance. Otherwise, it falls back to the static `appearance`.
    var appearance: AppearanceType { get }
    
    /// The parent appearance configuration, allowing instances to inherit
    /// appearance settings from another source.
    ///
    /// This property can be used to override the default static appearance
    /// on a per-instance basis.
    var parentAppearance: AppearanceType? { get set }
}

/// Provides a default implementation of the `appearance` property for
/// conforming types that are subclasses of `NSObject`.
///
/// - Note: This extension leverages the `parentAppearance` to determine
///         the effective appearance. If `parentAppearance` is `nil`,
///         it defaults to the static `appearance`.
public extension AppearanceProviding where Self: NSObject {
    /// The instance's appearance configuration.
    ///
    /// If a `parentAppearance` is set, returns it. Otherwise, returns the
    /// static `appearance`.
    var appearance: AppearanceType {
        parentAppearance ?? Self.appearance
    }
}

/// An extension on `NSObject` to manage associated appearance objects.
///
/// This extension provides methods to get and set a parent appearance
/// using Objective-C runtime functions. It uses associated objects to
/// store appearance configurations dynamically.
private extension NSObject {
    /// A unique key used for associating appearance objects with instances.
    ///
    /// The `UInt8` type is used here to ensure a unique memory address.
    static var parentAppearanceKey: UInt8 = 1
    
    /// Retrieves the parent appearance for a specific `AppearanceType`.
    ///
    /// - Returns: An optional appearance object of type `A`.
    ///
    /// - Note: This method uses `objc_getAssociatedObject` to fetch the
    ///         associated appearance object for the given type.
    func getParentAppearance<A>() -> A? {
        let key = ObjectIdentifier(A.self)
        return objc_getAssociatedObject(self, &Self.parentAppearanceKey) as? A
    }
    
    /// Sets the parent appearance for a specific `AppearanceType`.
    ///
    /// - Parameter appearance: The appearance object to associate with the instance.
    ///
    /// - Note: This method uses `objc_setAssociatedObject` to attach the
    ///         appearance object to the instance dynamically.
    func setParentAppearance<A>(_ appearance: A?) {
        let key = ObjectIdentifier(A.self)
        objc_setAssociatedObject(self, &Self.parentAppearanceKey, appearance, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

/// Provides a computed property for `parentAppearance` when conforming to
/// `AppearanceProviding` and subclassing `NSObject`.
///
/// This extension bridges the `parentAppearance` property with the
/// associated object storage methods defined in the `NSObject` extension.
public extension AppearanceProviding where Self: NSObject {//}& Configurable {
    /// The parent appearance configuration, allowing instances to inherit
    /// appearance settings from another source.
    ///
    /// - Getter: Retrieves the associated parent appearance using `getParentAppearance`.
    /// - Setter: Sets the associated parent appearance using `setParentAppearance`.
    var parentAppearance: AppearanceType? {
        get {
            return getParentAppearance()
        }
        set {
            setParentAppearance(newValue)
            // Conditionally call `setupAppearance` if `self` conforms to `Configurable`
            if let configurableSelf = self as? Configurable {
                configurableSelf.setupAppearance()
            }
        }
    }
}


extension ChannelSwipeActionsConfiguration: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public static var deleteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.delete,
            backgroundColor: .stateWarning)
        public static var leaveContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.leave,
            backgroundColor: .surface3
        )
        public static var readContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.read,
            backgroundColor: .accent4
        )
        public static var unreadContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unread,
            backgroundColor: .accent4
        )
        public static var muteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.mute,
            backgroundColor: .accent2
        )
        public static var unmuteContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unmute,
            backgroundColor: .accent2
        )
        public static var pinContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.pin,
            backgroundColor: .accent3
        )
        public static var unpinContextualAction = ContextualActionAppearance(
            title: L10n.Channel.List.Action.unpin,
            backgroundColor: .accent3
        )
        
        public init() {}
    }
}









extension ChannelInfoViewController: AppearanceProviding {
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

extension ChannelEditViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var textFieldColor: UIColor? = .primaryText
        public var textFieldFont: UIFont? = Fonts.regular.withSize(16)
        public var textFieldPlaceholderColor: UIColor? = .secondaryText
        public var textFieldBackgroundColor: UIColor? = .backgroundSections
        public var successColor: UIColor? = .stateSuccess
        public var errorColor: UIColor? = .stateWarning
        public var errorFont: UIFont? = Fonts.regular.withSize(13)
        public var separatorColor: UIColor? = .border
        public var backgroundColor: UIColor? = .backgroundSecondary
        
        public init() {}
    }
}

extension ChannelMemberListViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension ChannelMemberListViewController.MemberCell: AppearanceProviding {
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


extension ChannelMemberListViewController.AddMemberCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var titleLabelFont: UIFont? = Fonts.regular.withSize(16)
        public var titleLabelTextColor: UIColor? = UIColor.primaryText
        public var separatorColor: UIColor? = UIColor.border
        
        public init() {}
    }
}

extension MediaPickerViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var toolbarBackgroundColor: UIColor? = .background
        
        public var attachButtonBackgroundColor: UIColor? = .accent
        
        public var attachTitleColor: UIColor? = .onPrimary
        public var attachTitleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var attachTitleBackgroundColor: UIColor? = .clear
        
        public var attachCountTextColor: UIColor? = .accent
        public var attachCountTextFont: UIFont? = Fonts.semiBold.withSize(14)
        public var attachCountBackgroundColor: UIColor? = .onPrimary
        
        public init() {}
    }
}

extension ChannelInfoViewController.MediaCollectionView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var videoTimeTextColor: UIColor? = .onPrimary
        public var videoTimeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var videoTimeBackgroundColor: UIColor? = .overlayBackground2
        
        public init() {}
    }
}

extension ChannelInfoViewController.FileCollectionView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleTextColor: UIColor? = .primaryText
        public var titleFont: UIFont? = Fonts.semiBold.withSize(16)
        public var detailTextColor: UIColor? = .secondaryText
        public var detailFont: UIFont? = Fonts.regular.withSize(13)
        
        public var downloadBackgroundColor: UIColor? = .surface1
        public var progressColor: UIColor? = .accent
        public var trackColor: UIColor? = .clear
        
        public init() {}
    }
}

extension ChannelInfoViewController.LinkCollectionView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleLabelTextColor: UIColor? = .primaryText
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var linkLabelTextColor: UIColor? = .systemBlue
        public var linkLabelFont: UIFont? = Fonts.regular.withSize(14)
        public var detailLabelTextColor: UIColor? = .secondaryText
        public var detailLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var linkIcon: UIImage = .link

        public init() {}
    }
}

extension ChannelInfoViewController.VoiceCollectionView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public var titleLabelTextColor: UIColor? = .primaryText
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(16)
        public var durationLabelTextColor: UIColor? = .primaryText
        public var durationLabelFont: UIFont? = Fonts.regular.withSize(13)
        public var dateLabelTextColor: UIColor? = .secondaryText
        public var dateLabelFont: UIFont? = Fonts.regular.withSize(13)
        
        public var downloadBackgroundColor: UIColor? = .accent
        public var progressColor: UIColor? = .onPrimary
        public var trackColor: UIColor? = .clear
        
        public init() {}
    }
}

extension MediaPickerViewController.MediaCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public var backgroundColor: UIColor? = .surface1
        public var timeTextColor: UIColor? = .onPrimary
        public var timeTextFont: UIFont? = Fonts.regular.withSize(12)
        public var timeBackgroundColor: UIColor? = .overlayBackground2
        public lazy var checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance

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
        color: UIColor = .onPrimary,
        size: CGSize = .init(width: 60, height: 60))
    {
        self.color = color
        self.size = size
    }
}

extension MediaPreviewerViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor = UIColor.backgroundDark
        public var minimumTrackTintColor = UIColor.onPrimary
        public var maximumTrackTintColor = UIColor.surface3
        public var tintColor = UIColor.onPrimary
        public var controlFont = Fonts.regular.withSize(13)
        public var titleFont = Fonts.bold.withSize(16)
        public var subTitleFont = Fonts.regular.withSize(13)
        
        public init() {}
    }
}


extension ReactionsInfoViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = UIColor.background
        
        public init() {}
    }
}

extension ReactionsInfoViewController.ReactionScoreCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = UIColor.background
        public var selectedBackgroundColor: UIColor? = UIColor.accent
        public var borderColor: UIColor? = .border
        public var selectedBorderColor: UIColor? = .clear
        public var textColor: UIColor? = UIColor.secondaryText
        public var textFont: UIFont? = Fonts.semiBold.withSize(14)
        public var selectedTextColor: UIColor? = .onPrimary
        
        public init() {}
    }
}


extension EmojiPickerViewController.SectionHeaderView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var textColor: UIColor? = .secondaryText
        public var textFont: UIFont? = Fonts.regular.withSize(12)
        
        public init() {}
    }
}

extension ImagePreviewViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension NativeSegmentedController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .backgroundSections
        public var font: UIFont? = Fonts.semiBold.withSize(16)
        public var selectedTextColor: UIColor? = .primaryText
        public var textColor: UIColor? = .secondaryText
        public init() {}
    }
}

extension SheetViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .overlayBackground1
        public var contentBackgroundColor: UIColor? = .background
        public var titleFont: UIFont? = Fonts.semiBold.withSize(20)
        public var titleColor: UIColor? = .secondaryText
        public var doneFont: UIFont? = Fonts.semiBold.withSize(16)
        public var doneColor: UIColor? = .accent
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}


extension Alert: AppearanceProviding {
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
        public var normalTextColor: UIColor? = .accent
        public var normalIconColor: UIColor? = .accent
        public var destructiveTextColor: UIColor? = .stateWarning
        public var destructiveIconColor: UIColor? = .stateWarning
        public var cancelTextColor: UIColor? = .primaryText
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}


extension SelectUsersViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension NavigationController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var standard = {
            $0.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor.primaryText
            ]
            $0.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            $0.backgroundColor = .background
            $0.shadowColor = .border
            return $0
        }(UINavigationBarAppearance())
        
        public var tintColor: UIColor? = .accent
        
        public init() {}
    }
}

extension ChannelInfoViewController.AttachmentHeaderView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var headerBackgroundColor: UIColor? = .surface1
        public var headerTextColor: UIColor? = .secondaryText
        public var headerFont: UIFont? = Fonts.semiBold.withSize(13)
        
        public init() {}
    }
}

extension ChannelEditViewController.AvatarCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var avatarBackgroundColor: UIColor? = .surface3
        
        public init() {}
    }
}

extension ImageCropperViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var buttonBackgroundColor: UIColor? = .backgroundDark
        public var buttonFont: UIFont? = Fonts.semiBold.withSize(16)
        public var buttonColor: UIColor? = .onPrimary
        
        public init() {}
    }
}

extension StartChatViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension StartChatViewController.ActionsView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var font: UIFont? = Fonts.regular.withSize(16)
        public var color: UIColor? = .accent
        public var separatorColor: UIColor? = .border
        
        public init() {}
    }
}

extension CreateGroupViewController.DetailsView: AppearanceProviding {
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
        public var errorTextColor: UIColor? = .stateWarning
    }
}

extension CreateGroupViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        
        public init() {}
    }
}

extension SelectedBaseCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var font: UIFont? = Fonts.regular.withSize(13)
        public var textColor: UIColor? = UIColor.primaryText
    }
}

extension ReactedUserListViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
    }
}

extension ReactedUserListViewController.UserReactionCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var userLabelFont: UIFont? = Fonts.bold.withSize(16)
        public var reactionLabelFont: UIFont? = Fonts.bold.withSize(24)
        public var userLabelColor: UIColor? = .primaryText
        public var reactionLabelColor: UIColor? = .primaryText
    }
}


extension ChannelCreatedView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        
        public var channelCreatedImage: UIImage? = nil
        public var labelBackgroundColor: UIColor? = .overlayBackground1
        public var titleLabelFont: UIFont? = Fonts.semiBold.withSize(13)
        public var messageLabelFont: UIFont? = Fonts.semiBold.withSize(13)
        public var titleLabelColor: UIColor? = .onPrimary
        public var messageLabelColor: UIColor? = .onPrimary
    }
}



extension EmojiSectionToolBar: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
        public var normalColor: UIColor? = .footnoteText
        public var selectedColor: UIColor? = .accent
    }
}

extension EmojiPickerViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
        public var normalColor: UIColor? = .footnoteText
        public var selectedColor: UIColor? = .accent
    }
}




extension ForwardViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public init() {}
        
        public var backgroundColor: UIColor? = .background
    }
}

