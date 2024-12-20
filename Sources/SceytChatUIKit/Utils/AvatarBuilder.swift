//
//  AvatarBuilder.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

public protocol AvatarBuildable {
    var hashString: String { get }
    var imageUrl: URL? { get }
    var displayName: String { get }
    var defaultAvatar: UIImage? { get }
    var appearance: InitialsBuilderAppearance? { get }
}

public extension AvatarBuildable {
    
    var fileName: String {
        if let imageUrl {
            return imageUrl.encoded
        }
        return hashString
    }
}

open class AvatarBuilder {

    public static var avatarDefaultSize = CGSize(width: 60 * UIScreen.main.traitCollection.displayScale,
                                          height: 60 * UIScreen.main.traitCollection.displayScale)
    private static var cache = {
        $0.countLimit = 15
        return $0
    }(Cache<String, [String: UIImage]>())

    open class func buildAvatar(display: String, appearance: InitialsBuilderAppearance?)
    -> UIImage {
        if let appearance = appearance {
            return Components.initialsBuilder.build(appearance: appearance, display: display)
        }
        return Components.initialsBuilder.build(display: display)
    }

    open class func loadAvatar(into view: ImagePresentable,
                               for builder: AvatarBuildable,
                               appearance: InitialsBuilderAppearance? = nil,
                               defaultImage: UIImage? = nil,
                               size: CGSize = avatarDefaultSize,
                               preferMemCache: Bool = true,
                               completion: ((UIImage?) -> Void)? = nil
    )
    -> Cancellable? {
        func setDefault() {
            if let defaultImage {
                view.image = defaultImage
            } else if let avatar = builder.defaultAvatar {
                view.image = avatar
            } else {
                let displayName = builder.displayName
                view.image = buildAvatar(display: displayName, appearance: appearance ?? builder.appearance)
            }
        }
        
        let url = builder.imageUrl
        
        guard let url else {
            setDefault()
            return nil
        }
        
        let key = "\(url.absoluteString)\(size)"
        
        if preferMemCache, let image = cache[builder.hashString]?[key] {
            view.image = image
            return nil
        }
        
        func setImage(_ image: UIImage?) {
            view.image = image
            if cache[builder.hashString] == nil {
                cache[builder.hashString] = [:]
            }
            cache[builder.hashString]?[key] = image
            completion?(image)
        }
        
        var foundThumbnail = false
        
        let thumbnailUrl = thumbnailUrl(builder: builder, size: size)
        if let image = storedImage(for: thumbnailUrl) {
            setImage(image)
            foundThumbnail = true
        } else if
            let image = storedImage(for: url),
            let resized = try? Components.imageBuilder.init(image: image).resize(max: size.maxSide) {
                setImage(resized.uiImage)
            if let jpeg = resized.jpegData(compressionQuality: SceytChatUIKit.shared.config.avatarResizeConfig.compressionQuality) {
                    store(image: jpeg, fileUrl: thumbnailUrl)
                }
            foundThumbnail = true
        }
        
        if foundThumbnail {
            if Components.storage.fileUrl(for: url) != nil {
                return nil
            }
        } else {
            setDefault()
        }

        return download(
            url: url,
            builder: builder,
            size: size
        ) { image in
            if let image {
                cache.removeValue(forKey: builder.hashString)
                deleteThumbnail(builder: builder)
                setImage(image)
            }
        }
    }
    
    open class func loadAvatar(for builder: AvatarBuildable,
                               appearance: InitialsBuilderAppearance? = nil,
                               defaultImage: UIImage? = nil,
                               size: CGSize = SceytChatUIKit.Components.avatarBuilder.avatarDefaultSize,
                               preferMemCache: Bool = true,
                               avatar block: @escaping (UIImage?) -> Void
    ) -> Cancellable? {
        
        class Avatar: ImagePresentable {
            var image: UIImage? {
                didSet {
                    DispatchQueue.main.async {
                        self.block?(self.image)
                    }
                    
                }
            }
            var block: ((UIImage?) -> Void)?
        }
        let avatarPresentable = Avatar()
        avatarPresentable.block = block
        return loadAvatar(
            into: avatarPresentable,
            for: builder,
            appearance: appearance,
            defaultImage: defaultImage,
            size: size,
            preferMemCache: preferMemCache)
    }

    private class func download(
        url: URL,
        builder: AvatarBuildable,
        size: CGSize,
        completion: @escaping (UIImage?) -> Void) -> Cancellable? {
        Session
            .download(url: url,
                      completion: { result in
                switch result {
                case .failure:
                    DispatchQueue.main.async { completion(nil) }
                case .success(let responseUrl):
                    guard let storedUrl = store(fileUrl: responseUrl, originalUrl: url) else { return }
                    var image = UIImage(contentsOfFile: storedUrl.path)
                    if let img = image,
                       let resized = try? Components.imageBuilder.init(image: img).resize(max: size.maxSide) {
                        image = resized.uiImage
                        if let jpeg = resized.jpegData(compressionQuality: SceytChatUIKit.shared.config.avatarResizeConfig.compressionQuality) {
                            let thumbnailUrl = thumbnailUrl(builder: builder, size: size)
                            store(image: jpeg, fileUrl: thumbnailUrl)
                        }
                    }
                    DispatchQueue.main.async { completion(image) }
                }
            })
    }
    
    open class func store(fileUrl: URL, originalUrl: URL) -> URL? {
        Components.storage.storeFile(originalUrl: originalUrl, file: fileUrl, deleteFromSrc: true)
    }
    
    open class func store(image: Data, fileUrl: URL) {
        Components.storage.storeData(image, filePath: fileUrl.path)
    }

    open class func storedImage(for url: URL) -> UIImage? {
        if let url = Components.storage.fileUrl(for: url) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
    
    open class func thumbnailUrl(
        builder: AvatarBuildable,
        size: CGSize
    ) -> URL {
        let ext = "_\(Int(size.width))x\(Int(size.height))"
        return Components.storage.storingKey.storingFileFullUrl(filename: builder.fileName + ext)
    }
    
    open class func deleteThumbnail(
        builder: AvatarBuildable,
        size: CGSize? = nil
    ) {
        if let size {
            let ext = "_\(Int(size.width))x\(Int(size.height))"
            let url = Components.storage.storingKey.storingFileFullUrl(filename: builder.fileName + ext)
            try? FileManager.default.removeItem(at: url)
        } else {
            let url = Components.storage.storingKey.storingFileFullUrl(filename: builder.fileName)
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.contentsOfDirectory(atPath: directory.path)
                .forEach({ name in
                    if name != builder.fileName,
                        name.hasPrefix(builder.fileName) {
                        let url = Components.storage.storingKey.storingFileFullUrl(filename: name)
                        try? FileManager.default.removeItem(at: url)
                    }
                })
        }
    }
}

extension ChatChannel: AvatarBuildable {
    
    public var hashString: String {
        if isDirect, let peer = peer {
            return peer.hashString
        }
        return "\(id)"
    }
    
    public var imageUrl: URL? {
        if isDirect, let peer = peer {
            return URL(string: peer.avatarUrl)
        } else if let member = members?.first, isSelfChannel {
            return URL(string: member.avatarUrl ?? SceytChatUIKit.shared.chatClient.user.avatarUrl)
        }
        return URL(string: avatarUrl)
    }
#warning("To-Do: Remove")
    public var displayName: String {
        SceytChatUIKit.shared.formatters.channelNameFormatter.format(self)
    }

    public var defaultAvatar: UIImage? {
        if case .image(let image) = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider.provideVisual(for: self) {
            return image
        }
        return nil
    }
    
    public var appearance: InitialsBuilderAppearance? {
        if case .initialsAppearance(let appearance) = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider.provideVisual(for: self) {
            return appearance
        }
        return nil
    }
}

extension ChatUser: AvatarBuildable {
    
    public var hashString: String {
        return "\(id)"
    }
    
    public var imageUrl: URL? {
        URL(string: avatarUrl)
    }
#warning("To-Do: Consider to remove")
    public var displayName: String {
        SceytChatUIKit.shared.formatters.userNameFormatter.format(self)
    }
    
    public var defaultAvatar: UIImage? {
        if case .image(let image) = SceytChatUIKit.shared.visualProviders.userAvatarProvider.provideVisual(for: self) {
            return image
        }
        return nil
    }

#warning("To-Do: Consider to remove")
    public var appearance: InitialsBuilderAppearance? {
        if case .initialsAppearance(let appearance) = SceytChatUIKit.shared.visualProviders.userAvatarProvider.provideVisual(for: self) {
            return appearance
        }
        return nil
    }
}
