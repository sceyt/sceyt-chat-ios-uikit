//
//  ChannelProfileVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelProfileVM: NSObject {

    @Published open var event: Event?
    
    public private(set) var provider: ChannelProvider
    public private(set) var channel: ChatChannel

    open private(set) var attachments = Attachments()

    public var canEdit: Bool {
        channel.type != .direct && (channel.roleName == "owner" || channel.roleName == "admin")
    }
    
    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .fetch(predicate: .init(format: "id == %lld", channel.id))
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)])
                .relationshipKeyPathsFor(refreshing: [
                    #keyPath(ChannelDTO.peer.blocked),
                    #keyPath(ChannelDTO.peer.activityState),
                    #keyPath(ChannelDTO.peer.firstName),
                    #keyPath(ChannelDTO.peer.lastName),
                    #keyPath(ChannelDTO.peer.avatarUrl)
                ]),
            context: Config.database.viewContext) { $0.convert() }
    }()


    public required init(channel: ChatChannel) {
        self.channel = channel
        provider = ChannelProvider
            .init(channelId: channel.id)
        super.init()
    }

    open func startDatabaseObserver() {
        channelObserver.onDidChange = {[weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try channelObserver.startObserver()
        } catch {
            debugPrint("observer.startObserver", error)
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        guard let updatedChannel = channelObserver.item(at: .zero),
                updatedChannel.id == channel.id
        else { return }
        channel = updatedChannel
        event = .update
    }

    open var isGroupChannel: Bool {
        channel.type.isGroup
    }
    
    open var isActive: Bool {
        if channel.roleName == nil, channel.type == .private {
            return false
        }
//        if let peer = channel.peer {
//            if peer.blocked {
//                return false
//            }
//            if peer.activityState != .active {
//                return false
//            }
//        }
        return true
    }
    
    open var isUnsubscribedChannel: Bool {
        guard channel.type == .public else { return false }
        return channel.roleName == nil
    }

    // View Models
    open var mediaListViewModel: ChannelAttachmentListVM {
        Components.channelAttachmentListVM
            .init(channel: channel, attachmentTypes: ["image", "video"])
    }

    open var fileListViewModel: ChannelAttachmentListVM {
        Components.channelAttachmentListVM
            .init(channel: channel, attachmentTypes: ["file"])
    }

    open var linkListViewModel: ChannelAttachmentListVM {
        Components.channelAttachmentListVM
            .init(channel: channel,
                  attachmentTypes: ["link"])
    }
    
    open var voiceListViewModel: ChannelAttachmentListVM {
        Components.channelAttachmentListVM
            .init(channel: channel,
                  attachmentTypes: ["voice"])
    }
    
    open var previewer: AttachmentPreviewDataSource {
        AttachmentPreviewDataSource(channel: channel)
    }

    // MARK: Actions
    open func deleteAllMessages(
        forEveryone: Bool = false,
        completion: @escaping (Error?) -> Void
    ) {
        provider.deleteAllMessages(
            forEveryone: forEveryone,
            completion: completion
        )
    }

    open func leave(completion: @escaping (Error?) -> Void) {
        provider.leave(completion: completion)
    }

    open func blockAndLeave(completion: @escaping (Error?) -> Void) {
        provider.block(completion: completion)
    }

    open func block(completion: @escaping (Error?) -> Void) {
        switch channel.type {
        case .direct:
            if let userId = channel.peer?.id {
                chatClient.blockUsers(ids: [userId]) { (_, error) in
                    completion(error)
                }
            }
        case .public, .private:
            provider.block(completion: completion)
        }
    }
    
    open func unblock(completion: @escaping (Error?) -> Void) {
        switch channel.type {
        case .direct:
            if let userId = channel.peer?.id {
                chatClient.unblockUsers(ids: [userId]) { (_, error) in
                    completion(error)
                }
            }
        case .public, .private:
            provider.unblock(completion: completion)
        }
    }
    
    open func join(completion: ((Error?) -> Void)? = nil) {
        provider.join(completion: completion)
    }

    open func mute(timeInterval: TimeInterval, completion: ((Error?) -> Void)? = nil) {
        provider.mute(timeInterval: timeInterval, completion: completion)
    }

    open func unmute(completion: ((Error?) -> Void)? = nil) {
        provider.unmute(completion: completion)
    }

    open func hide(completion: ((Error?) -> Void)? = nil) {
        provider.hide(completion: completion)
    }
    
    open func delete(completion: ((Error?) -> Void)? = nil) {
        provider.delete(completion: completion)
    }

    open func update(uri: String? = nil,
                     subject: String? = nil,
                     label: String? = nil,
                     metadata: String? = nil,
                     avatarUrl: URL? = nil,
                     completion: @escaping (Error?) -> Void) {
        func updateChannel(uploadedAvatarUrl: URL?) {
            switch channel.type {
            case .public:
                provider.updatePublicChannel(
                    uri: uri ?? channel.uri ?? "",
                    subject: subject ?? channel.subject ?? "",
                    label: label,
                    metadata: metadata,
                    avatarUrl: uploadedAvatarUrl,
                    completion: completion
                )
            case .private:
                provider.updatePrivateChannel(
                    subject: subject ?? channel.subject ?? "",
                    label: label,
                    metadata: metadata,
                    avatarUrl: uploadedAvatarUrl,
                    completion: completion
                )
            case .direct:
                provider.updateDirectChannel(
                    label: label,
                    metadata: metadata,
                    completion: completion)
            }
        }

        if let avatarUrl = avatarUrl {
            chatClient.upload(fileUrl: avatarUrl) { _ in

            } completion: { url, _ in
                if let url = url {
                    instance(of: Storage.self)
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

public extension ChannelProfileVM {

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
