//
//  ChannelMediaImageCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelMediaImageCell: CollectionViewCell {
    open lazy var imageView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)

    override open func setup() {
        super.setup()
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(imageView)
        imageView.pin(to: contentView)
    }

    open var data: ChatMessage.Attachment! {
        didSet {
            DispatchQueue.global().async { [weak self] in
                guard let self,
                      var data = self.data
                else { return }

                var _image: UIImage?

                let itemSize = CGSize(width: Int((UIScreen.main.bounds.width - 16) / 3),
                                      height: Int((UIScreen.main.bounds.width - 16) / 3))
                if let path = fileProvider.thumbnailFile(for: data, preferred: itemSize) {
                    _image = UIImage(contentsOfFile: path)
                } else if let data = data.imageDecodedMetadata?.thumbnailData {
                    _image = UIImage(data: data)
                } else if let thumbnail = data.imageDecodedMetadata?.thumbnail,
                          let image = Components.imageBuilder.image(from: thumbnail)
                {
                    _image = image
                }
                DispatchQueue.main.async { [weak self] in
                    if self?.data == data {
                        self?.imageView.image = _image
                    }
                }
            }
        }
    }

    open var previewer: AttachmentPreviewDataSource? {
        didSet {
            imageView.setup(
                previewer: previewer,
                item: PreviewItem.attachment(data)
            )
        }
    }
}
