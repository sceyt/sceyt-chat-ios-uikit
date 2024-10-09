//
//  CreateGroupViewController+DetailsView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension CreateGroupViewController {
    open class DetailsView: View {
        
        open lazy var avatarButton = CircleButton(type: .custom)
            .withoutAutoresizingMask
        
        open lazy var subjectField: UITextField = {
            $0.borderStyle = .none
            $0.layer.sublayerTransform = CATransform3DMakeTranslation(0, 0, 0);
            $0.returnKeyType = .next
            return $0.withoutAutoresizingMask
        }(UITextField())
        
        open lazy var descriptionField: PlaceholderTextView = {
            $0.placeholder = L10n.Channel.Subject.descriptionPlaceholder
            $0.isScrollEnabled = false
            $0.textContainerInset = .init(top: 13, left: 0, bottom: 0, right: 0)
            $0.textContainer.lineFragmentPadding = 0
            return $0.withoutAutoresizingMask
        }(PlaceholderTextView())
        
        open lazy var commentLabel: ContentInsetLabel = {
            $0.text = L10n.Channel.Avatar.comment
            $0.edgeInsets = .zero
            $0.numberOfLines = 0
            return $0.withoutAutoresizingMask
        }(ContentInsetLabel())
        
        open lazy var mainStackView: UIStackView = {
            $0.axis = .vertical
            $0.alignment = .leading
            $0.distribution = .fill
            return $0.withoutAutoresizingMask
                .contentHuggingPriorityV(.required)
        }(UIStackView(arrangedSubviews: [subjectField, bottomLine1, descriptionField, bottomLine2]))
        
        open lazy var bottomLine1 = UIView().withoutAutoresizingMask
        open lazy var bottomLine2 = UIView().withoutAutoresizingMask
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(avatarButton)
            addSubview(mainStackView)
            avatarButton.centerXAnchor.pin(to: centerXAnchor)
            avatarButton.topAnchor.pin(to: topAnchor, constant: 16)
            avatarButton.resize(anchors: [.height(Layouts.avatarSize), .width(Layouts.avatarSize)])
            
            mainStackView.topAnchor.pin(to: avatarButton.bottomAnchor, constant: 16)
            mainStackView.pin(to: self,
                              anchors: [
                                .leading(24),
                                .trailing(-24),
                                .bottom(-16)
                              ])
            
            subjectField.heightAnchor.pin(constant: 48)
            subjectField.widthAnchor.pin(to: mainStackView.widthAnchor)
            descriptionField.heightAnchor.pin(greaterThanOrEqualToConstant: 48)
            descriptionField.widthAnchor.pin(to: mainStackView.widthAnchor)
            bottomLine1.widthAnchor.pin(to: mainStackView.widthAnchor)
            bottomLine2.widthAnchor.pin(to: mainStackView.widthAnchor)
            bottomLine1.heightAnchor.pin(constant: 1)
            bottomLine2.heightAnchor.pin(constant: 1)
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            avatarButton.backgroundColor = appearance.avatarBackgroundColor
            bottomLine1.backgroundColor = appearance.separatorColor
            bottomLine2.backgroundColor = appearance.separatorColor
            
            subjectField.font = appearance.fieldFont
            subjectField.textColor = appearance.fieldTextColor
            subjectField.attributedPlaceholder = NSAttributedString(
                string: L10n.Channel.Subject.Group.placeholder,
                attributes: [.font: appearance.fieldFont ?? Fonts.regular.withSize(16),
                             .foregroundColor: appearance.fieldPlaceHolderTextColor ?? UIColor.secondaryText]
            )
            
            descriptionField.backgroundColor = .clear
            descriptionField.font = appearance.fieldFont
            descriptionField.textColor = appearance.fieldTextColor
            descriptionField.placeholderColor = appearance.fieldPlaceHolderTextColor
            
            commentLabel.font = appearance.commentFont
            commentLabel.textColor = appearance.commentTextColor
        }
        
        override open func resignFirstResponder() -> Bool {
            subjectField.resignFirstResponder()
            descriptionField.resignFirstResponder()
            return super.resignFirstResponder()
        }
        
        override open var canResignFirstResponder: Bool {
            super.canResignFirstResponder ||
            subjectField.canResignFirstResponder ||
            descriptionField.canResignFirstResponder
        }
    }
}

public extension CreateGroupViewController.DetailsView {
    enum Layouts {
        public static var avatarSize: CGFloat = 72
    }
}
