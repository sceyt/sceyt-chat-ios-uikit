//
//  ViewOnceInfoViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

open class ViewOnceInfoViewController: ViewController {

    open lazy var scrollView: UIScrollView = {
        $0.showsVerticalScrollIndicator = false
        $0.showsHorizontalScrollIndicator = false
        return $0.withoutAutoresizingMask
    }(UIScrollView())

    open lazy var contentView: UIView = {
        return $0.withoutAutoresizingMask
    }(UIView())

    open lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .center
        $0.distribution = .fill
        $0.spacing = 20
        return $0.withoutAutoresizingMask
    }(UIStackView())

    open lazy var labelsStackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .center
        $0.distribution = .fill
        $0.spacing = 16
        return $0.withoutAutoresizingMask
    }(UIStackView())

    open lazy var iconImageView: UIImageView = {
        $0.contentMode = .scaleAspectFit
        $0.image = Images.iconOnceMessages
        return $0.withoutAutoresizingMask
    }(UIImageView())

    open lazy var titleLabel: UILabel = {
        $0.textAlignment = .center
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var subtitleLabel: UILabel = {
        $0.textAlignment = .center
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var okButton: UIButton = {
        $0.addTarget(self, action: #selector(okButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))

    open lazy var closeButton: UIButton = {
        $0.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))

    open override func setup() {
        super.setup()

        titleLabel.text = appearance.titleText
        subtitleLabel.text = appearance.subtitleText
        okButton.setTitle(appearance.okButtonTitle, for: .normal)

        typealias AID = SceytChatUIKit.AccessibilityIdentifiers.ViewOnceInfo
        titleLabel.accessibilityIdentifier = AID.title
        okButton.accessibilityIdentifier = AID.okButton
        closeButton.accessibilityIdentifier = AID.closeButton
    }

    open override func setupLayout() {
        super.setupLayout()

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        // Add labels to labels stack view
        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(subtitleLabel)

        // Add subviews to main stack view
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(labelsStackView)

        // Add ok button and close button to main view
        view.addSubview(okButton)
        view.addSubview(closeButton)

        let horizontalPadding: CGFloat = 24
        let bottomPadding: CGFloat = 16
        let topPadding: CGFloat = 50

        // Scroll view constraints
        scrollView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])

        // Content view constraints
        contentView.pin(to: scrollView, anchors: [.leading, .trailing, .top, .bottom])
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true

        // Stack view constraints
        stackView.pin(to: contentView, anchors: [
            .leading(horizontalPadding),
            .trailing(-horizontalPadding),
            .top(topPadding),
            .bottom(-bottomPadding)
        ])

        // Icon image view constraints
        iconImageView.widthAnchor.constraint(equalToConstant: 200).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        // OK button at bottom of view
        okButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(horizontalPadding), .trailing(-horizontalPadding), .bottom(-horizontalPadding)])
        okButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        // Scroll view bottom constraint (above ok button)
        scrollView.bottomAnchor.constraint(equalTo: okButton.topAnchor, constant: -horizontalPadding).isActive = true

        // Close button constraints
        closeButton.pin(to: view.safeAreaLayoutGuide, anchors: [.top(12), .trailing(-12)])
        closeButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    open override func setupAppearance() {
        super.setupAppearance()

        view.backgroundColor = appearance.backgroundColor

        // Title label appearance
        let titleAppearance = appearance.titleLabelAppearance
        titleLabel.font = titleAppearance.font
        titleLabel.textColor = titleAppearance.foregroundColor
        titleLabel.backgroundColor = titleAppearance.backgroundColor

        // Subtitle label appearance
        let subtitleAppearance = appearance.subtitleLabelAppearance
        subtitleLabel.font = subtitleAppearance.font
        subtitleLabel.textColor = subtitleAppearance.foregroundColor
        subtitleLabel.backgroundColor = subtitleAppearance.backgroundColor

        // OK button appearance
        let buttonAppearance = appearance.okButtonAppearance
        okButton.setTitleColor(buttonAppearance.labelAppearance.foregroundColor, for: .normal)
        okButton.backgroundColor = buttonAppearance.backgroundColor
        okButton.layer.cornerRadius = buttonAppearance.cornerRadius
        okButton.layer.cornerCurve = buttonAppearance.cornerCurve
        okButton.titleLabel?.font = buttonAppearance.labelAppearance.font
        okButton.tintColor = buttonAppearance.tintColor

        // Close button appearance
        closeButton.setImage(.closeIcon, for: .normal)
        closeButton.tintColor = appearance.closeButtonTintColor
        closeButton.backgroundColor = appearance.closeButtonBackgroundColor
        closeButton.layer.cornerRadius = 14
    }

    // MARK: Actions

    @objc open func okButtonTapped() {
        dismiss(animated: true)
    }

    @objc open func closeButtonTapped() {
        dismiss(animated: true)
    }
}
