//
//  FontFormatter.swift
//  SceytChatUIKit
//
//  Created by Duc on 26/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol FontFormatter {
    func isBold(_ font: UIFont) -> Bool
    func isItalic(_ font: UIFont) -> Bool
    func isMonospace(_ font: UIFont) -> Bool
    func toMonospace(_ original: UIFont) -> UIFont
    func toBold(_ original: UIFont) -> UIFont
    func toItalic(_ original: UIFont) -> UIFont
}
