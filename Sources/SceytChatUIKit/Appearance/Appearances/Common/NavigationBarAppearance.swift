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

public struct NavigationBarAppearance {
    // General Appearance
    public var barStyle: UIBarStyle
    public var isTranslucent: Bool
    public var prefersLargeTitles: Bool
    public var tintColor: UIColor
    public var barTintColor: UIColor?
    public var backgroundColor: UIColor?
    public var backgroundEffect: UIBlurEffect?
    
    // Title Attributes
    public var titleTextAttributes: [NSAttributedString.Key: Any]?
    public var largeTitleTextAttributes: [NSAttributedString.Key: Any]?
    
    // Back Indicator Images
    public var backIndicatorImage: UIImage?
    public var backIndicatorTransitionMaskImage: UIImage?
    
    // Background and Shadow Images
    public var backgroundImage: UIImage?
    public var shadowImage: UIImage?
    public var shadowColor: UIColor?
    
    // Appearance for Different States
    public var standardAppearance: UINavigationBarAppearance?
    public var compactAppearance: UINavigationBarAppearance?
    public var scrollEdgeAppearance: UINavigationBarAppearance?
    public var compactScrollEdgeAppearance: UINavigationBarAppearance?
    
    // Button Item Appearances
    public var backButtonAppearance: UIBarButtonItemAppearance?
    public var buttonAppearance: UIBarButtonItemAppearance?
    public var doneButtonAppearance: UIBarButtonItemAppearance?
    
    public init(
        barStyle: UIBarStyle = .default,
        isTranslucent: Bool = true,
        prefersLargeTitles: Bool = false,
        tintColor: UIColor = .accent,
        barTintColor: UIColor? = .green,
        backgroundColor: UIColor? = nil,
        backgroundEffect: UIBlurEffect? = nil,
        titleTextAttributes: [NSAttributedString.Key : Any]? = nil,
        largeTitleTextAttributes: [NSAttributedString.Key : Any]? = nil,
        backIndicatorImage: UIImage? = nil,
        backIndicatorTransitionMaskImage: UIImage? = nil,
        backgroundImage: UIImage? = nil,
        shadowImage: UIImage? = nil,
        shadowColor: UIColor? = nil,
        standardAppearance: UINavigationBarAppearance? = {
            $0.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor.primaryText
            ]
            $0.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            $0.backgroundColor = .background
            $0.shadowColor = .border
            return $0
        }(UINavigationBarAppearance()),
        compactAppearance: UINavigationBarAppearance? = nil,
        scrollEdgeAppearance: UINavigationBarAppearance? = {
            $0.titleTextAttributes = [
                .font: Fonts.bold.withSize(20),
                .foregroundColor: UIColor.primaryText
            ]
            $0.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            $0.backgroundColor = .background
            $0.shadowColor = .border
            return $0
        }(UINavigationBarAppearance()),
        compactScrollEdgeAppearance: UINavigationBarAppearance? = nil,
        backButtonAppearance: UIBarButtonItemAppearance? = nil,
        buttonAppearance: UIBarButtonItemAppearance? = nil,
        doneButtonAppearance: UIBarButtonItemAppearance? = nil
    ) {
        self.barStyle = barStyle
        self.isTranslucent = isTranslucent
        self.prefersLargeTitles = prefersLargeTitles
        self.tintColor = tintColor
        self.barTintColor = barTintColor
        self.backgroundColor = backgroundColor
        self.backgroundEffect = backgroundEffect
        self.titleTextAttributes = titleTextAttributes
        self.largeTitleTextAttributes = largeTitleTextAttributes
        self.backIndicatorImage = backIndicatorImage
        self.backIndicatorTransitionMaskImage = backIndicatorTransitionMaskImage
        self.backgroundImage = backgroundImage
        self.shadowImage = shadowImage
        self.shadowColor = shadowColor
        self.standardAppearance = standardAppearance
        self.compactAppearance = compactAppearance
        self.scrollEdgeAppearance = scrollEdgeAppearance
        self.compactScrollEdgeAppearance = compactScrollEdgeAppearance
        self.backButtonAppearance = backButtonAppearance
        self.buttonAppearance = buttonAppearance
        self.doneButtonAppearance = doneButtonAppearance
    }
}

extension UINavigationBar {
    public func apply(appearance: NavigationBarAppearance) {
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
