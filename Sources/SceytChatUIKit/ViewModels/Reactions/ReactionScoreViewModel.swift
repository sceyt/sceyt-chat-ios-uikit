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

    public required init(messageId: MessageId, reactionScores: [(key: String, value: Int64)]) {
        self.messageId = messageId
        self.dataSource = Self.buildDataSource(from: reactionScores)
    }

    open func startObserver() {
        reactionTotalObserver.onDidChange = { [weak self] _ in
            self?.updateDataSource()
        }
        do {
            try reactionTotalObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "reactionTotalObserver.startObserver")
        }
    }

    private func updateDataSource() {
        let totals = (0..<reactionTotalObserver.numberOfItems(in: 0))
            .compactMap { reactionTotalObserver.item(at: IndexPath(item: $0, section: 0)) }
        dataSource = Self.buildDataSource(from: totals.map { (key: $0.key, value: Int64($0.count)) })
        event = .reloadData(reactionKeys: totals.map { $0.key })
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
