//
//  ChannelProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelProvider: Provider {
    
    public let channelId: ChannelId
    public let channelOperator: ChannelOperator
    
    public static var defaultQueryParam: ChannelQueryParam {
        let param = ChannelQueryParam()
        param.includeLastMessage = true
        param.memberCount = 20
        param.userMessageReactionCount = 10
        return param
    }
    
    public required init(channelId: ChannelId) {
        self.channelId = channelId
        channelOperator = .init(channelId: channelId)
        super.init()
    }
    
    open func update(
        uri: String,
        subject: String,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .update(
                uri: uri,
                subject: subject,
                metadata: metadata,
                avatarUrl: avatarUrl
            ) { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Update channel \(self.channelId) in db")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Update channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func fetchChannel(completion: @escaping (ChatChannel?) -> Void) {
        database.read {
            ChannelDTO.fetch(id: self.channelId, context: $0)?
                .convert()
        } completion: { result in
            completion(try? result.get())
        }
        
    }
    
    open func loadChannel(
        param: ChannelQueryParam = defaultQueryParam,
        completion: ((Error?) -> Void)? = nil) {
            SceytChatUIKit.shared.chatClient.getChannel(
                id: channelId,
                param: param)
            { channel, error in
                guard let channel = channel
                else {
                    logger.errorIfNotNil(error, "Get channel \(self.channelId)")
                    completion?(error)
                    return
                }
                self.database.write {
                    $0.createOrUpdate(channel: channel)
                } completion: { error in
                    logger.errorIfNotNil(error, "Update channel \(self.channelId) in db")
                    completion?(error)
                }
            }
        }
    
    open func delete(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .delete { error in
                if error == nil || error?.sceytChatCode == .channelNotExists {
                    self.database.write {
                        $0.deleteChannel(id: self.channelId)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Delete channel \(self.channelId) in db")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Delete channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func leave(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .leave { error in
                if error == nil || error?.sceytChatCode == .channelNotExists {
                    self.database.write {
                        $0.deleteChannel(id: self.channelId)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Delete channel \(self.channelId) in db")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Leave channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func block(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .block { error in
                if error == nil  || error?.sceytChatCode == .channelNotExists {
                    self.database.write {
                        $0.deleteChannel(id: self.channelId)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Delete channel \(self.channelId) in db")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Block channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func unblock(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .unblock { error in
                logger.errorIfNotNil(error, "Unblock channel \(self.channelId)")
                completion?(error)
            }
    }
    
    open func mute(
        timeInterval: TimeInterval,
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .mute(timeInterval: timeInterval, completion: { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Store muted channel \(self.channelId) in db with timeInterval \(timeInterval)")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Mute channel \(self.channelId) with timeInterval \(timeInterval)")
                    completion?(error)
                }
            })
    }
    
    open func unmute(
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .unmute { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Store unmuted channel in db \(self.channelId)")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Unmute channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func pin(
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .pin { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Store pinned channel in db \(self.channelId)")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Pin channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func unpin(
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .unpin { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        logger.errorIfNotNil(error, "Store unpinned channel in db \(self.channelId)")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Unpin channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func markAs(
        read: Bool,
        completion: ((Error?) -> Void)? = nil
    ) {
        func _update(channel: Channel) {
            database.write {
                $0.createOrUpdate(channel: channel)
            } completion: { error in
                logger.errorIfNotNil(error, "Store markAs \(read ? "read" : "unread") channel \(self.channelId)")
                completion?(error)
            }
        }
        
        if read {
            channelOperator.markAsRead { channel, error in
                if let channel = channel {
                    _update(channel: channel)
                } else {
                    logger.errorIfNotNil(error, "Mark as read channel \(self.channelId)")
                    completion?(error)
                }
            }
        } else {
            channelOperator.markAsUnread { channel, error in
                if let channel = channel {
                    _update(channel: channel)
                } else {
                    logger.errorIfNotNil(error, "Mark as unread channel \(self.channelId)")
                    completion?(error)
                }
            }
        }
    }
    
    open func deleteAllMessages(
        forEveryone: Bool = false,
        completion: ((Error?) -> Void)? = nil) {
            let currentDate = Date()
            channelOperator
                .deleteAllMessages(forEveryone: forEveryone)
            { error in
                if error == nil {
                    self.database.write {
                        do {
                            try $0.deleteAllMessages(
                                channelId: self.channelId,
                                before: currentDate
                            )
                        } catch {
                            logger.errorIfNotNil(error, "Delete all messages from db in channel \(self.channelId) forEveryone: \(forEveryone)")
                        }
                    } completion: { error in
                        logger.errorIfNotNil(error, "Delete all messages from db in channel \(self.channelId) forEveryone: \(forEveryone)")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Delete all messages from channel \(self.channelId) for forEveryone: \(forEveryone)")
                    completion?(error)
                }
            }
        }
    
    open func join(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .join { channel, error in
                if let channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    }  completion: { error in
                        logger.errorIfNotNil(error, "Store channel \(self.channelId) in db")
                        completion?(error)
                    }
                } else {
                    logger.errorIfNotNil(error, "Join channel \(self.channelId)")
                    completion?(error)
                }
            }
    }
    
    open func changeOwner(newOwnerId: UserId,
                          completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .changeOwner(newOwnerId: newOwnerId)
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.createOrUpdate(
                        members: members,
                        channelId: self.channelId
                    )
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Change owner \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func setRole(name: String,
                      userId: UserId,
                      completion: ((Error?) -> Void)? = nil) {
        channelOperator.changeMembersRole([
            Member
                .Builder(id: userId)
                .roleName(name)
                .build()
        ])
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.createOrUpdate(
                        members: members,
                        channelId: channel.id
                    )
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Set Role \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func setRole(members: [ChatChannelMember],
                      completion: ((Error?) -> Void)? = nil) {
        channelOperator.changeMembersRole(
            members.map {
                let builder = Member.Builder(id: $0.id)
                if let role = $0.roleName {
                    builder.roleName(role)
                }
                return builder.build()
            }
        )
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.createOrUpdate(
                        members: members,
                        channelId: channel.id
                    )
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Set Role \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func add(
        members: [Member],
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .add(members: members)
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.add(members: members, channelId: channel.id)
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Add members Role \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func kick(
        members ids: [UserId],
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .kickMembers(ids: ids)
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    for member in members {
                        $0.deleteMember(id: member.id, from: channel.id)
                    }
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store/delete channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Kick members Role \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func block(
        members ids: [UserId],
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .blockMembers(ids: ids)
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(channel: channel)
                    for member in members {
                        $0.deleteMember(id: member.id, from: self.channelId)
                    }
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store/delete channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Block members Role \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func unblock(
        members ids: [UserId],
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator
            .unblockMembers(ids: ids)
        { channel, members, error in
            if let channel, let members {
                self.database.write {
                    $0.createOrUpdate(channel: channel)
                    for member in members {
                        $0.deleteMember(id: member.id, from: self.channelId)
                    }
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store/delete channel [members] \(self.channelId) in db")
                    completion?(error)
                }
            } else {
                logger.errorIfNotNil(error, "Unblock members Role \(self.channelId)")
                completion?(error)
            }
        }
    }
    
    open func hide(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .hide
        { error in
            self.database.write {
                $0.deleteChannel(id: self.channelId)
            }  completion: { dbError in
                logger.errorIfNotNil(dbError, "Delete channel \(self.channelId) in db")
                logger.errorIfNotNil(error, "Hide channel \(self.channelId)")
                completion?(error ?? dbError)
            }
        }
    }
    
    open func saveDraftMessage(_ message: NSAttributedString?, at date: Date? = Date()) {
        self.database.write {
            $0.update(draft: message, date: date, channelId: self.channelId)
        }  completion: { error in
            logger.errorIfNotNil(error, "save draft message channel \(self.channelId) in db")
        }
    }
    
    open func getLocalChannel(type: String, userId: UserId, completion: @escaping (ChatChannel?) -> Void) {
        database.read {
            let memberRequest = MemberDTO.fetchRequest()
            memberRequest.predicate = NSPredicate(format: "user.id == %@", userId)
            let channelIds = MemberDTO.fetch(request: memberRequest, context: $0).map { $0.channelId }
            let channelRequest = ChannelDTO.fetchRequest()
            channelRequest.predicate = NSPredicate(format: "type == %@ AND id IN %@", type, channelIds)
            let channel = ChannelDTO.fetch(request: channelRequest, context: $0).first?.convert()
            return channel
        } completion: { result in
            switch result {
            case .failure(let error):
                logger.errorIfNotNil(error, "Getting channel with \(userId)")
            case .success(let channel):
                completion(channel)
            }
        }

    }
}
