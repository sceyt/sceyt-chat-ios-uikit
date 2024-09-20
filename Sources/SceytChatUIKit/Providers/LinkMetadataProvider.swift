//
//  File.swift
//  
//
//  Created by Hovsep Keropyan on 26.12.23.
//

import UIKit
import ImageIO
import SceytChat

open class LinkMetadataProvider: Provider {
    public static var `default` = LinkMetadataProvider()

    public var cache = defaultCache
    private var observer: NSObjectProtocol?
    @Atomic private var fetchCache = Set<URL>()

    public required override init() {
        super.init()
        observer = NotificationCenter
            .default
            .addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil)
        { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }

    deinit {
        removeCache()
    }

    public func removeCache() {
        cache.removeAllObjects()
    }

    open func metadata(for url: URL) -> LinkMetadata? {
        if url.scheme == nil {
            var https: URL? {
                URL(string: "https://" + url.absoluteString)
            }
            var http: URL? {
                URL(string: "http://" + url.absoluteString)
            }
          
            logger.verbose("[LOAD LINK] metadata from cache url: \(https)")
            if let url = https, let object = cache.object(forKey: url.absoluteString as NSString) {
                return object
            }
            
            logger.verbose("[LOAD LINK] metadata from cache url: \(http)")
            if let url = http, let object = cache.object(forKey: url.absoluteString as NSString) {
                return object
            }
            
        }
        logger.verbose("[LOAD LINK] metadata from cache url: \(url.absoluteString)")
        return cache.object(forKey: url.absoluteString as NSString)
    }

    open func isFetching(url: URL) -> Bool {
        fetchCache.contains(url)
    }

    @discardableResult
    open func fetch(
        url: URL,
        downloadImage: Bool = true, 
        downloadIcon: Bool = true
    ) async -> Result<LinkMetadata, Error> {
        fetchCache.insert(url)
        defer {
            fetchCache.remove(url)
        }
        let log_hv = url.absoluteString.hashValue
        logger.verbose("[LOAD LINK] \(log_hv) Will load link Open Graph data from SceytChat url: \(url.absoluteString)")
        if let metadata = cache.object(forKey: url.absoluteString as NSString) {
            return .success(metadata)
        }
        
        let result: Result<LinkMetadata?, Error> =
        await withCheckedContinuation { continuation in
            database.performBgTask { context in
                LinkMetadataDTO.fetch(url: url, context: context)?.convert()
            } completion: { result in
                switch result {
                case .success(let link):
                    continuation.resume(returning: .success(link))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
                 
            }
        }
        
        if let metadata = try? result.get(), 
            metadata != nil {
            logger.verbose("[LOAD LINK] \(log_hv) Load metadata from db \(metadata.url): SUCCESS")
            await downloadImagesIfNeeded(
                linkMetadata: metadata,
                downloadImage: downloadImage,
                downloadIcon: downloadIcon)
            cache.setObject(metadata, forKey: url.absoluteString as NSString)
            return .success(metadata)
        }
        
        let linkMetadata = LinkMetadata(url: url)
        
        do {
            let (link, error) = await chatClient.loadLinkDetails(for: url)
            if let error {
                logger.verbose("[LOAD LINK] \(log_hv) Failed to load link Open Graph data from SceytChat error: \(error)")
                return .failure(error)
            }
            if let link {
                linkMetadata.title = link.title
                linkMetadata.summary = link.info
                if let urlStr = link.favicon?.url,
                   let url = URL(string: urlStr) {
                    linkMetadata.iconUrl = url
                }
                
                if let urlStr = link.images?.first?.url,
                   let url = URL(string: urlStr) {
                    linkMetadata.imageUrl = url
                }
                
                await downloadImagesIfNeeded(
                    linkMetadata: linkMetadata,
                    downloadImage: downloadImage,
                    downloadIcon: downloadIcon
                )
                
                logger.verbose("[LOAD LINK] \(log_hv) Load link Open Graph data siteName: \(link.siteName), title: \(link.title), type: \(link.type), info: \(link.info), locale: \(link.locale), localeAlternates: \(link.localeAlternates)")
                if let favicon = link.favicon {
                    logger.verbose("[LOAD LINK] \(log_hv) Load link Open Graph data favicon: \(favicon.url)")
                }
                
                if let images = link.images {
                    images.forEach { image in
                        logger.verbose("[LOAD LINK] \(log_hv) Load link Open Graph data image url: \(image.url), secureUrl: \(image.secureUrl), secureUrl: \(image.type), width: \(image.width), height: \(image.height)")
                    }
                }
                
            } else {
                logger.verbose("[LOAD LINK] \(log_hv) Load link Open Graph data success but no data")
            }
        } catch {
            logger.verbose("[LOAD LINK] \(log_hv) Failed to load link Open Graph data error: \(error)")
            return .failure(error)
        }
        logger.verbose("[LOAD LINK] metadata from cache ADD: \(url.absoluteString)")
        cache.setObject(linkMetadata, forKey: url.absoluteString as NSString)
        return .success(linkMetadata)
    }
    
    open func downloadImagesIfNeeded(
        linkMetadata: LinkMetadata,
        downloadImage: Bool = true,
        downloadIcon: Bool = true
    ) async {
        let log_hv = linkMetadata.url.absoluteString.hashValue
        do {
            if downloadImage, let imageUrl = linkMetadata.imageUrl,
                linkMetadata.image == nil {
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                if let image = Components.imageBuilder.image(from: data) {
                    logger.debug("[LOAD LINK] \(log_hv) image of size: \(image.size) from \(imageUrl)")
                    linkMetadata.image = (try? Components.imageBuilder.init(image: image)
                        .resize(max: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.dimensionThreshold))?
                        .uiImage ?? image
                    logger.debug("[LOAD LINK] \(log_hv) image of resize: \(linkMetadata.image!.size) from \(imageUrl)")
                }
                
                if linkMetadata.image != nil {
                    logger.verbose("[LOAD LINK] \(log_hv) Load Image size: \(linkMetadata.image!.size) from \(linkMetadata.imageUrl): SUCCESS")
                } else {
                    logger.error("[LOAD LINK] \(log_hv) Load Image from \(linkMetadata.imageUrl): FAILE")
                }
            }
            
            if downloadIcon, let iconUrl = linkMetadata.iconUrl,
                linkMetadata.icon == nil {
                let (data, _) = try await URLSession.shared.data(from: iconUrl)
                linkMetadata.icon = Components.imageBuilder.image(from: data)
                
                if linkMetadata.icon != nil {
                    logger.verbose("[LOAD LINK] \(log_hv) Load Icon size: \(linkMetadata.icon!.size) from \(linkMetadata.iconUrl): SUCCESS")
                } else {
                    logger.error("[LOAD LINK] \(log_hv) Load Icon from \(linkMetadata.iconUrl): FAILE")
                }
            }
            cache.setObject(linkMetadata, forKey: linkMetadata.url.absoluteString as NSString)
        } catch {
            logger.verbose("[LOAD LINK] \(log_hv) Failed to download image data error: \(error)")
        }
    }

    static var defaultCache: NSCache<NSString, LinkMetadata> {
        let cache = NSCache<NSString, LinkMetadata>()
        cache.countLimit = 100
        return cache
    }
}
