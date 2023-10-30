//
//  SyncOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class SyncOperation: Operation {
    
    enum OperationError: Error {
        case cancelled
    }
}
