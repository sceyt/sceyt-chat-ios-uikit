//
//  EditChannelViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .backgroundSecondary
        public var avatarCellAppearance: EditChannelViewController.AvatarCell.Appearance = SceytChatUIKit.Components.channelEditAvatarCell.appearance
        public var textFieldCellAppearance: EditChannelViewController.TextFieldCell.Appearance = SceytChatUIKit.Components.channelEditTextFieldCell.appearance
        public var uriCellAppearance: EditChannelViewController.URICell.Appearance = SceytChatUIKit.Components.channelEditURICell.appearance
        public var uriValidationAppearance: URIValidationAppearance = .init(
            successLabelAppearance: .init(
                foregroundColor: .stateSuccess,
                font: Fonts.regular.withSize(13)
            ),
            errorLabelAppearance: .init(
                foregroundColor: .stateWarning,
                font: Fonts.regular.withSize(13)
            )
        )
        
        public init(
            backgroundColor: UIColor = .backgroundSecondary,
            avatarCellAppearance: EditChannelViewController.AvatarCell.Appearance = SceytChatUIKit.Components.channelEditAvatarCell.appearance,
            textFieldCellAppearance: EditChannelViewController.TextFieldCell.Appearance = SceytChatUIKit.Components.channelEditTextFieldCell.appearance,
            uriCellAppearance: EditChannelViewController.URICell.Appearance = SceytChatUIKit.Components.channelEditURICell.appearance,
            uriValidationAppearance: URIValidationAppearance = .init(
                successLabelAppearance: .init(
                    foregroundColor: .stateSuccess,
                    font: Fonts.regular.withSize(13)
                ),
                errorLabelAppearance: .init(
                    foregroundColor: .stateWarning,
                    font: Fonts.regular.withSize(13)
                )
            )
        ) {
            self.backgroundColor = backgroundColor
            self.avatarCellAppearance = avatarCellAppearance
            self.textFieldCellAppearance = textFieldCellAppearance
            self.uriCellAppearance = uriCellAppearance
            self.uriValidationAppearance = uriValidationAppearance
        }
    }
}
