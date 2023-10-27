//
//  ChannelProfileEditVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import SceytChat
import UIKit

open class ChannelProfileEditVM: NSObject {
    public var subscriptions = Set<AnyCancellable>()
    public private(set) var provider: ChannelProvider
    public private(set) var channel: ChatChannel
    
    private let channelQueryBuilder = ChannelListQuery.Builder()
        .limit(1)
        .filterKey(.URI)
        .search(.EQ)
        .types(["public"])
    
    @Published open var avatarUrl: String?
    
    private var _lastUri: String?
    @Published open var uri: String?
    @Published open var uriError: Error?
    @Published open var subject: String?
    @Published open var metadata: String?
    @Published open var isDoneEnabled = false
    
    public var event = PassthroughSubject<Event, Never>()
    
    var subjectPlaceholder: String? {
        switch channel.channelType {
        case .broadcast:
            return L10n.Channel.Subject.Channel.placeholder
        case .private:
            return L10n.Channel.Subject.Group.placeholder
        default:
            return nil
        }
    }
    
    var aboutPlaceholder: String? {
        L10n.Channel.Profile.about
    }
    
    func checkDoneButton() {
        isDoneEnabled = uriError == nil
            && !(subject ?? "").isEmpty
            && (uri != channel.uri
                || subject != channel.subject
                || metadata != channel.metadata
                || avatarUrl != channel.avatarUrl)
    }

    public required init(channel: ChatChannel) {
        self.channel = channel
        provider = Components.channelProvider.init(channelId: channel.id)
        avatarUrl = channel.avatarUrl
        uri = channel.uri
        subject = channel.subject
        metadata = channel.metadata
        super.init()
        
        $avatarUrl
            .combineLatest($uri, $subject, $metadata)
            .combineLatest($uriError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkDoneButton()
            }
            .store(in: &subscriptions)
        
        $uri
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, let uri = $0 else { return }
                check(uri: uri)
            }.store(in: &subscriptions)
    }
    
    open var canShowURI: Bool {
        channel.channelType == .broadcast
    }
    
    open func update(completion: @escaping (Error?) -> Void) {
        func updateChannel(uploadedAvatarUrl: String?) {
            provider
                .update(
                    uri: uri ?? channel.uri,
                    subject: subject ?? channel.subject ?? "",
                    metadata: metadata ?? channel.metadata,
                    avatarUrl: uploadedAvatarUrl,
                    completion: completion)
        }
        
        if let avatarUrlString = avatarUrl,
           let avatarUrl = URL(string: avatarUrlString)
        {
            if avatarUrl.isFileURL,
               FileManager.default.fileExists(atPath: avatarUrl.path)
            {
                chatClient.upload(fileUrl: avatarUrl) { _ in
                    
                } completion: { url, _ in
                    if let url = url {
                        Components.storage
                            .storeFile(originalUrl: url,
                                       file: avatarUrl,
                                       deleteFromSrc: true)
                    }
                    updateChannel(uploadedAvatarUrl: url?.absoluteString)
                }
            } else {
                updateChannel(uploadedAvatarUrl: channel.avatarUrl)
            }
        } else {
            updateChannel(uploadedAvatarUrl: nil)
        }
    }
    
    func check(uri: String) {
        if uri == channel.uri {
            return event.send(.validURI)
        }
        if case .failure(let error) = Validator.isValid(URI: uri) {
            return event.send(.invalidURI(error))
        }
        // prevent spaming BE while typing
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(query(uri:)), object: _lastUri)
        _lastUri = uri
        perform(#selector(query(uri:)), with: uri, afterDelay: 0.3)
    }
    
    @objc
    func query(uri: String) {
        Task {
            let (_, channels, error) = await channelQueryBuilder
                .query(uri)
                .build()
                .loadNext()
            if let error = error {
                log.debug(error.localizedDescription)
                guard error.sceytChatCode == .queryInProgress
                else { return }
                uriError = error
                event.send(.error(error))
            } else if let channels = channels, !channels.isEmpty {
                uriError = error
                event.send(.invalidURI(ChannelURIError.alreadyExist))
            } else {
                uriError = nil
                event.send(.validURI)
            }
        }
    }
}

public extension ChannelProfileEditVM {
    enum Event {
        case invalidURI(Error), validURI, error(Error)
    }
}
