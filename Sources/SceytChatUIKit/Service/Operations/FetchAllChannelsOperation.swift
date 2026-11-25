//
//  FetchAllChannelsOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class FetchAllChannelsOperation: SyncOperation {
    
    public private(set) var result: Result<[Channel], Error>?
    public var onLoad: (([Channel]) -> Void)?
    
    private var channels = [Channel]()
    private var fetching = false
    
    private let query: ChannelListQuery
    private let provider: ChannelListProvider
    public init(query: ChannelListQuery) {
        self.query = query
        provider = Components.channelListProvider.init()
    }
    
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
        
        loadChannels()
        provider.onStoreChannels = {[weak self] channels, stored in
            guard let self
            else { return }
            // A channel deleted while its page was stored gets no message catch-up: it would
            // write messages for a channel that no longer exists.
            self.onLoad?(stored)
            // Paging and the missing-channel sweep go by everything the server returned.
            self.channels.append(contentsOf: channels)
            Components.channelListProvider.syncMessageForReactions(channels: stored)
            if channels.count < self.query.limit || !self.query.hasNext {
                self.finish(result: .success(self.channels))
            } else {
                self.loadChannels()
            }
        }
    }
    
    open func finish(result: Result<[Channel], Error>) {
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
    
    private func loadChannels() {
        if !isCancelled {
            fetching = true
            provider.loadChannels(query: query) {[weak self] error in
                if let error {
                    self?.finish(result: .failure(error))
                }
            }
        } else {
            self.finish(result: .failure(OperationError.cancelled))
        }
    }
}
