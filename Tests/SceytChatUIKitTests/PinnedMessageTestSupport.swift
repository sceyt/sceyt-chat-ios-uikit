//
//  PinnedMessageTestSupport.swift
//  SceytChatUIKitTests
//
//  Shared doubles for the pinned-message suites.
//

@testable import SceytChatUIKit
import Foundation
import SceytChat

/// A `ChannelOperator` that answers pin/unpin requests without a server.
///
/// It can only ever answer "failed" or "succeeded with no pins", because the success payload is
/// `[SceytChat.PinnedMessage]` and that type declares `init` unavailable — nothing outside the
/// SDK can build one. Both answers land on the same production branch (roll back, then re-sync),
/// which is the branch worth exercising; the genuine success path is
/// `ChannelPinnedMessageProvider.confirm`, which is why that is a separate, testable method.
///
/// Without this, `pin()` would call the real operator, the SDK would never call back for want of
/// a connection, and the test would hang rather than fail.
final class MockChannelOperator: ChannelOperator {

    var pinError: SceytError?
    var unpinError: SceytError?

    private let lock = NSLock()
    private var _pinnedIds = [[NSNumber]]()
    private var _unpinnedIds = [[NSNumber]]()
    private var _lastPinTill: Date?
    private var _lastPinType: PinType?

    /// Locked, because the concurrency suite calls these from many threads at once.
    var pinnedIds: [[NSNumber]] { lock.lock(); defer { lock.unlock() }; return _pinnedIds }
    var unpinnedIds: [[NSNumber]] { lock.lock(); defer { lock.unlock() }; return _unpinnedIds }
    var lastPinTill: Date? { lock.lock(); defer { lock.unlock() }; return _lastPinTill }
    var lastPinType: PinType? { lock.lock(); defer { lock.unlock() }; return _lastPinType }

    override func pinMessages(
        ids: [NSNumber],
        pinTill: Date?,
        pinType: PinType,
        completion: @escaping PinnedMessagesCompletion
    ) {
        lock.lock()
        _pinnedIds.append(ids)
        _lastPinTill = pinTill
        _lastPinType = pinType
        let error = pinError
        lock.unlock()
        completion(nil, error)
    }

    override func unpinMessages(ids: [NSNumber], completion: @escaping PinnedMessagesCompletion) {
        lock.lock()
        _unpinnedIds.append(ids)
        let error = unpinError
        lock.unlock()
        completion(nil, error)
    }
}

/// A provider wired to `MockChannelOperator` through the `makeChannelOperator()` seam.
final class MockPinnedMessageProvider: ChannelPinnedMessageProvider {

    let mockOperator: MockChannelOperator

    /// Unit tests never connect, so the real `canReachServer` would short-circuit every request.
    /// Set it to `false` to exercise the offline branch on purpose.
    var isConnected = true

    required init(channelId: ChannelId) {
        mockOperator = MockChannelOperator(channelId: channelId)
        super.init(channelId: channelId)
    }

    override func makeChannelOperator() -> ChannelOperator { mockOperator }

    override var canReachServer: Bool { isConnected }
}
