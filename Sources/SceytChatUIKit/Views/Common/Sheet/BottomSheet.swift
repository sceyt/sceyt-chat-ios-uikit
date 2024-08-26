//
//  BottomSheet.swift
//  SceytChatUIKit
//
//  Created by Duc on 02/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit

open class BottomSheet: View {
    private lazy var titleLabel = ContentInsetLabel()
    private lazy var columnStackView = UIStackView(column: [])
        .withoutAutoresizingMask
    
    private let title: String?
    private let actions: [SheetAction]
    private(set) var cancelAction: SheetAction?
    
    private var hasTitle: Bool { title != nil && !title!.isEmpty }
    
    public init(title: String? = nil, actions: [SheetAction]) {
        self.title = title
        if actions.isEmpty {
            fatalError("[BottomSheet]: actions cannot be empty")
        }
        if actions.filter({ $0.style == .cancel }).count > 1 {
            fatalError("[BottomSheet]: Only support 1 cancel action")
        }
        var actions = actions
        if let idx = actions.firstIndex(where: { $0.style == .cancel }) {
            cancelAction = actions.remove(at: idx)
        }
        self.actions = actions
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("[BottomSheet]: init(coder:) has not been implemented")
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        addSubview(columnStackView)
        columnStackView.pin(to: self, anchors: [.top, .leading, .trailing])
        
        if let cancelAction {
            let cancelButton = button(for: cancelAction, 
                                      maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
                                      hasSeparator: false)
            cancelButton.layer.cornerRadius = Layouts.cornerRadius
            cancelButton.layer.masksToBounds = true
            addSubview(cancelButton)
            columnStackView.bottomAnchor.pin(to: cancelButton.topAnchor, constant: -8)
            cancelButton.pin(to: self, anchors: [.bottom, .leading, .trailing])
        } else {
            columnStackView.pin(to: self, anchors: [.bottom])
        }
        
        columnStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if hasTitle {
            titleLabel.text = title
            columnStackView.addArrangedSubview(titleLabel)
        }
        columnStackView.addArrangedSubviews(actions.enumerated().map {
            var maskedCorners: CACornerMask = []
            if actions.count > 1 {
                if !hasTitle, $0.offset == 0 {
                    maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                } else if $0.offset == actions.count - 1 {
                    maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                }
            } else {
                if hasTitle {
                    maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                } else {
                    maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                }
            }
            return button(for: $0.element, maskedCorners: maskedCorners, hasSeparator: $0.offset != actions.count - 1)
        })
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = .clear
        
        if hasTitle {
            titleLabel.font = appearance.titleFont
            titleLabel.textAlignment = .center
            titleLabel.textColor = appearance.titleColor
            titleLabel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            titleLabel.layer.cornerRadius = Layouts.cornerRadius
            titleLabel.backgroundColor = appearance.backgroundColors?.normal
            titleLabel.edgeInsets = .init(top: 20, left: 16, bottom: 10, right: 16)
            titleLabel.layer.cornerRadius = Layouts.cornerRadius
            titleLabel.layer.masksToBounds = true
            titleLabel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }
    
    open func button(for action: SheetAction, maskedCorners: CACornerMask = [], hasSeparator: Bool = true) -> SheetButton {
        let button = SheetButton()
        button.publisher(for: .touchUpInside).sink { [weak self] _ in
            self?.sheet?.dismiss {
                action.handler?()
            }
        }.store(in: &subscriptions)
        button.contentEdgeInsets = .init(top: 18, left: 16 + (action.icon == nil ? 0 : 16), bottom: 18, right: 16)
        button.imageEdgeInsets = .init(top: 0, left: action.icon == nil ? 0 : -16, bottom: 0, right: 0)
        button.backgroundColors = appearance.backgroundColors
        button.tintColor = appearance.normalIconColor
        button.layer.maskedCorners = maskedCorners
        button.layer.cornerRadius = Layouts.cornerRadius
        button.layer.masksToBounds = true
        button.setImage(action.icon?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.contentHorizontalAlignment = action.icon == nil ? .center : .leading
        if action.style == .cancel {
            button.setAttributedTitle(NSAttributedString(string: action.title, attributes: [
                .font: appearance.cancelFont ?? Fonts.semiBold.withSize(16),
                .foregroundColor: appearance.cancelTextColor ?? .primaryAccent,
            ]), for: .normal)
        } else {
            if action.style == .destructive {
                button.tintColor = appearance.destructiveIconColor
                button.setAttributedTitle(NSAttributedString(string: action.title, attributes: [
                    .font: appearance.buttonFont ?? Fonts.regular.withSize(16),
                    .foregroundColor: appearance.destructiveTextColor ?? .stateError,
                ]), for: .normal)
            } else {
                button.setAttributedTitle(NSAttributedString(string: action.title, attributes: [
                    .font: appearance.buttonFont ?? Fonts.regular.withSize(16),
                    .foregroundColor: appearance.normalTextColor ?? .init(light: 0x111539, dark: 0xE1E3E6),
                ]), for: .normal)
            }
        }
        if hasSeparator {
            let separator = UIView()
            separator.backgroundColor = appearance.separatorColor
            button.addSubview(separator.withoutAutoresizingMask)
            separator.pin(to: button, anchors: [.leading, .trailing, .bottom])
            separator.heightAnchor.pin(constant: 1)
        }
        return button.withoutAutoresizingMask
    }
}

public extension BottomSheet {
    enum Layouts {
        public static var cornerRadius: CGFloat = 14
    }
}
