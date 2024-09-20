//
//  MediaPickerViewController+MediaCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import UIKit

extension MediaPickerViewController {
    open class MediaCell: CollectionViewCell {
        public static var scale: CGFloat = UIScreen.main.traitCollection.displayScale
        
        open var data: (manager: PHCachingImageManager, asset: PHAsset, thumbnailSize: CGSize)! {
            didSet {
                loadPhotoAssetIfNeeded()
            }
        }
        
        private var imageRequestID: PHImageRequestID?
        private var assetIdentifier: String?
        
        open lazy var imageView = UIImageView()
            .contentMode(.scaleAspectFill)
            .withoutAutoresizingMask
        
        open lazy var checkBoxView = Components.checkBoxView
            .init()
            .withoutAutoresizingMask
        
        open lazy var timeLabel = Components.timeLabel
            .init()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            checkBoxView.clipsToBounds = true
            checkBoxView.isUserInteractionEnabled = false
            imageView.clipsToBounds = true
            timeLabel.clipsToBounds = true
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            timeLabel.backgroundColor = appearance.timeBackgroundColor
            timeLabel.textLabel.font = appearance.timeTextFont
            timeLabel.textLabel.textColor = appearance.timeTextColor
            checkBoxView.selectedImage = .radioSelected
            checkBoxView.unselectedImage = .radioGray
        }
        
        override open func setupLayout() {
            super.setupLayout()
            contentView.addSubview(imageView)
            contentView.addSubview(checkBoxView)
            contentView.addSubview(timeLabel)
            imageView.pin(to: contentView)
            checkBoxView.pin(to: contentView, anchors: [.top(7), .trailing(-7)])
            checkBoxView.contentInsets = .zero
            checkBoxView.resize(anchors: [.width(24), .height(24)])
            timeLabel.pin(to: contentView, anchors: [.trailing(-8), .bottom(-6)])
        }
        
        override open var isSelected: Bool {
            didSet {
                checkBoxView.isSelected = isSelected
            }
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            imageView.image = nil
            
            timeLabel.isHidden = true
            
            let manager = PHImageManager.default()
            guard let imageRequestID = imageRequestID else { return }
            manager.cancelImageRequest(imageRequestID)
            self.imageRequestID = nil
            isSelected = false
        }
        
        private func loadPhotoAssetIfNeeded() {
            guard let data else { return }
            
            if data.asset.duration > 0 {
                timeLabel.isHidden = false
                timeLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(data.asset.duration)
            } else {
                timeLabel.isHidden = true
            }
            
            assetIdentifier = data.asset.localIdentifier
            imageRequestID = data.manager
                .requestImage(
                    for: data.asset,
                    targetSize: data.thumbnailSize,
                    contentMode: .aspectFill,
                    options: nil,
                    resultHandler: { [weak self] result, _ in
                        guard self?.assetIdentifier == data.asset.localIdentifier else { return }
                        self?.imageView.image = result
                        self?.imageRequestID = nil
                    })
        }
    }
}
