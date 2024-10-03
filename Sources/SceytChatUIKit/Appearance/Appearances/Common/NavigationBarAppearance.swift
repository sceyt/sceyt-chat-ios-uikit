//
//  NavigationBarAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct NavigationBarAppearance {
    public var backgroundColor: UIColor? = .background
    public var backIcon: UIImage?
    public var leftBarButtonsAppearance: [BarButtonAppearance] = []
    public var rightBarButtonsAppearance: [BarButtonAppearance] = []
    public var title: String?
    public var titleLabelAppearance: LabelAppearance?
    public var subtitle: String?
    public var subtitleLabelAppearance: LabelAppearance?
    public var titleFormatter: (any Formatting)?
    public var subtitleFormatter: (any Formatting)?
    public var underlineColor: UIColor?
    public init() {}
}
