//
//  MessageCell+ReactionTotalView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class ReactionTotalView: Control, MessageCellMeasurable {
        open lazy var stackView = UIStackView()
            .withoutAutoresizingMask

        public lazy var appearance = MessageCell.appearance
        
        override open func setup() {
            super.setup()
            stackView.distribution = .fill
            stackView.alignment = .leading
            stackView.axis = .vertical
            stackView.spacing = Measure.itemSpacingV
            stackView.isUserInteractionEnabled = false
            layer.cornerRadius = 16
            layer.cornerCurve = .continuous
            
            layer.shadowOffset = .init(width: 0, height: 4)
            layer.shadowRadius = 12
            layer.shadowOpacity = 1.0
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            layer.shadowColor = UIColor.darkGray.withAlphaComponent(0.3).cgColor
            backgroundColor = appearance.reactionContainerBackgroundColor
        }
    
        override open func layoutSubviews() {
            super.layoutSubviews()
            layer.shadowPath = UIBezierPath(
                roundedRect: layer.bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }

        override open func setupLayout() {
            super.setupLayout()
            let insets = Measure.contentInsets
            addSubview(stackView)
            stackView.pin(
                to: self,
                anchors: [.leading(insets.left), .trailing(-insets.right), .top(insets.top), .bottom(-insets.bottom)]
            )
        }
        
        open var data: MessageLayoutModel! {
            didSet {
                guard let groupedReactions = data.groupedReactions,
                      !groupedReactions.isEmpty,
                      data.estimatedReactionsNumberPerRow != 0
                else { return }
                
                func horizontalView() -> UIStackView {
                    let v = UIStackView()
                        .withoutAutoresizingMask
                    v.distribution = .fill
                    v.alignment = .leading
                    v.axis = .horizontal
                    v.spacing = Measure.itemSpacingH
                    return v
                }
                
                for (index, reactions) in groupedReactions.enumerated() {
                    let hv: UIStackView
                    if stackView.arrangedSubviews.indices.contains(index) {
                        hv = stackView.arrangedSubviews[index] as! UIStackView
                        hv.removeArrangedSubviews()
                    } else {
                        hv = horizontalView()
                        stackView.insertArrangedSubview(hv, at: index)
                    }
                    
                    for reaction in reactions {
                        let rLabel = Components.messageCellReactionLabel.init(key: reaction.key)
                            .withoutAutoresizingMask
                        hv.addArrangedSubview(rLabel)
                        
                        rLabel.resize(anchors: [.width(reaction.width), .height(Measure.emojiHeight)])
                    }
                }
                stackView.removeArrangedSubviews(stackView.arrangedSubviews.suffix(stackView.arrangedSubviews.count - groupedReactions.count))
            }
        }
        
        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            var size = CGSize.zero
            guard let reactions = model.reactions,
                  !reactions.isEmpty,
                  model.estimatedReactionsNumberPerRow != 0
            else { return size }
            
            var rows = 0
            var widths = [CGFloat](repeating: 0, count: model.estimatedReactionsNumberPerRow + 1)
            for index in 0 ..< reactions.count {
                widths[rows] += reactions[index].width + Measure.itemSpacingH
                if index != 0,
                   index % model.estimatedReactionsNumberPerRow == 0
                {
                    widths[rows] -= Measure.itemSpacingH
                    rows += 1
                }
            }
            
            size.width = (widths.max() ?? 0) + Measure.contentInsets.left + Measure.contentInsets.right
            if rows == 0 {
                size.height = Measure.emojiHeight
            } else {
                size.height = CGFloat(rows) * Measure.emojiHeight + (CGFloat(rows) - 1) * Measure.itemSpacingV
            }
            size.height += Measure.contentInsets.top + Measure.contentInsets.bottom
            return size
        }
    }
}

public extension MessageCell.ReactionTotalView {
    enum Measure {
        public static var contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        public static var emojiHeight = CGFloat(24)
        public static var emojiWidth = CGFloat(18)
        public static var itemSpacingH = CGFloat(8)
        public static var itemSpacingV = CGFloat(4)
    }
}
