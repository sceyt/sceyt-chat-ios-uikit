//
//  LinkMetadataProvider.swift
//
//
//  Created by Hovsep Keropyan on 26.12.23.
//

import UIKit
import ImageIO
import SceytChat

open class LinkMetadataProvider: DataProvider {
    
    open var titleMaxLength = 100 // characters
    open var summaryMaxLength = 200 // characters
    
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

    /// Resolves metadata for many URLs in a single Core Data round-trip — never hits the network.
    /// In-memory cache hits are returned synchronously; the rest is fetched once on a bg context.
    /// Completion is delivered on the main queue with a `[URL: LinkMetadata]` map of resolved URLs only
    /// (URLs absent from the map were not found in cache or DB).
    open func fetchManyFromCacheOrDB(
        urls: [URL],
        downloadImage: Bool = true,
        downloadIcon: Bool = true,
        completion: @escaping ([URL: LinkMetadata]) -> Void
    ) {
        var resolved: [URL: LinkMetadata] = [:]
        var missing: [URL] = []
        // 1. In-memory cache pass
        for url in urls {
            if let metadata = cache.object(forKey: url.absoluteString as NSString) {
                resolved[url] = metadata
            } else {
                missing.append(url)
            }
        }

        guard !missing.isEmpty else {
            completion(resolved)
            return
        }

        // 2. One DB query for everything still missing
        database.performBgTask { context in
            LinkMetadataDTO.fetch(urls: missing, context: context).map { $0.convert() }
        } completion: { [weak self] result in
            guard let self else { completion(resolved); return }
            guard case .success(let metadatas) = result else {
                completion(resolved)
                return
            }

            guard !metadatas.isEmpty else {
                completion(resolved)
                return
            }

            // 3. Hydrate images (disk + optional remote download) in parallel, then cache + return.
            let group = DispatchGroup()
            for metadata in metadatas {
                metadata.loadImages()
                group.enter()
                self.downloadImagesIfNeeded(
                    linkMetadata: metadata,
                    downloadImage: downloadImage,
                    downloadIcon: downloadIcon
                ) {
                    self.cache.setObject(metadata, forKey: metadata.url.absoluteString as NSString)
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                for metadata in metadatas {
                    resolved[metadata.url] = metadata
                }
                completion(resolved)
            }
        }
    }

    /// Resolves metadata from in-memory cache or the local DB only — never makes a network request.
    /// Calls `completion` with the metadata, or `nil` if not found in either store.
    open func fetchFromCacheOrDB(
        url: URL,
        downloadImage: Bool = true,
        downloadIcon: Bool = true,
        completion: @escaping (LinkMetadata?) -> Void
    ) {
        // 1. In-memory cache
        if let metadata = cache.object(forKey: url.absoluteString as NSString) {
            completion(metadata)
            return
        }

        // 2. Database — no network fallback
        database.performBgTask { context in
            LinkMetadataDTO.fetch(url: url, context: context)?.convert()
        } completion: { [weak self] result in
            guard let self else { completion(nil); return }
            guard case .success(let metadata) = result, let metadata else {
                completion(nil)
                return
            }
            metadata.loadImages()
            self.downloadImagesIfNeeded(
                linkMetadata: metadata,
                downloadImage: downloadImage,
                downloadIcon: downloadIcon
            ) {
                self.cache.setObject(metadata, forKey: url.absoluteString as NSString)
                completion(metadata)
            }
        }
    }

    @discardableResult
    open func fetch(
        url: URL,
        downloadImage: Bool = true,
        downloadIcon: Bool = true,
        forceFetch: Bool = false,
        completion: @escaping (Result<LinkMetadata, Error>) -> Void
    ) {
        fetchCache.insert(url)

        let log_hv = url.absoluteString.hashValue
        logger.verbose("[LOAD LINK] \(log_hv) Will load link Open Graph data from SceytChat url: \(url.absoluteString)")

        // Check cache first
        if let metadata = cache.object(forKey: url.absoluteString as NSString) {
            let prefixTitle = metadata.title?.prefix(titleMaxLength)
            let titleStr = prefixTitle == nil ? nil : String(prefixTitle!)
            metadata.title = titleStr

            let prefixSummary = metadata.summary?.prefix(summaryMaxLength)
            let summaryStr = prefixSummary == nil ? nil : String(prefixSummary!)
            metadata.summary = summaryStr

            fetchCache.remove(url)
            completion(.success(metadata))
            return
        }

        // Try to load from database
        database.performBgTask { context in
            LinkMetadataDTO.fetch(url: url, context: context)?.convert()
        } completion: { [weak self] result in
            guard let self else {
                self?.fetchCache.remove(url)
                completion(.failure(NSError(domain: "LinkMetadataProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"])))
                return
            }

            switch result {
            case .success(let metadata):
                if let metadata = metadata {
                    logger.verbose("[LOAD LINK] \(log_hv) Load metadata from db \(metadata.url): SUCCESS")

                    if forceFetch, (metadata.summary == nil || metadata.title == nil) {
                        logger.verbose("[LOAD LINK] \(log_hv) forceFetch — no summary in DB, fetching from network")
                        self.loadLinkMetadataFromNetwork(
                            url: url,
                            log_hv: log_hv,
                            downloadImage: downloadImage,
                            downloadIcon: downloadIcon,
                            completion: completion
                        )
                        return
                    }

                    metadata.loadImages()
                    self.downloadImagesIfNeeded(
                        linkMetadata: metadata,
                        downloadImage: downloadImage,
                        downloadIcon: downloadIcon
                    ) {
                        let prefixTitle = metadata.title?.prefix(self.titleMaxLength)
                        let titleStr = prefixTitle == nil ? nil : String(prefixTitle!)
                        metadata.title = titleStr

                        let prefixSummary = metadata.summary?.prefix(self.summaryMaxLength)
                        let summaryStr = prefixSummary == nil ? nil : String(prefixSummary!)
                        metadata.summary = summaryStr

                        self.cache.setObject(metadata, forKey: url.absoluteString as NSString)
                        self.fetchCache.remove(url)
                        completion(.success(metadata))
                    }
                    return
                }

                // No metadata in database, load from network
                self.loadLinkMetadataFromNetwork(
                    url: url,
                    log_hv: log_hv,
                    downloadImage: downloadImage,
                    downloadIcon: downloadIcon,
                    completion: completion
                )

            case .failure:
                // Database error, try network
                self.loadLinkMetadataFromNetwork(
                    url: url,
                    log_hv: log_hv,
                    downloadImage: downloadImage,
                    downloadIcon: downloadIcon,
                    completion: completion
                )
            }
        }
    }

    private func loadLinkMetadataFromNetwork(
        url: URL,
        log_hv: Int,
        downloadImage: Bool,
        downloadIcon: Bool,
        completion: @escaping (Result<LinkMetadata, Error>) -> Void
    ) {
        let linkMetadata = LinkMetadata(url: url)

        chatClient.loadLinkDetails(for: url) { [weak self] link, error in
            guard let self else {
                self?.fetchCache.remove(url)
                completion(.failure(NSError(domain: "LinkMetadataProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"])))
                return
            }

            if let error {
                logger.verbose("[LOAD LINK] \(log_hv) Failed to load link Open Graph data from SceytChat error: \(error)")
                self.fetchCache.remove(url)
                completion(.failure(error))
                return
            }

            if let link {
                let prefixTitle = link.title?.prefix(self.titleMaxLength)
                let titleStr = prefixTitle == nil ? nil : String(prefixTitle!)
                linkMetadata.title = titleStr

                let prefixedInfo = link.info?.prefix(self.summaryMaxLength)
                let infoStr = prefixedInfo == nil ? nil : String(prefixedInfo!)
                linkMetadata.summary = infoStr

                if let urlStr = link.favicon?.url,
                   let url = URL(string: urlStr) {
                    linkMetadata.iconUrl = url
                }

                if let urlStr = link.images?.first?.url,
                   let url = URL(string: urlStr) {
                    linkMetadata.imageUrl = url
                }

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

            self.downloadImagesIfNeeded(
                linkMetadata: linkMetadata,
                downloadImage: downloadImage,
                downloadIcon: downloadIcon
            ) {
                logger.verbose("[LOAD LINK] metadata from cache ADD: \(url.absoluteString)")
                self.cache.setObject(linkMetadata, forKey: url.absoluteString as NSString)
                self.fetchCache.remove(url)
                completion(.success(linkMetadata))
            }
        }
    }
    
    open func downloadImagesIfNeeded(
        linkMetadata: LinkMetadata,
        downloadImage: Bool = true,
        downloadIcon: Bool = true,
        completion: @escaping () -> Void
    ) {
        let log_hv = linkMetadata.url.absoluteString.hashValue

        let group = DispatchGroup()

        if downloadImage, let imageUrl = linkMetadata.imageUrl,
            linkMetadata.image == nil {
            group.enter()
            URLSession.shared.dataTask(with: imageUrl) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil else {
                    logger.verbose("[LOAD LINK] \(log_hv) Failed to download image data error: \(String(describing: error))")
                    return
                }
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
            }.resume()
        }

        if downloadIcon, let iconUrl = linkMetadata.iconUrl,
            linkMetadata.icon == nil {
            group.enter()
            URLSession.shared.dataTask(with: iconUrl) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil else {
                    logger.verbose("[LOAD LINK] \(log_hv) Failed to download icon data error: \(String(describing: error))")
                    return
                }
                linkMetadata.icon = Components.imageBuilder.image(from: data)

                if linkMetadata.icon != nil {
                    logger.verbose("[LOAD LINK] \(log_hv) Load Icon size: \(linkMetadata.icon!.size) from \(linkMetadata.iconUrl): SUCCESS")
                } else {
                    logger.error("[LOAD LINK] \(log_hv) Load Icon from \(linkMetadata.iconUrl): FAILE")
                }
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            self?.cache.setObject(linkMetadata, forKey: linkMetadata.url.absoluteString as NSString)
            completion()
        }
    }

    static var defaultCache: NSCache<NSString, LinkMetadata> {
        let cache = NSCache<NSString, LinkMetadata>()
        cache.countLimit = 100
        return cache
    }
}
