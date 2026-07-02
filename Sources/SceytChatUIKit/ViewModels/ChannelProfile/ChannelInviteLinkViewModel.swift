//
//  ChannelInviteLinkViewModel.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class ChannelInviteLinkViewModel: NSObject {

    public var channel: ChatChannel
    public var channelInviteKey: SCTChannelInviteKey?
    
    @Published public var event: Event?
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var showPreviousMessages: Bool = false

    public var inviteLink: String? {
        guard let config = SceytChatUIKit.shared.config.channelInviteDeepLinkConfig else {
            return nil
        }
        return config.constructInviteLink(for: channel.uri)
    }
    
    public var isPublicChannel: Bool {
        return channel.channelType == .broadcast
    }

    public required init(channel: ChatChannel) {
        self.channel = channel
        super.init()
    }
    
    public func loadInviteLinkData() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        SceytChatUIKit.shared.chatClient.getChannelInviteKey(
            channelId: "\(channel.id)",
            key: channel.uri
        ) { [weak self] key, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error
                } else if let key = key {
                    self?.channelInviteKey = key
                    self?.showPreviousMessages = key.accessPriorHistory
                }
            }
        }
    }
    
    // MARK: - Reset Link
    
    public func updateShowPreviousMessages(_ value: Bool) {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        guard let inviteKey = channelInviteKey else { return }
        
        SceytChatUIKit.shared.chatClient.updateChannelInviteKey(
            channelId: "\(channel.id)",
            key: inviteKey.key,
            maxUses: Int(inviteKey.maxUses),
            expiresAt: TimeInterval(inviteKey.expiresAt),
            accessPriorHistory: value
        ) { [weak self] inviteKey, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                } else if let inviteKey = inviteKey {
                    self.channelInviteKey = inviteKey
                    self.showPreviousMessages = inviteKey.accessPriorHistory
                } else {
                    self.showPreviousMessages = value
                }
            }
        }
    }
    
    public func resetLink() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        SceytChatUIKit.shared.chatClient.regenerateChannelInviteKey(
            channelId: "\(channel.id)",
            key: channel.uri,
            deletePermanently: true
        ) { [weak self] newKey, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                } else if let newKey = newKey {
                    // The regenerated primary key becomes the channel's invite URI,
                    // so persist it to the DTO. Non-primary keys are separate invite
                    // links and must not overwrite channel.uri.
                    SceytChatUIKit.shared.database.write { [weak self] in
                        guard let self = self else { return }
                        if newKey.isPrimary {
                            let (dto, _) = ChannelDTO.fetchOrCreate(id: channel.id, context: $0)
                            dto.uri = newKey.key
                        }
                    } completion: { [weak self] error in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if let error = error {
                                self.error = error
                            } else {
                                // Update in-memory channel on the main thread so the
                                // UI (inviteLink derives from channel.uri) reflects it.
                                if newKey.isPrimary {
                                    self.channel.uri = newKey.key
                                }
                                self.channelInviteKey = newKey
                                self.event = .reloadData
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func refreshChannelFromDB() {
        self.channel = (try? SceytChatUIKit.shared.database.read { context in
            ChannelDTO.fetch(id: self.channel.id, context: context)?.convert()
        }.get()) ?? channel
    }
}

public extension ChannelInviteLinkViewModel {
    enum Event {
        case reloadData
    }
}
