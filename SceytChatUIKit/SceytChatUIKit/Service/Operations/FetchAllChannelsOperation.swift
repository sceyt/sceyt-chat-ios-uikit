//
//  FetchAllChannelsOperation.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class FetchAllChannelsOperation: SyncOperation {
    
    public private(set) var result: Result<[Channel], Error>?
    public var onLoad: (([Channel]) -> Void)?
    private var channels = [Channel]()
    private var fetching = false
    
    private let query: ChannelListQuery
    
    public init(query: ChannelListQuery) {
        self.query = query
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
        print("[Operation] fetch start ")
        willChangeValue(forKey: #keyPath(isExecuting))
        fetching = true
        didChangeValue(forKey: #keyPath(isExecuting))
        
        guard !isCancelled else {
            print("[Operation] fetch isCancelled ", isCancelled)
            finish(result: .failure(OperationError.cancelled))
            return
        }
        
        loadChannels()
    }
    
    open func finish(result: Result<[Channel], Error>) {
        guard fetching else { return }
        
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))
        
        fetching = false
        self.result = result
        print("[Operation] fetch result ", (try? result.get()) != nil)
        didChangeValue(forKey: #keyPath(isFinished))
        didChangeValue(forKey: #keyPath(isExecuting))
    }
    
    open override func cancel() {
        super.cancel()
    }
    
    private func loadChannels() {
        print("[Operation] fetch loadChannels ")
        if !isCancelled {
            fetching = true
            print("[Operation] fetch loadChannels loadNext")
            query.loadNext { query, channels, error in
                print("[Operation] fetch query", query.totalCount, query.hasNext)
                if let channels {
                    self.onLoad?(channels)
                    self.channels.append(contentsOf: channels)
                    if channels.count < query.limit {
                        print("[Operation] fetch loadChannels done")
                        self.finish(result: .success(self.channels))
                    } else {
                        self.loadChannels()
                    }
                } else if let error {
                    self.finish(result: .failure(error))
                }
            }
        } else {
            print("[Operation] fetch loadChannels isCancelled", true)
            self.finish(result: .failure(OperationError.cancelled))
        }
    }
}
