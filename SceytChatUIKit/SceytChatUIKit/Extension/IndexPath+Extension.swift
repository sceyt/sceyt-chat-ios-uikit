//
//  IndexPath+Extension.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import Foundation

extension IndexPath {

    public init(row: Int) {
        self.init(row: row, section: 0)
    }

    public init(item: Int) {
        self.init(item: item, section: 0)
    }

    public static var zero: IndexPath {
        .init(row: 0)
    }
}
