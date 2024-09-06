//
//  MessageCell+ReplyView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageCell {

    open class ReplyView: Control, MessageCellMeasurable {

        open lazy var nameLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var imageView = UIImageView()
            .contentMode(.scaleAspectFill)
            .withoutAutoresizingMask
        
        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask

        open lazy var borderView = UIView()
            .withoutAutoresizingMask

        open lazy var stackViewV = UIStackView()
            .withoutAutoresizingMask

        open lazy var stackViewH = UIStackView()
            .withoutAutoresizingMask
        
        open lazy var stackViewH2 = UIStackView()
            .withoutAutoresizingMask
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setup() {
            super.setup()
            stackViewV.isUserInteractionEnabled = false
            stackViewH.isUserInteractionEnabled = false
            stackViewH2.isUserInteractionEnabled = false
            borderView.isUserInteractionEnabled = false
            
            stackViewV.distribution = .fill
            stackViewV.alignment = .leading
            stackViewV.axis = .vertical

            stackViewH.distribution = .fill
            stackViewH.alignment = .center
            stackViewH.axis = .horizontal
            
            stackViewH2.distribution = .fill
            stackViewH2.alignment = .leading
            stackViewH2.axis = .horizontal
            stackViewH2.spacing = 2
            
            messageLabel.lineBreakMode = .byTruncatingTail
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 4

            borderView.clipsToBounds = true
            borderView.layer.cornerRadius = 2
        }
       
        open override func setupLayout() {
            super.setupLayout()
            addSubview(stackViewH)
            stackViewH.addArrangedSubview(borderView)
            stackViewH.addArrangedSubview(stackViewV)
            stackViewV.addArrangedSubview(nameLabel)
            stackViewH2.addArrangedSubview(messageLabel)
            stackViewV.addArrangedSubview(stackViewH2)
            stackViewH.setCustomSpacing(8, after: borderView)
            stackViewH.pin(to: self, anchors: [.leading(0), .trailing(-8), .top(8), .bottom(-8)])
            borderView.resize(anchors: [.width(2)])
            borderView.heightAnchor.pin(to: self.heightAnchor)
            stackViewV.heightAnchor.pin(to: stackViewH.heightAnchor)
        }

        open override func setupAppearance() {
            super.setupAppearance()
            isHidden = true

            nameLabel.font = appearance.replyUserTitleFont
            nameLabel.textColor = appearance.replyUserTitleColor

            messageLabel.font = appearance.replyMessageFont
            messageLabel.textColor = appearance.replyMessageColor
            
            borderView.backgroundColor = appearance.replyMessageBorderColor
        }

        open var data: MessageLayoutModel.ReplyLayout? {
            didSet {
                stackViewH.removeArrangedSubview(imageView)
                stackViewH2.removeArrangedSubview(iconView)
                imageView.removeFromSuperview()
                iconView.removeFromSuperview()
                imageView.image = nil
                NSLayoutConstraint.deactivate(imageView.constraints)
                
                guard let data = data else {
                    isHidden = true
                    return
                }
                isHidden = false
                backgroundColor = data.byMe ? appearance.replyBackgroundColor.out : appearance.replyBackgroundColor.in
                layer.cornerRadius = Layouts.cornerRadius
                layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                layer.masksToBounds = true
                nameLabel.text = SceytChatUIKit.shared.formatters.userNameFormatter.format(data.user)
                messageLabel.attributedText = data.attributedBody
                if let image = data.icon {
                    stackViewH2.insertArrangedSubview(iconView, at: 0)
                    iconView.image = image
                    iconView.addConstraints([
                        iconView.heightAnchor.pin(constant: Measure.iconSize.height),
                        iconView.widthAnchor.pin(constant: Measure.iconSize.width)
                    ])
                } else {
                    iconView.image = nil
                }
                messageLabel.numberOfLines = 2
                stackViewV.distribution = .fill
                guard let attachment = data.attachment
                else { return }
                imageView.image = attachment.thumbnail
                guard imageView.image != nil else { return }
                messageLabel.numberOfLines = 1
                stackViewV.distribution = .fillEqually
                stackViewH.insertArrangedSubview(imageView, at: 1)
                stackViewH.setCustomSpacing(8, after: imageView)
                imageView.addConstraints([
                    imageView.heightAnchor.pin(constant: Measure.imageSize.height),
                    imageView.widthAnchor.pin(constant: Measure.imageSize.width)
                ])
                setProgressHandler()
            }
        }
        
        open func setProgressHandler() {
            guard let data = data,
                  let attachment = data.attachment
            else { return }
            let message = data.message
            fileProvider
                .progress(
                    message: message,
                    attachment: attachment.attachment,
                    objectIdKey: attachment.attachment.description + "reply"
                ) { _ in
                    
                } completion: { [weak self] done in
                    data.updateAttachment(message: done.message)
                    guard self?.data?.attachment?.attachment.id == data.attachment?.attachment.id
                    else { return }
                    if done.error == nil {
                        fileProvider.removeProgressObserver(message: done.message, attachment: done.attachment)
                    }
                    data.attachment?.update(attachment: done.attachment)
                    DispatchQueue.main.async {[weak self] in
                        self?.imageView.image = data.attachment?.thumbnail
                    }
                }
        }
        
        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            guard let data = model.replyLayout else { return .zero }
            
            var space = 0.0
            var iconSize = data.icon == nil ? .zero : Measure.iconSize
            if iconSize != .zero {
                iconSize.width += 2
            }
            var thumbnailSize = data.attachment?.thumbnail == nil ? .zero : Measure.imageSize
            if thumbnailSize != .zero {
                thumbnailSize.width += 8
            }
            
            space = iconSize.width + thumbnailSize.width
            if space == 0 {
                space = 10
            }
            var config = TextSizeMeasure.Config(maximumNumberOfLines: 1, lastFragmentUsedRect: false)
            config.font = appearance.replyUserTitleFont
            config.restrictingWidth = MessageLayoutModel.defaults.messageWidth - thumbnailSize.width
            let user = SceytChatUIKit.shared.formatters.userNameFormatter.format(data.user)
            let nameLabelSize = TextSizeMeasure.calculateSize(of: user, config: config).textSize
            
            config.font = appearance.replyMessageFont
            config.restrictingWidth = MessageLayoutModel.defaults.messageWidth - space
            config.maximumNumberOfLines = data.attachment == nil ? 2 : 1
            let messageLabelSize = TextSizeMeasure.calculateSize(of: data.attributedBody, config: config).textSize
            
            return CGSize(width: thumbnailSize.width + max(nameLabelSize.width, iconSize.width + messageLabelSize.width) + 8,
                          height: max(thumbnailSize.height, nameLabelSize.height + max(iconSize.height, messageLabelSize.height)) + 16)
        }
    }
}

extension MessageCell {

    open class ReplyCountView: Button {
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open override func setup() {
            super.setup()
            isUserInteractionEnabled = false
        }
        open override func setupAppearance() {
            super.setupAppearance()
            setTitleColor(appearance.replyCountTextColor, for: .normal)
            titleLabel?.font = appearance.replyCountTextFont
        }

        open var count: Int = 0 {
            didSet {
                setTitle(count > 0 ? L10n.Message.Reply.count(count) : nil, for: .normal)
                isUserInteractionEnabled = count > 0
            }
        }
    }
}

extension MessageCell {

    open class ReplyArrowView: View {
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open override func setupLayout() {
            super.setupLayout()
            backgroundColor = .clear
            clipsToBounds = true
            clearsContextBeforeDrawing = true
        }

        open var isFlipped: Bool = false {
            didSet {
                layer.setNeedsDisplay()
            }
        }

        open override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            guard let strokeColor = appearance.replyArrowStrokeColor?.cgColor
            else { return }
            
            let rect = bounds.insetBy(dx: 1, dy: 1)
            let radius = CGFloat(rect.width / 2)

            UIGraphicsPushContext(ctx)
            if isFlipped {
                ctx.translateBy(x: rect.maxX, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }
            ctx.setStrokeColor(strokeColor)
            ctx.setLineWidth(1)
            ctx.move(to: rect.origin)
            ctx.addLine(to: CGPoint(x: rect.origin.x, y: rect.maxY - radius))
            ctx.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                       radius: radius, startAngle: radians(degrees: -180),
                       endAngle: radians(degrees: -270),
                       clockwise: true)
            ctx.strokePath()

            UIGraphicsPopContext()
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.setNeedsDisplay()
        }

        open func radians(degrees: CGFloat) -> CGFloat {
            degrees * .pi / 180.0
        }
    }
}

public extension MessageCell.ReplyView {
    enum Anchors {
        public static var top = CGFloat(8)
        public static var leading = CGFloat(12)
        public static var trailing = CGFloat(-12)
        public static var width: CGFloat { Components.messageLayoutModel.defaults.messageWidth - leading + trailing }
    }
    
    enum Measure {
        public static var iconSize = CGSize(width: 16, height: 16)
        public static var imageSize = CGSize(width: 32, height: 32)
    }
}

