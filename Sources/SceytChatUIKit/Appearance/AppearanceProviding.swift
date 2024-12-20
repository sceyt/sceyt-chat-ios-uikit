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
    static var parentAppearanceKey: UInt8 = 0
    
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
public extension AppearanceProviding where Self: NSObject {
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
                if let viewController = configurableSelf as? UIViewController {
                    guard viewController.isViewLoaded else { return }
                }
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
    public var backgroundColor: UIColor?
    public var size: CGSize
    
    public var adjustsFontSizeToFitWidth = true
    
    public init(
        color: UIColor = .onPrimary,
        backgroundColor: UIColor? = nil,
        size: CGSize = .init(width: 60, height: 60))
    {
        self.color = color
        self.backgroundColor = backgroundColor
        self.size = size
    }
}
