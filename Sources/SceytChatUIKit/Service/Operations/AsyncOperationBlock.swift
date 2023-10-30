//
//  AsyncOperationBlock.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 02.08.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class AsyncOperationBlock: AsyncOperation {
    open var operationBlock: (AsyncOperationBlock) -> Void
    
    public init(
        uuid: String = UUID().uuidString,
        block: @escaping ((AsyncOperationBlock) -> Void))
    {
        operationBlock = block
        log.debug("[ASYNC OP] create operation with id \(uuid)")
        super.init(uuid)
    }
    
    override public func main() {
        operationBlock(self)
    }
    
    override open func copy() -> Any {
        AsyncOperationBlock(uuid: uuid, block: operationBlock)
    }
}

open class AsyncOperationQueue: OperationQueue {
    @Atomic private var ops = [AsyncOperation]()
    @Atomic private var copyOps = [AsyncOperation]()
    
    open func addOperation(_ op: AsyncOperation) {
        super.addOperation(op)
        ops.append(op)
        log.debug("[ASYNC OP] add operation with id \(op.uuid)")
    }
    
    func stopOperation(uuid: String) {
        if let index = ops.firstIndex(where: { $0.uuid == uuid }) {
            if let cp = ops[index].copy() as? AsyncOperation {
                copyOps.append(cp)
            }
            log.debug("[ASYNC OP] stopOperation operation with id \(ops[index].uuid)")
            ops[index].complete()
            ops.remove(at: index)
        }
    }
    
    func resumeOperation(uuid: String) {
        if let index = copyOps.firstIndex(where: { $0.uuid == uuid }) {
            addOperation(copyOps[index])
            copyOps.remove(at: index)
            log.debug("[ASYNC OP] resumeOperation operation with id \(ops[index].uuid)")
        }
    }
}
