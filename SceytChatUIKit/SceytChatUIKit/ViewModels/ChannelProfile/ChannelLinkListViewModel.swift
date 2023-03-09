//
//  ChannelLinkListViewModel.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelLinkListViewModel: NSObject {

    public let channel: ChatChannel
    public let linkMetadataProvider: LinkMetadataProvider?

    public static var queryLimit = UInt(10)
    public static var queryType = "link"

    open var links = [URL]()

    public required init(channel: ChatChannel, linkMetadataProvider: LinkMetadataProvider?) {
        self.channel = channel
        self.linkMetadataProvider = linkMetadataProvider
        super.init()
    }

    open lazy var linkListQuery: MessageListQueryByType = {
        MessageListQueryByType
            .Builder(channelId: channel.id,
                     type: Self.queryType)
            .limit(Self.queryLimit)
            .build()
    }()

    open func loadLinks(_ completion: @escaping ([URL]) -> Void) {
        if !linkListQuery.hasNext || linkListQuery.loading {
            completion([])
            return
        }
        linkListQuery.loadNext {[weak self] (_, messages, _) in
            if let messages = messages {
                let items = self?.filter(messages: messages) ?? []
                completion(items)
            } else {
                completion([])
            }
        }
    }

    open func filter(messages: [Message]) -> [URL] {
        var links = [URL]()
        messages.reversed().forEach {
            links.append(contentsOf: LinkDetector.getLinks(text: $0.body))
        }
        self.links.append(contentsOf: links)
        return links
    }
}
