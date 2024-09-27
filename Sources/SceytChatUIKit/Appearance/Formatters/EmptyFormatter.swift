//
//  EmptyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

/// A formatter that represents the absence of formatting functionality.
///
/// `EmptyFormatter` conforms to the `Formatting` protocol but is designed to indicate that
/// no formatting should be applied. It utilizes Swift's `Never` type to signify that the
/// `format` method should never be called. Attempting to call `format` will result in a runtime
/// crash, ensuring that the absence of a formatter is enforced at compile time.
///
/// This formatter is typically used as a default or placeholder when a formatting operation is
/// optional and not required by the user.
public struct EmptyFormatter: Formatting {
    
    public init() {}
    
    /// Formats the given input into a `String`.
    ///
    /// - Parameter value: The input to format. This parameter uses the `Never` type,
    ///   indicating that this method should never be called.
    /// - Returns: A formatted `String`. This method does not return and will
    ///   always trigger a runtime error if called.
    ///
    /// - Note: Since the input type is `Never`, there is no valid input that can
    ///   be passed to this method. If this method is somehow called, it indicates a
    ///   logical error in the program, and a runtime crash will occur.
    public func format(_ value: Never) -> String {
        fatalError("This method should never be called.")
    }
}
