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
                guard let data,
                        let preview = data.linkPreviews?.first
                else { return }
                [preview].forEach {
                    let v = Components.messageCellLinkView.init()
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
                let size = Components.messageCellLinkView.measure(model: preview, appearance: appearance)
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
