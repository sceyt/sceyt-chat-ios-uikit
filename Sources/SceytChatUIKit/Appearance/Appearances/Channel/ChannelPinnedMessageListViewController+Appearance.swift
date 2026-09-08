//
//  ChannelPinnedMessageListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelPinnedMessageListViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: .init(
            reference: NavigationBarAppearance.appearance,
            standardAppearance: {
                let appearance = UINavigationBarAppearance()
                appearance.titleTextAttributes = [
                    .font: Fonts.bold.withSize(20),
                    .foregroundColor: UIColor.primaryText
                ]
                appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
                appearance.backgroundColor = .surface1
                appearance.shadowColor = .border
                return appearance
            }()
        ),
        backgroundColor: .background,
        messageCellAppearance: ChatMessageCell.appearance,
        navigateIcon: .pinnedMessageNavigate,
        navigateIconTintColor: .iconSecondary,
        navigateIconBackgroundColor: UIColor(light: UIColor(rgb: 0xF0F2F5), dark: UIColor(rgb: 0x25262A)),
        closeIcon: .closeIcon,
        closeIconTintColor: .closeButtonTint,
        emptyStateAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: nil,
            title: L10n.Channel.PinnedMessages.empty,
            message: nil
        ),
        titleText: L10n.Channel.PinnedMessages.title,
        unpinActionTitleText: L10n.Message.Action.Title.unpin,
        unpinActionBackgroundColor: .stateWarning
    )

    public struct Appearance {

        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance

        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        /// The rows are the conversation's own message cells, so they take the
        /// conversation's cell appearance — same bubbles, same fonts.
        @Trackable<Appearance, MessageCellAppearance>
        public var messageCellAppearance: MessageCellAppearance

        /// The arrow beside each row — the one control that jumps the conversation to
        /// that message. Just the glyph: the disc behind it is `navigateIconBackgroundColor`.
        @Trackable<Appearance, UIImage>
        public var navigateIcon: UIImage

        /// Tints `navigateIcon`, which is a template image.
        @Trackable<Appearance, UIColor>
        public var navigateIconTintColor: UIColor

        /// The disc drawn behind `navigateIcon`.
        @Trackable<Appearance, UIColor>
        public var navigateIconBackgroundColor: UIColor

        /// The bar button at the trailing edge of the navigation bar — the screen is
        /// presented, so it closes itself rather than popping.
        @Trackable<Appearance, UIImage>
        public var closeIcon: UIImage

        /// Tints `closeIcon`, which is a template image. The button's background is the
        /// system's own — a bar button item draws it, so nothing here describes it.
        @Trackable<Appearance, UIColor>
        public var closeIconTintColor: UIColor

        /// Shown once the last pin goes away — the screen stays up rather than popping.
        @Trackable<Appearance, EmptyStateView.Appearance>
        public var emptyStateAppearance: EmptyStateView.Appearance

        @Trackable<Appearance, String>
        public var titleText: String

        /// The row's trailing swipe action.
        @Trackable<Appearance, String>
        public var unpinActionTitleText: String

        @Trackable<Appearance, UIColor>
        public var unpinActionBackgroundColor: UIColor

        public init(
            navigationBarAppearance: NavigationBarAppearance,
            backgroundColor: UIColor,
            messageCellAppearance: MessageCellAppearance,
            navigateIcon: UIImage,
            navigateIconTintColor: UIColor,
            navigateIconBackgroundColor: UIColor,
            closeIcon: UIImage,
            closeIconTintColor: UIColor,
            emptyStateAppearance: EmptyStateView.Appearance,
            titleText: String,
            unpinActionTitleText: String,
            unpinActionBackgroundColor: UIColor
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._messageCellAppearance = Trackable(value: messageCellAppearance)
            self._navigateIcon = Trackable(value: navigateIcon)
            self._navigateIconTintColor = Trackable(value: navigateIconTintColor)
            self._navigateIconBackgroundColor = Trackable(value: navigateIconBackgroundColor)
            self._closeIcon = Trackable(value: closeIcon)
            self._closeIconTintColor = Trackable(value: closeIconTintColor)
            self._emptyStateAppearance = Trackable(value: emptyStateAppearance)
            self._titleText = Trackable(value: titleText)
            self._unpinActionTitleText = Trackable(value: unpinActionTitleText)
            self._unpinActionBackgroundColor = Trackable(value: unpinActionBackgroundColor)
        }

        public init(
            reference: ChannelPinnedMessageListViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            backgroundColor: UIColor? = nil,
            messageCellAppearance: MessageCellAppearance? = nil,
            navigateIcon: UIImage? = nil,
            navigateIconTintColor: UIColor? = nil,
            navigateIconBackgroundColor: UIColor? = nil,
            closeIcon: UIImage? = nil,
            closeIconTintColor: UIColor? = nil,
            emptyStateAppearance: EmptyStateView.Appearance? = nil,
            titleText: String? = nil,
            unpinActionTitleText: String? = nil,
            unpinActionBackgroundColor: UIColor? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._messageCellAppearance = Trackable(reference: reference, referencePath: \.messageCellAppearance)
            self._navigateIcon = Trackable(reference: reference, referencePath: \.navigateIcon)
            self._navigateIconTintColor = Trackable(reference: reference, referencePath: \.navigateIconTintColor)
            self._navigateIconBackgroundColor = Trackable(reference: reference, referencePath: \.navigateIconBackgroundColor)
            self._closeIcon = Trackable(reference: reference, referencePath: \.closeIcon)
            self._closeIconTintColor = Trackable(reference: reference, referencePath: \.closeIconTintColor)
            self._emptyStateAppearance = Trackable(reference: reference, referencePath: \.emptyStateAppearance)
            self._titleText = Trackable(reference: reference, referencePath: \.titleText)
            self._unpinActionTitleText = Trackable(reference: reference, referencePath: \.unpinActionTitleText)
            self._unpinActionBackgroundColor = Trackable(reference: reference, referencePath: \.unpinActionBackgroundColor)

            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let messageCellAppearance { self.messageCellAppearance = messageCellAppearance }
            if let navigateIcon { self.navigateIcon = navigateIcon }
            if let navigateIconTintColor { self.navigateIconTintColor = navigateIconTintColor }
            if let navigateIconBackgroundColor { self.navigateIconBackgroundColor = navigateIconBackgroundColor }
            if let closeIcon { self.closeIcon = closeIcon }
            if let closeIconTintColor { self.closeIconTintColor = closeIconTintColor }
            if let emptyStateAppearance { self.emptyStateAppearance = emptyStateAppearance }
            if let titleText { self.titleText = titleText }
            if let unpinActionTitleText { self.unpinActionTitleText = unpinActionTitleText }
            if let unpinActionBackgroundColor { self.unpinActionBackgroundColor = unpinActionBackgroundColor }
        }
    }
}
