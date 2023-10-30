//
//  SceytChatError.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 17.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

public enum SceytChatError: Int, Error {
    
    case channelNotExists = 1109
    case channelAlreadyExists = 1108
    case notAllowed = 1301
    case badMessageParam = 1234
    case markMessageNotfoundMessagesWithIds = 1241
    
    case queryInProgress = 10008
    
}

public extension Error {
    
    var sceytChatCode: SceytChatError? {
        .init(rawValue: (self as NSError).code)
    }
    
}

public enum ChannelURIError: Error, LocalizedError {
    case range(min: Int, length: Int)
    case regex(String)
    case alreadyExist
    
    public var errorDescription: String? {
        switch self {
        case let .range(min: min, length: length):
            return L10n.Channel.Create.Uri.Error.range(min, length)
        case .regex(_):
            return L10n.Channel.Create.Uri.Error.regex
        case .alreadyExist:
            return L10n.Channel.Create.Uri.Error.exist
        }
    }
}
