//
//  ChannelPinnedMessageListViewModel.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Combine
import CoreData
import Foundation
import SceytChat
import UIKit

/// Backs the standalone pinned-messages screen: every live pin in one channel.
///
/// It observes the same request the banner does — `PinnedMessageDTO.fetchRequest(channelId:)`,
/// read newest pin first — rather than reading `ChannelViewModel.pinnedMessages` once, so
/// unpinning from the list updates the list itself with no reload plumbing between the two
/// screens.
///
/// It also watches the pinned *messages*, because the rows are the conversation's own
/// message cells: a reaction, an edit or a vote has to land in the list the same way it
/// lands in the conversation.
open class ChannelPinnedMessageListViewModel: NSObject {

    public let channel: ChatChannel
    public let pinnedMessageProvider: ChannelPinnedMessageProvider

    @Published public var event: Event?

    /// The channel's live pins in pin order, **newest pin first**: the most recent pin is
    /// the top row, and a pin taken while the screen is open arrives there rather than at
    /// the bottom of a long scroll.
    ///
    /// The banner reads the same pins the other way round, so a row index here is *not* a
    /// banner index — `ChannelViewController.didSelectPinnedMessage` looks the picked pin up
    /// by `messageTid` rather than carrying a row number across.
    public private(set) var items: [PinnedMessage] = []

    /// One layout model per pin, keyed by the pinned message's tid — the only id a pending
    /// send has. The rows are the conversation's own message cells, so they need the same
    /// models the message list feeds them.
    public private(set) var layoutModels: [Int64: MessageLayoutModel] = [:]

    /// The appearance the models measure against, pushed here by the screen before the
    /// first fetch. Measuring with one appearance and rendering with another clips the
    /// bubble's own content.
    open var messageCellAppearance: MessageCellAppearance = MessageCell.appearance

    /// Bound to `viewContext`, the main-queue context, because the table reads `items`
    /// synchronously from `cellForRowAt`. `ChannelViewModel`'s banner observer watches the
    /// same request on the background observable context; both are read-only.
    public private(set) lazy var pinnedMessageObserver: DatabaseObserver<PinnedMessageDTO, PinnedMessage> = {
        DatabaseObserver<PinnedMessageDTO, PinnedMessage>(
            request: PinnedMessageDTO.fetchRequest(channelId: channel.id, newestFirst: true),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    /// Watches the pinned messages themselves, not just the pin rows: a reaction added
    /// from this screen, an edit, a poll vote, a delete — the conversation shows all of
    /// them live, and the rows here are its cells, so they must too. `PinnedMessageDTO`
    /// carries only a render snapshot, which is why this second observer exists; its
    /// predicate is re-pointed at the current pins every time the pin set changes.
    public private(set) lazy var messageObserver: DatabaseObserver<MessageDTO, ChatMessage> = {
        DatabaseObserver<MessageDTO, ChatMessage>(
            request: MessageDTO.fetchRequest()
                .fetch(predicate: pinnedMessagesPredicate)
                .sort(descriptors: [.init(keyPath: \MessageDTO.id, ascending: true)]),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    /// The stored rows behind the current pins. A pin whose send is still pending has no
    /// server id and therefore no row to watch.
    open var pinnedMessagesPredicate: NSPredicate {
        NSPredicate(
            format: "channelId == %lld AND id IN %@",
            channel.id,
            items.filter { !$0.isPending }.map { NSNumber(value: $0.messageId) }
        )
    }

    public required init(channel: ChatChannel) {
        self.channel = channel
        self.pinnedMessageProvider = Components.channelPinnedMessageProvider.init(channelId: channel.id)
        super.init()
    }

    deinit {
        pinnedMessageObserver.stopObserver()
        messageObserver.stopObserver()
    }

    open func startDatabaseObserver() {
        pinnedMessageObserver.onDidChange = { [weak self] _ in
            self?.reload()
        }
        messageObserver.onDidChange = { [weak self] _ in
            self?.reloadMessages()
        }
        try? pinnedMessageObserver.startObserver()
        try? messageObserver.startObserver()
        reload()
        // The screen shows whatever is on disk immediately (above), then reconciles against the
        // server. Usually a no-op: the conversation kicked the same sweep when it opened, and
        // `SyncService`'s per-channel guard collapses the second call. It matters when this
        // screen is reached without one — a deep link, or a sweep that has since finished.
        //
        // Deferred a turn so none of it — claiming the channel's sweep slot, building the query,
        // enqueueing — lands inside the presentation that is calling this.
        let channelId = channel.id
        DispatchQueue.main.async {
            SyncService.syncChannelPins(channelId: channelId)
        }
    }

    open func reload() {
        // The observer's `items` is dictionary-backed and unordered; the screen's order is
        // the request's, so read the ordered view. Lapsed pins are dropped here for the same
        // reason `ChannelViewModel.reloadPinnedMessages` does it: the request's predicate is
        // evaluated when the fetch runs, not as time passes.
        items = pinnedMessageObserver.orderedItems.filter { !$0.isExpired }
        // The message observer follows whatever is pinned now, so it is re-pointed here
        // rather than at every message in the channel.
        try? messageObserver.update(predicate: pinnedMessagesPredicate)
        reloadLayoutModels()
        event = .reload
    }

    /// A pinned message changed under the screen — a reaction, an edit, a vote. The pins
    /// themselves are untouched, so only the models are rebuilt.
    open func reloadMessages() {
        reloadLayoutModels()
        event = .reload
    }

    open var numberOfItems: Int { items.count }

    open var isEmpty: Bool { items.isEmpty }

    open func item(at indexPath: IndexPath) -> PinnedMessage? {
        items.indices.contains(indexPath.row) ? items[indexPath.row] : nil
    }

    open func layoutModel(at indexPath: IndexPath) -> MessageLayoutModel? {
        guard let item = item(at: indexPath) else { return nil }
        return layoutModels[item.messageTid]
    }

    /// Rebuilds the models for the current pins, reusing the ones already built so an
    /// unpin does not re-measure the rows that stayed. Models for pins that went away are
    /// dropped with the dictionary they were in.
    open func reloadLayoutModels() {
        var models = [Int64: MessageLayoutModel]()
        var previousModel: MessageLayoutModel?
        for (index, item) in items.enumerated() {
            let model = layoutModel(for: item)
            // Every pin stands on its own here — there are no runs of messages from one
            // sender to collapse — so each incoming bubble carries its sender's name and
            // avatar. The call is a no-op in direct and broadcast channels.
            model.showUserInfo(true)
            updateContentInsets(for: model, at: index, previousModel: previousModel)
            models[item.messageTid] = model
            previousModel = model
        }
        layoutModels = models
    }

    open func layoutModel(for item: PinnedMessage) -> MessageLayoutModel {
        let message = message(for: item)
        if let model = layoutModels[item.messageTid] {
            model.update(channel: channel, message: message)
            return model
        }
        return Components.messageLayoutModel.init(
            channel: channel,
            message: message,
            appearance: messageCellAppearance
        )
    }

    /// The pinned message as the conversation renders it: the stored message while its row
    /// is in the database — reactions, reply, poll and attachments included — and the pin's
    /// own snapshot otherwise, which is what keeps the screen working for a message that
    /// was evicted or never fetched.
    open func message(for item: PinnedMessage) -> ChatMessage {
        let context = SceytChatUIKit.shared.database.viewContext
        if item.messageId != 0,
           let dto = MessageDTO.fetch(id: item.messageId, context: context) {
            return dto.convert()
        }
        if let dto = MessageDTO.fetch(tid: item.messageTid, channelId: Int64(channel.id), context: context) {
            return dto.convert()
        }
        return item.previewMessage
    }

    /// The spacing above a row, by the conversation's rules — pins keep the rhythm the
    /// message list has, not a uniform gap.
    open func updateContentInsets(
        for model: MessageLayoutModel,
        at index: Int,
        previousModel: MessageLayoutModel?
    ) {
        var contentInsets = UIEdgeInsets.zero
        if index == 0 {
            contentInsets.top = ChannelViewModel.Layouts.firstMessageSpacing
        } else if let previousModel {
            if previousModel.isSystemMessage || model.isSystemMessage {
                contentInsets.top = ChannelViewModel.Layouts.systemMessageSpacing
            } else if model.message.incoming == previousModel.message.incoming {
                contentInsets.top = ChannelViewModel.Layouts.sameSenderSpacing
            } else {
                contentInsets.top = ChannelViewModel.Layouts.differentSenderSpacing
            }
        }
        model.contentInsets = contentInsets
    }

    /// Whether the row offers Unpin.
    ///
    /// Unconditional: the server decides whether an unpin is allowed and answers with an error,
    /// and a rejected unpin is restored by the channel's next pin sweep. Override to hide the
    /// action up front — e.g. to let only the pinner or an admin unpin.
    open func canUnpin(_ item: PinnedMessage) -> Bool { true }

    open func unpin(_ item: PinnedMessage, completion: ((Error?) -> Void)? = nil) {
        pinnedMessageProvider.unpin(item) { error in
            logger.errorIfNotNil(error, "Unpin message from the pinned list")
            completion?(error)
        }
    }

    /// The message a row jumps to, or `nil` while the pinned message is still a pending
    /// send and therefore has no server id to scroll to.
    open func jumpTarget(for item: PinnedMessage) -> PinnedMessage? {
        item.messageId == 0 ? nil : item
    }

    public enum Event {
        case reload
    }
}
