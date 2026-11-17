//
//  ChannelInfoViewController+ThumbnailRenderer.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {

    /// Turns a media-grid thumbnail into a bitmap the size of the tile, off the main thread.
    ///
    /// A `UIImage` read from a file (`UIImage(data:)`, `UIImage(contentsOfFile:)`) is not decoded
    /// until it is first drawn, and that draw happens on the main thread, during the scroll. The
    /// thumbnails that reach the grid are often several times the tile's pixels (a chat bubble's
    /// 810×1080 file arriving through the sharp-thumbnail relay), so every tile coming on screen
    /// paid a full-size decode on main. Here the image is drawn once, in the background, at the
    /// tile's pixel size (aspect-fill), and the result — decoded and small — is kept in a memory
    /// cache, so scrolling back to a tile is a cache hit.
    open class ThumbnailRenderer {

        public static let shared = ThumbnailRenderer()

        /// Decoded bitmaps, costed by their bytes. Evicted under memory pressure by `NSCache`.
        public let cache: NSCache<NSString, UIImage> = {
            let cache = NSCache<NSString, UIImage>()
            cache.totalCostLimit = 48 * 1024 * 1024
            cache.name = "SceytChatUIKit.ChannelInfo.ThumbnailRenderer"
            return cache
        }()

        /// Two at a time: enough to keep up with a fling, without competing with the
        /// transfers' decryption and the thumbnail files' generation for every core.
        public let queue: OperationQueue = {
            let queue = OperationQueue()
            queue.name = "SceytChatUIKit.ChannelInfo.ThumbnailRenderer"
            queue.maxConcurrentOperationCount = 2
            queue.qualityOfService = .userInitiated
            return queue
        }()

        /// Renders keyed by cache key while they run, so a prefetch and a bind of the same tile
        /// share one render.
        private var inFlight = [NSString: [(UIImage) -> Void]]()
        private let lock = NSLock()

        public init() {}

        /// Whether `image` should go through a render before it is shown in a tile of
        /// `targetPixelSize`: only when it is clearly bigger than the tile. A small image (a
        /// thumbHash blur, an icon, a thumbnail already at the tile's size) costs little to
        /// decode, and showing it directly avoids a frame without an image.
        open func needsRendering(_ image: UIImage, targetPixelSize: CGSize) -> Bool {
            guard targetPixelSize.width > 0, targetPixelSize.height > 0 else { return false }
            let source = Self.pixelSize(of: image)
            return source.width * source.height > targetPixelSize.width * targetPixelSize.height * 1.5
        }

        /// The cache key of `image` rendered for `targetPixelSize`, for the attachment `identity`.
        /// The source's own pixel size is part of it: one attachment can show a thumbHash blur,
        /// a downloaded poster and a full thumbnail over its life.
        open func key(identity: String, image: UIImage, targetPixelSize: CGSize) -> NSString {
            let source = Self.pixelSize(of: image)
            return "\(identity)|\(Int(source.width))x\(Int(source.height))|\(Int(targetPixelSize.width))x\(Int(targetPixelSize.height))" as NSString
        }

        open func cachedImage(forKey key: NSString) -> UIImage? {
            cache.object(forKey: key)
        }

        /// Renders `image` for `targetPixelSize` in the background and calls `completion` on the
        /// main queue with the result (also stored under `key`). Joins a render of the same key
        /// that is already running.
        open func render(
            _ image: UIImage,
            key: NSString,
            targetPixelSize: CGSize,
            completion: ((UIImage) -> Void)? = nil
        ) {
            if let cached = cache.object(forKey: key) {
                completion?(cached)
                return
            }
            lock.lock()
            if inFlight[key] != nil {
                if let completion { inFlight[key]?.append(completion) }
                lock.unlock()
                return
            }
            inFlight[key] = completion.map { [$0] } ?? []
            lock.unlock()

            queue.addOperation { [weak self] in
                guard let self else { return }
                let rendered = Self.draw(image, aspectFilling: targetPixelSize)
                self.cache.setObject(rendered, forKey: key, cost: Self.byteCost(of: rendered))
                DispatchQueue.main.async {
                    self.lock.lock()
                    let completions = self.inFlight.removeValue(forKey: key) ?? []
                    self.lock.unlock()
                    completions.forEach { $0(rendered) }
                }
            }
        }

        /// Draws `image` scaled to cover `target` (in pixels), never upscaled, into a fresh
        /// bitmap at scale 1. Drawing forces the decode here, on the calling (background) thread.
        open class func draw(_ image: UIImage, aspectFilling target: CGSize) -> UIImage {
            let source = pixelSize(of: image)
            guard source.width > 0, source.height > 0 else { return image }
            let scale = min(1, max(target.width / source.width, target.height / source.height))
            let size = CGSize(width: max(1, (source.width * scale).rounded()),
                              height: max(1, (source.height * scale).rounded()))
            let format = UIGraphicsImageRendererFormat.preferred()
            format.scale = 1
            format.opaque = false
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        public class func pixelSize(of image: UIImage) -> CGSize {
            CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        }

        class func byteCost(of image: UIImage) -> Int {
            let size = pixelSize(of: image)
            return Int(size.width * size.height * 4)
        }
    }

    /// Delivers only the newest of a stream of values on the main queue: values submitted from
    /// any thread between two main-queue passes collapse into one call with the last of them.
    /// For progress ticks, where an older value is worthless once a newer one exists, and one
    /// main-queue hop per tick floods main when many transfers run at once.
    public final class MainQueueLatestValue<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var pending: Value?
        private var isScheduled = false
        private let deliver: (Value) -> Void

        public init(_ deliver: @escaping (Value) -> Void) {
            self.deliver = deliver
        }

        public func submit(_ value: Value) {
            lock.lock()
            pending = value
            let schedule = !isScheduled
            isScheduled = true
            lock.unlock()
            guard schedule else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let value = self.pending
                self.pending = nil
                self.isScheduled = false
                self.lock.unlock()
                if let value { self.deliver(value) }
            }
        }

        /// Drops a value not yet delivered (the cell was rebound, or the transfer ended).
        public func discardPending() {
            lock.lock()
            pending = nil
            lock.unlock()
        }
    }
}
