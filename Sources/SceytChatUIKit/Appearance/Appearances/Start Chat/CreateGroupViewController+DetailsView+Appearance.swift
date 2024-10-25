//
//  CreateGroupViewController+DetailsView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension CreateGroupViewController.DetailsView: AppearanceProviding {
    
    public static var appearance = Appearance(
        avatarBackgroundColor: .surface3,
        separatorColor: .border,
        avatarDefaultIcon: .editAvatar,
        nameTextFieldAppearance: .init(
            reference: TextInputAppearance.appearance,
            placeholder: L10n.Channel.Subject.Group.placeholder
        ),
        aboutTextFieldAppearance: .init(
            reference: TextInputAppearance.appearance,
            placeholder: L10n.Channel.Subject.descriptionPlaceholder
        ),
        uriTextFieldAppearance: .init(
            reference: TextInputAppearance.appearance,
            placeholder: L10n.Channel.Create.Uri.placeholder
        ),
        uriValidationAppearance: URIValidationAppearance(
            successLabelAppearance: LabelAppearance(
                foregroundColor: .stateSuccess,
                font: Fonts.regular.withSize(13)
            ),
            errorLabelAppearance: LabelAppearance(
                foregroundColor: .stateWarning,
                font: Fonts.regular.withSize(13)
            )
        ),
        captionLabelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var avatarBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var avatarDefaultIcon: UIImage
        
        @Trackable<Appearance, TextInputAppearance>
        public var nameTextFieldAppearance: TextInputAppearance
        
        @Trackable<Appearance, TextInputAppearance>
        public var aboutTextFieldAppearance: TextInputAppearance
        
        @Trackable<Appearance, TextInputAppearance>
        public var uriTextFieldAppearance: TextInputAppearance
        
        @Trackable<Appearance, URIValidationAppearance>
        public var uriValidationAppearance: URIValidationAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var captionLabelAppearance: LabelAppearance
        
        public init(
            avatarBackgroundColor: UIColor,
            separatorColor: UIColor,
            avatarDefaultIcon: UIImage,
            nameTextFieldAppearance: TextInputAppearance,
            aboutTextFieldAppearance: TextInputAppearance,
            uriTextFieldAppearance: TextInputAppearance,
            uriValidationAppearance: URIValidationAppearance,
            captionLabelAppearance: LabelAppearance
        ){
            self._avatarBackgroundColor = Trackable(value: avatarBackgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._avatarDefaultIcon = Trackable(value: avatarDefaultIcon)
            self._nameTextFieldAppearance = Trackable(value: nameTextFieldAppearance)
            self._aboutTextFieldAppearance = Trackable(value: aboutTextFieldAppearance)
            self._uriTextFieldAppearance = Trackable(value: uriTextFieldAppearance)
            self._uriValidationAppearance = Trackable(value: uriValidationAppearance)
            self._captionLabelAppearance = Trackable(value: captionLabelAppearance)
        }
        
        public init(
            reference: CreateGroupViewController.DetailsView.Appearance,
            avatarBackgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            avatarDefaultIcon: UIImage? = nil,
            nameTextFieldAppearance: TextInputAppearance? = nil,
            aboutTextFieldAppearance: TextInputAppearance? = nil,
            uriTextFieldAppearance: TextInputAppearance? = nil,
            uriValidationAppearance: URIValidationAppearance? = nil,
            captionLabelAppearance: LabelAppearance? = nil
        ) {
            self._avatarBackgroundColor = Trackable(reference: reference, referencePath: \.avatarBackgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._avatarDefaultIcon = Trackable(reference: reference, referencePath: \.avatarDefaultIcon)
            self._nameTextFieldAppearance = Trackable(reference: reference, referencePath: \.nameTextFieldAppearance)
            self._aboutTextFieldAppearance = Trackable(reference: reference, referencePath: \.aboutTextFieldAppearance)
            self._uriTextFieldAppearance = Trackable(reference: reference, referencePath: \.uriTextFieldAppearance)
            self._uriValidationAppearance = Trackable(reference: reference, referencePath: \.uriValidationAppearance)
            self._captionLabelAppearance = Trackable(reference: reference, referencePath: \.captionLabelAppearance)
            
            if let avatarBackgroundColor { self.avatarBackgroundColor = avatarBackgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let avatarDefaultIcon { self.avatarDefaultIcon = avatarDefaultIcon }
            if let nameTextFieldAppearance { self.nameTextFieldAppearance = nameTextFieldAppearance }
            if let aboutTextFieldAppearance { self.aboutTextFieldAppearance = aboutTextFieldAppearance }
            if let uriTextFieldAppearance { self.uriTextFieldAppearance = uriTextFieldAppearance }
            if let uriValidationAppearance { self.uriValidationAppearance = uriValidationAppearance }
            if let captionLabelAppearance { self.captionLabelAppearance = captionLabelAppearance }
        }
    }
}
