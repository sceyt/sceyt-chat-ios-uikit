//
//  ConnectionStateViewAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public class ConnectionStateViewAppearance {
    public lazy var labelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                             font: Fonts.semiBold.withSize(18))
    public lazy var failedIcon: UIImage = .failedMessage
    public lazy var indicatorColor: UIColor = .accent
    public lazy var indicatorStyle: UIActivityIndicatorView.Style = .medium
    public lazy var connectionStateTextProvider: any ConnectionStateProviding = SceytChatUIKit.shared.visualProviders.connectionStateProvider
    
    // Initializer with default values
    public init(
        labelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(18)),
        failedIcon: UIImage = .failedMessage,
        indicatorColor: UIColor = .accent,
        indicatorStyle: UIActivityIndicatorView.Style = .medium,
        connectionStateTextProvider: any ConnectionStateProviding = SceytChatUIKit.shared.visualProviders.connectionStateProvider
    ) {
        self.labelAppearance = labelAppearance
        self.failedIcon = failedIcon
        self.indicatorColor = indicatorColor
        self.indicatorStyle = indicatorStyle
        self.connectionStateTextProvider = connectionStateTextProvider
    }
}
