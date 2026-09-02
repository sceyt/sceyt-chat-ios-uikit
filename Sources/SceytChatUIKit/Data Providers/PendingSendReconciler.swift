//
//  PendingSendReconciler.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Recovers the `tid → id` binding for an outgoing message whose send ack was lost.
///
/// The SDK can drop a send response it has *already* matched to its request — it logs
/// `"Received late response for timed-out request … ignoring"` — and then reports the send as
/// `deliveryStatus == .failed` with `id == 0`. The message is on the server, so its delivery
/// markers arrive normally, but a marker carries only server ids (`MessageListMarker` has no
/// `tid`), and the local row is still at `id == 0`. `MessageDatabaseSession.update(messageMarkers:)`
/// matches by id and additionally excludes `pending`/`failed` rows, so the marker is dropped
/// (`marker.unknownMessage` in the trace) and the row keeps the failed tick for the rest of the
/// session.
///
/// A marker naming an id this device has never stored, arriving in a channel that *does* hold an
/// outgoing row stuck at `id == 0`, is positive evidence that one of our sends actually landed.
/// Since the marker cannot say *which* one, the ids are resolved the only authoritative way:
/// ask the server for them and read the `tid` off the messages it returns. That the server echoes
/// the original tid for our own messages is what already makes the message-list sync able to
/// repair such a row — this just stops the repair from depending on the user reopening the chat.
///
/// The lookup is **read-only**, so unlike retrying the send it cannot produce a duplicate.
public enum PendingSendReconciler {

    /// Set to `false` to disable reconciliation entirely.
    public static var isEnabled = true

    /// Upper bound on ids sent to `getMessages(ids:)` in one lookup. A `displayed` marker can name
    /// a long range; only the unknown ids are ever requested, but the request still needs a cap.
    public static var maxLookupIds = 50

    private static let lock = NSLock()
    /// Channels with a lookup in flight, so a burst of markers (the reproduction had eight
    /// `displayed` markers inside 120 ms) produces one request rather than eight.
    nonisolated(unsafe) private static var inFlightChannels = Set<ChannelId>()

    /// Ids the server has already answered for, so a marker that keeps arriving for genuinely
    /// un-synced history doesn't re-request it every time. Only populated once a lookup
    /// *completes* — a lookup that failed on the network stays retryable.
    nonisolated(unsafe) private static var answeredIds = Set<MessageId>()

    /// Keeps `answeredIds` from growing without bound over a long session.
    public static var maxAnsweredIds = 500

    // MARK: - Entry point

    /// Called after a marker has been written. Cheap and silent in the common case: it does a
    /// single local read and returns unless there is both an unknown id *and* a stuck outgoing row.
    public static func reconcile(marker: MessageListMarker, channelId: ChannelId) {
        guard isEnabled else { return }
        guard ChatMessage.DeliveryStatus(rawValue: marker.name) != nil else { return }

        let markerIds = marker.messageIds.map { MessageId($0.uint64Value) }
        guard !markerIds.isEmpty else { return }

        DataProvider.database.read(resultQueue: .global()) { context -> (unknown: [MessageId], stuck: [Int64]) in
            let known = Set(
                MessageDTO
                    .fetch(predicate: NSPredicate(format: "id IN %@", markerIds), context: context)
                    .map { MessageId($0.id) }
            )
            let unknown = markerIds.filter { !known.contains($0) }
            guard !unknown.isEmpty else { return (unknown: [], stuck: []) }

            // Only outgoing rows that never learned their server id can be repaired by this.
            let stuck = MessageDTO.fetch(
                predicate: NSPredicate(
                    format: "channelId == %lld AND incoming == false AND id == 0 AND (deliveryStatus == %d OR deliveryStatus == %d)",
                    Int64(channelId),
                    ChatMessage.DeliveryStatus.pending.intValue,
                    ChatMessage.DeliveryStatus.failed.intValue
                ),
                context: context
            ).map { $0.tid }

            return (unknown: unknown, stuck: stuck)
        } completion: { result in
            guard let scan = try? result.get(),
                  !scan.unknown.isEmpty,
                  !scan.stuck.isEmpty
            else { return }

            let lookup = filterAndClaim(ids: scan.unknown, channelId: channelId)
            guard !lookup.isEmpty else { return }

            MessageSendTrace.log(
                "reconcile.start", channelId: channelId,
                "marker=\(marker.name) unknownIds=\(lookup) stuckTids=\(scan.stuck)"
            )
            lookUp(ids: lookup, marker: marker, channelId: channelId)
        }
    }

    // MARK: - Server lookup

    private static func lookUp(ids: [MessageId], marker: MessageListMarker, channelId: ChannelId) {
        ChannelOperator(channelId: channelId)
            .getMessages(ids: ids.map { NSNumber(value: $0) }) { messages, error in
                defer { release(channelId: channelId) }

                guard let messages, !messages.isEmpty else {
                    // Deliberately not recorded as answered: a transport failure here must stay
                    // retryable, or one bad moment would strand the row for the whole session.
                    MessageSendTrace.log(
                        "reconcile.lookupFailed", channelId: channelId,
                        "ids=\(ids) retryable=true \(MessageSendTrace.describe(error: error))"
                    )
                    return
                }
                markAnswered(ids: ids)
                apply(messages: messages, marker: marker, channelId: channelId)
            }
    }

    private static func apply(messages: [Message], marker: MessageListMarker, channelId: ChannelId) {
        var boundTids = [Int64]()
        var suppressedByDelete = false

        DataProvider.database.write ({ context in
            for message in messages {
                let tid = Int64(message.tid)
                // Anything incoming, or without a tid, cannot be one of our stranded sends.
                guard !message.incoming, tid != 0 else { continue }
                // Bind only rows that never got an id. A row that already has one is either
                // correct or somebody else's business — this must not become a sync path.
                guard let dto = MessageDTO.fetch(tid: tid, channelId: Int64(channelId), context: context),
                      dto.id == 0
                else { continue }

                MessageSendTrace.log(
                    "reconcile.bind", tid: tid, channelId: channelId, messageId: message.id,
                    "\(MessageSendTrace.describe(dto: dto)) -> \(MessageSendTrace.describe(ack: message))"
                )
                // Reuse the send-ack resolution so a message the user deleted while it was
                // stranded is not resurrected: the delete intent takes the server id instead.
                switch context.resolveSendAck(sentMessage: message, channelId: channelId) {
                case .stored:
                    boundTids.append(tid)
                case .suppressedByPendingDelete(let tid, let serverMessageId):
                    MessageSendTrace.log(
                        "reconcile.suppressedByPendingDelete", tid: tid, channelId: channelId,
                        messageId: serverMessageId
                    )
                    suppressedByDelete = true
                }
            }

            // Re-apply the marker in the same transaction: the rows now carry their server ids, so
            // the update that was dropped as `marker.unknownMessage` can finally land the tick.
            if !boundTids.isEmpty {
                context.update(messageMarkers: marker)
            }
        }) { dbError in
            MessageSendTrace.log(
                "reconcile.done", channelId: channelId,
                "bound=\(boundTids) markerReapplied=\(!boundTids.isEmpty) \(MessageSendTrace.describe(error: dbError))"
            )
            if suppressedByDelete {
                // The delete now has a server id to use.
                SyncService.sendPendingMessageDeletes()
            }
        }
    }

    // MARK: - Coalescing

    /// Drops ids the server has already answered for and claims the channel, so only one lookup
    /// per channel is in flight. Returns the ids to request, or empty if there is nothing to do.
    private static func filterAndClaim(ids: [MessageId], channelId: ChannelId) -> [MessageId] {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlightChannels.contains(channelId) else { return [] }
        let fresh = ids.filter { !answeredIds.contains($0) }
        guard !fresh.isEmpty else { return [] }
        // Newest ids first: a stranded send is the most recent thing in the channel.
        let claimed = Array(fresh.sorted(by: >).prefix(maxLookupIds))
        inFlightChannels.insert(channelId)
        return claimed
    }

    private static func markAnswered(ids: [MessageId]) {
        lock.lock()
        defer { lock.unlock() }
        if answeredIds.count + ids.count > maxAnsweredIds {
            // Nothing here needs to be remembered accurately — it is a request damper, not state.
            answeredIds.removeAll()
        }
        answeredIds.formUnion(ids)
    }

    private static func release(channelId: ChannelId) {
        lock.lock()
        inFlightChannels.remove(channelId)
        lock.unlock()
    }

    /// Clears the per-session caches. Call on logout / account switch.
    public static func reset() {
        lock.lock()
        inFlightChannels.removeAll()
        answeredIds.removeAll()
        lock.unlock()
    }
}
