//
//  MessageCell+Measurable.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.05.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol MessageCellMeasurable: Measurable {
    associatedtype Model = MessageLayoutModel
    associatedtype Appearance = MessageCell.Appearance
}
