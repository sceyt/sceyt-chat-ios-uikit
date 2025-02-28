//
//  Validator.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public struct Validator {
    
    public static func isValid(URI: String) -> Result<Bool, ChannelURIError> {
        guard URI.count >= SceytChatUIKit.shared.config.channelURIConfig.minLength, URI.count < SceytChatUIKit.shared.config.channelURIConfig.maxLength
        else {
            return .failure(.range(min: SceytChatUIKit.shared.config.channelURIConfig.minLength,
                                   length: SceytChatUIKit.shared.config.channelURIConfig.maxLength))
        }
        let lowercased = URI.lowercased()
        var isValid = false
        do {
            let regex = try NSRegularExpression(pattern: SceytChatUIKit.shared.config.channelURIConfig.regex)
            let range = NSRange(location: 0, length: lowercased.utf16.count)
            isValid = regex.firstMatch(in: lowercased, options: [], range: range) != nil
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return isValid ? .success(true) : .failure(.regex(SceytChatUIKit.shared.config.channelURIConfig.regex))
    }
    
    public static func isValidEmail(_ email: String?) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email ?? "")
    }
    
}


