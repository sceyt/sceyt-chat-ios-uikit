//
//  AttachmentVideoView+AttachmentVideoView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit
import Photos

extension MessageCell {
    open class AttachmentVideoView: AttachmentView {

        open lazy var playButton = UIImageView()
            .withoutAutoresizingMask

        open lazy var timeLabel = Components.timeLabel
            .init()
            .withoutAutoresizingMask

        open lazy var blurEffectView: UIVisualEffectView = {
            let blur = UIBlurEffect(style: .light)
            let view = UIVisualEffectView(effect: blur)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isUserInteractionEnabled = false
            view.isHidden = true
            return view
        }()

        open lazy var fireIconContainerView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = UIColor(hex: "#17191C", alpha: 0x66 / 255.0)
            view.layer.cornerRadius = 28
            view.isUserInteractionEnabled = false
            view.isHidden = true
            return view
        }()

        open lazy var fireIconView: UIImageView = {
            let view = UIImageView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.contentMode = .scaleAspectFit
            view.image = .fire
            view.tintColor = .white
            view.isUserInteractionEnabled = false
            return view
        }()

        private var progressViewHeightConstraint: NSLayoutConstraint?
        
        
        override open func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true
            blurEffectView.clipsToBounds = true

            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.backgroundColor = appearance.overlayMediaLoaderAppearance.backgroundColor

            playButton.image = appearance.videoPlayIcon
            timeLabel.backgroundColor = appearance.overlayColor
            timeLabel.textLabel.font = appearance.videoDurationLabelAppearance.font
            timeLabel.textLabel.textColor = appearance.videoDurationLabelAppearance.foregroundColor
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(blurEffectView)
            addSubview(fireIconContainerView)
            fireIconContainerView.addSubview(fireIconView)
            addSubview(playButton)
            addSubview(timeLabel)
            addSubview(progressView)
            addSubview(progressLabel)
            addSubview(pauseButton)

            imageView.pin(to: self)
            blurEffectView.pin(to: imageView)
            playButton.pin(to: imageView, anchors: [.centerX(), .centerY()])
            timeLabel.pin(to: imageView, anchors: [.top(8), .leading(8)])
            progressViewHeightConstraint = progressView.heightAnchor.pin(constant: 56)
            progressView.widthAnchor.pin(to: progressView.heightAnchor)
            playButton.heightAnchor.pin(to: progressView.heightAnchor)
            playButton.widthAnchor.pin(to: progressView.widthAnchor)
            progressView.pin(to: imageView, anchors: [.centerX(), .centerY()])
            pauseButton.pin(to: progressView)
            progressLabel.centerXAnchor.pin(to: centerXAnchor)
            progressLabel.topAnchor.pin(to: progressView.bottomAnchor, constant: 4)
            progressLabel.bottomAnchor.pin(lessThanOrEqualTo: bottomAnchor, constant: -2)

            fireIconContainerView.resize(anchors: [.width(56), .height(56)])
            fireIconContainerView.pin(to: imageView, anchors: [.centerX, .centerY])

            fireIconView.resize(anchors: [.width(32), .height(32)])
            fireIconView.pin(to: fireIconContainerView, anchors: [.centerX, .centerY])
        }
        
        override open var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                setupPreviewer()
                updateThumbnailPlaceholderBackground()
                let duration = data.mediaDuration
                if duration >= 0 {
                    timeLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(duration)
                }

                // Show/hide blur and fire icon based on viewOnce
                let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
                blurEffectView.isHidden = !isViewOnce
                fireIconContainerView.isHidden = !isViewOnce

                // Resolve the play button *after* the transfer state, not before: binding a
                // video whose bytes are already on disk while its ring is still on screen
                // (a rebind mid-download, or the frames between 100% and the ring shrinking
                // out) used to draw the play glyph straight through the full circle.
                applyTransferStatus(data.transferStatus)
                updatePlayButtonVisibility()

                if let filePath = data.attachment.filePath,
                   filePath.hasPrefix("/local/"),
                   let asset = PHAsset.fetchAssets(withLocalIdentifiers: [filePath.substring(fromIndex: 7)], options: .none).firstObject {
                    PHImageManager.default().requestImage(for: asset, targetSize: imageView.frame.size, contentMode: .aspectFill, options: .none) { [weak self] image, _ in
                        guard let self else { return }
                        self.imageView.image = image ?? self.data.thumbnail
                    }
                } else {
                    imageView.image = data.thumbnail
                    data.onLoadThumbnail = { [weak self, weak data] thumbnail in
                        guard let self else {
                            logger.verbose("[Attachment] onLoadThumbnail self is nil \(data.map { "\($0.attachment.description) layout=\(ObjectIdentifier($0))" } ?? "layout=deallocated")")
                            return
                        }
                        guard let data, self.data === data else {
                            logger.verbose("[Attachment] self.data !== data case")
                            return
                        }
                        self.imageView.image = thumbnail
                    }

                    // Self-heal for "blurry placeholder stays after download" (see
                    // AttachmentImageView for the full rationale). When this view (re)binds a
                    // downloaded video whose layout still shows the low-res placeholder, pull the
                    // sharp frame from disk now — instance-agnostic via setFileBackedThumbnail —
                    // so it recovers even when the post-download load landed on a duplicate layout
                    // instance or the completion observer never fired for this view.
                    if data.transferStatus == .done, !data.isThumbnailLoadedFromFile {
                        reloadThumbnailFromFile(for: data.attachment)
                    }
                }
            }
        }
        
        override open func setProgress(_ progress: CGFloat) {
            guard progressView.progress != progress
            else { return }
            if progress > 0, progress < 1 {
                // Hide viewOnce blur and fire icon during upload/download to avoid double blur
                let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
                if isViewOnce {
                    fireIconContainerView.isHidden = true
                }
            }
            super.setProgress(progress)
            updatePlayButtonVisibility()
        }

        /// The play button and the transfer overlay share the centre of the thumbnail and are
        /// the same size (their dimensions are pinned to each other), so at most one of them
        /// may ever be on screen. `isTransferOverlayVisible` stays true for the whole
        /// shrink-out, which is what keeps the completed ring from being drawn under the play
        /// glyph on the last frames of a download.
        open func updatePlayButtonVisibility() {
            guard let data else { return }
            let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
            let isPlayable = data.attachment.status == .done
                || fileProvider.filePath(attachment: data.attachment) != nil
            let isHidden = isViewOnce || !isPlayable || isTransferOverlayVisible
            if isHidden {
                // A view recycled mid-pop would otherwise come back holding the shrunken
                // transform the reveal animates away from.
                playButton.transform = .identity
            }
            playButton.isHidden = isHidden
        }
        
        open override func didHideProgressView() {
            super.didHideProgressView()

            // Show viewOnce blur and fire icon again after upload/download completes
            let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
            fireIconContainerView.isHidden = !isViewOnce

            // The reveal runs here rather than in `willHideProgressView`: popping the play
            // button in as the ring starts shrinking put both in the middle of the thumbnail
            // for the length of that animation, with the ring still drawn at 100%.
            let wasHidden = playButton.isHidden
            updatePlayButtonVisibility()
            guard wasHidden, !playButton.isHidden else { return }
            UIView.performWithoutAnimation {
                playButton.transform = .init(scaleX: 0.01, y: 0.01)
            }
            UIView.animate(withDuration: progressView.animationDuration + 0.1) {
                self.playButton.transform = .init(scaleX: 1, y: 1)
            } completion: { _ in
                self.playButton.transform = .identity
            }
        }

        override open func update(status: ChatMessage.Attachment.TransferStatus) {
            super.update(status: status)

            // Hide fire icon when showing download/upload icons
            switch status {
            case .pauseDownloading, .failedDownloading, .pauseUploading, .failedUploading:
                fireIconContainerView.isHidden = true
            default:
                let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
                fireIconContainerView.isHidden = !isViewOnce
            }
            // A paused/failed download puts the overlay back on screen without going through
            // `setProgress`, so the play button has to be re-resolved from here too.
            updatePlayButtonVisibility()
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            progressViewHeightConstraint?.constant = min(56, bounds.height / 2)
            // Match the blur view's corner radius to the image view
            blurEffectView.layer.cornerRadius = 16.0
        }
    }
}
