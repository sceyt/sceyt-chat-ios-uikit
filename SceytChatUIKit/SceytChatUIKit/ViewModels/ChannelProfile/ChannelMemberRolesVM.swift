//
//  ChannelMemberRolesViewModel.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelMemberRolesVM {

    public required init() {}

    open var selectedRole: Role?
    open var roles = [Role]()

    open func loadRoles(completion: @escaping (Error?) -> Void) {
        chatClient.getRoles { [weak self] (roles, error) in
            self?.roles = roles ?? []
            completion(error)
        }
    }

    open func role(at index: Int) -> Role? {
        guard roles.indices.contains(index) else { return nil }
        return roles[index]
    }
}
