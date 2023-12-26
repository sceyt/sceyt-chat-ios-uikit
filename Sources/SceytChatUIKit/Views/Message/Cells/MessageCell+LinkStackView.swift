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
                guard let previews = data.linkPreviews, !previews.isEmpty else { return }
                previews.forEach {
                    let v = LinkView()
                        .withoutAutoresizingMask
                    addArrangedSubview(v)
                    v.widthAnchor.pin(to: widthAnchor)
                    let tap = UITapGestureRecognizer(target: self, action: #selector(openUrlAction(_:)))
                    v.addGestureRecognizer(tap)
                    v.data = $0
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
            guard let linkPreviews = model.linkPreviews,
                  !linkPreviews.isEmpty
            else { return .zero }
            
            let size = linkPreviews.reduce(CGSize.zero) { partialResult, preview in
                let size = LinkView.measure(model: preview, appearance: appearance)
                var result = partialResult
                result.width = max(result.width, size.width)
                result.height += 4 + size.height
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
            titleLabel.numberOfLines = 1
            descriptionLabel.numberOfLines = 2
            
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
            imageView.pin(to: self, anchors: [.bottom, .leading(2), .trailing(-2)])
            titleLabel.pin(to: self, anchors: [.leading(12), .trailing(-12)])
            descriptionLabel.pin(to: self, anchors: [.leading(12), .trailing(-12)])
            titleLabel.topAnchor.pin(to: self.topAnchor)
            descriptionLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 2)
            descriptionLabel.bottomAnchor.pin(to: imageView.topAnchor, constant: -6)
        }
        
        open var data: MessageLayoutModel.LinkPreview! {
            didSet {
                imageView.image = data.image// ?? data.icon
                titleLabel.attributedText = data.title
                descriptionLabel.attributedText = data.description
                link = data.url
            }
        }

        open class func measure(model: MessageLayoutModel.LinkPreview, appearance: Appearance) -> CGSize {
            var size = CGSize()
            if let image = model.image ?? model.icon {
                size.width = min(image.size.width, 260)
                size.height = min(image.size.height, 140)
            } else {
                size.width = max(model.titleSize.width, model.descriptionSize.width)
            }
            size.height += model.titleSize.height //size name
            size.height += model.descriptionSize.height // desc
            size.height += 8 // padding
            return size
        }
    }
}

