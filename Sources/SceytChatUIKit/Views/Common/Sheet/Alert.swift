//
//  Alert.swift
//  SceytChatUIKit
//
//  Created by Duc on 03/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class Alert: View {
    private lazy var titleLabel = ContentInsetLabel().withoutAutoresizingMask
    private lazy var messageLabel = ContentInsetLabel().withoutAutoresizingMask
    private lazy var separator = UIView().withoutAutoresizingMask
    private lazy var buttonsStackView = UIStackView().withoutAutoresizingMask
    private lazy var columnStackView = UIStackView(column: [titleLabel, messageLabel, separator, buttonsStackView]).withoutAutoresizingMask
    private var actions: [SheetAction] = []
    private var preferredActionIndex: Int = 0
    
    open var title: String? {
        set { titleLabel.text = newValue }
        get { titleLabel.text }
    }
    
    open var message: String? {
        set { messageLabel.text = newValue }
        get { messageLabel.text }
    }
    
    open var attributedTitle: NSAttributedString? {
        set { titleLabel.attributedText = newValue }
        get { titleLabel.attributedText }
    }
    
    open var attributedMessage: NSAttributedString? {
        set { messageLabel.attributedText = newValue }
        get { messageLabel.attributedText }
    }
    
    init(title: String? = nil, message: String? = nil, actions: [SheetAction], preferredActionIndex: Int = 0) {
        self.actions = actions
        self.preferredActionIndex = preferredActionIndex
        super.init(frame: .zero)
        
        titleLabel.text = title
        messageLabel.text = message
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        addSubview(columnStackView)
        columnStackView.pin(to: self, anchors: [.top, .leading, .trailing, .bottom])
        
        buttonsStackView.addArrangedSubviews(actions.enumerated().map {
            button(
                for: $0.element,
                hasBottomSeparator: actions.count > 2 && $0.offset < actions.count - 1,
                hasRightSeparator: actions.count <= 2 && $0.offset < actions.count - 1,
                isPreferred: $0.offset == preferredActionIndex
            )
        })
        
        separator.heightAnchor.pin(constant: 1)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        layer.cornerRadius = Layouts.cornerRadius
        layer.masksToBounds = true
        backgroundColor = appearance.backgroundColor
        titleLabel.numberOfLines = 0
        titleLabel.edgeInsets = .init(top: 20, left: 16, bottom: 8, right: 16)
        titleLabel.textAlignment = .center
        titleLabel.font = appearance.titleLabelAppearance.font
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.edgeInsets = .init(top: 0, left: 16, bottom: 20, right: 16)
        messageLabel.font = appearance.messageLabelAppearance.font
        messageLabel.textColor = appearance.messageLabelAppearance.foregroundColor
        separator.backgroundColor = appearance.separatorColor
        buttonsStackView.axis = actions.count <= 2 ? .horizontal : .vertical
        buttonsStackView.distribution = actions.count <= 2 ? .fillEqually : .fill
    }
    
    open func button(for action: SheetAction, maskedCorners: CACornerMask = [], hasBottomSeparator: Bool = true, hasRightSeparator: Bool = true, isPreferred: Bool = false) -> SheetButton {
        let button = SheetButton()
        button.publisher(for: .touchUpInside).sink { [weak self] _ in
            self?.sheet?.dismiss {
                action.handler?()
            }
        }.store(in: &subscriptions)
        button.contentEdgeInsets = .init(top: 12, left: 16 + (action.icon == nil ? 0 : 16), bottom: 12, right: 16)
        button.imageEdgeInsets = .init(top: 0, left: action.icon == nil ? 0 : -16, bottom: 0, right: 0)
        button.layer.maskedCorners = maskedCorners
        button.layer.cornerRadius = Layouts.cornerRadius
        button.layer.masksToBounds = true
        button.setImage(action.icon?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.contentHorizontalAlignment = action.icon == nil ? .center : .leading
        
        let buttonAppearance = switch action.style {
        case .default:
            appearance.buttonAppearance
        case .destructive:
            appearance.destructiveButtonAppearance
        case .cancel:
            appearance.cancelButtonAppearance
        }

        button.backgroundColors = (
            normal: buttonAppearance.backgroundColor,
            highlighted: buttonAppearance.highlightedBackgroundColor
        )
        button.tintColor = buttonAppearance.tintColor
        button.setAttributedTitle(NSAttributedString(string: action.title, attributes: [
            .font: isPreferred ? appearance.preferredActionFont : buttonAppearance.labelAppearance.font,
            .foregroundColor: buttonAppearance.labelAppearance.foregroundColor
        ]), for: .normal)
        
        if hasBottomSeparator {
            let separator = UIView()
            separator.backgroundColor = appearance.separatorColor
            button.addSubview(separator.withoutAutoresizingMask)
            separator.pin(to: button, anchors: [.leading, .trailing, .bottom])
            separator.heightAnchor.pin(constant: 1)
        }
        if hasRightSeparator {
            let separator = UIView()
            separator.backgroundColor = appearance.separatorColor
            button.addSubview(separator.withoutAutoresizingMask)
            separator.pin(to: button, anchors: [.trailing, .top, .bottom])
            separator.widthAnchor.pin(constant: 1)
        }
        return button.withoutAutoresizingMask
    }
}

public extension Alert {
    enum Layouts {
        public static var cornerRadius: CGFloat = 16
    }
}
