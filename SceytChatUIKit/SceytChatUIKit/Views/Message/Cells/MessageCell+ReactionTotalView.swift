//
//  MessageCell+ReactionTotalView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageCell {

    open class ReactionTotalView: Control {

        enum Defaults {
            static let contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
            static let emojiHeight: CGFloat = 26
            static let emojiWidth: CGFloat = 24
            static let hInterItemSpacing: CGFloat = 8
        }
        
        open lazy var stackView = UIStackView()
            .withoutAutoresizingMask

        public lazy var appearance = MessageCell.appearance
        
        open override func setupAppearance() {
            super.setupAppearance()
            addTarget(self, action: #selector(onTap), for: .touchUpInside)
            stackView.distribution = .fill
            stackView.alignment = .leading
            stackView.axis = .vertical
            stackView.spacing = 6
            stackView.isUserInteractionEnabled = false
            backgroundColor = appearance.reactionContainerBackgroundColor
            layer.cornerRadius = 16
            layer.cornerCurve = .continuous
            layer.shadowColor = UIColor.darkGray.withAlphaComponent(0.3).cgColor
            layer.shadowOffset = .init(width: 0, height: 4)
            layer.shadowRadius = 12
            layer.shadowOpacity = 1.0
        }
    
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.shadowPath = UIBezierPath(
                roundedRect: layer.bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }

        open override func setupLayout() {
            super.setupLayout()
            let insets = Defaults.contentInsets
            addSubview(stackView)
            stackView.pin(
                to: self,
                anchors: [.leading(insets.left), .trailing(-insets.right), .top(insets.top)]
            )
            stackView.bottomAnchor.pin(to: bottomAnchor, constant: -insets.bottom)//.priority(.defaultLow)
        }
        open var data: MessageLayoutModel! {
            didSet {
                stackView.removeArrangedSubviews()
                guard let reactions = data.reactions, !reactions.isEmpty, data.estimatedReactionsNumberPerRow != 0 else {
                    return
                }
                
                func horizontalView() -> UIStackView {
                    let v = UIStackView().withoutAutoresizingMask
                    v.distribution = .fill
                    v.alignment = .leading
                    v.axis = .horizontal
                    v.spacing = Defaults.hInterItemSpacing
                    return v
                }
                
                var v: UIStackView!
                for index in 0 ..< reactions.count {
                    if index % data.estimatedReactionsNumberPerRow == 0 {
                        v = horizontalView()
                        stackView.addArrangedSubview(v)
                    }
                    let r = reactions[index]
                    let rLabel = ReactionLabel.init(key: r.key, isScore: r.isCommonScoreNumber)
                    rLabel.appearance = appearance
                    v.addArrangedSubview(rLabel)
                    rLabel.resize(anchors: [.width(r.width), .height(Defaults.emojiHeight)])
                }
            }
        }
    
        var onAction: (() -> Void)?
        
        @objc
        func onTap() {
            onAction?()
        }
    }

}
extension MessageCell {
    
    open class ReactionLabel: UILabel {

        public let key: String
        public let isScore: Bool

        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        public required init(key: String, isScore: Bool) {
            self.key = key
            self.isScore = isScore
            super.init(frame: .zero)
        }

        public required init?(coder: NSCoder) {
            key = ""
            isScore = false
            super.init(coder: coder)
        }
        
        open func setupAppearance() {
            text = key
            textAlignment = .center
            font = isScore ? appearance.reactionCommonScoreFont : appearance.reactionFont
            textColor = appearance.reactionColor
        }
    }

}
