//
//  DEBUG_ReproReplyViewHidden.swift
//  Temporary debug file — DELETE once the bug is fixed/verified.
//
//  Reproduces: ReplyView hidden in a cell whose computed height still
//  reserves space for the reply.
//
//  Root cause: MessageLayoutModel.update() with force=false reassigns
//  replyLayout (to nil if message.parent==nil) but does NOT recompute
//  measureSize unless an updateOption was added. The parent → nil
//  transition adds nothing to updateOptions, so measureSize stays stale.
//
//  How to wire it up — add ONE line to ChannelViewController.viewDidAppear
//  (or anywhere after the navigationItem is available):
//
//      override func viewDidAppear(_ animated: Bool) {
//          super.viewDidAppear(animated)
//          installReplyViewHiddenBugTrigger()   // <-- add this
//      }
//
//  This installs a "🐞 Repro" button on the right of the navigation bar.
//  Tap it to trigger the bug on the first visible reply cell. Logs are
//  tagged [DEBUG-REPRO]. Re-enter the channel to recover.
//

import UIKit
import SceytChat

extension ChannelViewController {

    /// Installs a "🐞 Repro" button on the navigation bar that triggers the
    /// repro on tap. Idempotent — won't add a second button if called twice.
    public func installReplyViewHiddenBugTrigger() {
        let existing = (navigationItem.rightBarButtonItems ?? []).contains { item in
            item.action == #selector(debugReplyViewHiddenBugTapped(_:))
        }
        if existing { return }

        let button = UIBarButtonItem(
            title: "🐞 Repro",
            style: .plain,
            target: self,
            action: #selector(debugReplyViewHiddenBugTapped(_:))
        )
        var items = navigationItem.rightBarButtonItems ?? []
        items.append(button)
        navigationItem.rightBarButtonItems = items
        logger.debug("[DEBUG-REPRO] '🐞 Repro' button installed on navigation bar")
    }

    @objc
    private func debugReplyViewHiddenBugTapped(_ sender: Any) {
        debugTriggerReplyViewHiddenBug()
    }

    /// Strips `parent` from a visible reply cell's layout model via
    /// `update(force: false)`, then reloads that item. The cell rebinds
    /// with `replyLayout == nil` → replyView hidden, but `measureSize`
    /// stays at its old value (with reply space) because the parent-cleared
    /// path in update() does not add to `updateOptions`.
    public func debugTriggerReplyViewHiddenBug() {
        guard let (indexPath, lm) = firstVisibleReplyLayoutModel() else {
            logger.error("[DEBUG-REPRO] no visible reply cell — scroll to one first")
            return
        }
        let original = lm.message

        // Construct a ChatMessage identical to `original` except `parent == nil`.
        // The designated init (ChatMessage.swift line 56-130) unconditionally
        // sets `parent = nil` at line 120 — so we just rebuild every other
        // field. Going through `original.builder.build()` would lose
        // deliveryStatus / state and trigger isUpdated == true, which would
        // recompute measureSize and hide the bug.
        let stripped = ChatMessage(
            id: original.id,
            tid: original.tid,
            channelId: original.channelId,
            body: original.body,
            type: original.type,
            metadata: original.metadata,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            autoDeleteAt: original.autoDeleteAt,
            incoming: original.incoming,
            transient: original.transient,
            silent: original.silent,
            state: original.state,
            deliveryStatus: original.deliveryStatus,
            repliedInThread: original.repliedInThread,
            replyCount: original.replyCount,
            displayCount: original.displayCount,
            disableMentionsCount: original.disableMentionsCount,
            viewOnce: original.viewOnce,
            attachments: original.attachments,
            userReactions: original.userReactions,
            userPendingReactions: original.userPendingReactions,
            reactionTotals: original.reactionTotal,
            mentionedUsers: original.mentionedUsers,
            markerCount: original.markerCount,
            userMarkers: original.userMarkers,
            linkMetadatas: original.linkMetadatas,
            user: original.user,
            changedBy: original.changedBy,
            forwardingDetails: original.forwardingDetails,
            bodyAttributes: original.bodyAttributes,
            poll: original.poll
        )

        let measureBefore = lm.measureSize.height
        let hadReplyBefore = lm.replyLayout != nil

        // force: false is THE critical flag. With force=true, update() would
        // recompute measureSize and the bug would not manifest.
        _ = lm.update(channel: lm.channel, message: stripped, force: false)

        let measureAfter = lm.measureSize.height
        let hasReplyAfter = lm.replyLayout != nil

        logger.debug("[DEBUG-REPRO] indexPath=\(indexPath) "
                     + "measureSize: \(measureBefore) → \(measureAfter) "
                     + "(expected EQUAL — stale), "
                     + "replyLayout: \(hadReplyBefore ? "set" : "nil") → "
                     + "\(hasReplyAfter ? "set" : "nil") "
                     + "(expected nil)")

        collectionView.reloadItems(at: [indexPath])

        logger.debug("[DEBUG-REPRO] reloaded \(indexPath). "
                     + "Cell should be tall with replyView hidden. "
                     + "Re-enter the channel to recover.")
    }

    private func firstVisibleReplyLayoutModel() -> (IndexPath, MessageLayoutModel)? {
        for case let cell as MessageCell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell),
                  let lm = channelViewModel.layoutModel(at: indexPath),
                  lm.hasReply
            else { continue }
            return (indexPath, lm)
        }
        return nil
    }
}
