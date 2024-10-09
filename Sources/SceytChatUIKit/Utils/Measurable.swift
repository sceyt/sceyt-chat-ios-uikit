//
//  Measurable.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.05.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol Measurable: AnyObject {
    associatedtype Model
    associatedtype AppearanceType
    static func measure(model: Model, appearance: AppearanceType) -> CGSize
}
