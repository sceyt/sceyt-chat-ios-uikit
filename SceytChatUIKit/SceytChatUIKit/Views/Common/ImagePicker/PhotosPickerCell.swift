//
//  PhotosPickerCell.swift
//  SceytChatUIKit
//

import UIKit
import Photos

open class PhotosPickerCell: CollectionViewCell {
    
    public static var scale: CGFloat = UIScreen.main.scale
    
    open var indexPath: IndexPath? {
        didSet {
            loadPhotoAssetIfNeeded()
        }
    }
    
    open var data: PHAsset! {
        didSet {
            loadPhotoAssetIfNeeded()
        }
    }
    
    open var size = CGSize(width: 50, height: 50)
    
    private var imageRequestID: PHImageRequestID?
    
    open lazy var imageView = UIImageView()
        .contentMode(.scaleAspectFill)
        .withoutAutoresizingMask
    
    open lazy var checkBoxView = Components.checkBoxView
        .init()
        .withoutAutoresizingMask
    
    open lazy var timeLabel = Components.timeLabel
        .init()
        .withoutAutoresizingMask
    
    open override func setup() {
        super.setup()
        checkBoxView.clipsToBounds = true
        checkBoxView.selectedImage = .galleryAssetSelect
        checkBoxView.unselectedImage = .galleryAssetUnselect
        checkBoxView.isUserInteractionEnabled = false
        imageView.clipsToBounds = true
        timeLabel.clipsToBounds = true
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        timeLabel.backgroundColor = appearance.timeBackgroundColor
        timeLabel.textLabel.font = appearance.timeTextFont
        timeLabel.textLabel.textColor = appearance.timeTextColor
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(imageView)
        contentView.addSubview(checkBoxView)
        contentView.addSubview(timeLabel)
        imageView.pin(to: contentView)
        checkBoxView.pin(to: contentView, anchors: [.top(7), .trailing(-7)])
        checkBoxView.resize(anchors: [.width(22), .height(22)])
        timeLabel.pin(to: contentView, anchors: [.trailing(-8), .bottom(-6)])
    }
    
    open override var isSelected: Bool {
        didSet {
            checkBoxView.isSelected = isSelected
        }
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        
        timeLabel.isHidden = true
        
        let manager = PHImageManager.default()
        guard let imageRequestID = self.imageRequestID else { return }
        manager.cancelImageRequest(imageRequestID)
        self.imageRequestID = nil
        isSelected = false
    }
    
    private func loadPhotoAssetIfNeeded() {
        guard let indexPath = self.indexPath,
            let asset = data
        else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        if asset.duration > 0 {
            timeLabel.isHidden = false
            timeLabel.text = Formatters.videoAssetDuration.format(asset.duration)
        } else {
            timeLabel.isHidden = true
        }
        
        let manager = PHImageManager.default()
        let newSize = CGSize(width: size.width * Self.scale,
                             height: size.height * Self.scale)
        imageRequestID = manager
            .requestImage(
                for: asset,
                targetSize: newSize,
                contentMode: .aspectFill,
                options: options,
                resultHandler: { [weak self] (result, _) in
            guard self?.indexPath?.item == indexPath.item else { return }
            self?.imageRequestID = nil
            self?.imageView.image = result
        })
    }
}
