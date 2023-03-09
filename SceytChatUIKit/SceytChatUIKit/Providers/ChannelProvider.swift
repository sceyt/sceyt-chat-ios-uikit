//
//  ChannelProvider.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelProvider: Provider {
    
    let channelId: ChannelId
    let channelOperator: GroupChannelOperator
    public required init(channelId: ChannelId) {
        self.channelId = channelId
        channelOperator = .init(channelId: channelId)
        super.init()
    }
    
    open func updatePublicChannel(
        uri: String,
        subject: String,
        label: String?,
        metadata: String?,
        avatarUrl: URL?,
        completion: ((Error?) -> Void)? = nil
    ) {
        PublicChannelOperator(channelId: channelId)
            .update(
                uri: uri,
                subject: subject,
                label: label,
                metadata: metadata,
                avatarUrl: avatarUrl
            ) { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
    }
    
    open func updatePrivateChannel(
        subject: String,
        label: String? = nil,
        metadata: String? = nil,
        avatarUrl: URL? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        PrivateChannelOperator(channelId: channelId)
            .update(
                subject: subject,
                label: label,
                metadata: metadata,
                avatarUrl: avatarUrl
            ) { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
    }
    
    open func updateDirectChannel(
        label: String? = nil,
        metadata: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        DirectChannelOperator(channelId: channelId)
            .update(
                label: label,
                metadata: metadata
            ) { channel, error in
                if let channel = channel {
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
    }
    
    open func delete(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .delete {error in
                if error == nil || error?.sceytCode == .channelNotExists {
                    self.database.write {
                        $0.deleteChannel(id: self.channelId)
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
    }
    
    open func leave(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .leave { error in
                debugPrint(error as Any)
                if error == nil || error?.sceytCode == .channelNotExists {
                    self.database.write {
                        $0.deleteChannel(id: self.channelId)
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
    }
    
    open func block(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .block { error in
                debugPrint(error as Any)
                if error == nil  || error?.sceytCode == .channelNotExists {
                    self.database.write {
                        $0.deleteChannel(id: self.channelId)
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
    }
    
    open func unblock(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .unblock { error in
                debugPrint(error as Any)
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
                        completion?(error)
                    }
                } else {
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
                        completion?(error)
                    }
                } else {
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
                completion?(error)
            }
        }
        
        if read {
            channelOperator.markAsRead { channel, error in
                debugPrint(error as Any)
                if let channel = channel {
                    _update(channel: channel)
                } else {
                    completion?(error)
                }
            }
        } else {
            channelOperator.markAsUnread { channel, error in
                if let channel = channel {
                    _update(channel: channel)
                } else {
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
                                messagesDeletionDate: currentDate
                            )
                        } catch {
                            debugPrint(error)
                        }
                    } completion: { error in
                        completion?(error)
                    }
                } else {
                    completion?(error)
                }
            }
        }
    
    open func join(completion: ((Error?) -> Void)? = nil) {
        PublicChannelOperator(channelId: channelId)
            .join { channel, error in
                defer { completion?(error) }
                guard let channel = channel
                else { return }
                self.database.write {
                    $0.createOrUpdate(channel: channel)
                }  completion: { error in
                    debugPrint(error as Any)
                }
            }
    }
    
    open func changeOwner(newOwnerId: UserId,
                          completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .changeOwner(newOwnerId: newOwnerId)
        { channel, members, error in
                defer { completion?(error) }
                guard let channel,
                      let members
                else { return }
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.createOrUpdate(
                        members: members,
                        channelId: self.channelId
                    )
                }  completion: { error in
                    debugPrint(error as Any)
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
                defer { completion?(error) }
                guard let channel,
                      let members
                else { return }
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.createOrUpdate(
                        members: members,
                        channelId: self.channelId
                    )
                }  completion: { error in
                    debugPrint(error as Any)
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
                defer { completion?(error) }
                guard let channel,
                      let members
                else { return }
                self.database.write {
                    $0.createOrUpdate(
                        channel: channel
                    )
                    $0.createOrUpdate(
                        members: members,
                        channelId: self.channelId
                    )
                }  completion: { error in
                    debugPrint(error as Any)
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
            defer { completion?(error) }
            guard let channel,
                  let members
            else { return }
            self.database.write {
                $0.createOrUpdate(channel: channel)
                $0.add(members: members, channelId: self.channelId)
            }  completion: { error in
                debugPrint(error as Any)
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
            defer { completion?(error) }
            guard let channel,
                  let members
            else { return }
            self.database.write {
                $0.createOrUpdate(channel: channel)
                for member in members {
                    $0.deleteMember(id: member.id, from: self.channelId)
                }
            }  completion: { error in
                debugPrint(error as Any)
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
            defer { completion?(error) }
            guard let channel,
                  let members
            else { return }
            self.database.write {
                $0.createOrUpdate(channel: channel)
                for member in members {
                    $0.deleteMember(id: member.id, from: self.channelId)
                }
            }  completion: { error in
                debugPrint(error as Any)
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
            defer { completion?(error) }
            guard let channel,
                  let members
            else { return }
            self.database.write {
                $0.createOrUpdate(channel: channel)
                for member in members {
                    $0.deleteMember(id: member.id, from: self.channelId)
                }
            }  completion: { error in
                debugPrint(error as Any)
            }
        }
    }
    
    open func hide(completion: ((Error?) -> Void)? = nil) {
        channelOperator
            .hide
        { error in
            defer { completion?(error) }
            self.database.write {
                $0.deleteChannel(id: self.channelId)
            }  completion: { error in
                debugPrint(error as Any)
            }
        }
    }
    
    open func saveDraftMessage(_ message: NSAttributedString?) {
        self.database.write {
            $0.update(draft: message, channelId: self.channelId)
        }  completion: { error in
            debugPrint(error as Any)
        }
    }
}
