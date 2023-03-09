//
//  ChannelProfileTitleCell.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class ChannelProfileTitleCell: TableViewCell, Bindable {

    open lazy var avatarView = instance(of: CircleImageView.self)
        .init()
        .withoutAutoresizingMask

    open lazy var avatarUpdateButton = UIButton(type: .custom)
        .withoutAutoresizingMask

    open lazy var titleTextView = instance(of: TitleTextView.self)
        .init()
        .withoutAutoresizingMask

    open lazy var membersLabel = UILabel()
        .withoutAutoresizingMask

    open var isUpdating: Bool = false {
        didSet {
            avatarUpdateButton.isHidden = !isUpdating
            titleTextView.isEditing = isUpdating
        }
    }

    open var avatarBuilder = Components.avatarBuilder
    open var imageTask: Cancellable?

    open var onChangeText: ((ChannelProfileTitleCell) -> Void)?
    open var onUpdateAvatar: ((ChannelProfileTitleCell) -> Void)?

    open override func setup() {
        super.setup()
        avatarUpdateButton.isHidden = !isUpdating
        avatarUpdateButton.addTarget(self, action: #selector(avatarUpdateAction(_:)), for: .touchUpInside)

        NotificationCenter.default
            .addObserver(forName: UITextField.textDidChangeNotification,
                         object: titleTextView.textField,
                         queue: nil) { [weak self] _ in
                guard let self = self else { return }
                self.onChangeText?(self)
        }
    }

    open override func setupAppearance() {
        super.setupAppearance()
        contentView.backgroundColor = Appearance.Colors.background
        membersLabel.textColor = Appearance.Colors.textGray
        membersLabel.font = Fonts.regular.withSize(14)
        avatarUpdateButton.setImage(Appearance.Images.camera, for: .normal)
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(avatarUpdateButton)

        let stackView = UIStackView(arrangedSubviews: [titleTextView, membersLabel]).withoutAutoresizingMask
        stackView.alignment = .leading
        stackView.axis = .vertical
        stackView.distribution = .fillProportionally
        stackView.spacing = 4

        contentView.addSubview(stackView)

        avatarView.pin(to: contentView, anchors: [
            .leading(16),
            .top(16, .greaterThanOrEqual),
            .bottom(16, .lessThanOrEqual),
            .centerY()])
        avatarView.resize(anchors: [.width(72), .height(72)])
        avatarUpdateButton.pin(to: avatarView)

        stackView.pin(to: contentView, anchors: [
            .top(16, .greaterThanOrEqual),
                .bottom(16, .lessThanOrEqual),
                .trailing(-16, .greaterThanOrEqual),
                .centerY()])
        stackView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 16)
    }

    open func bind(_ data: ChatChannel) {
        if data.type.isGroup {
            switch data.memberCount {
            case 1:
                membersLabel.text = L10n.Channel.MembersCount.one
            case 2...:
                membersLabel.text = L10n.Channel.MembersCount.more(2)
            default:
                membersLabel.text = ""
            }
        } else {
            membersLabel.text = ""
        }

        titleTextView.textField.text = Formatters.channelDisplayName.format(data)
        imageTask = avatarBuilder
            .loadAvatar(into: avatarView.imageView,
                        for: data)
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }

    @objc
    open func avatarUpdateAction(_ sender: UIButton) {
        onUpdateAvatar?(self)
    }
}

extension ChannelProfileTitleCell {

    open class TitleTextView: View {

        open lazy var textField = UITextField()
            .withoutAutoresizingMask

        open lazy var underLine = UIView()
            .withoutAutoresizingMask

        open var isEditing: Bool = false {
            didSet {
                underLine.isHidden = !isEditing
                textField.isEnabled = isEditing
                textField.becomeFirstResponder()
            }
        }

        open var text: String? { textField.text }

        open override func setup() {
            super.setup()
            underLine.isHidden = !isEditing
            textField.isEnabled = isEditing
        }

        open override func setupAppearance() {
            super.setupAppearance()
            textField.backgroundColor = .clear
            textField.borderStyle = .none
            textField.placeholder = L10n.Channel.Profile.subject
            textField.returnKeyType = .next
            textField.textColor = Colors.textBlack
            textField.font = Fonts.medium.withSize(17)
            underLine.backgroundColor = Colors.kitBlue
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(textField)
            addSubview(underLine)
            textField.pin(to: self)
            underLine.pin(to: textField, anchors: [.leading(), .trailing()])
            underLine.topAnchor.pin(to: textField.bottomAnchor, constant: 4)
            underLine.heightAnchor.pin(constant: 1)
        }
    }
}
