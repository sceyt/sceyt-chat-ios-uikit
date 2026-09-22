//
//  KeyHelpers.swift
//  SceytChatUIKitTests
//
//  Test helpers for building `ChannelViewModel.Key` values without needing
//  a real `ChatMessage`. Used to construct synthetic `appliedSnapshot`
//  fixtures in canReconcile tests.
//

@testable import SceytChatUIKit
import SceytChat

extension ChannelViewModel.Key {
    /// Build a deterministic fake Key with a synthetic message id.
    /// Different ids produce distinct keys (Equatable / Hashable).
    static func fake(_ id: MessageId) -> ChannelViewModel.Key {
        .init(messageId: id)
    }
}
