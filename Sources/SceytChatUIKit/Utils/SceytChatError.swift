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
    case badMessageAttachmentParam = 1215
    case badMessageParam = 1234
    case markMessageNotfoundMessagesWithIds = 1241
    case networkConnection = 9904
    /// The SDK gave up waiting for a response. Note this says nothing about whether the server
    /// acted on the request — see `isTransport`.
    case requestTimeout = 9902
    
    case queryInProgress = 10008
    
    case notConnect = 9001
    
    var isBadParam: Bool {
        self == .badMessageAttachmentParam ||
        self == .badMessageParam
    }

    /// The request never got an answer, so the outcome is **indeterminate**: the server may have
    /// acted on it anyway. These arrive as plain `NSError` rather than `SceytError`, so
    /// `Error.sdkError` is `nil` for them and `SDKErrorTypeEnum.isResendable` cannot classify
    /// them — which is why anything deciding whether to retry has to consult this too.
    var isTransport: Bool {
        self == .networkConnection ||
        self == .notConnect ||
        self == .requestTimeout
    }
}

extension SceytChatError: LocalizedError {
    /// Without this, anything that surfaces one of these to the user renders Foundation's
    /// default — "The operation couldn’t be completed. (SceytChatUIKit.SceytChatError
    /// error 9001.)" — which is not something to put in an alert.
    public var errorDescription: String? {
        switch self {
        case .notConnect, .networkConnection, .requestTimeout:
            return L10n.Connection.Error.networkLost
        default:
            return L10n.Connection.Error.Try.again
        }
    }
}

public extension Error {
    
    var sceytChatCode: SceytChatError? {
        .init(rawValue: (self as NSError).code)
    }
    
}

extension Error {
    var sdkError: SDKErrorTypeEnum? {
        if let sceytError = self as? SceytError {
            return SDKErrorTypeEnum(rawValue: sceytError.type)
        }
        return nil
    }
}

public enum SDKErrorTypeEnum: String {
    
    case badRequest      = "BadRequest"
    case badParam        = "BadParam"
    case notFound        = "NotFound"
    case notAllowed      = "NotAllowed"
    case tooLargeRequest = "TooLargeRequest"
    case internalError   = "InternalError"
    case tooManyRequests = "TooManyRequests"
    case authentication  = "Authentication"
    
    public var isResendable: Bool {
        switch self {
        case .internalError,
             .tooManyRequests,
             .authentication:
            return true
            
        case .badRequest,
             .badParam,
             .notFound,
             .notAllowed,
             .tooLargeRequest:
            return false
        }
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
