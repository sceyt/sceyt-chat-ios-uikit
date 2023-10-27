//
//  UITableView+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
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
    
    func register<T: UITableViewHeaderFooterView>(_ viewType: T.Type) {
        register(viewType.self, forHeaderFooterViewReuseIdentifier: viewType.reuseId)
    }
    
    func dequeueReusableHeaderFooterView<T: UITableViewHeaderFooterView>(_ viewType: T.Type) -> T {
        guard let view = dequeueReusableHeaderFooterView(withIdentifier: viewType.reuseId) as? T else {
            fatalError("Failed to dequeue view \(viewType.self) \(viewType.reuseId)")
        }
        return view
    }
}

extension UITableViewCell {
    static var reuseId: String {
        String(describing: self)
    }
}

extension UITableViewHeaderFooterView {
    static var reuseId: String {
        String(describing: self)
    }
}
