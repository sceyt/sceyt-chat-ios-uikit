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
    public let isThumbnailData: Bool
    open var title: String?
    open var summary: String?
    open var creator: String?
    open var icon: UIImage?
    open var iconUrl: URL?
    open var image: UIImage?
    open var imageUrl: URL?
    open var imageOriginalSize: CGSize?
    open var iconOriginalSize: CGSize?
    open var thumbnail: UIImage?
    
    public var jpegDataCompressionQuality = CGFloat(0.8)
    
    public required init(isThumbnailData: Bool = false, url: URL) {
        self.isThumbnailData = isThumbnailData
        self.url = url
    }
    
    public init(
        isThumbnailData: Bool = false,
        url: URL,
        title: String? = nil,
        summary: String? = nil,
        creator: String? = nil,
        icon: UIImage? = nil,
        iconUrl: URL? = nil,
        iconOriginalSize: CGSize? = nil,
        image: UIImage? = nil,
        imageUrl: URL? = nil,
        imageOriginalSize: CGSize? = nil)
    {
        self.isThumbnailData = isThumbnailData
        self.url = url
        self.title = title
        self.summary = summary
        self.creator = creator
        self.icon = icon
        self.iconUrl = iconUrl
        self.image = image
        self.imageUrl = imageUrl
        self.iconOriginalSize = iconOriginalSize
        self.imageOriginalSize = imageOriginalSize
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
        if hasImage, let filename = Crypto.hash(value: url.normalizedURL.absoluteString) {
            logger.debug("[LINK PREVIEV] storeImages \(url), fn: \(filename) isz \(image?.size), icn: isz \(icon?.size)")
            if let icon = icon, let jpeg = icon.jpegData(compressionQuality: jpegDataCompressionQuality) {
                Components.storage.storeData(jpeg, filename: "icon_" + filename)
                
            }
            if let image = image, let jpeg = image.jpegData(compressionQuality: jpegDataCompressionQuality) {
                Components.storage.storeData(jpeg, filename: "image_" + filename)
            }
        } else {
            logger.debug("[LINK PREVIEV] storeImages \(url)")
        }
        
        
    }

    open func loadImages() {
        if let filename = Crypto.hash(value: url.normalizedURL.absoluteString) {
            if let path = Storage
                .filePath(filename: "icon_" + filename),
                icon == nil {
                icon = UIImage(contentsOfFile: path)
            }
            if let path = Storage
                .filePath(filename: "image_" + filename),
                (image == nil || isThumbnailData) {
                image = UIImage(contentsOfFile: path)
            }
            logger.debug("[LINK PREVIEV] loadImages \(url), fn: \(filename) isz \(image?.size), icn: isz \(icon?.size)")
        } else {
            logger.debug("[LINK PREVIEV] loadImages \(url)")
        }
    }
    
    open func loadThumbnail(of size: CGSize) {
        
        guard let image
        else { return }
        guard 1.5 * size.maxSide < image.size.maxSide
        else { return }
        if let filename = Crypto.hash(value: url.normalizedURL.absoluteString) {
            let thName = "thumbnail_link_" + filename
            
            let filePath = Components.storage.createFilePath(filename: thName)
            if let path = Components.storage.filePath(filename: thName) {
                thumbnail = UIImage(contentsOfFile: path)
            } else {
                if let ib = try? Components.imageBuilder.init(image: image).resize(max: size.maxSide),
                   let data = ib.jpegData(compressionQuality: jpegDataCompressionQuality) {
                    Components.storage.storeData(data, filePath: filePath)
                    thumbnail = ib.uiImage
                    
                }
            }            
        }
    }
}
