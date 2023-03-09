//
//  FileSizeFormatter.swift
//  SceytChatUIKit
//

import Foundation

public protocol FileSizeFormatter {

    func format(_ size: UInt) -> String
}
