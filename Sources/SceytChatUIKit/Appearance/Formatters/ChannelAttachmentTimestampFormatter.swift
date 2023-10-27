//
//  ChannelAttachmentTimestampFormatter.swift
//  SceytChatUIKit
//
//  Created by Duc on 25/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol ChannelProfileFileTimestamp: TimestampFormatter {
    func format(_ date: Date) -> String
    func header(_ date: Date) -> String
}
