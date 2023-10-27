//
//  UICollectionView+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UICollectionView {

    enum SupplementaryViewKind: String {
        case header
        case footer

        public var rawValue: String {
            switch self {
            case .header:
                return UICollectionView.elementKindSectionHeader
            case .footer:
                return UICollectionView.elementKindSectionFooter
            }
        }
    }

    var totalNumberOfItems: Int {
        var count = 0
        for s in 0 ..< numberOfSections {
            count += numberOfItems(inSection: s)
        }
        return count
    }

    var lastIndexPath: IndexPath? {
        guard numberOfSections > 0 else { return nil }
        let section = numberOfSections - 1
        let item = numberOfItems(inSection: section)
        guard item - 1 >= 0 else { return nil }
        return .init(item: item - 1, section: section)
    }
    
    func register<T: UICollectionViewCell>(_ cellType: T.Type) {
        register(
            cellType.self,
            forCellWithReuseIdentifier: cellType.reuseId
        )
    }

    func register<T: UICollectionReusableView>(
        _ cellType: T.Type,
        kind: SupplementaryViewKind
    ) {
        register(
            cellType.self,
            forSupplementaryViewOfKind: kind.rawValue,
            withReuseIdentifier: cellType.reuseId
        )
    }

    func dequeueReusableCell<T: UICollectionViewCell>(
        for indexPath: IndexPath,
        cellType: T.Type
    ) -> T {
        guard let cell = dequeueReusableCell(
            withReuseIdentifier: cellType.reuseId,
            for: indexPath)
                as? T
        else { fatalError("Failed to dequeue cell \(cellType.self) \(cellType.reuseId)") }
        return cell
    }

    func dequeueReusableSupplementaryView<T: UICollectionReusableView>(
        for indexPath: IndexPath,
        cellType: T.Type,
        kind: SupplementaryViewKind
    ) -> T {
        guard let cell = dequeueReusableSupplementaryView(
            ofKind: kind.rawValue,
            withReuseIdentifier: cellType.reuseId,
            for: indexPath
        ) as? T
        else { fatalError("Failed to dequeue cell \(cellType.self) \(cellType.reuseId)") }
        return cell
    }

    func cell<T: UICollectionViewCell>(
        for indexPath: IndexPath,
        cellType: T.Type
    ) -> T? {
        cellForItem(at: indexPath) as? T
    }
}

public extension UICollectionReusableView {

    static var reuseId: String {
        String(describing: self)
    }
}
