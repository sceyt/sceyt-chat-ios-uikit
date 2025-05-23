//
//  ChannelCreator.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

open class ChannelCreator: DataProvider {
    
    public required override init() {
        super.init()
    }
    
    open func create(
        type: String,
        uri: String? = nil,
        subject: String? = nil,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        members: [Member]? = nil,
        completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        Channel
            .create(
                type: type,
                uri: uri,
                subject: subject,
                metadata: metadata,
                avatarUrl: avatarUrl,
                members: members
            ) { channel, error in
                guard let channel = channel
                else {
                    logger.errorIfNotNil(error, "Create channel")
                    completion?(nil, error)
                    return
                }
                var chatChannel: ChatChannel?
                self.database.write {
                    chatChannel = $0.createOrUpdate(channel: channel)
                        .convert()
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store created channel in db")
                    completion?(chatChannel, nil)
                }
            }
    }
    
    open func create(channel: ChatChannel,
                     completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        Channel
            .create(
                type: channel.type,
                uri: channel.uri,
                subject: channel.subject,
                metadata: channel.metadata,
                avatarUrl: channel.avatarUrl,
                members: channel.members?.map { Member.Builder(id: $0.id).build()}
            ) { sceytChannel, error in
                guard let sceytChannel
                else {
                    logger.errorIfNotNil(error, "Create channel")
                    completion?(nil, error)
                    return
                }
                var chatChannel: ChatChannel?
                self.database.write {
                    if var dto = ChannelDTO.fetch(id: channel.id, context: $0) {
                        let oldId = dto.id
                        dto = dto.map(sceytChannel)
                        dto.id = Int64(sceytChannel.id)
                        try $0.batchUpdate(object: MessageDTO.self, predicate: .init(format: "channelId == %lld", oldId), propertiesToUpdate: [#keyPath(MessageDTO.channelId): oldId])
                        try $0.batchUpdate(object: MemberDTO.self, predicate: .init(format: "channelId == %lld", oldId), propertiesToUpdate: [#keyPath(MemberDTO.channelId): oldId])
                    }
                    chatChannel = $0.createOrUpdate(channel: sceytChannel)
                        .convert()
                }  completion: { error in
                    logger.errorIfNotNil(error, "Store created channel in db")
                    completion?(chatChannel, nil)
                }
            }
    }
    
    open func create(
        type: String,
        uri: String? = nil,
        subject: String? = nil,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        userIds: [UserId]?,
        completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        let members: [Member]? = userIds?.map {
            Member.Builder(id: $0).build()
        }
        create(
            type: type,
            uri: uri,
            subject: subject,
            metadata: metadata,
            avatarUrl: avatarUrl,
            members: members,
            completion: completion)
    }
    
    open func createLocalChannelByMembers(
        type: String,
        uri: String? = nil,
        subject: String? = nil,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        members: [ChatChannelMember],
        completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        var channelId: Int64 = Crypto.hash(value: members.map { $0.id }.sorted().joined(separator: "$"))
        if channelId < 0 {
            channelId *= -1
        }
        
        self.database.read {
            UserDTO.fetch(ids: members.map { $0.id } ?? [], context: $0).map { $0.convert() }
        } completion: { result in
            let newMembers: [ChatChannelMember]
            if let users = try? result.get() {
                var group = [UserId: ChatChannelMember]()
                for m in members {
                    group[m.id] = m
                }
                newMembers = group.values.map { ChatChannelMember(user: $0, roleName: $0.roleName)}
            } else {
                newMembers = members
            }
            
            let channel = ChatChannel(
                id: ChannelId(channelId),
                type: type,
                createdAt: Date(),
                memberCount: Int64(newMembers.count),
                subject: subject,
                metadata: metadata,
                avatarUrl: avatarUrl,
                uri: "",
                members: newMembers,
                userRole: SceytChatUIKit.shared.config.memberRolesConfig.owner,
                draftMessage: nil
            )
            
            self.database.read {
                ChannelDTO.fetchChannelByMembers(channel: channel, context: $0)
            } completion: { result in
                if let chatChannel = try? result.get() {
                    logger.info("Found channel with id: \(channelId) for members \(String(describing: members.map { $0.id}))")
                    completion?(chatChannel, nil)
                } else {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                            .unsynched = true
                    } completion: { error in
                        logger.errorIfNotNil(error, "Store created channel in db")
                        self.database.read {
                            ChannelDTO.fetch(id: ChannelId(channelId), context: $0)?
                                .convert()
                        } completion: { result in
                            switch result {
                            case .success(let chatChannel):
                                logger.info("Get channel after store with id: \(channelId)")
                                completion?(chatChannel, nil)
                            case .failure(let error):
                                completion?(channel, error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// When a channel with given URI exists, it will be returned, and given members will be ignored
    /// If a channel does not exist, it will be created with the given members
    open func createLocalChannelByURI(
        type: String,
        uri: String,
        subject: String? = nil,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        members: [ChatChannelMember]? = nil,
        completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        let channelId = 0
        
        self.database.read {
            UserDTO.fetch(ids: members?.map { $0.id } ?? [], context: $0).map { $0.convert() }
        } completion: { result in
            let newMembers: [ChatChannelMember]
            if let users = try? result.get() {
                var group = [UserId: ChatChannelMember]()
                for m in members ?? [] {
                    group[m.id] = m
                }
                newMembers = group.values.map { ChatChannelMember(user: $0, roleName: $0.roleName)}
                
            } else {
                newMembers = members ?? []
            }
            
            let channel = ChatChannel(
                id: ChannelId(channelId),
                type: type,
                createdAt: Date(),
                memberCount: Int64(newMembers.count),
                subject: subject,
                metadata: metadata,
                avatarUrl: avatarUrl,
                uri: uri,
                members: newMembers,
                userRole: SceytChatUIKit.shared.config.memberRolesConfig.owner,
                draftMessage: nil
            )
            
            self.database.read {
                ChannelDTO.fetchChannelByURI(channel: channel, context: $0)?.convert()
            } completion: { result in
                if let chatChannel = try? result.get() {
                    logger.info("Found channel with id: \(channelId) for members \(String(describing: members?.map { $0.id}))")
                    completion?(chatChannel, nil)
                } else {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                            .unsynched = true
                    } completion: { error in
                        logger.errorIfNotNil(error, "Store created channel in db")
                        self.database.read {
                            ChannelDTO.fetch(id: ChannelId(channelId), context: $0)?
                                .convert()
                        } completion: { result in
                            switch result {
                            case .success(let chatChannel):
                                logger.info("Get channel after store with id: \(channelId)")
                                completion?(chatChannel, nil)
                            case .failure(let error):
                                completion?(channel, error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    open func createChannelOnServerIfNeeded(channelId: ChannelId,
                                            completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        database.read {
            ChannelDTO.fetch(id: channelId, context: $0)?.convert()
        } completion: { result in
            switch result {
            case .failure(let error):
                logger.errorIfNotNil(error, "Get channel for db \(channelId)")
                completion?(nil, nil)
            case .success(let channel):
                if let channel, channel.unSynched == true {
                    self.create(channel: channel)
                    { channel, error in
                        completion?(channel, error)
                    }
                } else {
                    completion?(nil, nil)
                }
            }
        }
    }
    
    open func createChannelOnServerIfNeeded(channelId: ChannelId) async throws -> ChatChannel? {
        logger.verbose("[MESSAGE SEND] createChannelOnServerIfNeeded")
        return try await withCheckedThrowingContinuation { continuation in
            database.read {
                ChannelDTO.fetch(id: channelId, context: $0)?.convert()
            } completion: { result in
                switch result {
                case .failure(let error):
                    logger.verbose("[MESSAGE SEND] createChannelOnServerIfNeeded failed")
                    logger.errorIfNotNil(error, "Get channel for db \(channelId)")
                    continuation.resume(throwing: error)
                case .success(let channel):
                    if let channel, channel.unSynched {
                        logger.verbose("[MESSAGE SEND] createChannelOnServerIfNeeded success \(channelId) unSynched")
                        self.create(channel: channel)
                        { channel, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: channel)
                            }
                        }
                    } else {
                        logger.verbose("[MESSAGE SEND] createChannelOnServerIfNeeded success \(channelId) synched")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

extension ChannelDTO {
    
    class func fetchChannelByMembers(channel: ChatChannel, context: NSManagedObjectContext) -> ChatChannel? {
        let request = ChannelDTO.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", channel.type)
        let channelDtos = ChannelDTO.fetch(request: request, context: context)
        for dto in channelDtos {
            let channelMembers = MemberDTO.fetch(channelId: ChannelId(dto.id), context: context)
            if channelMembers.count == channel.members?.count ?? 0 {
                let join: String = channelMembers.compactMap { $0.user?.id }.sorted().joined(separator: "$")
                var hash: Int64 = Crypto.hash(value: join)
                if hash < 0 {
                    hash *= -1
                }
                if hash == channel.id && dto.metadata == channel.metadata {
                    return dto.convert()
                }
            }
        }
        return nil
    }
    
    class func fetchChannelByURI(channel: ChatChannel, context: NSManagedObjectContext) -> ChannelDTO? {
        let request = ChannelDTO.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND uri == %@", channel.type, channel.uri)
        let channelDtos = ChannelDTO.fetch(request: request, context: context)
        return channelDtos.first
    }
}
