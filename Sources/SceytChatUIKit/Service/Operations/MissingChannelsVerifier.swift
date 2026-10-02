//
//  MissingChannelsVerifier.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// What the server says about a channel the channel-list sync did not return.
public enum MissingChannelStatus {
    /// The channel is still the user's. It is stored again and kept.
    case exists
    /// The server confirmed the channel is gone for this user. It is deleted locally.
    case gone
    /// The answer settles nothing — a transport failure, a rate limit, a server error. The channel
    /// is kept and the next sync decides.
    case unknown
}

/// Decides whether a channel the sync missed is really gone.
///
/// The sync pages the server's list by offset, so a channel that gets a new message mid-sync
/// jumps into a page already read and every later page skips it. Missing from the result is
/// therefore not proof of deletion; only the server's answer about that one channel is.
///
/// Kept free of side effects so it can be unit tested without the SDK's `Channel`, whose `init`
/// is unavailable.
public struct MissingChannelPolicy {

    /// A channel the server still returns counts as gone when the channel list would not show it
    /// either: hidden or archived for this user, or the user no longer has a role in it.
    public static func status(hidden: Bool, archived: Bool, userRole: String?) -> MissingChannelStatus {
        if hidden || archived || (userRole ?? "").isEmpty {
            return .gone
        }
        return .exists
    }

    public static func status(error: Error) -> MissingChannelStatus {
        if let code = error.sceytChatCode,
           code == .channelNotExists || code == .notAllowed {
            return .gone
        }
        // `NotFound`, `NotAllowed` and the bad-request family are permanent answers. Everything
        // else — including the transport errors, which carry no `sdkError` at all — is not.
        if let sdkError = error.sdkError, !sdkError.isResendable {
            return .gone
        }
        return .unknown
    }
}

/// Asks about the channels the sync did not return, and reports the ones confirmed gone.
public protocol MissingChannelsVerifier: AnyObject {
    func verify(channelIds: [ChannelId], completion: @escaping (_ goneChannelIds: [ChannelId]) -> Void)
}

/// Fetches every missing channel by id, in parallel, and stores the ones that still exist the
/// same way a sync page is stored.
open class ServerMissingChannelsVerifier: MissingChannelsVerifier {

    /// Called with the channels found to still exist, once they are stored, so the sync can give
    /// them the same message catch-up every fetched page gets.
    public var onRecover: (([Channel]) -> Void)?

    public init() {}

    open func verify(channelIds: [ChannelId], completion: @escaping ([ChannelId]) -> Void) {
        guard !channelIds.isEmpty else {
            completion([])
            return
        }
        let lock = NSLock()
        var existing = [Channel]()
        var gone = [ChannelId]()
        var unknown = [ChannelId]()
        let group = DispatchGroup()
        let param = ChannelProvider.defaultQueryParam

        for channelId in channelIds {
            group.enter()
            SceytChatUIKit.shared.chatClient.getChannel(id: channelId, param: param) { channel, error in
                lock.lock()
                defer {
                    lock.unlock()
                    group.leave()
                }
                if let channel {
                    switch MissingChannelPolicy.status(hidden: channel.hidden, archived: channel.archived, userRole: channel.userRole) {
                    case .exists:
                        existing.append(channel)
                    case .gone:
                        gone.append(channelId)
                    case .unknown:
                        unknown.append(channelId)
                    }
                } else if let error, MissingChannelPolicy.status(error: error) == .gone {
                    gone.append(channelId)
                } else {
                    logger.errorIfNotNil(error, "Confirm missing channel \(channelId)")
                    unknown.append(channelId)
                }
            }
        }

        let onRecover = self.onRecover
        group.notify(queue: .global()) {
            logger.info("SyncService: missing channels — recovered: \(existing.map(\.id)), gone: \(gone), kept until next sync: \(unknown)")
            guard !existing.isEmpty else {
                completion(gone)
                return
            }
            Components.channelListProvider.init().store(channels: existing) { error in
                if error == nil {
                    Components.channelListProvider.syncMessageForReactions(channels: existing)
                    onRecover?(existing)
                }
                completion(gone)
            }
        }
    }
}
