//
//  SheetButton.swift
//  SceytChatUIKit
//
//  Created by Duc on 03/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public class SheetButton: Button {
    public var backgroundColors: (normal: UIColor, highlighted: UIColor)? {
        didSet {
            backgroundColor = backgroundColors?.normal
        }
    }
    
    public override var isHighlighted: Bool {
        didSet {
            if let backgroundColors {
                backgroundColor = isHighlighted ? backgroundColors.highlighted : backgroundColors.normal
            }
        }
    }
}
