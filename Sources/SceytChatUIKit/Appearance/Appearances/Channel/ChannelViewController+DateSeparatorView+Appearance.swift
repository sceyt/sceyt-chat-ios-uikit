//
//  ChannelViewController+DateSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.DateSeparatorView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .clear
        public lazy var labelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                                 font: Fonts.semiBold.withSize(13),
                                                                 backgroundColor: .overlayBackground1)
        public lazy var labelBorderColor: CGColor = UIColor.clear.cgColor
        public lazy var labelBorderWidth: CGFloat = 1
        public lazy var labelCornerRadius: CGFloat = 10
        public lazy var labelCornerCurve: CALayerCornerCurve = .continuous
        
        public lazy var dateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageDateSeparatorFormatter
        
        public init(backgroundColor: UIColor = .clear,
                    labelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                             font: Fonts.semiBold.withSize(13),
                                                             backgroundColor: .overlayBackground1),
                    labelBorderColor: UIColor = UIColor.clear,
                    labelBorderWidth: CGFloat = 1,
                    labelCornerRadius: CGFloat = 10,
                    labelCornerCurve: CALayerCornerCurve = .continuous,
                    dateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageDateSeparatorFormatter) {
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
            self.labelBorderColor = labelBorderColor.cgColor
            self.labelBorderWidth = labelBorderWidth
            self.labelCornerRadius = labelCornerRadius
            self.labelCornerCurve = labelCornerCurve
            self.dateFormatter = dateFormatter
        }
    }
}
