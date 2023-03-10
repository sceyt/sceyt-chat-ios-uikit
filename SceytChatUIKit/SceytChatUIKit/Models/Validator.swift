//
//  Validator.swift
//  SceytChatUIKit
//

import Foundation

public struct Validator {
    
    public static func isValid(URI: String) -> Result<Bool, ChannelURIError> {
        guard URI.count >= Config.channelURIMinLength, URI.count < Config.channelURIMaxLength
        else {
            return .failure(.range(min: Config.channelURIMinLength,
                                   length: Config.channelURIMaxLength))
        }
        let lowercased = URI.lowercased()
        var isValid = false
        do {
            let regex = try NSRegularExpression(pattern: Config.channelURIRegex)
            let range = NSRange(location: 0, length: lowercased.utf16.count)
            isValid = regex.firstMatch(in: lowercased, options: [], range: range) != nil
        } catch {
            print(error)
        }
        return isValid ? .success(true) : .failure(.regex(Config.channelURIRegex))
    }
    
    public static func isValidEmail(_ email: String?) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email ?? "")
    }
    
}


