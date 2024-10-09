//
//  NavigationBarAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit
//
//public struct NavigationBarAppearance {
//    public public var backgroundColor: UIColor? = .background
//    public public var backIcon: UIImage?
//    public public var leftBarButtonsAppearance: [BarButtonAppearance] = []
//    public public var rightBarButtonsAppearance: [BarButtonAppearance] = []
//    public public var title: String?
//    public public var titleLabelAppearance: LabelAppearance?
//    public public var subtitle: String?
//    public public var subtitleLabelAppearance: LabelAppearance?
//    public public var titleFormatter: (any Formatting)?
//    public public var subtitleFormatter: (any Formatting)?
//    public public var underlineColor: UIColor?
//    public init() {}
//}

//
//  NavigationBarAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class NavigationBarAppearance: AppearanceProviding {
    public var appearance: Appearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: Appearance?
    
    
    public static var appearance = Appearance(
        barStyle: .default,
        isTranslucent: true,
        prefersLargeTitles: false,
        tintColor: .accent,
        barTintColor: .green,
        backgroundColor: nil,
        backgroundEffect: nil,
        titleTextAttributes: [
            .font: Fonts.bold.withSize(20),
            .foregroundColor: UIColor.primaryText
        ],
        largeTitleTextAttributes: [
            .font: Fonts.bold.withSize(20),
            .foregroundColor: UIColor.primaryText
        ],
        backIndicatorImage: nil,
        backIndicatorTransitionMaskImage: nil,
        backgroundImage: nil,
        shadowImage: nil,
        shadowColor: nil,
        standardAppearance: {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor.primaryText
            ]
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            appearance.backgroundColor = .background
            appearance.shadowColor = .border
            return appearance
        }(),
        compactAppearance: nil,
        scrollEdgeAppearance: {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor.primaryText
            ]
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            appearance.backgroundColor = .background
            appearance.shadowColor = .border
            return appearance
        }(),
        compactScrollEdgeAppearance: nil,
        backButtonAppearance: nil,
        buttonAppearance: nil,
        doneButtonAppearance: nil
    )
    
    public class Appearance {
        @Trackable<Appearance, UIBarStyle>
        public var barStyle: UIBarStyle
        
        @Trackable<Appearance, Bool>
        public var isTranslucent: Bool
        
        @Trackable<Appearance, Bool>
        public var prefersLargeTitles: Bool
        
        @Trackable<Appearance, UIColor>
        public var tintColor: UIColor
        
        @Trackable<Appearance, UIColor?>
        public var barTintColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, UIBlurEffect?>
        public var backgroundEffect: UIBlurEffect?
        
        @Trackable<Appearance, [NSAttributedString.Key: Any]?>
        public var titleTextAttributes: [NSAttributedString.Key: Any]?
        
        @Trackable<Appearance, [NSAttributedString.Key: Any]?>
        public var largeTitleTextAttributes: [NSAttributedString.Key: Any]?
        
        @Trackable<Appearance, UIImage?>
        public var backIndicatorImage: UIImage?
        
        @Trackable<Appearance, UIImage?>
        public var backIndicatorTransitionMaskImage: UIImage?
        
        @Trackable<Appearance, UIImage?>
        public var backgroundImage: UIImage?
        
        @Trackable<Appearance, UIImage?>
        public var shadowImage: UIImage?
        
        @Trackable<Appearance, UIColor?>
        public var shadowColor: UIColor?
        
        @Trackable<Appearance, UINavigationBarAppearance?>
        public var standardAppearance: UINavigationBarAppearance?
        
        @Trackable<Appearance, UINavigationBarAppearance?>
        public var compactAppearance: UINavigationBarAppearance?
        
        @Trackable<Appearance, UINavigationBarAppearance?>
        public var scrollEdgeAppearance: UINavigationBarAppearance?
        
        @Trackable<Appearance, UINavigationBarAppearance?>
        public var compactScrollEdgeAppearance: UINavigationBarAppearance?
        
        @Trackable<Appearance, UIBarButtonItemAppearance?>
        public var backButtonAppearance: UIBarButtonItemAppearance?
        
        @Trackable<Appearance, UIBarButtonItemAppearance?>
        public var buttonAppearance: UIBarButtonItemAppearance?
        
        @Trackable<Appearance, UIBarButtonItemAppearance?>
        public var doneButtonAppearance: UIBarButtonItemAppearance?
        
        // Primary Initializer with all parameters
        public init(
            barStyle: UIBarStyle,
            isTranslucent: Bool,
            prefersLargeTitles: Bool,
            tintColor: UIColor,
            barTintColor: UIColor?,
            backgroundColor: UIColor?,
            backgroundEffect: UIBlurEffect?,
            titleTextAttributes: [NSAttributedString.Key: Any]?,
            largeTitleTextAttributes: [NSAttributedString.Key: Any]?,
            backIndicatorImage: UIImage?,
            backIndicatorTransitionMaskImage: UIImage?,
            backgroundImage: UIImage?,
            shadowImage: UIImage?,
            shadowColor: UIColor?,
            standardAppearance: UINavigationBarAppearance?,
            compactAppearance: UINavigationBarAppearance?,
            scrollEdgeAppearance: UINavigationBarAppearance?,
            compactScrollEdgeAppearance: UINavigationBarAppearance?,
            backButtonAppearance: UIBarButtonItemAppearance?,
            buttonAppearance: UIBarButtonItemAppearance?,
            doneButtonAppearance: UIBarButtonItemAppearance?
        ) {
            self._barStyle = Trackable(value: barStyle)
            self._isTranslucent = Trackable(value: isTranslucent)
            self._prefersLargeTitles = Trackable(value: prefersLargeTitles)
            self._tintColor = Trackable(value: tintColor)
            self._barTintColor = Trackable(value: barTintColor)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._backgroundEffect = Trackable(value: backgroundEffect)
            self._titleTextAttributes = Trackable(value: titleTextAttributes)
            self._largeTitleTextAttributes = Trackable(value: largeTitleTextAttributes)
            self._backIndicatorImage = Trackable(value: backIndicatorImage)
            self._backIndicatorTransitionMaskImage = Trackable(value: backIndicatorTransitionMaskImage)
            self._backgroundImage = Trackable(value: backgroundImage)
            self._shadowImage = Trackable(value: shadowImage)
            self._shadowColor = Trackable(value: shadowColor)
            self._standardAppearance = Trackable(value: standardAppearance)
            self._compactAppearance = Trackable(value: compactAppearance)
            self._scrollEdgeAppearance = Trackable(value: scrollEdgeAppearance)
            self._compactScrollEdgeAppearance = Trackable(value: compactScrollEdgeAppearance)
            self._backButtonAppearance = Trackable(value: backButtonAppearance)
            self._buttonAppearance = Trackable(value: buttonAppearance)
            self._doneButtonAppearance = Trackable(value: doneButtonAppearance)
        }
        
        // Secondary Initializer with optional parameters
        public init(
            reference: NavigationBarAppearance.Appearance,
            barStyle: UIBarStyle? = nil,
            isTranslucent: Bool? = nil,
            prefersLargeTitles: Bool? = nil,
            tintColor: UIColor? = nil,
            barTintColor: UIColor? = nil,
            backgroundColor: UIColor? = nil,
            backgroundEffect: UIBlurEffect? = nil,
            titleTextAttributes: [NSAttributedString.Key: Any]? = nil,
            largeTitleTextAttributes: [NSAttributedString.Key: Any]? = nil,
            backIndicatorImage: UIImage? = nil,
            backIndicatorTransitionMaskImage: UIImage? = nil,
            backgroundImage: UIImage? = nil,
            shadowImage: UIImage? = nil,
            shadowColor: UIColor? = nil,
            standardAppearance: UINavigationBarAppearance? = nil,
            compactAppearance: UINavigationBarAppearance? = nil,
            scrollEdgeAppearance: UINavigationBarAppearance? = nil,
            compactScrollEdgeAppearance: UINavigationBarAppearance? = nil,
            backButtonAppearance: UIBarButtonItemAppearance? = nil,
            buttonAppearance: UIBarButtonItemAppearance? = nil,
            doneButtonAppearance: UIBarButtonItemAppearance? = nil
        ) {
            self._barStyle = Trackable(reference: reference, referencePath: \.barStyle)
            self._isTranslucent = Trackable(reference: reference, referencePath: \.isTranslucent)
            self._prefersLargeTitles = Trackable(reference: reference, referencePath: \.prefersLargeTitles)
            self._tintColor = Trackable(reference: reference, referencePath: \.tintColor)
            self._barTintColor = Trackable(reference: reference, referencePath: \.barTintColor)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._backgroundEffect = Trackable(reference: reference, referencePath: \.backgroundEffect)
            self._titleTextAttributes = Trackable(reference: reference, referencePath: \.titleTextAttributes)
            self._largeTitleTextAttributes = Trackable(reference: reference, referencePath: \.largeTitleTextAttributes)
            self._backIndicatorImage = Trackable(reference: reference, referencePath: \.backIndicatorImage)
            self._backIndicatorTransitionMaskImage = Trackable(reference: reference, referencePath: \.backIndicatorTransitionMaskImage)
            self._backgroundImage = Trackable(reference: reference, referencePath: \.backgroundImage)
            self._shadowImage = Trackable(reference: reference, referencePath: \.shadowImage)
            self._shadowColor = Trackable(reference: reference, referencePath: \.shadowColor)
            self._standardAppearance = Trackable(reference: reference, referencePath: \.standardAppearance)
            self._compactAppearance = Trackable(reference: reference, referencePath: \.compactAppearance)
            self._scrollEdgeAppearance = Trackable(reference: reference, referencePath: \.scrollEdgeAppearance)
            self._compactScrollEdgeAppearance = Trackable(reference: reference, referencePath: \.compactScrollEdgeAppearance)
            self._backButtonAppearance = Trackable(reference: reference, referencePath: \.backButtonAppearance)
            self._buttonAppearance = Trackable(reference: reference, referencePath: \.buttonAppearance)
            self._doneButtonAppearance = Trackable(reference: reference, referencePath: \.doneButtonAppearance)
            
            if let barStyle { self.barStyle = barStyle }
            if let isTranslucent { self.isTranslucent = isTranslucent }
            if let prefersLargeTitles { self.prefersLargeTitles = prefersLargeTitles }
            if let tintColor { self.tintColor = tintColor }
            if let barTintColor { self.barTintColor = barTintColor }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let backgroundEffect { self.backgroundEffect = backgroundEffect }
            if let titleTextAttributes { self.titleTextAttributes = titleTextAttributes }
            if let largeTitleTextAttributes { self.largeTitleTextAttributes = largeTitleTextAttributes }
            if let backIndicatorImage { self.backIndicatorImage = backIndicatorImage }
            if let backIndicatorTransitionMaskImage { self.backIndicatorTransitionMaskImage = backIndicatorTransitionMaskImage }
            if let backgroundImage { self.backgroundImage = backgroundImage }
            if let shadowImage { self.shadowImage = shadowImage }
            if let shadowColor { self.shadowColor = shadowColor }
            if let standardAppearance { self.standardAppearance = standardAppearance }
            if let compactAppearance { self.compactAppearance = compactAppearance }
            if let scrollEdgeAppearance { self.scrollEdgeAppearance = scrollEdgeAppearance }
            if let compactScrollEdgeAppearance { self.compactScrollEdgeAppearance = compactScrollEdgeAppearance }
            if let backButtonAppearance { self.backButtonAppearance = backButtonAppearance }
            if let buttonAppearance { self.buttonAppearance = buttonAppearance }
            if let doneButtonAppearance { self.doneButtonAppearance = doneButtonAppearance }
        }
    }
}

extension UINavigationBar {
    public func apply(appearance: NavigationBarAppearance.Appearance) {
        // General Appearance
        self.barStyle = appearance.barStyle
        self.isTranslucent = appearance.isTranslucent
        self.prefersLargeTitles = appearance.prefersLargeTitles
        self.tintColor = appearance.tintColor
        self.barTintColor = appearance.barTintColor
        self.backgroundColor = appearance.backgroundColor
        
        // Title Attributes
        self.titleTextAttributes = appearance.titleTextAttributes
        self.largeTitleTextAttributes = appearance.largeTitleTextAttributes
        
        // Back Indicator Images
        if let backImage = appearance.backIndicatorImage {
            self.backIndicatorImage = backImage
        }
        if let backMaskImage = appearance.backIndicatorTransitionMaskImage {
            self.backIndicatorTransitionMaskImage = backMaskImage
        }
        
        // Background and Shadow Images
        if let backgroundImage = appearance.backgroundImage {
            self.setBackgroundImage(backgroundImage, for: .default)
        }
        if let shadowImage = appearance.shadowImage {
            self.shadowImage = shadowImage
        }
        if let shadowColor = appearance.shadowColor {
            let appearance = self.standardAppearance.copy()
            appearance.shadowColor = shadowColor
            self.standardAppearance = appearance
        }
        
        if let standardAppearance = appearance.standardAppearance {
            self.standardAppearance = standardAppearance
        }
        if let compactAppearance = appearance.compactAppearance {
            self.compactAppearance = compactAppearance
        }
        if let scrollEdgeAppearance = appearance.scrollEdgeAppearance {
            self.scrollEdgeAppearance = scrollEdgeAppearance
        }
        if #available(iOS 15.0, *) {
            if let compactScrollEdgeAppearance = appearance.compactScrollEdgeAppearance {
                self.compactScrollEdgeAppearance = compactScrollEdgeAppearance
            }
        }
        
        // Button Item Appearances
        if let standardAppearance = self.standardAppearance.copy() as? UINavigationBarAppearance {
            if let backButtonAppearance = appearance.backButtonAppearance {
                standardAppearance.backButtonAppearance = backButtonAppearance
            }
            if let buttonAppearance = appearance.buttonAppearance {
                standardAppearance.buttonAppearance = buttonAppearance
            }
            if let doneButtonAppearance = appearance.doneButtonAppearance {
                standardAppearance.doneButtonAppearance = doneButtonAppearance
            }
            self.standardAppearance = standardAppearance
        }
    }
}
