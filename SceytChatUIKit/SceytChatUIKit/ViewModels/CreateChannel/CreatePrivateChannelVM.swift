//
//  CreatePrivateChannelVM.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class CreatePrivateChannelVM {
    
    @Published public var event: Event?
    public private(set) var users = [ChatUser]()
    public let channelCreator: ChannelCreator
    
    public required init(users: [ChatUser]) {
        self.users = users
        channelCreator = .init()
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
        func createChannel(uploadedAvatarUrl: URL?) {
            let members = users.map {
                Member.Builder(id: $0.id).build()
            }
            
            let metadataObj = try? ChannelMetadata(d: metadata).jsonString()
            channelCreator.createPrivateChannel(
                subject: subject,
                metadata: metadataObj,
                avatarUrl: uploadedAvatarUrl,
                members: members) { [weak self] channel, error in
                    if let error = error {
                        self?.event = .createChannelError(error)
                    } else {
                        self?.event = .createdChannel(channel!)
                    }
                }
        }
        
        if let image, let jpeg = try? Components.imageBuilder.init(image: image).resize(max: Config.maximumImageSize).jpegData() {
            if let fileUrl = Storage.storeInTemporaryDirectory(data: jpeg, ext: "jpeg") {
                
                ChatClient.shared.upload(fileUrl: fileUrl) { _ in
                    
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

public extension CreatePrivateChannelVM {
    
    enum Event {
        case createChannelError(Error)
        case createdChannel(ChatChannel)
    }
    
}

