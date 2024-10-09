//
//  PreviewerViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import Photos
import SceytChat
import Combine

open class PreviewerViewModel: PreviewDataSourceItemObservable {
    
    public let index: Int
    public private(set) var previewItem: PreviewItem
    
    @Published public var event: Event?
    
    required public init(index: Int, previewItem: PreviewItem) {
        self.previewItem = previewItem
        self.index = index
    }
    
    open func save() {
        let attachment = previewItem.attachment
        if attachment.type == "video" {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: attachment.fileUrl ?? attachment.originUrl)
            }) { _, error in
                self.event = .videoSaved(error)
            }
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: attachment.fileUrl ?? attachment.originUrl)
            }) { _, error in
                self.event = .photoSaved(error)
            }
        }
    }

    open func forward(
        channelIds: [ChannelId],
        completion: (() -> Void)? = nil
    ) {
        guard !channelIds.isEmpty else {
            completion?()
            return
        }
        let attachment = previewItem.attachment
        let message = try? DataProvider.database.read {
            MessageDTO.fetch(id: attachment.messageId, context: $0)?
                .convert()
        }.get()
        guard let message else { return }
        let builder = message.builder
        builder.id(0)
        builder.tid(0)
        builder.parentMessageId(0)
        builder.forwardingMessageId(attachment.messageId)
        builder.attachments([attachment.builder.build()])
        
        let group = DispatchGroup()
        for channelId in channelIds {
            group.enter()
            let message = builder.build()
            Components.channelMessageSender
                .init(channelId: channelId)
                .sendMessage(message) { _ in
                    group.leave()
                }
        }
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    public func didUpdate(previewItem: PreviewItem) {
        if self.previewItem.attachment.filePath != nil {
            return
        }
        self.previewItem = previewItem
        event = .didUpdateItem
    }
}

public extension PreviewerViewModel {
    enum Event {
        case photoSaved(Error?)
        case videoSaved(Error?)
        case didUpdateItem
    }
}
