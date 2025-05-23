//
//  ChannelProfileViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class ChannelProfileViewModel: NSObject {

    @Published public var event: Event?
    
    public private(set) var channelProvider: ChannelProvider
    public private(set) var userProvider: UserProvider
    public private(set) var channel: ChatChannel
    public private(set) var appearance: MessageCell.Appearance
    open var channelType: ChatChannel.ChannelType { channel.channelType }
    open var autoDelete: TimeInterval = 0

    open private(set) var attachments = Attachments()

    public var isOwner: Bool { channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.owner }
    public var isAdmin: Bool { channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.admin }
    public var canEdit: Bool { !channel.isDirect && (isOwner || isAdmin) }

    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .fetch(predicate: .init(format: "id == %lld", channel.id))
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)]),
            context: SceytChatUIKit.shared.database.viewContext) { $0.convert() }
    }()


    public required init(channel: ChatChannel, appearance: MessageCell.Appearance) {
        self.channel = channel
        self.appearance = appearance
        channelProvider = Components.channelProvider
            .init(channelId: channel.id)
        userProvider = Components.userProvider
            .init()
        super.init()
    }

    open func startDatabaseObserver() {
        channelObserver.onDidChange = {[weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try channelObserver.startObserver(fetchedAllObjects: false)
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        guard let updatedChannel = channelObserver.item(at: .zero),
                updatedChannel.id == channel.id
        else { return }
        channel = updatedChannel
        event = .update
    }

    open var isDirectChannel: Bool {
        channel.channelType == .direct
    }
    
    open var isActive: Bool {
        if channel.userRole == nil, channel.channelType == .group {
            return false
        }
        return true
    }
    
    open var isUnsubscribedChannel: Bool {
        guard channel.channelType == .broadcast
        else { return false }
        return channel.userRole == nil
    }

    // View Models
    open var mediaListViewModel: ChannelAttachmentListViewModel {
        Components.channelAttachmentListViewModel
            .init(channel: channel,
                  attachmentTypes: ["image", "video"],
                  appearance: appearance)
    }

    open var fileListViewModel: ChannelAttachmentListViewModel {
        Components.channelAttachmentListViewModel
            .init(channel: channel, 
                  attachmentTypes: ["file"],
                  appearance: appearance)
    }

    open var linkListViewModel: ChannelAttachmentListViewModel {
        Components.channelAttachmentListViewModel
            .init(channel: channel,
                  attachmentTypes: ["link"],
                  appearance: appearance)
    }
    
    open var voiceListViewModel: ChannelAttachmentListViewModel {
        Components.channelAttachmentListViewModel
            .init(channel: channel,
                  attachmentTypes: ["voice"],
                  appearance: appearance)
    }
    
    open var previewer: AttachmentPreviewDataSource {
        AttachmentPreviewDataSource(channel: channel, ascending: true)
    }

    // MARK: Actions
    open func deleteAllMessages(
        forEveryone: Bool = false,
        completion: @escaping (Error?) -> Void
    ) {
        channelProvider.deleteAllMessages(
            forEveryone: forEveryone,
            completion: completion
        )
    }

    open func leave(completion: @escaping (Error?) -> Void) {
        channelProvider.leave(completion: completion)
    }

    open func blockAndLeave(completion: @escaping (Error?) -> Void) {
        channelProvider.block(completion: completion)
    }

    open func block(completion: @escaping (Error?) -> Void) {
        switch channel.channelType {
        case .direct:
            if let userIds = channel.members?.compactMap({ $0.id == SceytChatUIKit.shared.currentUserId ? nil : $0.id }) {
                userProvider.blockUsers(ids: userIds) { error in
                    completion(error)
                }
            }
        default:
            channelProvider.block(completion: completion)
        }
    }
    
    open func unblock(completion: @escaping (Error?) -> Void) {
        switch channel.channelType {
        case .direct:
            if let userIds = channel.members?.compactMap({ $0.id == SceytChatUIKit.shared.currentUserId ? nil : $0.id }) {
                userProvider.unblockUsers(ids: userIds) { error in
                    completion(error)
                }
            }
        default:
            channelProvider.unblock(completion: completion)
        }
    }
    
    open func join(completion: ((Error?) -> Void)? = nil) {
        channelProvider.join(completion: completion)
    }

    open func mute(timeInterval: TimeInterval, completion: ((Error?) -> Void)? = nil) {
        channelProvider.mute(timeInterval: timeInterval, completion: completion)
    }

    open func unmute(completion: ((Error?) -> Void)? = nil) {
        channelProvider.unmute(completion: completion)
    }

    open func hide(completion: ((Error?) -> Void)? = nil) {
        channelProvider.hide(completion: completion)
    }
    
    open func delete(completion: ((Error?) -> Void)? = nil) {
        channelProvider.delete(completion: completion)
    }

    open func update(uri: String? = nil,
                     subject: String? = nil,
                     label: String? = nil,
                     metadata: String? = nil,
                     avatarUrl: URL? = nil,
                     completion: @escaping (Error?) -> Void) {
        func updateChannel(uploadedAvatarUrl: URL?) {
            channelProvider
                .update(
                    uri: uri ?? channel.uri,
                    subject: subject ?? channel.subject ?? "",
                    metadata: metadata,
                    avatarUrl: uploadedAvatarUrl?.absoluteString,
                    completion: completion)
        }

        if let avatarUrl = avatarUrl {
            SceytChatUIKit.shared.chatClient.upload(fileUrl: avatarUrl) { _ in

            } completion: { url, _ in
                if let url = url {
                    Components.storage
                        .storeFile(originalUrl: url,
                                   file: avatarUrl,
                                   deleteFromSrc: true)
                }
                updateChannel(uploadedAvatarUrl: url)
            }
        } else {
            updateChannel(uploadedAvatarUrl: nil)
        }
    }
}

public extension ChannelProfileViewModel {

    struct AttachmentItem {
        public let url: URL
        public let title: String?
        public let metadata: String?
        public let date: Date
        public var size: UInt
    }

    struct Attachments {
        public var medias: [AttachmentItem] = []
        public var files: [AttachmentItem] = []
        public var links: [AttachmentItem] = []
    }
    
    enum Event {
        case update
    }
}
