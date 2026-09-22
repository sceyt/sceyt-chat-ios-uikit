//
//  DraftMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class DraftMessageBodyFormatter: DraftMessageBodyFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: DraftMessageBodyFormatterAttributes) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let title = messageBodyAttributes.draftStateText + ": "
        let draftString = NSMutableAttributedString(string: title)
        draftString.addAttributes(
            [
                .foregroundColor: messageBodyAttributes.draftPrefixLabelAppearance.foregroundColor,
                .font: messageBodyAttributes.draftPrefixLabelAppearance.font
            ],
            range: NSMakeRange(0, title.count)
        )
        text.append(draftString)

        let bodyFont = messageBodyAttributes.lastMessageLabelAppearance.font
        let bodyColor = messageBodyAttributes.lastMessageLabelAppearance.foregroundColor

        // With nothing typed, the preview falls back to whatever else the draft holds. Text wins
        // over an attachment, and an attachment over a bare reply/edit target — most informative
        // first.
        if messageBodyAttributes.draftMessage.length == 0,
           messageBodyAttributes.draftAttachment == nil,
           let actionText = messageBodyAttributes.draftActionText
        {
            text.append(NSAttributedString(
                string: actionText,
                attributes: [.font: bodyFont, .foregroundColor: bodyColor]
            ))
            return text
        }

        // An attachments-only draft previews the attachment the same way
        // `ChannelLastMessageBodyFormatter` previews an attachment-only message: icon, space,
        // type name ("Draft: 🖼 Image").
        if messageBodyAttributes.draftMessage.length == 0,
           let attachment = messageBodyAttributes.draftAttachment
        {
            if let icon = messageBodyAttributes.attachmentIconProvider.provideVisual(for: attachment) {
                let iconAttachment = NSTextAttachment()
                iconAttachment.bounds = CGRect(
                    x: 0,
                    y: (bodyFont.capHeight - icon.size.height).rounded() / 2,
                    width: icon.size.width,
                    height: icon.size.height
                )
                iconAttachment.image = icon
                text.append(NSAttributedString(attachment: iconAttachment))
                text.append(NSAttributedString(string: " ", attributes: [.font: bodyFont]))
            }
            text.append(NSAttributedString(
                string: messageBodyAttributes.attachmentNameFormatter.format(attachment),
                attributes: [.font: bodyFont, .foregroundColor: bodyColor]
            ))
            return text
        }

        let contentString = NSMutableAttributedString(attributedString: messageBodyAttributes.draftMessage)
        contentString.addAttributes(
            [
                .foregroundColor: bodyColor,
                .font: bodyFont
            ],
            range: NSMakeRange(0, messageBodyAttributes.draftMessage.length)
        )
        text.append(contentString)
        return text
    }
}
