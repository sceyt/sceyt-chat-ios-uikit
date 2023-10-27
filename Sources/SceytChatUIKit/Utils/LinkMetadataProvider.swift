//
//  LinkMetadataProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import CoreServices
import LinkPresentation
import UIKit

open class LinkMetadataProvider {
    public static var `default` = LinkMetadataProvider()

    public var cache = defaultCache
    private var observer: NSObjectProtocol?
    @Atomic private var fetchCache = [URL: [(Result<LinkMetadata, Error>) -> Void]]()
    @Atomic private var activeTasks = Set<Task>()

    public required init() {
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
        activeTasks.removeAll()
    }

    open func metadata(for url: URL) -> LinkMetadata? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    open func isFetching(url: URL) -> Bool {
        fetchCache[url] != nil
    }

    @discardableResult
    open func fetch(url: URL, completion: @escaping ((Result<LinkMetadata, Error>) -> Void)) -> Task? {
        if let metadata = cache.object(forKey: url.absoluteString as NSString) {
            completion(.success(metadata))
            return nil
        }
        let linkMetadata = LinkMetadata(url: url)
        let provider = LPMetadataProvider()
        if fetchCache[url] == nil {
            fetchCache[url] = [completion]
        } else {
            fetchCache[url]?.append(completion)
            return nil
        }
        let task = Task(provider: provider)
        activeTasks.insert(task)
        provider.startFetchingMetadata(for: url.sanitise) { [weak self, task = task] metadata, error in
            var result: Result<LinkMetadata, Error>!
            defer {
                self?.activeTasks.remove(task)
                if let closures = self?.fetchCache[url] {
                    self?.fetchCache[url] = nil
                    DispatchQueue.main.async {
                        closures.forEach {
                            $0(result)
                        }
                    }
                }
            }

            if let error {
                result = .failure(error)
                return
            }

            linkMetadata.title = metadata?.title
            linkMetadata.summary = metadata?.value(forKey: "summary") as? String
            linkMetadata.creator = metadata?.value(forKey: "creator") as? String
            linkMetadata.icon = metadata?.value(forKeyPath: "icon.platformImage") as? UIImage
            linkMetadata.iconUrl = metadata?.value(forKeyPath: "iconMetadata.URL") as? URL
            linkMetadata.image = metadata?.value(forKeyPath: "image.platformImage") as? UIImage
            linkMetadata.imageUrl = metadata?.value(forKeyPath: "imageMetadata.URL") as? URL
            self?.cache.setObject(linkMetadata, forKey: url.absoluteString as NSString)
            result = .success(linkMetadata)
        }
        return task
    }

    static var defaultCache: NSCache<NSString, LinkMetadata> {
        let cache = NSCache<NSString, LinkMetadata>()
        cache.countLimit = 100
        return cache
    }
}

extension LinkMetadataProvider {
    open class Task: NSObject {
        private let provider: LPMetadataProvider
        private var isCanceled = false
        init(provider: LPMetadataProvider) {
            self.provider = provider
        }

        func cancel() {
            guard !isCanceled else { return }
            isCanceled = true
            provider.cancel()
        }

        deinit {
            cancel()
        }
    }
}

open class LinkMetadata {
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

    public let url: URL
    open var title: String?
    open var summary: String?
    open var creator: String?
    open var icon: UIImage?
    open var iconUrl: URL?
    open var image: UIImage?
    open var imageUrl: URL?

    func storeImages() {
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

    func loadImages() {
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

open class DataDetector {
    
    public class func getLinks(text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        return matches.compactMap {
            guard $0.url?.scheme != "mailto",
                  let range = Range($0.range, in: String(text)),
                  let url = URL(string: String(text[range]))
            else { return nil }
            return url
        }
    }
    
    public class func matches(
        text: String,
        types: NSTextCheckingResult.CheckingType = .link) -> [NSTextCheckingResult] {
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        return detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    }

    public class func containsLink(text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        return detector.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil
    }
    
    public class func matches(text: String) -> [NSTextCheckingResult] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        return detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    }
}

public extension DataDetector {
    
    class func setAttributes(
        _ attributes: [NSAttributedString.Key: Any]?,
        string: NSMutableAttributedString,
        matches types: NSTextCheckingResult.CheckingType) {
            let matches = matches(text: string.string, types: types)
            for match in matches {
                string.setAttributes(attributes, range: match.range)
            }
    }
    
    class func addAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        string: NSMutableAttributedString,
        matches types: NSTextCheckingResult.CheckingType) {
            let matches = matches(text: string.string, types: types)
            for match in matches {
                string.addAttributes(attributes, range: match.range)
            }
    }
}
