//
//  MessageCell+LinkStackView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import LinkPresentation

extension MessageCell {

    open class LinkStackView: UIStackView, Measurable {
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open var onDidTapContentView: ((LinkView) -> Void)?

        public override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
            setupAppearance()
        }

        public required init(coder: NSCoder) {
            super.init(coder: coder)
            setup()
            setupAppearance()
        }

        private var isConfigured = false

        open override func willMove(toSuperview newSuperview: UIView?) {
            super.willMove(toSuperview: newSuperview)
            guard !isConfigured, newSuperview != nil else { return }
            isConfigured = true
            setupLayout()
        }

        func setup() {
            
        }
        
        func setupLayout() {
            
        }
        
        open func setupAppearance() {
            alignment = .center
            distribution = .fillProportionally
            axis = .vertical
            spacing = 4
        }

        open var data: MessageLayoutModel! {
            didSet {
                removeArrangedSubviews()
                guard let preview = data.linkPreviews?.first
                else { return }
                [preview].forEach {
                    let v = LinkView()
                        .withoutAutoresizingMask
                    addArrangedSubview(v)
                    v.leadingAnchor.pin(to: self.leadingAnchor, constant: 8)
                    v.trailingAnchor.pin(to: self.trailingAnchor, constant: -8)
                    let tap = UITapGestureRecognizer(target: self, action: #selector(openUrlAction(_:)))
                    v.addGestureRecognizer(tap)
                    v.data = $0
                    v.backgroundColor = data.message.incoming ?
                    appearance.linkPreviewBackgroundColor.in :
                    appearance.linkPreviewBackgroundColor.out
                }
            }
        }
       
        @objc
        open func openUrlAction(_ sender: UITapGestureRecognizer) {
            guard let linkView = sender.view as? LinkView else {
                return
            }
            onDidTapContentView?(linkView)
        }
        
        open class func measure(model: MessageLayoutModel, appearance: Appearance) -> CGSize {
            guard let linkPreview = model.linkPreviews?.first
            else { return .zero }
            
            let size = [linkPreview].reduce(CGSize.zero) { partialResult, preview in
                let size = LinkView.measure(model: preview, appearance: appearance)
                var result = partialResult
                result.width = max(result.width, size.width)
                if size.height > 0 {
                    result.height += 4 + size.height
                }
                return result
            }
            return size
        }
    }
}

extension MessageCell {

    open class LinkView: View, Measurable {
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var imageView = ImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityV(.required)

        open lazy var descriptionLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityV(.required)

        open private(set) var link: URL!
        
        open override func setup() {
            super.setup()
            imageView.clipsToBounds = true
            titleLabel.numberOfLines = 2
            descriptionLabel.numberOfLines = 3
            
        }

        open override func setupAppearance() {
            super.setupAppearance()
            titleLabel.font = appearance.linkTitleFont
            titleLabel.textColor = appearance.linkTitleColor
            descriptionLabel.font = appearance.linkDescriptionFont
            descriptionLabel.textColor = appearance.linkDescriptionColor
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(descriptionLabel)
            imageView.pin(to: self, anchors: [.top(6), .leading(6), .trailing(-6)])
            titleLabel.pin(to: self, anchors: [.leading(6), .trailing(-6)])
            descriptionLabel.pin(to: self, anchors: [.leading(6), .trailing(-6)])
            titleLabel.topAnchor.pin(to: imageView.bottomAnchor, constant: 6)
            descriptionLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 2)
            descriptionLabel.bottomAnchor.pin(to: self.bottomAnchor, constant: -6)
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = 16
        }
        
        open var data: MessageLayoutModel.LinkPreview! {
            didSet {
                imageView.image = data.image
                titleLabel.attributedText = data.title
                descriptionLabel.attributedText = data.description
                link = data.url
            }
        }

        open class func measure(model: MessageLayoutModel.LinkPreview, appearance: Appearance) -> CGSize {
            var size = CGSize()
            if let image = model.image {
                size.width = min(max(model.imageOriginalSize?.width ?? 0, image.size.width), 260)
                size.height = min(max(model.imageOriginalSize?.height ?? 0, image.size.height), 140)
            } else {
                size.width = max(model.titleSize.width, model.descriptionSize.width)
            }
            size.height += model.titleSize.height //size name
            size.height += model.descriptionSize.height // desc
            if size.height > 0 {
                size.height += 20 // padding
            }
            return size
        }
    }
}

