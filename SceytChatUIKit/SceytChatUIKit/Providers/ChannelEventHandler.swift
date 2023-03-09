//
//  ChannelEventHandler.swift
//  SceytChatUIKit
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
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            debugPrint(error as Any)
        }
    }

    open func channel(_ channel: GroupChannel, didAdd members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.add(members: members, channelId: channel.id)
        } completion: { error in
            debugPrint(error as Any)
        }
    }

    open func channel(_ channel: PublicChannel, didJoin member: Member) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.add(members: [member], channelId: channel.id)
        } completion: { error in
            debugPrint(error as Any)
        }
    }

    open func channel(_ channel: GroupChannel, didKick members: [Member]) {
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

    open func channel(_ channel: GroupChannel, didLeave member: Member) {
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
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id)
        }
    }

    open func channel(_ channel: Channel, user: User, message: Message, didDelete reaction: Reaction) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id)
        }
    }

    open func channel(_ channel: GroupChannel, didChange newOwner: Member, oldOwner: Member) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.update(owner: newOwner, channelId: channel.id)
        }
    }
    
    public func channel(_ channel: GroupChannel, didBlock members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    public func channel(_ channel: GroupChannel, didUnblock members: [Member]) {
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
                    messagesDeletionDate: channel.messagesDeletionDate
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
                    messagesDeletionDate: channel.messagesDeletionDate
                )
            } catch {
                debugPrint(error)
            }
        } completion: { error in
            debugPrint(error as Any)
        }
    }

    open func channelDidUpdateUnreadCount(_ channel: Channel, totalUnreadChannelCount: UInt, totalUnreadMessageCount: UInt) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            debugPrint(error as Any)
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
        
        if let group = channel as? GroupChannel,
           group.role == nil {
            return
        }
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
