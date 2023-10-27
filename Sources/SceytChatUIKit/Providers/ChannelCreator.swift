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

open class ChannelCreator: Provider {
        
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
                    log.errorIfNotNil(error, "Create channel")
                    completion?(nil, error)
                    return
                }
                var chatChannel: ChatChannel?
                self.database.write {
                    chatChannel = $0.createOrUpdate(channel: channel)
                        .convert()
                }  completion: { error in
                    log.errorIfNotNil(error, "Store created channel in db")
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
                    log.errorIfNotNil(error, "Create channel")
                    completion?(nil, error)
                    return
                }
                var chatChannel: ChatChannel?
                self.database.write {
                    if var dto = ChannelDTO.fetch(id: channel.id, context: $0) {
                        dto = dto.map(sceytChannel)
                        dto.id = Int64(sceytChannel.id)
                        dto.messages?.forEach({
                            $0.channelId = Int64(sceytChannel.id)
                        })
                        dto.members?.forEach({
                            $0.channelId = Int64(sceytChannel.id)
                        })
                    }
                    chatChannel = $0.createOrUpdate(channel: sceytChannel)
                        .convert()
                }  completion: { error in
                    log.errorIfNotNil(error, "Store created channel in db")
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
    
    open func createLocalChannel(
        type: String,
        uri: String? = nil,
        subject: String? = nil,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        members: [Member]? = nil,
        completion: ((ChatChannel?, Error?) -> Void)? = nil
    ) {
        var channelId: Int64 = Crypto.hash(value: (members ?? []).map { $0.id }.sorted().joined(separator: "$"))
        if channelId < 0 {
            channelId *= -1
        }
        
        let chatMembers = members?.map { ChatChannelMember(member: $0) }
        let channel = ChatChannel(
            id: ChannelId(channelId),
            type: type,
            createdAt: Date(),
            memberCount: Int64(members?.count ?? 0),
            subject: subject,
            metadata: metadata,
            avatarUrl: avatarUrl,
            uri: "",
            members: chatMembers,
            userRole: Config.chatRoleOwner,
            draftMessage: nil
        )
        self.database.read {
            ChannelDTO.fetchChannelByMembers(channel: channel, context: $0)
        } completion: { result in
            if let chatChannel = try? result.get() {
                log.info("Found channel with id: \(channelId) for members \(String(describing: chatMembers?.map { $0.id}))")
                completion?(chatChannel, nil)
            } else {
                self.database.write { 
                    $0.createOrUpdate(channel: channel)
                        .unsynched = true
                } completion: { error in
                    log.errorIfNotNil(error, "Store created channel in db")
                    self.database.read {
                        ChannelDTO.fetch(id: ChannelId(channelId), context: $0)?
                            .convert()
                    } completion: { result in
                        switch result {
                        case .success(let chatChannel):
                            log.info("Get channel after store with id: \(channelId)")
                            completion?(chatChannel, nil)
                        case .failure(let error):
                            completion?(channel, error)
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
                log.errorIfNotNil(error, "Get channel for db \(channelId)")
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
        return try await withCheckedThrowingContinuation { continuation in
            database.read {
                ChannelDTO.fetch(id: channelId, context: $0)?.convert()
            } completion: { result in
                switch result {
                case .failure(let error):
                    log.errorIfNotNil(error, "Get channel for db \(channelId)")
                    continuation.resume(throwing: error)
                case .success(let channel):
                    if let channel, channel.unSynched == true {
                        self.create(channel: channel)
                        { channel, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: channel)
                            }
                        }
                    } else {
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
            if let channelMembers = dto.members, channelMembers.count == channel.members?.count ?? 0 {
                let join: String = channelMembers.compactMap { $0.user?.id }.sorted().joined(separator: "$")
                var hash: Int64 = Crypto.hash(value: join)
                if hash < 0 {
                    hash *= -1
                }
                if hash == channel.id {
                    return dto.convert()
                }
            }
        }
        return nil
    }
}
