//
//  ComposerVC+MediaView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import CoreServices
import Photos
import UIKit

extension ComposerVC {
    open class MediaView: View {
        public static var scale: CGFloat = Config.displayScale
        
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var imageRequestOptions: PHImageRequestOptions = {
            $0.deliveryMode = .highQualityFormat
            $0.resizeMode = .fast
            $0.isSynchronous = false
            return $0
        }(PHImageRequestOptions())
        
        open lazy var imageManager = PHImageManager.default()
        
        open lazy var scrollView = UIScrollView()
            .withoutAutoresizingMask

        open lazy var stackView = UIStackView()
            .withoutAutoresizingMask

        var _onDelete: ((AttachmentView) -> Void)?
        var _onUpdate: (() -> Void)?

        override open func setup() {
            super.setup()
            scrollView.alwaysBounceVertical = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.contentInset = .init(top: 0, left: 12, bottom: 0, right: 12)
            stackView.alignment = .center
            stackView.axis = .horizontal
            stackView.distribution = .fill
            stackView.spacing = 4
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(scrollView)
            scrollView.addSubview(stackView)
            scrollView.pin(to: self)
            stackView.pin(to: scrollView)
            stackView.heightAnchor.pin(to: scrollView.heightAnchor)
        }

        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.mediaViewBackgroundColor
        }

        open private(set) var items = [AttachmentView]()
        private var imageRequestIDs = [PHImageRequestID]()

        open func insert(view: AttachmentView, at index: Int = -1) {
            if index != -1, items.indices.contains(index) {
                items.insert(view, at: index)
            } else {
                items.append(view)
            }
            let v: View!
            switch view.type {
            case .file:
                let fv = ThumbnailView.FileView()
                    .withoutAutoresizingMask
                fv.imageView.image = view.thumbnail
                v = fv
            default:
                let mv = ThumbnailView.MediaView()
                    .withoutAutoresizingMask
                mv.imageView.image = view.thumbnail
                v = mv
            }
            _onUpdate?()
            let tv = Components.composerAttachmentThumbnailView
                .init(containerView: v)
                .withoutAutoresizingMask
            if index != -1, stackView.arrangedSubviews.indices.contains(index) {
                stackView.insertArrangedSubview(tv, at: index)
            } else {
                stackView.addArrangedSubview(tv)
            }
            
            v.topAnchor.pin(to: stackView.topAnchor, constant: 8)
            v.bottomAnchor.pin(to: stackView.bottomAnchor, constant: -8)
            tv.onDelete = { [unowned self] v in
                if let index = stackView.arrangedSubviews.firstIndex(of: v) {
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveLinear) {
                        v.transform = .init(scaleX: 0.1, y: 1)
                        v.alpha = 0
                    } completion: { [weak self] _ in
                        guard let self = self else { return }
                        self.stackView.removeArrangedSubview(v)
                        v.removeFromSuperview()
                        self._onDelete?(self.items.remove(at: index))
                        self._onUpdate?()
                    }
                }
            }
            let mv = v as? ThumbnailView.MediaView
            let fv = v as? ThumbnailView.FileView
            if let asset = view.photoAsset {
                if asset.duration > 0 {
                    imageManager.requestAVAsset(forVideo: asset, options: .none) { avAsset, _, _ in
                        guard let avAsset else { return }
                        
                        var duration = asset.duration
                        if avAsset.isSlowMotionVideo, let slowMoDuration = (avAsset as? AVComposition)?.slowMoDuration {
                            duration = slowMoDuration
                        }
                        DispatchQueue.main.async {
                            mv?.timeLabel.isHidden = false
                            mv?.timeLabel.text = Formatters.videoAssetDuration.format(duration)
                        }
                    }
                }
                let newSize = CGSize(width: 56 * Self.scale,
                                     height: 56 * Self.scale)
                imageRequestIDs += [
                    imageManager
                        .requestImage(
                            for: asset,
                            targetSize: newSize,
                            contentMode: .aspectFit,
                            options: imageRequestOptions,
                            resultHandler: { [weak mv] result, _ in
                                mv?.imageView.image = result
                            })
                ]
            } else if view.duration > 0 {
                mv?.timeLabel.isHidden = false
                mv?.timeLabel.text = Formatters.videoAssetDuration.format(Double(view.duration))
            } else if view.type == .file {
                fv?.titleLabel.text = view.name
                fv?.subtitleLabel.text = Formatters.fileSize.format(view.fileSize)
            }
        }

        open func removeAll() {
            items.removeAll()
            imageRequestIDs.forEach {
                imageManager.cancelImageRequest($0)
            }
            _onUpdate?()
            stackView.removeArrangedSubviews()
        }
        
        deinit {
            imageRequestIDs.forEach {
                imageManager.cancelImageRequest($0)
            }
        }
    }
}

extension ComposerVC {
    open class ThumbnailView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var closeButton = UIButton()
            .withoutAutoresizingMask
                
        public let containerView: View
        
        public required init(containerView: View) {
            self.containerView = containerView
            super.init(frame: .zero)
        }
        
        @available(*, unavailable)
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override open func setup() {
            super.setup()
            closeButton.setImage(Images.closeCircle, for: .normal)
            closeButton.addTarget(self, action: #selector(deleteAction), for: .touchUpInside)
        }

        override open func setupAppearance() {
            super.setupAppearance()
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(containerView)
            addSubview(closeButton)
            containerView.pin(to: self, anchors: [.leading(0), .top(6), .trailing(-6), .bottom()])
            closeButton.pin(to: self, anchors: [.top(), .trailing()])
        }

        open var onDelete: ((ThumbnailView) -> Void)?

        @objc
        open func deleteAction() {
            onDelete?(self)
        }
    }
}

extension ComposerVC.ThumbnailView {
    open class MediaView: View {
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var timeLabel = TimeLabel()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            timeLabel.isHidden = true
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(timeLabel)
            imageView.pin(to: self)
            timeLabel.pin(to: self, anchors: [.leading(0, .greaterThanOrEqual), .bottom(-4), .trailing(-4)])
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
        }
    }
}

extension ComposerVC.ThumbnailView {
    open class FileView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var subtitleLabel = UILabel()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            clipsToBounds = true
            layer.cornerRadius = 8
            titleLabel.lineBreakMode = .byTruncatingMiddle
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.fileAttachmentBackgroundColor
            titleLabel.textColor = appearance.fileAttachmentTitleTextColor
            titleLabel.font = appearance.fileAttachmentTitleTextFont
            subtitleLabel.textColor = appearance.fileAttachmentSubtitleTextColor
            subtitleLabel.font = appearance.fileAttachmentSubtitleTextFont
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(subtitleLabel)
            imageView.pin(to: self, anchors: [.top(12, .greaterThanOrEqual), .bottom(-12, .lessThanOrEqual), .leading(12)])
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
            imageView.heightAnchor.pin(constant: 46)
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            titleLabel.pin(to: self, anchors: [.top(12, .greaterThanOrEqual), .trailing(-21, .lessThanOrEqual)])
            titleLabel.bottomAnchor.pin(to: imageView.centerYAnchor)
            titleLabel.widthAnchor.pin(lessThanOrEqualToConstant: 120)
            subtitleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            subtitleLabel.pin(to: self, anchors: [.bottom(-12, .lessThanOrEqual), .trailing(-21, .lessThanOrEqual)])
            subtitleLabel.topAnchor.pin(to: imageView.centerYAnchor, constant: 4)
        }
    }
}

extension ComposerVC.ThumbnailView {
    open class TimeLabel: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var timeLabel: UILabel = {
            $0.font = Fonts.regular.withSize(12)
            return $0.withoutAutoresizingMask
        }(UILabel())
        
        override open func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.videoAttachmentTimeBackgroundColor
            timeLabel.font = appearance.videoAttachmentTimeTextFont
            timeLabel.textColor = appearance.videoAttachmentTimeTextColor
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(timeLabel)
            timeLabel.pin(to: self, anchors: [.leading(6), .top(3), .bottom(-3), .trailing(-6)])
        }
        
        var text: String? {
            set { timeLabel.text = newValue }
            get { timeLabel.text }
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
    }
}
