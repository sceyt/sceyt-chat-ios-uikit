//
//  AttachmentIconProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct AttachmentIconProvider: AttachmentIconProviding {
    public func provideVisual(for attachment: ChatMessage.Attachment) -> UIImage? {
        UIImage(named: "attachment")
    }
}
