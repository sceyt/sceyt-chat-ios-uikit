//
//  QRCodeViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

open class QRCodeViewController: ViewController {

    public var inviteLink: String = ""

    open lazy var qrCodeImageView: UIImageView = {
        $0.contentMode = .scaleAspectFit
        return $0.withoutAutoresizingMask
    }(UIImageView())

    open lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .center
        $0.distribution = .fill
        return $0.withoutAutoresizingMask
    }(UIStackView())

    open lazy var titleLabel: UILabel = {
        $0.textAlignment = .center
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var linkLabel: UILabel = {
        $0.textAlignment = .center
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var shareButton: UIButton = {
        $0.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))

    open lazy var logoImageView: UIImageView = {
        $0.contentMode = .scaleAspectFit
        $0.layer.masksToBounds = true
        return $0.withoutAutoresizingMask
    }(UIImageView())

    open lazy var closeButton: UIButton = {
        $0.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))

    open override func setup() {
        super.setup()

        title = appearance.titleText
        titleLabel.text = appearance.titleText
        linkLabel.text = appearance.linkLabelText
        shareButton.setTitle(appearance.shareButtonTitle, for: .normal)

        // Generate QR code
        if !inviteLink.isEmpty, let qrCodeImage = Components.imageBuilder.qrCode(
            from: inviteLink,
            size: appearance.qrCodeSize
        ) {
            qrCodeImageView.image = qrCodeImage
        }

        // Configure logo
        logoImageView.image = appearance.logoImage
        logoImageView.isHidden = appearance.logoImage == nil

        // Configure close button
        closeButton.setImage(appearance.closeButtonImage, for: .normal)
        closeButton.isHidden = !appearance.showCloseButton

        typealias AID = SceytChatUIKit.AccessibilityIdentifiers.QRCode
        qrCodeImageView.accessibilityIdentifier = AID.image
        linkLabel.accessibilityIdentifier = AID.link
        shareButton.accessibilityIdentifier = AID.shareButton
        closeButton.accessibilityIdentifier = AID.closeButton
    }

    open override func setupLayout() {
        super.setupLayout()

        view.addSubview(titleLabel)
        stackView.addArrangedSubview(qrCodeImageView)
        view.addSubview(stackView)
        view.addSubview(logoImageView)
        view.addSubview(linkLabel)
        view.addSubview(shareButton)
        view.addSubview(closeButton)

        let padding = appearance.qrCodePadding
        let horizontalPadding: CGFloat = 16.0

        // Title label at top of view
        titleLabel.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(horizontalPadding), .trailing(-horizontalPadding), .top(20)])
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        // Share button at bottom of view
        shareButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(horizontalPadding), .trailing(-horizontalPadding), .bottom(-horizontalPadding)])
        shareButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        shareButton.setContentCompressionResistancePriority(.required, for: .vertical)

        // Link label above share button - always visible
        linkLabel.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(horizontalPadding), .trailing(-horizontalPadding)])
        linkLabel.setContentHuggingPriority(.required, for: .vertical)
        linkLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        linkLabel.bottomAnchor.constraint(equalTo: shareButton.topAnchor, constant: -horizontalPadding).isActive = true

        // Stack view with configurable padding
        stackView.pin(to: view.safeAreaLayoutGuide, anchors: [
            .leading(padding.left),
            .trailing(-padding.right)
        ])
        stackView.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: horizontalPadding).isActive = true
        stackView.bottomAnchor.constraint(lessThanOrEqualTo: linkLabel.topAnchor, constant: -horizontalPadding).isActive = true

        // Center stack view vertically with lower priority to allow flexibility
        let centerYConstraint = stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -horizontalPadding)
        centerYConstraint.priority = UILayoutPriority(750) // Lower than required
        centerYConstraint.isActive = true

        qrCodeImageView.contentMode = .scaleAspectFit
        // Ensure QR code doesn't become too large
        let maxSize = min(view.bounds.width - padding.left - padding.right, 200)
        qrCodeImageView.widthAnchor.constraint(lessThanOrEqualToConstant: maxSize).isActive = true

        // Logo overlay positioned in center of QR code
        logoImageView.centerXAnchor.constraint(equalTo: qrCodeImageView.centerXAnchor).isActive = true
        logoImageView.centerYAnchor.constraint(equalTo: qrCodeImageView.centerYAnchor).isActive = true
        logoImageView.widthAnchor.constraint(equalToConstant: appearance.logoSize.width).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: appearance.logoSize.height).isActive = true

        // Close button positioned in top right corner
        closeButton.pin(to: view.safeAreaLayoutGuide, anchors: [.top(12), .trailing(-12)])
        closeButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    open override func setupAppearance() {
        super.setupAppearance()

        view.backgroundColor = appearance.backgroundColor

        // Apply QR code image view appearance
        qrCodeImageView.backgroundColor = appearance.qrCodeBackgroundColor

        // Apply title label appearance
        let titleAppearance = appearance.titleLabelAppearance
        titleLabel.font = titleAppearance.font
        titleLabel.textColor = titleAppearance.foregroundColor
        titleLabel.backgroundColor = titleAppearance.backgroundColor

        // Apply link label appearance
        let linkAppearance = appearance.linkLabelAppearance
        linkLabel.font = linkAppearance.font
        linkLabel.textColor = linkAppearance.foregroundColor
        linkLabel.backgroundColor = linkAppearance.backgroundColor

        // Apply share button appearance
        let buttonAppearance = appearance.shareButtonAppearance
        shareButton.setTitleColor(buttonAppearance.labelAppearance.foregroundColor, for: .normal)
        shareButton.backgroundColor = buttonAppearance.backgroundColor
        shareButton.layer.cornerRadius = buttonAppearance.cornerRadius
        shareButton.layer.cornerCurve = buttonAppearance.cornerCurve
        shareButton.titleLabel?.font = buttonAppearance.labelAppearance.font
        shareButton.tintColor = buttonAppearance.tintColor

        // Apply logo appearance
        logoImageView.backgroundColor = appearance.logoBackgroundColor
        logoImageView.layer.cornerRadius = appearance.logoCornerRadius

        // Apply close button appearance
        closeButton.tintColor = appearance.closeButtonTintColor
        closeButton.backgroundColor = appearance.closeButtonBackgroundColor
        closeButton.layer.cornerRadius = 16 // Half of 32x32 size for circular button
    }

    @objc open func shareButtonTapped() {
        var activityItems: [Any] = []
        
        // Add composite QR code image if available
        if let compositeImage = createCompositeQRCodeImage() {
            activityItems.append(compositeImage)
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // For iPad popover presentation
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }

        present(activityViewController, animated: true)
    }

    @objc open func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Private Methods
    
    private func createCompositeQRCodeImage() -> UIImage? {
        guard let qrCodeImage = qrCodeImageView.image else { return nil }
        
        let size = qrCodeImage.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw QR code as background
            qrCodeImage.draw(in: CGRect(origin: .zero, size: size))
            
            // Draw logo overlay if available
            if let logoImage = logoImageView.image, !logoImageView.isHidden {
                let logoSize = appearance.logoSize
                let logoRect = CGRect(
                    x: (size.width - logoSize.width) / 2,
                    y: (size.height - logoSize.height) / 2,
                    width: logoSize.width,
                    height: logoSize.height
                )
                
                // Draw logo background if configured
                let logoBackgroundColor = appearance.logoBackgroundColor
                logoBackgroundColor.setFill()
                let backgroundRect = logoRect.insetBy(dx: -2, dy: -2)
                let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: appearance.logoCornerRadius)
                path.fill()
                
                // Draw logo image
                logoImage.draw(in: logoRect)
            }
        }
    }
}
