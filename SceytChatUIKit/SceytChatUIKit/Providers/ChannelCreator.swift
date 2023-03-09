//
//  ChannelCreator.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelCreator: Provider {
    
    public required override init() {
        super.init()
    }
    
    open func createPrivateChannel(
        subject: String,
        label: String? = nil,
        metadata: String? = nil,
        avatarUrl: URL? = nil,
        members: [Member]? = nil,
        completion: ((ChatChannel?, Error?) -> Void)? = nil) {
            PrivateChannel
                .create(
                    subject: subject,
                    members: members,
                    label: label,
                    metadata: metadata,
                    avatarUrl: avatarUrl
                ) { channel, error in
                    guard let channel = channel
                    else {
                        completion?(nil, error)
                        return
                    }
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    }  completion: { error in
                        debugPrint(error as Any)
                        completion?(.init(channel: channel), nil)
                    }
                }
        }
    
    open func createPublicChannel(
        uri: String,
        subject: String,
        label: String? = nil,
        metadata: String? = nil,
        avatarUrl: URL? = nil,
        members: [Member]? = nil,
        completion: ((ChatChannel?, Error?) -> Void)? = nil) {
            PublicChannel
                .create(
                    uri: uri,
                    subject: subject,
                    members: members,
                    label: label,
                    metadata: metadata,
                    avatarUrl: avatarUrl
                ) { channel, error in
                    guard let channel = channel
                    else {
                        completion?(nil, error)
                        return
                    }
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    }  completion: { error in
                        debugPrint(error as Any)
                        completion?(.init(channel: channel), nil)
                    }
                }
        }
    
    open func createDirectChannel(
        peer: UserId,
        label: String? = nil,
        metadata: String? = nil,
        completion: ((ChatChannel?, Error?) -> Void)? = nil) {
            DirectChannel
                .create(peer: peer,
                        label: label,
                        metadata: metadata
                ) { channel, error in
                    guard let channel = channel
                    else {
                        completion?(nil, error)
                        return
                    }
                    self.database.write {
                        $0.createOrUpdate(channel: channel)
                    }  completion: { error in
                        debugPrint(error as Any)
                        completion?(.init(channel: channel), nil)
                    }
                }
        }
}
