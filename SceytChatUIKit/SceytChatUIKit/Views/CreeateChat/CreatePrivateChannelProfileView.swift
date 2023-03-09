//
//  CreatePrivateChannelProfileView.swift
//  SceytChatUIKit
//

import UIKit

open class CreatePrivateChannelProfileView: View {

    open lazy var avatarButton: CircleButton = {
        $0.setImage(.editAvatar, for: .normal)
        return $0.withoutAutoresizingMask
    }(CircleButton(type: .custom))

    open lazy var editButton: CircleButton = {
        $0.setImage(.editAvatar, for: .normal)
        return $0.withoutAutoresizingMask
    }(CircleButton(type: .custom))

    open lazy var subjectField: UITextField = {
        $0.borderStyle = .none
        $0.font = Fonts.regular.withSize(16)
        $0.textColor = Colors.textBlack
        $0.attributedPlaceholder = NSAttributedString(
            string: L10n.Channel.Subject.placeholder,
            attributes: [.font: Fonts.regular.withSize(16),
                .foregroundColor: Colors.textGray]
        )
        $0.layer.sublayerTransform = CATransform3DMakeTranslation(0, 0, 0);
        $0.returnKeyType = .next
        return $0.withoutAutoresizingMask
    }(UITextField())

    open lazy var descriptionField: PlaceholderTextView = {
        $0.font = Fonts.regular.withSize(16)
        $0.textColor = .textBlack
        $0.placeholderColor = Colors.textGray
        $0.placeholder = L10n.Channel.Subject.descriptionPlaceholder
        $0.isScrollEnabled = false
        $0.directionalLayoutMargins.leading = 0
        $0.directionalLayoutMargins.trailing = 0
        $0.directionalLayoutMargins.top += 4
        $0.textContainer.lineFragmentPadding = 0
        return $0.withoutAutoresizingMask
    }(PlaceholderTextView())

    open lazy var commentLabel: ContentInsetLabel = {
        $0.font = Fonts.regular.withSize(13)
        $0.textColor = Colors.textGray
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

    open lazy var bottomLine1: UIView = {
        $0.backgroundColor = Colors.separatorBorder
        return $0.withoutAutoresizingMask
    }(UIView())

    open lazy var bottomLine2: UIView = {
        $0.backgroundColor = Colors.separatorBorder
        return $0.withoutAutoresizingMask
    }(UIView())

    override open func setup() {
        super.setup()
        editButton.isUserInteractionEnabled = false
        editButton.isHidden = true
    }

    override open func setupLayout() {
        super.setupLayout()
        addSubview(avatarButton)
        addSubview(editButton)
        addSubview(mainStackView)
        avatarButton.centerXAnchor.pin(to: centerXAnchor)
        avatarButton.topAnchor.pin(to: topAnchor, constant: 16)
        avatarButton.resize(anchors: [.height(90),
                                      .width(90)])
        editButton.leadingAnchor.pin(to: avatarButton.leadingAnchor)
        editButton.trailingAnchor.pin(to: avatarButton.trailingAnchor)
        editButton.topAnchor.pin(to: avatarButton.topAnchor)
        editButton.bottomAnchor.pin(to: avatarButton.bottomAnchor)

        mainStackView.topAnchor.pin(to: avatarButton.bottomAnchor, constant: 12)
        mainStackView.pin(to: self,
                          anchors: [
                            .leading(16),
                            .trailing(-16),
                            .bottom(-32)
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
