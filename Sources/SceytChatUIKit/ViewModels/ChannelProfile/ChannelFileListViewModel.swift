//
//  ChannelFileListViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelFileListViewModel: NSObject {

    public let channel: ChatChannel

    public static var queryLimit = SceytChatUIKit.shared.config.queryLimits.messageListQueryLimit
    public static var queryType = "file"

    public typealias Item = (attachment: Attachment, createdAt: Date)
    open var files = [Item]()

    public required init(channel: ChatChannel) {
        self.channel = channel
        super.init()
    }

    open lazy var fileListQuery: MessageListQuery = {
        MessageListQuery
            .Builder(channelId: channel.id)
            .searchFields([.init(key: .attachmentType, search: .contains, searchWord: Self.queryType),
                .init(key: .type, search: .contains, searchWord: Self.queryType)])
            .limit(Self.queryLimit)
            .build()
    }()

    open func filter(messages: [Message]) -> [Item] {
        var files: [Item] = []
        messages.reversed().forEach { message in
            guard let atchs = message.attachments else { return }
            files.append(contentsOf: atchs.compactMap { (atch) in
                guard let type = AttachmentType(rawValue: atch.type) else { return nil }
                switch type {
                case .file:
                    return (atch, message.createdAt)
                default:
                    return nil
                }
            })
        }
        self.files.append(contentsOf: files)
        return files
    }
}
