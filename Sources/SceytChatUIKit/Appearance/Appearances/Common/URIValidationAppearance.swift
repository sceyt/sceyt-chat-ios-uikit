//
//  URIValidationAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct URIValidationAppearance {
    public var successLabelAppearance: LabelAppearance
    public var errorLabelAppearance: LabelAppearance
    public var messageProvider: any ChannelURIValidationMessageProviding = SceytChatUIKit.shared.visualProviders.channelURIValidationMessageProvider
    
    public init(successLabelAppearance: LabelAppearance,
                errorLabelAppearance: LabelAppearance,
                messageProvider: any ChannelURIValidationMessageProviding = SceytChatUIKit.shared.visualProviders.channelURIValidationMessageProvider) {
        self.successLabelAppearance = successLabelAppearance
        self.errorLabelAppearance = errorLabelAppearance
        self.messageProvider = messageProvider
    }
}
