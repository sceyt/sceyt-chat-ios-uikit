//
//  ChannelURIValidationMessageProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct ChannelURIValidationMessageProvider: ChannelURIValidationMessageProviding {
    public func provideVisual(for type: URIValidationType) -> String {
        switch type {
        case .freeToUse: return "Free to use"
        case .alreadyTaken: return "Already taken"
        case .tooLong: return "Too long"
        case .tooShort: return "Too short"
        case .invalidCharacters: return "Invalid characters"
        }
    }
}
