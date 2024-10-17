//
//  UITableView+Extensions.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension UITableView {
    func isFirst(_ indexPath: IndexPath) -> Bool {
        indexPath.item == 0
    }
    
    func isLast(_ indexPath: IndexPath) -> Bool {
        indexPath.item == numberOfRows(inSection: indexPath.section) - 1
    }
}
