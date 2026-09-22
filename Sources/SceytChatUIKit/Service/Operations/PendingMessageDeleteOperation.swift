//
//  PendingMessageDeleteOperation.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Replays one stored "delete this message" intent against the server.
open class PendingMessageDeleteOperation: AsyncOperation {

    /// Guards the queue against an SDK callback that never arrives.
    public static var watchdogTimeout: TimeInterval = 20

    let sender: ChannelMessageSender
    let record: PendingMessageDelete

    private let completionLock = NSLock()
    private var didComplete = false

    public init(sender: ChannelMessageSender, record: PendingMessageDelete) {
        self.sender = sender
        self.record = record
        super.init("\(sender.channelId)-\(record.messageTid)")
        // `AsyncOperation.timeout` is deliberately not used: its `cancel()` never sets
        // `isFinished`, which would wedge a serial queue forever.
    }

    override open func main() {
        guard !isCancelled, DataProvider.chatClient.connectionState == .connected else {
            logger.verbose("SyncService: Skip pending delete for tid \(record.messageTid): cancelled or not connected")
            completeOnce()
            return
        }
        logger.verbose("SyncService: Resending pending delete for tid \(record.messageTid) in channel \(record.channelId)")
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.watchdogTimeout) { [weak self] in
            guard let self, !self.didCompleteValue else { return }
            logger.error("SyncService: Pending delete for tid \(self.record.messageTid) timed out")
            self.completeOnce()
        }
        sender.flushPendingDelete(record) { [weak self] _ in
            self?.completeOnce()
        }
    }

    private var didCompleteValue: Bool {
        completionLock.lock()
        defer { completionLock.unlock() }
        return didComplete
    }

    private func completeOnce() {
        completionLock.lock()
        let alreadyCompleted = didComplete
        didComplete = true
        completionLock.unlock()
        guard !alreadyCompleted else { return }
        complete()
    }
}
