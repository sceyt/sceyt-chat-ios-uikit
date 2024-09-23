//
//  UserProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 10.08.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class UserProvider: DataProvider {
    
    required public override init() {
        super.init()
    }

    open func blockUsers(
        ids: [UserId],
        completion: ((Error?) -> Void)? = nil) {
            logger.verbose("Request to block users \(ids)")
            SceytChatUIKit.shared.chatClient.blockUsers(ids: ids) { users, error in
                if let users = users {
                    self.store(users: users) { error in
                        logger.errorIfNotNil(error, "Store users")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Response block users")
                    completion?(error)
                }
            }
    }
    
    open func unblockUsers(
        ids: [UserId],
        completion: ((Error?) -> Void)? = nil) {
            logger.verbose("Request to unblock users \(ids)")
            SceytChatUIKit.shared.chatClient.unblockUsers(ids: ids) { users, error in
                if let users = users {
                    self.store(users: users) { error in
                        logger.errorIfNotNil(error, "Store users")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Response unblock users")
                    completion?(error)
                }
            }
    }
    
    open func fetch(
        userIds: [UserId],
        completion: @escaping (([ChatUser]) -> Void)) {
            guard !userIds.isEmpty
            else {
                completion([])
                return
            }
            database.read {
                $0.fetch(userIds: userIds).map { $0.convert() }
            } completion: { result in
                completion((try? result.get()) ?? [])
            }
        }
    
    open func store(
        users: [User],
        updateChannelsForUsers: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.performWriteTask {
            for user in users {
                var isUpdated = false
                if updateChannelsForUsers {
                    if let _user = UserDTO.fetch(id: user.id, context: $0)?.convert(),
                       _user !~= ChatUser(user: user) {
                        isUpdated = true
                    }
                }
                $0.createOrUpdate(user: user)
                if isUpdated {
                    $0.updateChannelDTOs(for: user.id)
                }
            }
        } completion: { error in
            logger.errorIfNotNil(error, "Unable Store users")
            completion?(error)

        }
    }
}
