//
//  CreatePublicChannelVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat
import Combine

open class CreatePublicChannelVM {
    
    @Published open var event: Event!
    public let channelCreator: ChannelCreator
    
    private var channelQueryBuilder: ChannelListQuery.Builder
    private var channelQuery: ChannelListQuery!
    
    @Atomic private(set) var lastValidURI: (Bool, String)?
    @Atomic private var lastCheckableURI: String?
    required public init() {
        channelCreator = Components.channelCreator.init()
        channelQueryBuilder =  ChannelListQuery.Builder()
            .limit(1)
            .filterKey(.URI)
            .search(.EQ)
            .types(["public"])
    }
    
    func check(uri: String) {
        lastCheckableURI = uri
        if channelQuery != nil, channelQuery.loading {
            return
        }
        switch Validator.isValid(URI: uri) {
        case .success:
            break
        case .failure(let error):
            lastValidURI = (false, uri)
            event = .invalidURI(error)
            return
        }
        channelQuery =
        channelQueryBuilder
            .query(uri)
            .build()
       
        Task {
            let (query, channels, error) = await channelQuery.loadNext()
            defer {
                DispatchQueue.main.async {[weak self] in
                    guard let self = self else { return }
                    if (self.lastCheckableURI != nil && query.query != self.lastCheckableURI) ||
                        (self.lastCheckableURI == query.query && error?.sceytChatCode == .queryInProgress) {
                        self.check(uri: self.lastCheckableURI!)
                    }
                }
            }
            if  let error = error {
                guard error.sceytChatCode == .queryInProgress
                else { return }
                lastValidURI = (false, uri)
                event = .error(error)
            } else if let channels = channels, !channels.isEmpty {
                lastValidURI = (false, uri)
                event = .invalidURI(ChannelURIError.alreadyExist)
            } else {
                lastValidURI = (true, uri)
                event = .validURI
            }
        }
    }
    
    func create(uri: String,
                     subject: String,
                     metadata: String?,
                     image: UIImage?) {
//        let metadataObj = try? ChannelMetadata(d: metadata).jsonString()
        let subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = metadata?.trimmingCharacters(in: .whitespacesAndNewlines)

        func createChannel(uploadedAvatarUrl: URL?) {
            
            channelCreator
                .create(
                    type: SceytChatUIKit.shared.config.broadcastChannel,
                    uri: uri,
                    subject: subject,
                    metadata: metadata,
                    avatarUrl: uploadedAvatarUrl?.absoluteString)
            { [weak self] channel, error in
                    if let error = error {
                        self?.lastValidURI = (false, uri)
                        if  error.sceytChatCode == .channelAlreadyExists {
                            self?.event = .invalidURI(ChannelURIError.alreadyExist)
                        } else {
                            self?.event = .error(error)
                        }
                    } else {
                        self?.event = .createdChannel(channel!)
                    }
                }
        }
        
        if let image, let jpeg = try? Components.imageBuilder.init(image: image).resize(max: SceytChatUIKit.shared.config.maximumImageSize).jpegData() {
            if let fileUrl = Components.storage.storeInTemporaryDirectory(data: jpeg, ext: "jpeg") {
                
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

public extension CreatePublicChannelVM {
    
    enum Event {
        case createdChannel(ChatChannel)
        case error(Error)
        case validURI
        case invalidURI(Error)
    }
}

