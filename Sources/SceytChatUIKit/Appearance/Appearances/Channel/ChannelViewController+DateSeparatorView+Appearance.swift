//
//  ChannelViewController+DateSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.DateSeparatorView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        labelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.semiBold.withSize(13),
            backgroundColor: .overlayBackground1
        ),
        labelBorderColor: .clear,
        labelBorderWidth: 1,
        labelCornerRadius: 10,
        labelCornerCurve: .continuous,
        dateFormatter: SceytChatUIKit.shared.formatters.messageDateSeparatorFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, CGColor>
        public var labelBorderColor: CGColor
        
        @Trackable<Appearance, CGFloat>
        public var labelBorderWidth: CGFloat
        
        @Trackable<Appearance, CGFloat>
        public var labelCornerRadius: CGFloat
        
        @Trackable<Appearance, CALayerCornerCurve>
        public var labelCornerCurve: CALayerCornerCurve
        
        @Trackable<Appearance, any DateFormatting>
        public var dateFormatter: any DateFormatting
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            labelBorderColor: UIColor,
            labelBorderWidth: CGFloat,
            labelCornerRadius: CGFloat,
            labelCornerCurve: CALayerCornerCurve,
            dateFormatter: any DateFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._labelBorderColor = Trackable(value: labelBorderColor.cgColor)
            self._labelBorderWidth = Trackable(value: labelBorderWidth)
            self._labelCornerRadius = Trackable(value: labelCornerRadius)
            self._labelCornerCurve = Trackable(value: labelCornerCurve)
            self._dateFormatter = Trackable(value: dateFormatter)
        }
        
        public init(
            reference: ChannelViewController.DateSeparatorView.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            labelBorderColor: UIColor? = nil,
            labelBorderWidth: CGFloat? = nil,
            labelCornerRadius: CGFloat? = nil,
            labelCornerCurve: CALayerCornerCurve? = nil,
            dateFormatter: (any DateFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._labelBorderColor = Trackable(reference: reference, referencePath: \.labelBorderColor)
            self._labelBorderWidth = Trackable(reference: reference, referencePath: \.labelBorderWidth)
            self._labelCornerRadius = Trackable(reference: reference, referencePath: \.labelCornerRadius)
            self._labelCornerCurve = Trackable(reference: reference, referencePath: \.labelCornerCurve)
            self._dateFormatter = Trackable(reference: reference, referencePath: \.dateFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let labelBorderColor { self.labelBorderColor = labelBorderColor.cgColor }
            if let labelBorderWidth { self.labelBorderWidth = labelBorderWidth }
            if let labelCornerRadius { self.labelCornerRadius = labelCornerRadius }
            if let labelCornerCurve { self.labelCornerCurve = labelCornerCurve }
            if let dateFormatter { self.dateFormatter = dateFormatter }
        }
    }
}
