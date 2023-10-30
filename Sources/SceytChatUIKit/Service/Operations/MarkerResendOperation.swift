//
//  MarkerResendOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 30.06.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class MarkerResendOperation: AsyncOperation {
    let provider: ChannelMessageMarkerProvider
    let messageIds: [MessageId]
    let markerName: String
    public init(provider: ChannelMessageMarkerProvider,
                messageIds: [MessageId],
                markerName: String) {
        self.provider = provider
        self.messageIds = messageIds
        self.markerName = markerName
        super.init(String(provider.channelId))
//        timeout = 15.0
    }
    
    override open func main() {
        mark { [weak self] in
            self?.complete()
        }
    }
    
    private func mark(_ completion: @escaping () -> Void) {
        let mids = messageIds
        log.verbose("SyncService: Resending Marker with messageIds \(mids)")
        provider.mark(
            ids: messageIds,
            markerName: markerName
        ) { error in
            log.errorIfNotNil(error, "SyncService: Resending Marker with messageIds \(mids)")
            completion()
        }
    }
}
