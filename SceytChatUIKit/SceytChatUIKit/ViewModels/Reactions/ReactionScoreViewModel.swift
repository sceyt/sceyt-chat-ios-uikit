//
//  ReactionScoreViewModel.swift
//  SceytChatUIKit
//

public struct ReactionScoreViewModel {

    public let reactionScores: [String: Int]
    public var dataSource: [String]
    
    public init(reactionScores: [String: Int]) {
        self.reactionScores = reactionScores
        let allCount = reactionScores.reduce(0) { $0 + $1.value }
        var dataSource = ["All \(allCount)"]
        dataSource.append(contentsOf: reactionScores.map { "\($0.key) \($0.value)" })
        self.dataSource = dataSource
    }

    public func numberOfItems() -> Int {
        dataSource.count
    }

    public func value(at indexPath: IndexPath) -> String {
        dataSource[indexPath.item]
    }

    public func width(at indexPath: IndexPath) -> CGFloat {
        let appearance = ReactionScoreCell.appearance
        let textInsets = ReactionScoreCell.textInsets ?? .zero
        let containerInsets = ReactionScoreCell.containerInsets ?? .zero
        let size = dataSource[indexPath.item].size(withAttributes: [.font: appearance.textFont ?? .systemFont(ofSize: 12)])
        return ceil(size.width) + textInsets.left + textInsets.right + containerInsets.left + containerInsets.right
    }

}
