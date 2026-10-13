//
//  PinResendOperation.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

/// Replays one stored pin-or-unpin intent against the server.
///
/// The `ReactionResendOperation` analogue. Like a pending reaction, the intent lives in the store
/// (`PinnedMessageDTO.syncState`) rather than in this operation, so it survives relaunch and the
/// operation is free to fail: whatever is still pending is picked up by the next
/// `SyncService.sendPendingPins()`.
///
/// The provider decides what to send from the record's own `syncState`, and it is the provider
/// that posts the "X pinned" system message when the server acks a `.forAll` pin — which for a
/// pin taken offline is right here, long after the user tapped it.
open class PinResendOperation: AsyncOperation {

    /// Guards the queue against an SDK callback that never arrives.
    public static var watchdogTimeout: TimeInterval = 20

    let provider: ChannelPinnedMessageProvider
    let record: PinnedMessage

    private let completionLock = NSLock()
    private var didComplete = false

    public init(provider: ChannelPinnedMessageProvider, record: PinnedMessage) {
        self.provider = provider
        self.record = record
        super.init("pin-resend-\(record.channelId)-\(record.messageTid)")
        // `AsyncOperation.timeout` is deliberately not used: its `cancel()` never sets
        // `isFinished`, which would wedge a serial queue forever.
    }

    override open func main() {
        guard !isCancelled, DataProvider.chatClient.connectionState == .connected else {
            logger.info("[Pin] sync: skipping intent for message tid \(record.messageTid): cancelled or not connected")
            completeOnce()
            return
        }
        logger.info("[Pin] sync: draining \(record.syncState) intent for message \(record.messageId) (tid \(record.messageTid)) in channel \(record.channelId)")

        DispatchQueue.global().asyncAfter(deadline: .now() + Self.watchdogTimeout) { [weak self] in
            guard let self, !self.didCompleteValue else { return }
            logger.error("[Pin] sync: intent for message tid \(self.record.messageTid) timed out after \(Self.watchdogTimeout)s — it stays queued")
            self.completeOnce()
        }

        // Captured up front: the closure is `[weak self]`, so it must not reach through `self`.
        let messageId = record.messageId
        let channelId = record.channelId
        provider.flushPendingIntent(record) { [weak self] error in
            // The error is deliberately swallowed *as an operation result*: the intent is still on
            // disk, so the next sync retries it, and failing the operation would only stall the
            // queue behind it. It is still logged — by the provider, and again here so the drain
            // reads as one story.
            if let error {
                logger.error("[Pin] sync: intent for message \(messageId) in channel \(channelId) still not sent: \(error)")
            } else {
                logger.info("[Pin] sync: intent for message \(messageId) in channel \(channelId) drained")
            }
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
