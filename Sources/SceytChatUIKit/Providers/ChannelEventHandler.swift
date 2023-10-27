//
//  ChannelEventHandler.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelEventHandler: NSObject, ChannelDelegate {
    
    public static let channelDelegateIdentifier = NSUUID().uuidString
    
    let database: Database
    let chatClient: ChatClient
    
    public required init(
        database: Database,
        chatClient: ChatClient
    ) {
        self.database = database
        self.chatClient = chatClient
        super.init()
    }
    
    deinit {
        stopEventHandler()
    }
    
    open func startEventHandler() {
        chatClient.add(
            channelDelegate: self,
            identifier: Self.channelDelegateIdentifier
        )
    }
    
    open func stopEventHandler() {
        chatClient.removeChannelDelegate(identifier: Self.channelDelegateIdentifier)
    }
    
    // MARK: ChannelsDelegate
    open func channelDidDelete(id: ChannelId) {
        database.write {
            $0.deleteChannel(id: id)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidCreate(_ channel: Channel) {
        var channelId: Int64 = Crypto.hash(value: (channel.members ?? []).map { $0.id }.sorted().joined(separator: "$"))
        if channelId < 0 {
            channelId *= -1
        }
        database.write {
            if let dto = ChannelDTO.fetch(id: ChannelId(channelId), context: $0) {
                dto.id = Int64(channel.id)
                dto.unsynched = false
                dto.messages?.forEach({
                    $0.channelId = Int64(channel.id)
                })
                let chatChannel = $0.createOrUpdate(channel: channel).convert()
                NotificationCenter.default
                    .post(name: .didUpdateLocalCreateChannelOnEventChannelCreate,
                          object: nil,
                          userInfo: ["localChannelId": channelId, "channel": chatChannel])
            } else {
                $0.createOrUpdate(channel: channel)
            }
            
        } completion: { error in
            debugPrint(error as Any)
        }
    }

    open func channel(_ channel: Channel, didAdd members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.add(members: members, channelId: channel.id)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channel(_ channel: Channel, didJoin member: Member) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.add(members: [member], channelId: channel.id)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channel(_ channel: Channel, didKick members: [Member]) {
        let me = members.contains(where: { $0.id == chatClient.user.id })
        database.write {
            if me {
                $0.deleteChannel(id: channel.id)
            } else {
                $0.createOrUpdate(channel: channel)
                $0.delete(members: members, channelId: channel.id)
            }
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channel(_ channel: Channel, didLeave member: Member) {
        let me = member.id == chatClient.user.id
        database.write {
            if me {
                $0.deleteChannel(id: channel.id)
            } else {
                $0.createOrUpdate(channel: channel)
                $0.delete(members: [member], channelId: channel.id)
            }
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidUpdate(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channel(channelId: ChannelId, didReceive marker: MessageListMarker) {
        log.debug("[MARKER CHECK] didReceive in cid \(channelId) mark: \(marker.name) for \(marker.messageIds) in channelId:\(marker.channelId)")
        database.write {
            $0.update(messageMarkers: marker)
        }
    }
    
    open func channel(_ channel: Channel, didReceive message: Message) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id)
        } completion: { error in
            debugPrint(error as Any)
        }
        markReceivedMessageAsReceivedIfNeeded(message: message, channel: channel)
    }
    
    open func channel(_ channel: Channel, user: User, didEdit message: Message) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id, changedBy: user)
        }
    }
    
    open func channel(_ channel: Channel, user: User, didDelete message: Message) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id, changedBy: user)
        }
    }
    
    open func channel(_ channel: Channel, user: User, message: Message, didAdd reaction: Reaction) {
        database.write {
            $0.add(reaction: reaction)
        }
    }
    
    open func channel(_ channel: Channel, user: User, message: Message, didDelete reaction: Reaction) {
        database.write {
            $0.delete(reaction: reaction)
        }
    }
    
    open func channel(_ channel: Channel, didChange newOwner: Member, oldOwner: Member) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.update(owner: newOwner, channelId: channel.id)
        }
    }
    
    open func channel(_ channel: Channel, didChangeRole members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    public func channel(_ channel: Channel, didBlock members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    public func channel(_ channel: Channel, didUnblock members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    open func channelDidDeleteAllMessagesForMe(_ channel: Channel) {
        database.write {
            do {
                try $0.deleteAllMessages(
                    channelId: channel.id,
                    before: channel.messagesClearedAt
                )
            } catch {
                debugPrint(error)
            }
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidDeleteAllMessagesForEveryone(_ channel: Channel) {
        database.write {
            do {
                try $0.deleteAllMessages(
                    channelId: channel.id,
                    before: channel.messagesClearedAt
                )
            } catch {
                debugPrint(error)
            }
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidUpdateUnreadCount(
        _ channel: Channel,
        totalUnreadChannelCount: UInt,
        totalUnreadMessageCount: UInt) {
            log.debug("[MARKER CHECK] received channelDidUpdateUnreadCount: \(channel.id) for \(channel.newMessageCount)")
            database.write {
                $0.createOrUpdate(channel: channel)
            } completion: { error in
                log.errorIfNotNil(error, "Unable update channel from ```channelDidUpdateUnreadCount```")
            }
        }
    
    open func channelDidMute(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidUnmute(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidMarkAsRead(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.markAsRead(channelId: channel.id)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func channelDidMarkAsUnread(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
    
    open func markReceivedMessageAsReceivedIfNeeded(
        message: Message,
        channel: Channel
    ) {
        guard channel.userRole != nil
        else { return }
        
        if message.incoming {
            ChannelOperator(channelId: channel.id)
                .markMessagesAsReceived(ids: [message.id as NSNumber])
            { marker, error in
                if let marker {
                    self.database.write {
                        $0.update(messageMarkers: marker)
                    }
                }
            }
        }
    }
}
