//
//  FetchChannelMessagesOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class FetchChannelMessagesOperation: SyncOperation {
    
    enum LoadDirection {
        case next
    }
    
    public private(set) var result: Result<[Message], Error>?
    
    public var onLoad: ((Result<[Message], Error>, @escaping (() -> Void)) -> Void)?

    private var fetching = false
    
    private let query: MessageListQuery
    
    public init(query: MessageListQuery) {
        self.query = query
    }
    
    open var startMessageId: MessageId = 0
    open var syncLastPageImmediately = true
    
    open override var isAsynchronous: Bool {
        return true
    }
    
    open override var isExecuting: Bool {
        return fetching
    }
    
    open override var isFinished: Bool {
        return result != nil
    }
    
    open override func start() {
        willChangeValue(forKey: #keyPath(isExecuting))
        fetching = true
        didChangeValue(forKey: #keyPath(isExecuting))
        
        guard !isCancelled else {
            finish(result: .failure(OperationError.cancelled))
            return
        }
        
        loadMessages(start: startMessageId)
        if syncLastPageImmediately {
            loadLastMessages()
        }
    }
    
    open func finish(result: Result<[Message], Error>) {
        guard fetching else { return }
        
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))
        
        fetching = false
        self.result = result
        didChangeValue(forKey: #keyPath(isFinished))
        didChangeValue(forKey: #keyPath(isExecuting))
    }
    
    open override func cancel() {
        super.cancel()
    }
    
    private func loadMessages(start: MessageId) {
        if !isCancelled {
            fetching = true
            query.loadNext(messageId: start, didLoad)
        } else {
            self.finish(result: .failure(OperationError.cancelled))
        }
    }
    
    private func loadMessages() {
        if !isCancelled {
            fetching = true
            query.loadNext(didLoad)
        } else {
            finish(result: .failure(OperationError.cancelled))
        }
    }
    
    private func loadLastMessages() {
        MessageListQuery
            .Builder(channelId: query.channelId)
            .limit(SceytChatUIKit.shared.config.queryLimits.messageListQueryLimit)
            .build()
            .loadPrevious(messageId: 0) {[weak self] query, messages, error in
                if let messages {
                    self?.onLoad?(.success(messages), {})
                }
            }
    }
    
    private func didLoad(query: MessageListQuery, messages: [Message]?, error: Error?) {
        if let messages {
            onLoad?(.success(messages), {
                if !query.hasNext {
                    self.finish(result: .success(messages))
                }
            })
            if query.hasNext {
                loadMessages()
            }
            
        } else if let error {
            finish(result: .failure(error))
        }
    }
}

