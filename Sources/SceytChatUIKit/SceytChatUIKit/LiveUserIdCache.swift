//
//  LiveUserIdCache.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// The chat client's user id, cached for ``SceytChatUIKit/currentUserId``.
///
/// Asking the client is not a property read: `ChatClient.user` copies the whole
/// native user — every profile string and the metadata map — across the
/// Objective-C++ bridge, only for its `id` to be kept. `currentUserId` is read
/// several times per cell bind, so that copy ran on every frame of a list
/// scroll.
///
/// The native client changes the user id only while authenticating, and a
/// connection state change always follows, so clearing the cache on every
/// state change keeps it exact. That needs an observer; until ``enable()`` is
/// called nothing is cached and every read asks the client, as before.
final class LiveUserIdCache {

    private let lock = NSLock()
    private let readLiveUserId: () -> UserId
    private var cached: UserId?
    private var isEnabled = false
    /// Bumped by every invalidation, so a read that raced one does not store
    /// the id it fetched before it.
    private var generation: UInt64 = 0

    init(readLiveUserId: @escaping () -> UserId) {
        self.readLiveUserId = readLiveUserId
    }

    /// Starts caching. Call it only once something calls ``invalidate()`` on
    /// every connection state change.
    func enable() {
        lock.lock()
        isEnabled = true
        cached = nil
        generation &+= 1
        lock.unlock()
    }

    /// Forgets the cached id; the next read asks the client.
    func invalidate() {
        lock.lock()
        cached = nil
        generation &+= 1
        lock.unlock()
    }

    /// The cached id, or the client's when there is none.
    ///
    /// An empty id is never cached: before the first authentication there is
    /// no user to copy, so reading it is cheap, and caching it would hide the
    /// user that authentication is about to fill in.
    var value: UserId {
        lock.lock()
        if isEnabled, let cached {
            lock.unlock()
            return cached
        }
        let shouldStore = isEnabled
        let readGeneration = generation
        lock.unlock()

        // Outside the lock: it crosses into the native client.
        let liveUserId = readLiveUserId()

        if shouldStore, !liveUserId.isEmpty {
            lock.lock()
            if generation == readGeneration {
                cached = liveUserId
            }
            lock.unlock()
        }
        return liveUserId
    }

    /// Asks the client, bypassing the cache, and caches the answer.
    func refreshed() -> UserId {
        invalidate()
        return value
    }
}

/// Clears ``LiveUserIdCache`` whenever the connection state changes.
final class LiveUserIdCacheInvalidator: NSObject, ChatClientDelegate {

    private let cache: LiveUserIdCache

    init(cache: LiveUserIdCache) {
        self.cache = cache
        super.init()
    }

    func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        cache.invalidate()
    }
}
