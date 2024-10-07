//
//  ChannelInfoViewController+DateSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.DateSeparatorView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .surface1,
        labelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(13)
        ),
        dateFormatter: SceytChatUIKit.shared.formatters.channelInfoAttachmentSeparatorDateFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, any DateFormatting>
        public var dateFormatter: any DateFormatting
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            dateFormatter: any DateFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._dateFormatter = Trackable(value: dateFormatter)
        }
        
        public init(
            reference: ChannelInfoViewController.DateSeparatorView.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            dateFormatter: (any DateFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._dateFormatter = Trackable(reference: reference, referencePath: \.dateFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let dateFormatter { self.dateFormatter = dateFormatter }
        }
    }
}
