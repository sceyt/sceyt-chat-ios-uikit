//
//  UITableView+Extension.swift
//  SceytChatUIKit
//

import UIKit

public extension UITableView {

    var rowAutomaticDimension: Self {
        rowHeight = UITableView.automaticDimension
        estimatedRowHeight = UITableView.automaticDimension
        return self
    }

    func register<T: UITableViewCell>(_ cellType: T.Type) {
        register(cellType.self, forCellReuseIdentifier: cellType.reuseId)
    }

    func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath, cellType: T.Type) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: cellType.reuseId, for: indexPath) as? T else {
            fatalError("Failed to dequeue cell \(cellType.self) \(cellType.reuseId)")
        }
        return cell
    }

    func cell<T: UITableViewCell>(for indexPath: IndexPath, cellType: T.Type) -> T? {
        cellForRow(at: indexPath) as? T
    }
}

extension UITableViewCell {
    static var reuseId: String {
        String(describing: self)
    }
}
