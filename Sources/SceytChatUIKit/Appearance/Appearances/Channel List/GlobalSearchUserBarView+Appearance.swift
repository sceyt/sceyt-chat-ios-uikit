//
//  GlobalSearchUserBarView+Appearance.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 07.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

// MARK: - GlobalSearchUserBarCell Appearance

extension GlobalSearchUserBarCell: AppearanceProviding {

    public static var appearance = Appearance(
        backgroundColor: .background,
        borderColor: DefaultColors.border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(14)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
        avatarRenderer: AnyUserAvatarRendering(SceytChatUIKit.shared.avatarRenderers.userAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )

    public class Appearance: NSObject {

        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        @Trackable<Appearance, UIColor>
        public var borderColor: UIColor

        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance

        @Trackable<Appearance, AnyUserFormatting>
        public var titleFormatter: AnyUserFormatting

        @Trackable<Appearance, AnyUserAvatarRendering>
        public var avatarRenderer: AnyUserAvatarRendering

        @Trackable<Appearance, AvatarAppearance>
        public var avatarAppearance: AvatarAppearance

        public init(
            backgroundColor: UIColor,
            borderColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._borderColor = Trackable(value: borderColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._titleFormatter = Trackable(value: titleFormatter)
            self._avatarRenderer = Trackable(value: avatarRenderer)
            self._avatarAppearance = Trackable(value: avatarAppearance)
        }

        public init(
            reference: GlobalSearchUserBarCell.Appearance,
            backgroundColor: UIColor? = nil,
            borderColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: AnyUserFormatting? = nil,
            avatarRenderer: AnyUserAvatarRendering? = nil,
            avatarAppearance: AvatarAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._borderColor = Trackable(reference: reference, referencePath: \.borderColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._titleFormatter = Trackable(reference: reference, referencePath: \.titleFormatter)
            self._avatarRenderer = Trackable(reference: reference, referencePath: \.avatarRenderer)
            self._avatarAppearance = Trackable(reference: reference, referencePath: \.avatarAppearance)
            super.init()
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let borderColor { self.borderColor = borderColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let titleFormatter { self.titleFormatter = titleFormatter }
            if let avatarRenderer { self.avatarRenderer = avatarRenderer }
            if let avatarAppearance { self.avatarAppearance = avatarAppearance }
        }
    }
}

// MARK: - GlobalSearchUserBarView Appearance

extension GlobalSearchUserBarView: AppearanceProviding {

    public static var appearance = Appearance(
        backgroundColor: .clear,
        separatorColor: DefaultColors.border,
        cellAppearance: GlobalSearchUserBarCell.appearance
    )

    public class Appearance: NSObject {

        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor

        @Trackable<Appearance, GlobalSearchUserBarCell.Appearance>
        public var cellAppearance: GlobalSearchUserBarCell.Appearance

        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            cellAppearance: GlobalSearchUserBarCell.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._cellAppearance = Trackable(value: cellAppearance)
        }

        public init(
            reference: GlobalSearchUserBarView.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            cellAppearance: GlobalSearchUserBarCell.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            super.init()
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
