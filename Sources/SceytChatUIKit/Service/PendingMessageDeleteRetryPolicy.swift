//
//  PendingMessageDeleteRetryPolicy.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

public enum PendingMessageDeleteOutcome {
    /// The server confirmed the delete.
    case done
    /// The server will never accept this delete; stop trying. Carries the reason for logging.
    case drop(String)
    /// Transient failure; keep the record and try again on the next sync.
    case retry

    public var isRetry: Bool {
        if case .retry = self { return true }
        return false
    }
}

/// Decides what happens to a stored delete intent after one attempt.
///
/// There is no attempt cap and no age limit: an intent is kept until the server answers, and it
/// only ever answers in two ways that matter — it deleted the message, or it has no such message.
/// Kept free of side effects so it can be unit tested without a database.
public struct PendingMessageDeleteRetryPolicy {

    public static func outcome(error: Error?) -> PendingMessageDeleteOutcome {
        guard let error else { return .done }

        if let code = error.sceytChatCode {
            switch code {
            case .channelNotExists, .notAllowed, .badMessageParam, .badMessageAttachmentParam:
                return .drop("terminal code \(code)")
            default:
                break
            }
        }

        // `NotFound` means the server never got the message, so there is nothing left to delete.
        // The other non-resendable errors are permanent rejections; retrying them changes nothing.
        if let sdkError = error.sdkError, !sdkError.isResendable {
            return .drop("non-resendable \(sdkError.rawValue)")
        }

        return .retry
    }
}
