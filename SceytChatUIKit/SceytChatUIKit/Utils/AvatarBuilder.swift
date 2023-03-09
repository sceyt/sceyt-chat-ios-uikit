//
//  AvatarBuilder.swift
//  SceytChatUIKit
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

open class AvatarBuilder {

    public static var avatarDefaultSize = CGSize(width: 60 * UIScreen.main.traitCollection.displayScale,
                                          height: 60 * UIScreen.main.traitCollection.displayScale)

    open class func buildAvatar(display: String, appearance: InitialsBuilderAppearance?)
    -> UIImage {
        if let appearance = appearance {
            return Components.initialsBuilder.build(appearance: appearance, display: display)
        }
        return Components.initialsBuilder.build(display: display)
    }

    open class func loadAvatar(into view: ImagePresentable,
                               for builder: AvatarBuildable,
                               defaultImage: UIImage? = nil,
                               size: CGSize = AvatarBuilder.avatarDefaultSize)
    -> Cancellable? {

        
        let url = builder.imageUrl
        let isUpdated = url != nil ? (Storage.fileUrl(for: url!) == nil) : false
        var foundThumbnail = false
        if let url {
            let thumbnailUrl = thumbnailUrl(builder: builder, size: size)
            if let image = storedImage(for: thumbnailUrl) {
                view.image = image
                foundThumbnail = true
            } else if let image = storedImage(for: url) {
                if let resized = try? Components.imageBuilder.init(image: image).resize(max: size.maxSide) {
                    view.image = resized.uiImage
                    if let jpeg = resized.jpegData() {
                        store(image: jpeg, fileUrl: thumbnailUrl)
                    }
                    foundThumbnail = true
                }
            }
        }
        if foundThumbnail, !isUpdated {
            return nil
        }
        
        if !foundThumbnail {
            if let defaultImage {
                view.image = defaultImage
            } else if let avatar = builder.defaultAvatar {
                view.image = avatar
            } else {
                let displayName = builder.displayName
                view.image = buildAvatar(display: displayName, appearance: builder.appearance)
            }
        }

        if let url = url {
            return download(
                url: url,
                builder: builder,
                size: size
            ) {[weak view] image in
                if let image = image {
                    view?.image = image
                }
            }
        }
        return nil
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
                        if let jpeg = resized.jpegData() {
                            let thumbnailUrl = thumbnailUrl(builder: builder, size: size)
                            store(image: jpeg, fileUrl: thumbnailUrl)
                        }
                    }
                    DispatchQueue.main.async { completion(image) }
                }
            })
    }

    open class func store(fileUrl: URL, originalUrl: URL) -> URL? {
        Storage.storeFile(originalUrl: originalUrl, file: fileUrl, deleteFromSrc: true)
    }
    
    open class func store(image: Data, fileUrl: URL) {
        Storage.storeData(image, filePath: fileUrl.path)
    }

    open class func storedImage(for url: URL) -> UIImage? {
        if let url = Storage.fileUrl(for: url) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
    
    open class func thumbnailUrl(
        builder: AvatarBuildable,
        size: CGSize
    ) -> URL {
        let ext = "_\(Int(size.width))x\(Int(size.height))"
        return Storage.storingKey.storingFileFullUrl(filename: builder.hashString + ext)
    }
    
    open class func deleteThumbnail(
        builder: AvatarBuildable,
        size: CGSize? = nil
    ) {
        if let size {
            let ext = "_\(Int(size.width))x\(Int(size.height))"
            let url = Storage.storingKey.storingFileFullUrl(filename: builder.hashString + ext)
            try? FileManager.default.removeItem(at: url)
        } else {
            let url = Storage.storingKey.storingFileFullUrl(filename: builder.hashString)
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.contentsOfDirectory(atPath: directory.path)
                .forEach({ name in
                    if name.hasPrefix(builder.hashString) {
                        let url = Storage.storingKey.storingFileFullUrl(filename: name)
                        try? FileManager.default.removeItem(at: url)
                    }
                })
        }
    }
}

extension UIImageView: ImagePresentable {

}

extension ChatChannel: AvatarBuildable {
    
    public var hashString: String {
        "\(id)"
    }
    
    public var imageUrl: URL? {
        if let peer = peer {
            return peer.avatarUrl
        }
        return avatarUrl
    }

    public var displayName: String {
        Formatters.channelDisplayName.format(self)
    }

    public var defaultAvatar: UIImage? {
        if type == .direct {
            return peer?.defaultAvatar
        }
        switch type {
        case .public:
            return Config.chatChannelDefaultAvatar.public
        case .private:
            return Config.chatChannelDefaultAvatar.private
        case .direct:
            return Config.chatChannelDefaultAvatar.direct
        }
    }
    
    public var appearance: InitialsBuilderAppearance? {
        if Config.chatChannelDefaultAvatar.generateFromInitials {
            return Config.chatChannelDefaultAvatar.initialsBuilderAppearance
        }
        return nil
    }
}

extension ChatUser: AvatarBuildable {
    
    public var hashString: String {
        "\(id)"
    }
    
    public var imageUrl: URL? {
        avatarUrl
    }

    public var displayName: String {
        Formatters.userDisplayName.format(self)
    }
    
    public var defaultAvatar: UIImage? {
        switch activityState {
        case .active:
            return Config.chatUserDefaultAvatar.activeState
        case .inactive:
            return Config.chatUserDefaultAvatar.inactiveState
        case .deleted:
            return Config.chatUserDefaultAvatar.deletedState
        }
    }
    
    public var appearance: InitialsBuilderAppearance? {
        if Config.chatUserDefaultAvatar.generateFromInitials {
            return Config.chatUserDefaultAvatar.initialsBuilderAppearance
        }
        return nil
    }
}
