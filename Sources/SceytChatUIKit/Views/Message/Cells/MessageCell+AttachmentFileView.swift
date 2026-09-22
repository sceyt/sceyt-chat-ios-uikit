//
//  MessageCell+AttachmentFileView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

/// Extension → "is this previewable" lookup, memoized.
///
/// Resolving it goes through two `UTType` round-trips (extension → MIME → UTI → conformance),
/// and `AttachmentFileView` asks the question about half a dozen times per bind — from
/// `applyThumbnail`, `showsPreviewImage`, `showsMediaPlaceholderBackground` and
/// `updateProgressViewBackground`. The answer depends only on the file extension, so the
/// whole app needs to resolve any given one once.
enum AttachmentFileKind {
    struct Kind {
        let isImage: Bool
        let isVideo: Bool
        var isPreviewable: Bool { isImage || isVideo }
    }

    private static let lock = NSLock()
    private static var cache = [String: Kind]()

    static func kind(ofFileNamed name: String?) -> Kind {
        let ext = ((name ?? "") as NSString).pathExtension.lowercased()
        lock.lock()
        let cached = cache[ext]
        lock.unlock()
        if let cached { return cached }

        let url = URL(fileURLWithPath: "file.\(ext)")
        let kind = Kind(isImage: url.isImage, isVideo: url.isVideo)
        lock.lock()
        cache[ext] = kind
        lock.unlock()
        return kind
    }
}

extension MessageCell {

    open class AttachmentFileView: AttachmentView {

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var sizeLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var playButton = UIImageView()
            .withoutAutoresizingMask

        /// Spans the name + size labels so they can be centered on the thumbnail as one block.
        open lazy var textLayoutGuide = UILayoutGuide()

        /// Keeps the size line inside the space the layout model reserved for the bubble's
        /// date/tick InfoView. Its constant is re-applied on every bind, since the reserve
        /// depends on the message the row belongs to.
        public private(set) var sizeLabelTrailingConstraint: NSLayoutConstraint?

        open override func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true
            imageView.cornerRadius = 8

            titleLabel.font = appearance.attachmentFileNameLabelAppearance.font
            titleLabel.textColor = appearance.attachmentFileNameLabelAppearance.foregroundColor
            titleLabel.lineBreakMode = .byTruncatingMiddle

            sizeLabel.font = appearance.attachmentFileSizeLabelAppearance.font
            sizeLabel.textColor = appearance.attachmentFileSizeLabelAppearance.foregroundColor
            // Explicit, not UILabel's defaults: this line shares its row with the bubble's
            // timestamp, so truncating is the contract, not a host-tunable detail.
            sizeLabel.numberOfLines = 1
            sizeLabel.lineBreakMode = .byTruncatingTail
            sizeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            updateProgressViewBackground()
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)

            playButton.image = .videoPlayerPlay
            playButton.isHidden = true
        }

        open override func setupLayout() {
            super.setupLayout()

            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(sizeLabel)
            addSubview(progressView)
            addSubview(pauseButton)
            addSubview(playButton)

            // The stack this view fills is itself inset from the bubble on the top and sides but
            // flush with its bottom, so equal insets here would not read as equal on screen —
            // subtract the stack's own inset on the two sides that have one. The bottom's full
            // padding comes from the row height (`defaults.fileAttachmentSize`).
            let inset = Layouts.attachmentFilePadding - Layouts.attachmentStackBubbleInset
            imageView.pin(to: self, anchors: [.leading(inset), .top(inset)])
            imageView.resize(anchors: [.height(Layouts.attachmentFileIconSize), .width(Layouts.attachmentFileIconSize)])
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: Layouts.horizontalPadding)
            titleLabel.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor, constant: -Layouts.horizontalPadding)
            sizeLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            sizeLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 4)
            // The bubble draws its date/tick InfoView over this line (the icon is centered in a
            // 62pt row, so the size label and the InfoView share a vertical band). The layout
            // model already widened the row to fit both, so this only bites in the residual cases
            // — the row cap reached, or the running "<downloaded> • <total>" string a couple of
            // points wider than the "<total> • <total>" it was measured against. Truncating there
            // is the intended fallback; without any trailing anchor the label just ran under the
            // clock. 999 rather than required so a host that shrinks the row cap below icon +
            // reserve degrades to that overlap instead of breaking the row's layout.
            // Priority is set before activation: UIKit refuses to move an installed constraint
            // across the required boundary.
            sizeLabelTrailingConstraint = sizeLabel.trailingAnchor
                .pin(lessThanOrEqualTo: trailingAnchor, constant: -Layouts.horizontalPadding, activate: false)
                .priority(999)
                .activate(true)

            // Center the name/size pair on the thumbnail as one block. A guide rather than an
            // offset from the icon's top so it stays centered whatever the two label fonts are
            // (they differ) and whatever the slot grows to.
            addLayoutGuide(textLayoutGuide)
            textLayoutGuide.topAnchor.pin(to: titleLabel.topAnchor)
            textLayoutGuide.bottomAnchor.pin(to: sizeLabel.bottomAnchor)
            textLayoutGuide.centerYAnchor.pin(to: imageView.centerYAnchor)

            // Centered in the slot at a fixed size rather than filling it, like the image view's
            // loader does over a photo. The background is a circle of the view's own bounds
            // (`CircularProgressView.layoutSubviews`), so the size is the disc the user sees.
            progressView.resize(anchors: [.height(Layouts.attachmentFileProgressSize), .width(Layouts.attachmentFileProgressSize)])
            progressView.pin(to: imageView, anchors: [.centerX(), .centerY()])
            pauseButton.pin(to: progressView)
            playButton.pin(to: imageView, anchors: [.centerX(), .centerY()])
            playButton.resize(anchors: [.height(24.0), .width(24.0)])
        }

        /// Nil-safe: these are reached from `setupAppearance()`, which runs before `data` is
        /// ever bound (`data` is implicitly unwrapped, so a plain access would trap there).
        private var fileKind: AttachmentFileKind.Kind {
            AttachmentFileKind.kind(ofFileNamed: data?.attachment.name)
        }

        private var isVideoFile: Bool {
            fileKind.isVideo
        }

        private var isImageFile: Bool {
            fileKind.isImage
        }

        /// A document that carries a real preview (image/video sent as a file), as opposed to
        /// a pdf/zip/etc. whose icon slot only ever holds the generic file-type icon.
        private var isPreviewableFile: Bool {
            fileKind.isPreviewable
        }

        /// True when the icon slot currently has a real preview to draw — either the sharp
        /// on-disk thumbnail or the blurred thumbHash placeholder decoded from metadata.
        /// False for a previewable document whose sender shipped no thumbHash (older clients)
        /// until its download lands, which is exactly when the placeholder background shows.
        private var showsPreviewImage: Bool {
            guard let data, isPreviewableFile else { return false }
            if data.isThumbnailLoadedFromFile { return true }
            guard let metadata = data.attachment.imageDecodedMetadata else { return false }
            return metadata.thumbnailImage != nil || !metadata.thumbnail.isEmpty
        }

        /// Previewable documents get the media placeholder background, so their slot reads like
        /// an image attachment's rather than flashing the generic file puck before the preview
        /// arrives. Plain files (pdf/zip/…) keep the icon and need no background behind it.
        open override var showsMediaPlaceholderBackground: Bool {
            isPreviewableFile
        }

        /// The loader fills the whole 40×40 icon slot, so an opaque background would hide what
        /// is underneath it for the entire transfer — and, since an undownloaded attachment
        /// sits in `.pauseDownloading` with the circle still visible, before the download even
        /// starts. Use the translucent overlay the image/video views use for any previewable
        /// document — including one with no thumbHash, where it sits over the placeholder
        /// background. Keep the solid accent puck for plain files, where it covers nothing but
        /// the generic icon.
        private func updateProgressViewBackground() {
            progressView.backgroundColor = isPreviewableFile
                ? appearance.overlayMediaLoaderAppearance.backgroundColor
                : appearance.mediaLoaderAppearance.backgroundColor
        }

        /// Paints the icon slot. A previewable document shows only a real preview — never the
        /// generic file puck, which is an opaque accent circle that would hide the placeholder
        /// background and then jump to a photo once the download lands. Note the layout model
        /// resolves `data.thumbnail` to that same icon when no preview is available, so this
        /// deliberately drops it rather than passing it through.
        open override func applyThumbnail(_ thumbnail: UIImage?) {
            if isPreviewableFile {
                imageView.image = showsPreviewImage ? (thumbnail ?? data.thumbnail) : nil
            } else {
                imageView.image = thumbnail ?? data.thumbnail
                    ?? appearance.attachmentIconProvider.provideVisual(for: data.attachment)
            }
            updateThumbnailPlaceholderBackground()
            updateProgressViewBackground()
        }

        open override func update(status: ChatMessage.Attachment.TransferStatus) {
            super.update(status: status)
            if data.transferStatus == .done {
                if imageView.image != nil && isVideoFile {
                    playButton.isHidden = false
                }
            }
        }

        open override var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                playButton.isHidden = true
                // Show whatever preview the layout resolved: the sharp on-disk one when the
                // file is local/downloaded, or the blurred thumbHash placeholder decoded from
                // metadata while the upload/download is still in flight. The play button stays
                // gated on .done — the blurred placeholder is not playable.
                applyThumbnail(nil)
                if data.transferStatus == .done, imageView.image != nil, isVideoFile {
                    playButton.isHidden = false
                }
                titleLabel.text = data.name
                sizeLabel.text = data.fileSize(using: appearance.attachmentFileSizeFormatter)
                updateSizeLabelTrailingInset()

                // The file-preview thumbnail is loaded asynchronously (and re-loaded after a
                // download completes), so at bind time data.thumbnail may still be nil or the
                // blurred metadata placeholder. Without this hook the blurred/sharp preview
                // lands on the layout but never reaches the cell until the screen is reopened.
                data.onLoadThumbnail = { [weak self, weak data] thumbnail in
                    guard let self, let data, self.data === data else { return }
                    // A file-backed load flips showsPreviewImage for a document with no
                    // metadata thumbHash (older messages), so re-run the whole paint.
                    self.applyThumbnail(thumbnail)
                    self.playButton.isHidden = !(self.imageView.image != nil && self.isVideoFile && data.transferStatus == .done)
                }

                // Self-heal for "blurred placeholder stays after download" — same recovery the
                // image/video views use. Only for previewable documents; other files have no
                // on-disk thumbnail to load, so the retry loop would be wasted work.
                if data.transferStatus == .done, !data.isThumbnailLoadedFromFile, isPreviewableFile {
                    reloadThumbnailFromFile(for: data.attachment)
                }
            }
        }

        /// Reads the reserve off `data`, so the file-view recycling path in
        /// `AttachmentStackView.bind` — which rebinds an existing row to a different attachment —
        /// picks up the new message's InfoView width for free.
        open func updateSizeLabelTrailingInset() {
            sizeLabelTrailingConstraint?.constant = -(Layouts.horizontalPadding + (data?.reservedTrailingWidth ?? 0))
        }

        open override func setProgress(_ progress: AttachmentTransfer.AttachmentProgress) {
            super.setProgress(progress)
            playButton.isHidden = true

            let message: String
            if progress.progress <= 0.01 || progress.progress >= 1 {
                message = data.fileSize(using: appearance.attachmentFileSizeFormatter)
            } else {
                let total = progress.attachment.uploadedFileSize
                let downloaded = UInt(progress.progress * Double(total))
                message = "\(appearance.attachmentFileSizeFormatter.format(UInt64(downloaded))) • \(appearance.attachmentFileSizeFormatter.format(UInt64(total)))"
            }
            sizeLabel.text = message
        }

        open override func setCompletion(_ completion: AttachmentTransfer.AttachmentCompletion) {
            super.setCompletion(completion)
            guard completion.error == nil
            else { return }
            sizeLabel.text = data.fileSize(using: appearance.attachmentFileSizeFormatter)
        }
    }
}
