//
//  Appearance+Colors.swift
//  SceytChatUIKit
//

import UIKit

typealias Colors = Appearance.Colors

public extension Appearance {
    
    struct Colors {
        
        public static var kitBlue: UIColor = UIColor(light: 0x4F6AFF, dark: 0x4F6AFF)
        public static var kitRed: UIColor = UIColor(light: 0xF23F51, dark: 0xF23F51)
        public static var textBlack: UIColor = UIColor(light: 0x060A26, dark: 0xFFFFFF)
        public static var textGray: UIColor = UIColor(light: 0x7C7E8E, dark: 0x7C7E8E)
        public static var textGray2: UIColor = UIColor(light: 0x9B9DA8, dark: 0x9B9DA8)
        public static var textRed: UIColor = UIColor(light: 0xED4D60, dark: 0xED4D60)
        public static var background: UIColor = UIColor(light: 0xFFFFFF, dark: 0x010212)
        public static var background2: UIColor = UIColor(light: 0xF1F2F6, dark: 0x1A1B2A)
        public static var background3: UIColor = UIColor(light: 0xE3E7FF, dark: 0x182159)
        public static var background4: UIColor = UIColor(light: 0xCDCDCF, dark: 0x383B51)
        public static var background5: UIColor = UIColor(light: 0x191A1D, dark: 0x191A1D)
        public static var background6: UIColor = UIColor(light: 0x17191C, dark: 0x17191C)
        public static var neutral700: UIColor = UIColor(light: 0x111539, dark: 0xFFFFFF)
        public static var neutralRed: UIColor = UIColor(light: 0xFF3B30, dark: 0xFF453A)
        
        
        public static var separatorBorder: UIColor = UIColor(light: 0xEDEDED, dark: 0xEDEDED)
        public static var separatorBorder2: UIColor = UIColor(light: 0xEDEDED, dark: 0x383838)
        public static var success: UIColor = UIColor(light: 0x31C48D, dark: 0x31C48D)
        public static var info: UIColor = UIColor(light: 0x4BBEFD, dark: 0x4BBEFD)
        public static var warning: UIColor = UIColor(light: 0xF88E69, dark: 0xF88E69)
        public static var error: UIColor = UIColor(light: 0xF23F51, dark: 0xF23F51)
        public static var initialColors: [UIColor] = [ UIColor(rgb: 0x4F6AFF),
                                                       UIColor(rgb: 0xFBB019),
                                                       UIColor(rgb: 0x00CC99),
                                                       UIColor(rgb: 0x63AFFF),
                                                       UIColor(rgb: 0xFF3E74),
                                                       UIColor(rgb: 0x9F35E7) ]
        
        public init() {}
        
        public static func initial(title: String) -> UIColor {
            initialColors[abs(title.hash) % initialColors.count]
        }
        
    }
}

extension UIColor {
    private typealias Colors = Appearance.Colors
    
    static var kitBlue: UIColor { Colors.kitBlue }
    static var kitRed: UIColor { Colors.kitRed }
    static var textBlack: UIColor { Colors.textBlack }
    static var textGray: UIColor { Colors.textGray }
    static var textGray2: UIColor { Colors.textGray2 }
    static var textRed: UIColor { Colors.textRed }
    static var background: UIColor { Colors.background }
    static var background2: UIColor { Colors.background2 }
    static var background3: UIColor { Colors.background3 }
    static var background4: UIColor { Colors.background4 }
    static var background5: UIColor { Colors.background5 }
    static var background6: UIColor { Colors.background6 }
    static var separatorBorder: UIColor { Colors.separatorBorder }
    static var success: UIColor { Colors.success }
    static var info: UIColor { Colors.info }
    static var warning: UIColor { Colors.warning }
    static var error: UIColor { Colors.error }
    
    static var initialColors: [UIColor] { Colors.initialColors }
    
    static func initial(title: String) -> UIColor {
        initialColors[abs(title.hash) % initialColors.count]
    }
}

public extension UIColor {
    
    convenience init(light: String, dark: String) {
        if #available(iOS 13.0, *) {
            self.init { $0.userInterfaceStyle == .dark ? .init(hex: dark) : .init(hex: light) }
        } else {
            self.init(hex: light)
        }
    }
    
    convenience init(light: Int, dark: Int) {
        if #available(iOS 13.0, *) {
            self.init { $0.userInterfaceStyle == .dark ? .init(rgb: dark) : .init(rgb: light) }
        } else {
            self.init(rgb: light)
        }
    }
    
    convenience init(light: UIColor, dark: UIColor) {
        if #available(iOS 13.0, *) {
            self.init { $0.userInterfaceStyle == .dark ? dark : light }
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
    
}

public extension UIColor {
    
    convenience init(hex: String, alpha: CGFloat = 1) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "#"))))
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        self.init(rgb: Int(color), alpha: alpha)
    }
    
    convenience init(rgb: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat(rgb >> 16 & 0xFF) / 255.0,
                  green: CGFloat(rgb >> 8 & 0xFF) / 255.0,
                  blue: CGFloat(rgb & 0xFF) / 255.0,
                  alpha: alpha)
    }
}
