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

    open class LinkStackView: UIStackView {

        open var provider: LinkMetadataProvider!
        open var layoutModel: MessageLayoutModel!

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
                    v.bind($0)
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
    }
}

extension MessageCell {

    open class LinkView: View, Bindable {

        open lazy var imageView = ImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentHuggingPriorityV(.required)

        open lazy var descriptionLabel = UILabel()
            .withoutAutoresizingMask
            .contentHuggingPriorityV(.required)

        open private(set) var link: URL!

        open override func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true
            titleLabel.numberOfLines = 1
            descriptionLabel.numberOfLines = 3
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(descriptionLabel)
            imageView.pin(to: self, anchors: [.top(), .trailing(), .leading()])
            titleLabel.pin(to: self, anchors: [.leading(8), .trailing()])
            descriptionLabel.pin(to: self, anchors: [.leading(8), .trailing(0)])
            titleLabel.topAnchor.pin(to: imageView.bottomAnchor, constant: 2)
            descriptionLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 2)
            descriptionLabel.bottomAnchor.pin(to: bottomAnchor, constant: 2)
        }

        open func bind(_ data: MessageLayoutModel.LinkPreview) {
            imageView.image = data.image
            titleLabel.attributedText = data.title
            descriptionLabel.attributedText = data.description
            link = data.url
        }
    }
}
