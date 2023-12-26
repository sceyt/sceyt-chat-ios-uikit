//
//  LinkMetadata.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.12.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class LinkMetadata {

    public let url: URL
    open var title: String?
    open var summary: String?
    open var creator: String?
    open var icon: UIImage?
    open var iconUrl: URL?
    open var image: UIImage?
    open var imageUrl: URL?
    
    public required init(url: URL) {
        self.url = url
    }

    public init(url: URL,
                title: String? = nil,
                summary: String? = nil,
                creator: String? = nil,
                icon: UIImage? = nil,
                iconUrl: URL? = nil,
                image: UIImage? = nil,
                imageUrl: URL? = nil)
    {
        self.url = url
        self.title = title
        self.summary = summary
        self.creator = creator
        self.icon = icon
        self.iconUrl = iconUrl
        self.image = image
        self.imageUrl = imageUrl
    }
    
    public convenience init(dto: LinkMetadataDTO) {
        self.init(
            url: dto.url,
            title: dto.title,
            summary: dto.summary,
            creator: dto.creator,
            iconUrl: dto.iconUrl,
            imageUrl: dto.imageUrl
        )
    }

    open func storeImages() {
        var hasImage: Bool { image != nil || icon != nil }
        if hasImage, let filename = Crypto.hash(value: url.absoluteString) {
            if let icon = icon, let jpeg = icon.jpegData(compressionQuality: Config.jpegDataCompressionQuality) {
                Components.storage.storeData(jpeg, filename: "icon_" + filename)
                
            }
            if let image = image, let jpeg = image.jpegData(compressionQuality: Config.jpegDataCompressionQuality) {
                Components.storage.storeData(jpeg, filename: "image_" + filename)
            }
        }
    }

    open func loadImages() {
        if let filename = Crypto.hash(value: url.absoluteString) {
            if let path = Storage
                .filePath(filename: "icon_" + filename)
            {
                icon = UIImage(contentsOfFile: path)
            }
            if let path = Storage
                .filePath(filename: "image_" + filename)
            {
                image = UIImage(contentsOfFile: path)
            }
        }
    }
}
