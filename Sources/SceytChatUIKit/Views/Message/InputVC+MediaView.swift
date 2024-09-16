//
//  InputVC+MediaView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import CoreServices
import Photos
import UIKit

extension InputVC {
    open class MediaView: View {
        public static var scale: CGFloat = SceytChatUIKit.shared.config.displayScale
        
        public lazy var appearance = InputVC.appearance {
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
                let fv = Components.inputThumbnailViewFileView.init()
                    .withoutAutoresizingMask
                fv.imageView.image = view.thumbnail
                v = fv
            default:
                let mv = Components.inputThumbnailViewMediaView.init()
                    .withoutAutoresizingMask
                mv.imageView.image = view.thumbnail
                v = mv
            }
            _onUpdate?()
            let tv = Components.inputThumbnailView
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
                            mv?.timeLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(duration)
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
                mv?.timeLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(Double(view.duration))
            } else if view.type == .file {
                fv?.titleLabel.text = view.name
                fv?.subtitleLabel.text = SceytChatUIKit.shared.formatters.fileSizeFormatter.format(UInt64(view.fileSize))
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
