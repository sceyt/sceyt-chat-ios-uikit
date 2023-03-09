//
//  ChatToolbarMediaView.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 12/14/20.
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit

open class ChatToolbarMediaView: View {

    open lazy var scrollView = UIScrollView()
        .withoutAutoresizingMask

    open lazy var stackView =  UIStackView()
        .withoutAutoresizingMask

    open var onDelete: ((AttachmentView) -> Void)?

    open private(set) var thumbnails = [AttachmentView]()

    open override func setupAppearance() {
        super.setupAppearance()
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        stackView.alignment = .center
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 2
    }

    open override func setupLayout() {
        super.setupLayout()
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.pin(to: self)
        stackView.pin(to: scrollView)
    }

    open func append(view: AttachmentView) {
        thumbnails.append(view)

        let view = ThumbnailView(image: view.thumbnail)
            .withoutAutoresizingMask
        stackView.addArrangedSubview(view)
        view.resize(anchors: [.width(58), .height(57)])
        view.onDelete = {[unowned self] view in
            if let index = stackView.arrangedSubviews.firstIndex(of: view) {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveLinear) {
                    view.transform = .init(scaleX: 0.1, y: 1)
                    view.alpha = 0
                } completion: {[weak self ] _ in
                    guard let self = self else { return }
                    self.stackView.removeArrangedSubview(view)
                    view.removeFromSuperview()
                    self.onDelete?(self.thumbnails.remove(at: index))
                }
            }
        }
    }

    open func removeAll() {
        thumbnails.removeAll()
        stackView.removeArrangedSubviews()
    }
}

extension ChatToolbarMediaView {

    open class ThumbnailView: View {

        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)

        open lazy var closeButton = UIButton()
            .withoutAutoresizingMask

        open var onDelete: ((ThumbnailView) -> Void)?

        public init(image: UIImage) {
            super.init(frame: .zero)
            imageView.image = image

        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        open override func setup() {
            super.setup()
            closeButton.addTarget(self, action: #selector(deleteAction), for: .touchUpInside)
        }

        open override func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true
            closeButton.setImage(appearance.images.closeImage, for: .normal)
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(closeButton)
            imageView.pin(to: self, anchors: [.top(5), .centerX(-3.5)])
            imageView.widthAnchor.pin(constant: 50)
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
            closeButton.pin(to: self, anchors: [.top(), .trailing()])
        }

        @objc
        open func deleteAction() {
            onDelete?(self)
        }
    }
}
