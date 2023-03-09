//
//  MessageCell+ReplyView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageCell {

    open class ReplyView: Control {

        open lazy var nameLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var imageView = UIImageView()
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
            stackViewH.alignment = .leading
            stackViewH.axis = .horizontal
            
            stackViewH2.distribution = .fill
            stackViewH2.alignment = .leading
            stackViewH2.axis = .horizontal
            
            messageLabel.lineBreakMode = .byTruncatingTail
            messageLabel.numberOfLines = 2
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
            stackViewH.pin(to: self)
            borderView.resize(anchors: [.width(2)])
            borderView.bottomAnchor.pin(to: messageLabel.bottomAnchor)
            borderView.heightAnchor.pin(to: stackViewH.heightAnchor)
//            messageLabel.widthAnchor.pin(to: stackViewV.widthAnchor)
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

        open var data: ChatMessage? {
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
                nameLabel.text = Formatters.userDisplayName.format(data.user)
                messageLabel.text = messageText(data)
                if let image = messageIcon(data) {
                    stackViewH2.insertArrangedSubview(iconView, at: 0)
                    iconView.image = image
                    iconView.addConstraints([
                        iconView.heightAnchor.pin(constant: 16),
                        iconView.widthAnchor.pin(constant: 16)
                    ])
                } else {
                    iconView.image = nil
                }
                guard (data.attachments?.first) != nil
                else { return }
                imageView.image = thumbnail()
                guard imageView.image != nil else { return }
                stackViewH.insertArrangedSubview(imageView, at: 1)
                stackViewH.setCustomSpacing(8, after: imageView)
                imageView.addConstraints([
                    imageView.heightAnchor.pin(constant: 40),
                    imageView.widthAnchor.pin(constant: 40)
                ])
                if data.body.isEmpty,
                    data.attachments?.first != nil {
                    messageLabel.bottomAnchor.pin(to: stackViewH2.bottomAnchor, constant: -6)
                }
            }
        }

        open func messageText(_ message: ChatMessage) -> String {
            switch message.state {
            case .deleted:
                return L10n.Message.deleted
            default:
                if message.body.isEmpty {
                    if let attachment = message.attachments?.first {
                        switch attachment.type {
                        case "image":
                            return L10n.Message.Attachment.image
                        case "video":
                            return L10n.Message.Attachment.video
                        case "voice":
                            return L10n.Message.Attachment.voice
                        default:
                            return L10n.Message.Attachment.file
                        }
                    }
                    return " "
                }
                return message.body
            }
        }
        
        open func messageIcon(_ message: ChatMessage) -> UIImage? {
            if let attachment = message.attachments?.first {
                switch attachment.type {
                case "voice":
                    return Images.attachmentVoice.withTintColor(Colors.kitBlue)
                default:
                    break
                }
            }
            return nil
            
        }

        open func thumbnail() -> UIImage? {
            guard let attachment = data?.attachments?.first
            else { return nil }
            
            switch attachment.type {
            case "image", "video":
                if let path = fileProvider.thumbnailFile(for: attachment, preferred: .init(width: 40, height: 40)) {
                    return UIImage(contentsOfFile: path)
                } else if let thumbnail = attachment.imageDecodedMetadata?.thumbnail {
                    return  Components.imageBuilder.image(from: thumbnail)
                }
                return nil
            case "voice":
                return nil
            default:
                return .file
            }
            
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
