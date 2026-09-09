//
//  FetchAllPinnedMessagesOperation.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Walks every page of a channel's server pins, storing each page as it lands.
///
/// The `FetchAllChannelsOperation` analogue, with two deliberate differences:
///
/// - Pagination here is **opaque-token based** (`ListQueryPage.nextToken`), so `query.hasNext` is
///   the only loop condition. Do not add a `pins.count < query.limit` short-circuit the way the
///   channel version has — a full page with an empty token is a legitimate last page.
/// - The watchdog is a plain timer rather than `AsyncOperation.timeout`, whose `cancel()` never
///   sets `isFinished` and would wedge a serial queue forever. Same reason, same shape, as
///   `PendingMessageDeleteOperation`.
///
/// `result` accumulates every pin across every page — that is what seeds
/// `ReconcilePinnedMessagesOperation`'s keep set. A failure leaves `result` a `.failure`, which is
/// what makes the reconcile step cancel itself rather than delete pins on a half-read answer.
open class FetchAllPinnedMessagesOperation: AsyncOperation {

    /// Guards the queue against an SDK callback that never arrives.
    public static var watchdogTimeout: TimeInterval = 20

    public private(set) var result: Result<[SceytChat.PinnedMessage], Error>?
    public var onLoad: (([SceytChat.PinnedMessage]) -> Void)?

    private let query: PinnedMessagesListQuery
    private let provider: ChannelPinnedMessageProvider

    private var pins = [SceytChat.PinnedMessage]()
    private let completionLock = NSLock()
    private var didComplete = false

    public init(query: PinnedMessagesListQuery, provider: ChannelPinnedMessageProvider) {
        self.query = query
        self.provider = provider
        super.init("pins-\(query.channelId)")
    }

    override open func main() {
        guard !isCancelled else {
            finish(result: .failure(SyncOperation.OperationError.cancelled))
            return
        }
        guard DataProvider.chatClient.connectionState == .connected else {
            logger.verbose("SyncService: skip pin sync for channel \(query.channelId) — not connected")
            finish(result: .failure(SyncOperation.OperationError.cancelled))
            return
        }

        finish(result: .failure(SyncOperation.OperationError.cancelled))
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.watchdogTimeout) { [weak self] in
            guard let self, !self.didCompleteValue else { return }
            logger.error("SyncService: pin sync for channel \(self.query.channelId) timed out")
            self.finish(result: .failure(SyncOperation.OperationError.cancelled))
        }

        loadNextPage()
    }

    private func loadNextPage() {
        // Cancellation is only observed between pages, as in `FetchAllChannelsOperation`.
        guard !isCancelled else {
            finish(result: .failure(SyncOperation.OperationError.cancelled))
            return
        }
        query.loadNext { [weak self] query, pins, error in
            guard let self else { return }
            if let error {
                logger.errorIfNotNil(error, "Load pinned messages page for channel \(query.channelId)")
                self.finish(result: .failure(error))
                return
            }
            let pins = pins ?? []
            self.pins.append(contentsOf: pins)
            self.onLoad?(pins)

            // Advance only once the page is on disk, so the banner grows monotonically and a
            // later page can never be written before an earlier one.
            self.provider.store(pinnedMessages: pins) { [weak self] _ in
                guard let self else { return }
                if query.hasNext {
                    self.loadNextPage()
                } else {
                    self.finish(result: .success(self.pins))
                }
            }
        }
    }

    private var didCompleteValue: Bool {
        completionLock.lock()
        defer { completionLock.unlock() }
        return didComplete
    }

    private func finish(result: Result<[SceytChat.PinnedMessage], Error>) {
        completionLock.lock()
        let alreadyCompleted = didComplete
        didComplete = true
        completionLock.unlock()
        guard !alreadyCompleted else { return }
        self.result = result
        complete()
    }
}
