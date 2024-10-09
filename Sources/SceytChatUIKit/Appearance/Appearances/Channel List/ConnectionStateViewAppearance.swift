//
//  ConnectionStateViewAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public class ConnectionStateViewAppearance: AppearanceProviding {
    public var appearance: ConnectionStateViewAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: ConnectionStateViewAppearance?
    
    public static var appearance = ConnectionStateViewAppearance(
        labelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(18)
        ),
        failedIcon: .failedMessage,
        indicatorColor: .accent,
        indicatorStyle: .medium,
        connectionStateTextProvider: SceytChatUIKit.shared.visualProviders.connectionStateProvider
    )
    
    @Trackable<ConnectionStateViewAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
    
    @Trackable<ConnectionStateViewAppearance, UIImage>
    public var failedIcon: UIImage
    
    @Trackable<ConnectionStateViewAppearance, UIColor>
    public var indicatorColor: UIColor
    
    @Trackable<ConnectionStateViewAppearance, UIActivityIndicatorView.Style>
    public var indicatorStyle: UIActivityIndicatorView.Style
    
    @Trackable<ConnectionStateViewAppearance, any ConnectionStateProviding>
    public var connectionStateTextProvider: any ConnectionStateProviding
    
    // Initializer with all parameters
    public init(
        labelAppearance: LabelAppearance,
        failedIcon: UIImage,
        indicatorColor: UIColor,
        indicatorStyle: UIActivityIndicatorView.Style,
        connectionStateTextProvider: any ConnectionStateProviding
    ) {
        self._labelAppearance = Trackable(value: labelAppearance)
        self._failedIcon = Trackable(value: failedIcon)
        self._indicatorColor = Trackable(value: indicatorColor)
        self._indicatorStyle = Trackable(value: indicatorStyle)
        self._connectionStateTextProvider = Trackable(value: connectionStateTextProvider)
    }
    
    // Convenience initializer with optional parameters
    public init(
        reference: ConnectionStateViewAppearance,
        labelAppearance: LabelAppearance? = nil,
        failedIcon: UIImage? = nil,
        indicatorColor: UIColor? = nil,
        indicatorStyle: UIActivityIndicatorView.Style? = nil,
        connectionStateTextProvider: (any ConnectionStateProviding)? = nil
    ) {
        self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
        self._failedIcon = Trackable(reference: reference, referencePath: \.failedIcon)
        self._indicatorColor = Trackable(reference: reference, referencePath: \.indicatorColor)
        self._indicatorStyle = Trackable(reference: reference, referencePath: \.indicatorStyle)
        self._connectionStateTextProvider = Trackable(reference: reference, referencePath: \.connectionStateTextProvider)
        
        if let labelAppearance { self.labelAppearance = labelAppearance }
        if let failedIcon { self.failedIcon = failedIcon }
        if let indicatorColor { self.indicatorColor = indicatorColor }
        if let indicatorStyle { self.indicatorStyle = indicatorStyle }
        if let connectionStateTextProvider { self.connectionStateTextProvider = connectionStateTextProvider }
    }
}
