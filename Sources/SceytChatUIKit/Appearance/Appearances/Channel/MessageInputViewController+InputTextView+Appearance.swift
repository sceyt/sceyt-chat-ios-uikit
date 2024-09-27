//
//  MessageInputViewController+InputTextView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.InputTextView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var textInputAppearance: TextInputAppearance = .init(backgroundColor: .surface1,
                                                                         placeholder: L10n.Message.Input.placeholder,
                                                                         borderColor: .clear)
        
        // Initializer with default values
        public init(
            textInputAppearance: TextInputAppearance = .init(backgroundColor: .surface1,
                                                             placeholder: L10n.Message.Input.placeholder,
                                                             borderColor: .clear)
        ) {
            self.textInputAppearance = textInputAppearance
        }
    }
}
