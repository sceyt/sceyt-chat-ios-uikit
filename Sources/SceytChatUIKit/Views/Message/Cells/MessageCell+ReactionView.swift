//
//  MessageCell+ReactionsView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class ReactionsView: View {
        open lazy var stackView = UIStackView(column: [], spacing: 8, distribution: .fill, alignment: .leading)
            .withoutAutoresizingMask

        public lazy var appearance = MessageCell.appearance

        override open func setupAppearance() {
            super.setupAppearance()
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(stackView)
            stackView.pin(to: self)
        }

        open var data: MessageLayoutModel! {
            didSet {
                stackView.removeArrangedSubviews()
                guard let reactions = data.reactions, !reactions.isEmpty else {
                    return
                }

                func horizontalView() -> UIStackView {
                    let v = UIStackView().withoutAutoresizingMask
                    v.distribution = .fill
                    v.alignment = .leading
                    v.axis = .horizontal
                    v.spacing = 8
                    return v
                }

                var v: UIStackView!
                for index in 0 ..< reactions.count {
                    if index % 5 == 0 {
                        v = horizontalView()
                        stackView.addArrangedSubview(v)
                    }
                    let r = reactions[index]
                    let rv = ReactionView(key: r.key, score: r.score, byMe: r.byMe)
                    rv.appearance = appearance
                    v.addArrangedSubview(rv)
                    rv.resize(anchors: [.width(40), .height(28)])
                    rv.onSelectAction = { [weak self] a in
                        self?.onAction?(.score(a.key, a.score, a.byMe))
                    }
                }
                let rv = AddReactionView()
                v.addArrangedSubview(rv)
                rv.resize(anchors: [.width(40), .height(28)])
                rv.addTarget(self, action: #selector(addReactionAction(_:)), for: .touchUpInside)
                if data.message.incoming {
                    v.addArrangedSubview(UIView())
                } else {
                    let c = v.arrangedSubviews.count
                    let w = (6 - c) * 40 + (6 - c) * 6
                    guard w > 0 else { return }
                    let space = UIView()
                    v.insertArrangedSubview(space, at: 0)
                    space.widthAnchor.pin(constant: CGFloat(w))
                }
            }
        }

        @objc
        func addReactionAction(_ sender: AddReactionView) {
            onAction?(.new)
        }

        var onAction: ((Action) -> Void)?
        private(set) var reactionScores = [(key: String, score: UInt)]()
    }
}

public extension MessageCell.ReactionsView {
    enum Action {
        case new
        case delete(String)
        case score(String, UInt, Bool)
    }
}

extension MessageCell {
    open class ReactionView: Button {
        public let key: String
        public let score: UInt
        public let byMe: Bool

        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        public var onSelectAction: (((key: String, score: UInt, byMe: Bool)) -> Void)?

        public required init(key: String, score: UInt, byMe: Bool) {
            self.key = key
            self.score = score
            self.byMe = byMe
            super.init(frame: .zero)
        }

        public required init?(coder: NSCoder) {
            key = ""
            score = 0
            byMe = false
            super.init(coder: coder)
        }

        override open func setup() {
            super.setup()
            addTarget(self, action: #selector(selectAction), for: .touchUpInside)
        }

        override open func setupAppearance() {
            super.setupAppearance()
            setTitle(key + " " + String(score), for: .normal)
            titleLabel?.textAlignment = .center
            titleLabel?.font = appearance.reactionFont
            setTitleColor(appearance.reactionColor, for: .normal)
            layer.cornerRadius = 12
            layer.borderWidth = 1
            _setCGColors()
            backgroundColor = (byMe ? appearance.reactionBackgroundColor.out : appearance.reactionBackgroundColor.in)
        }

        private func _setCGColors() {
            layer.borderColor = (byMe ? appearance.reactionBorderColor.out?.cgColor : appearance.reactionBorderColor.in?.cgColor)
        }

        @objc
        open func selectAction() {
            onSelectAction?((key, score, byMe))
        }

        override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            _setCGColors()
        }
    }

    open class AddReactionView: Button {
        override open func setupAppearance() {
            super.setupAppearance()
            setImage(.messageActionReact, for: .normal)
        }
    }
}
