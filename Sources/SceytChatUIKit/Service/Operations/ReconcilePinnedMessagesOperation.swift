//
//  ReconcilePinnedMessagesOperation.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Deletes the channel's local pins the completed sweep did not report.
///
/// The `DeleteChannelsOperation` analogue, and it carries the same hard rule: this operation must
/// be **cancelled** when the fetch that seeds it failed. A half-read answer would otherwise look
/// like "the server has fewer pins now" and wipe good rows. `SyncService.Operations`
/// `.syncChannelPinOperations` is where that cancel lives.
open class ReconcilePinnedMessagesOperation: AsyncOperation {

    public let channelId: ChannelId
    public private(set) var serverPinIds: Set<Int64>

    private let provider: ChannelPinnedMessageProvider

    public init(
        channelId: ChannelId,
        provider: ChannelPinnedMessageProvider,
        serverPinIds: Set<Int64> = []
    ) {
        self.channelId = channelId
        self.provider = provider
        self.serverPinIds = serverPinIds
        super.init("reconcile-pins-\(channelId)")
    }

    open func addPin(serverPinIds ids: [Int64]) {
        serverPinIds.formUnion(ids)
    }

    override open func main() {
        guard !isCancelled else {
            complete()
            return
        }
        provider.reconcile(serverPinIds: serverPinIds) { [weak self] _ in
            self?.complete()
        }
    }
}
