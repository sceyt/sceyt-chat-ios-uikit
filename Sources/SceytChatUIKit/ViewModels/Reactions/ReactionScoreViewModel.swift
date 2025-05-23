//
//  ReactionScoreViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ReactionScoreViewModel {

    public let reactionScores: [(key: String, value: Int64)]
    open var dataSource: [String]
    
    public required init(reactionScores: [(key: String, value: Int64)]) {
        self.reactionScores = reactionScores
        let allCount = reactionScores.reduce(0) { $0 + $1.value }
        var dataSource = ["All \(allCount)"]
        dataSource.append(contentsOf: reactionScores
            .map { "\($0.key) \($0.value)" }
        )
        self.dataSource = dataSource
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
