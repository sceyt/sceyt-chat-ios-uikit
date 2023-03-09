//
//  CreatePublicChannelVM.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class CreatePublicChannelVM {
    
    @Published open var event: Event!
    public let channelCreator: ChannelCreator
    
    private var channelQueryBuilder: ChannelListQuery.Builder
    private var channelQuery: ChannelListQuery!
    
    @Atomic private(set) var lastValidURI: (Bool, String)?
    @Atomic private var lastCheckableURI: String?
    required public init() {
        channelCreator = .init()
        channelQueryBuilder =  ChannelListQuery.Builder()
            .limit(1)
            .filterKey(.URI)
            .queryType(.equal)
            .type(.public)
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
                        (self.lastCheckableURI == query.query && error?.value == .queryInProgress) {
                        self.check(uri: self.lastCheckableURI!)
                    }
                }
            }
            if  let error = error {
                guard error.value != .queryInProgress
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
//        HUD.isLoading = true
        let metadataObj = try? ChannelMetadata(d: metadata).jsonString()
        func createChannel(uploadedAvatarUrl: URL?) {
            channelCreator.createPublicChannel(
                uri: uri,
                subject: subject,
                metadata: metadataObj,
                avatarUrl: uploadedAvatarUrl,
                members: nil) { [weak self] channel, error in
//                    HUD.isLoading = false
                    if let error = error {
                        self?.lastValidURI = (false, uri)
                        if  error.value == .channelAlreadyExists {
                            self?.event = .invalidURI(ChannelURIError.alreadyExist)
                        } else {
                            self?.event = .error(error)
                        }
                    } else {
//                        SMS.sendMessage(to: channel!.id, type: .createChannel)
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

public extension CreatePublicChannelVM {
    
    enum Event {
        case createdChannel(ChatChannel)
        case error(Error)
        case validURI
        case invalidURI(Error)
    }
}

public enum ChannelURIError: Error, LocalizedError {
    case range(min: Int, length: Int)
    case regex(String)
    case alreadyExist
    
    public var errorDescription: String? {
        switch self {
        case let .range(min: min, length: length):
            return L10n.Channel.Create.Uri.Error.range(min, length)
        case .regex(_):
            return L10n.Channel.Create.Uri.Error.regex
        case .alreadyExist:
            return L10n.Channel.Create.Uri.Error.exist
        }
    }
}

extension SceytError {
    
    var value: ErrorCode? {
        .init(rawValue: code)
    }
}

extension Error {
    
    var value: ErrorCode? {
        (self as? SceytError)?.value
    }
}
