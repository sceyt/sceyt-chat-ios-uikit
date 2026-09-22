//
//  ReactionScoreViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class ReactionScoreViewModel {

    @Published public var event: Event?

    public let messageId: MessageId
    open var dataSource: [String]

    private lazy var reactionTotalObserver: DatabaseObserver<ReactionTotalDTO, ChatMessage.ReactionTotal> = {
        return DatabaseObserver<ReactionTotalDTO, ChatMessage.ReactionTotal>(
            request: ReactionTotalDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ReactionTotalDTO.key, ascending: false)])
                .fetch(predicate: .init(format: "message.id == %lld", messageId)),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    /// Reactions the user added locally that the server hasn't acknowledged yet have no
    /// ReactionTotalDTO row — only a `pending` ReactionDTO. They must still be counted here,
    /// otherwise the chips contradict the message cell (which sums totals and pending
    /// reactions) and a reaction that is pending-only renders as "All 0" with no chip.
    private lazy var pendingReactionObserver: DatabaseObserver<ReactionDTO, ChatMessage.Reaction> = {
        return DatabaseObserver<ReactionDTO, ChatMessage.Reaction>(
            request: ReactionDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ReactionDTO.key, ascending: false)])
                .fetch(predicate: .init(format: "message.id == %lld AND pending == true", messageId)),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    public required init(messageId: MessageId, reactionScores: [(key: String, value: Int64)]) {
        self.messageId = messageId
        self.dataSource = Self.buildDataSource(from: reactionScores)
    }

    open func startObserver() {
        // Both observers feed a single merged data source, and startObserver() reports its
        // initial fetch through onDidChange. Fetch first with no handler attached so the
        // screen never sees a half-merged snapshot (pending without totals or vice versa),
        // then emit once from the complete state.
        do {
            try reactionTotalObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "reactionTotalObserver.startObserver")
        }
        do {
            try pendingReactionObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "pendingReactionObserver.startObserver")
        }
        reactionTotalObserver.onDidChange = { [weak self] _ in
            self?.updateDataSource()
        }
        pendingReactionObserver.onDidChange = { [weak self] _ in
            self?.updateDataSource()
        }
        updateDataSource()
    }

    private func updateDataSource() {
        let totals = Self.uniqueTotals(
            (0..<reactionTotalObserver.numberOfItems(in: 0))
                .compactMap { reactionTotalObserver.item(at: IndexPath(item: $0, section: 0)) }
        )
        let pendingKeys = (0..<pendingReactionObserver.numberOfItems(in: 0))
            .compactMap { pendingReactionObserver.item(at: IndexPath(item: $0, section: 0))?.key }
        let scores = Self.merge(totals: totals, pendingKeys: pendingKeys)
        dataSource = Self.buildDataSource(from: scores)
        event = .reloadData(reactionKeys: scores.map { $0.key })
    }

    /// Adds one to the count of every pending reaction's key, appending keys that have no
    /// total row yet. Sorted by key descending — the same order the total observer fetches in
    /// — so a pending key keeps its position once the server total replaces it.
    public static func merge(
        totals: [ChatMessage.ReactionTotal],
        pendingKeys: [String]
    ) -> [(key: String, value: Int64)] {
        var scores = totals.map { (key: $0.key, value: Int64($0.count)) }
        for key in pendingKeys {
            if let index = scores.firstIndex(where: { $0.key == key }) {
                scores[index].value += 1
            } else {
                scores.append((key: key, value: 1))
            }
        }
        return scores.sorted { $0.key > $1.key }
    }

    /// Duplicate (message, key) total rows can persist when writers without shared
    /// visibility race (a notification-service extension persisting a push while the main
    /// app persists the socket event). Writes heal such rows lazily, but the observer sees
    /// whatever is in the store right now — collapse by key so the screen never renders the
    /// same reaction as two chips/pages. Duplicates describe the same reaction, so keep the
    /// row with the highest count rather than summing.
    public static func uniqueTotals(_ totals: [ChatMessage.ReactionTotal]) -> [ChatMessage.ReactionTotal] {
        var unique = [ChatMessage.ReactionTotal]()
        for total in totals {
            if let index = unique.firstIndex(where: { $0.key == total.key }) {
                if total.count > unique[index].count {
                    unique[index] = total
                }
            } else {
                unique.append(total)
            }
        }
        return unique
    }

    private static func buildDataSource(from reactionScores: [(key: String, value: Int64)]) -> [String] {
        let allCount = reactionScores.reduce(0) { $0 + $1.value }
        var dataSource = ["All \(allCount)"]
        dataSource.append(contentsOf: reactionScores.map { "\($0.key) \($0.value)" })
        return dataSource
    }

    open func numberOfItems() -> Int {
        dataSource.count
    }

    open func value(at indexPath: IndexPath) -> String {
        dataSource[indexPath.item]
    }

    open func width(at indexPath: IndexPath) -> CGFloat {
        let appearance = Components.reactionsInfoHeaderCell.appearance
        let textInsets = Components.reactionsInfoHeaderCell.textInsets ?? .zero
        let containerInsets = Components.reactionsInfoHeaderCell.containerInsets ?? .zero
        let size = dataSource[indexPath.item].size(withAttributes: [
            .font: appearance.labelAppearance.font
        ])
        return ceil(size.width) + textInsets.left + textInsets.right + containerInsets.left + containerInsets.right
    }

}

public extension ReactionScoreViewModel {
    enum Event {
        case reloadData(reactionKeys: [String])
    }
}
