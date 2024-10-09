//
//  MessageInputViewController+InputTextView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.InputTextView: AppearanceProviding {
    public static var appearance = Appearance(
        textInputAppearance: TextInputAppearance(
            reference: TextInputAppearance.appearance,
            backgroundColor: .surface1,
            placeholder: L10n.Message.Input.placeholder,
            borderColor: .clear
        )
    )
    
    public struct Appearance {
        @Trackable<Appearance, TextInputAppearance>
        public var textInputAppearance: TextInputAppearance
        
        public init(
            textInputAppearance: TextInputAppearance
        ) {
            self._textInputAppearance = Trackable(value: textInputAppearance)
        }
        
        public init(
            reference: MessageInputViewController.InputTextView.Appearance,
            textInputAppearance: TextInputAppearance? = nil
        ) {
            self._textInputAppearance = Trackable(reference: reference, referencePath: \.textInputAppearance)
            
            if let textInputAppearance { self.textInputAppearance = textInputAppearance }
        }
    }
}
