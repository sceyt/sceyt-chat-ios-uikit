//
//  DraftMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class DraftMessageBodyFormatter: DraftMessageBodyFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: DraftMessageBodyFormatterAttributes) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let title = messageBodyAttributes.draftStateText
        let draftString = NSMutableAttributedString(string: "\(title)\n")
        draftString.addAttributes(
            [
                .foregroundColor: messageBodyAttributes.draftPrefixLabelAppearance.foregroundColor,
                .font: messageBodyAttributes.draftPrefixLabelAppearance.font
            ],
            range: NSMakeRange(0, title.count)
        )
        text.append(draftString)
        
        let contentString = NSMutableAttributedString(attributedString: messageBodyAttributes.draftMessage)
        contentString.addAttributes(
            [
                .foregroundColor: messageBodyAttributes.lastMessageLabelAppearance.foregroundColor,
                .font: messageBodyAttributes.lastMessageLabelAppearance.font
            ],
            range: NSMakeRange(0, messageBodyAttributes.draftMessage.length)
        )
        text.append(contentString)
        return text
    }
}
