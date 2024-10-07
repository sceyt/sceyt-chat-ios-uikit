//
//  EditChannelViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSecondary,
        avatarCellAppearance: SceytChatUIKit.Components.channelEditAvatarCell.appearance,
        textFieldCellAppearance: SceytChatUIKit.Components.channelEditTextFieldCell.appearance,
        uriCellAppearance: SceytChatUIKit.Components.channelEditURICell.appearance,
        uriValidationAppearance: URIValidationAppearance(
            successLabelAppearance: LabelAppearance(
                foregroundColor: .stateSuccess,
                font: Fonts.regular.withSize(13)
            ),
            errorLabelAppearance: LabelAppearance(
                foregroundColor: .stateWarning,
                font: Fonts.regular.withSize(13)
            )
        )
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, EditChannelViewController.AvatarCell.Appearance>
        public var avatarCellAppearance: EditChannelViewController.AvatarCell.Appearance
        
        @Trackable<Appearance, EditChannelViewController.TextFieldCell.Appearance>
        public var textFieldCellAppearance: EditChannelViewController.TextFieldCell.Appearance
        
        @Trackable<Appearance, EditChannelViewController.URICell.Appearance>
        public var uriCellAppearance: EditChannelViewController.URICell.Appearance
        
        @Trackable<Appearance, URIValidationAppearance>
        public var uriValidationAppearance: URIValidationAppearance
        
        public init(
            backgroundColor: UIColor,
            avatarCellAppearance: EditChannelViewController.AvatarCell.Appearance,
            textFieldCellAppearance: EditChannelViewController.TextFieldCell.Appearance,
            uriCellAppearance: EditChannelViewController.URICell.Appearance,
            uriValidationAppearance: URIValidationAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._avatarCellAppearance = Trackable(value: avatarCellAppearance)
            self._textFieldCellAppearance = Trackable(value: textFieldCellAppearance)
            self._uriCellAppearance = Trackable(value: uriCellAppearance)
            self._uriValidationAppearance = Trackable(value: uriValidationAppearance)
        }
        
        public init(
            reference: EditChannelViewController.Appearance,
            backgroundColor: UIColor? = nil,
            avatarCellAppearance: EditChannelViewController.AvatarCell.Appearance? = nil,
            textFieldCellAppearance: EditChannelViewController.TextFieldCell.Appearance? = nil,
            uriCellAppearance: EditChannelViewController.URICell.Appearance? = nil,
            uriValidationAppearance: URIValidationAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._avatarCellAppearance = Trackable(reference: reference, referencePath: \.avatarCellAppearance)
            self._textFieldCellAppearance = Trackable(reference: reference, referencePath: \.textFieldCellAppearance)
            self._uriCellAppearance = Trackable(reference: reference, referencePath: \.uriCellAppearance)
            self._uriValidationAppearance = Trackable(reference: reference, referencePath: \.uriValidationAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let avatarCellAppearance { self.avatarCellAppearance = avatarCellAppearance }
            if let textFieldCellAppearance { self.textFieldCellAppearance = textFieldCellAppearance }
            if let uriCellAppearance { self.uriCellAppearance = uriCellAppearance }
            if let uriValidationAppearance { self.uriValidationAppearance = uriValidationAppearance }
        }
    }
}
