//
//  UserDisplayNameFormatter.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

public protocol UserDisplayNameFormatter {

    func format( _ user: ChatUser) -> String

}

open class DefaultUserDisplayNameFormatter: UserDisplayNameFormatter {

    public init() {}

    open func format( _ user: ChatUser) -> String {
        switch user.activityState {
        case .deleted:
            return L10n.User.deleted
        case .inactive:
            return L10n.User.inactive
        default:
            break
        }

        var name = ""
        if let firstName = user.firstName, !firstName.isEmpty {
            name = firstName
        }
        if let lastName = user.lastName, !lastName.isEmpty {
            if name.isEmpty {
                name = lastName
            } else {
               name += " " + lastName
            }
        }
        if name.isEmpty {
            name = user.id
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
