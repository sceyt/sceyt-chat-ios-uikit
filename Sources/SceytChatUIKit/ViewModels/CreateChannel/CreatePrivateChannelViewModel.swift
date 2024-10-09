//
//  CreatePrivateChannelViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat
import Combine

open class CreatePrivateChannelViewModel {
    
    @Published public var event: Event?
    public private(set) var users = [ChatUser]()
    public let channelCreator: ChannelCreator
    
    public required init(users: [ChatUser]) {
        self.users = users
        channelCreator = Components.channelCreator.init()
    }

    public var numberOfUser: Int {
        users.count
    }
    
    open func user(at indexPath: IndexPath) -> ChatUser? {
        guard indexPath.section == 0,
              users.indices.contains(indexPath.row)
        else { return nil }
        return users[indexPath.row]
    }
    
    open func create(subject: String,
                metadata: String?,
                image: UIImage?) {
        let subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = metadata?.trimmingCharacters(in: .whitespacesAndNewlines)
        func createChannel(uploadedAvatarUrl: URL?) {
            let members = users.map {
                Member.Builder(id: $0.id).build()
            }
            
            let metadataObj = try? ChannelMetadata(d: metadata).jsonString()
            
            channelCreator
                .create(
                    type: SceytChatUIKit.shared.config.channelTypesConfig.group,
                    subject: subject,
                    metadata: metadataObj,
                    avatarUrl: uploadedAvatarUrl?.absoluteString,
                    userIds: users.map { $0.id })
            { [weak self] channel, error in
                    if let error = error {
                        self?.event = .createChannelError(error)
                    } else {
                        self?.event = .createdChannel(channel!)
                    }
                }
        }
        
        if let image, let jpeg = try? Components.imageBuilder.init(image: image).resize(max: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.dimensionThreshold).jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality) {
            if let fileUrl = Components.storage.storeInTemporaryDirectory(data: jpeg, ext: "jpeg") {
                
                SceytChatUIKit.shared.chatClient.upload(fileUrl: fileUrl) { _ in
                    
                } completion: { url, _ in
                    if let url = url {
                        Storage
                            .storeFile(originalUrl: url,
                                       file: fileUrl,
                                       deleteFromSrc: true)
                    }
                    createChannel(uploadedAvatarUrl: url)
                }
            }
        } else {
            createChannel(uploadedAvatarUrl: nil)
        }
    }
    
}

public extension CreatePrivateChannelViewModel {
    
    enum Event {
        case createChannelError(Error)
        case createdChannel(ChatChannel)
    }
    
}

