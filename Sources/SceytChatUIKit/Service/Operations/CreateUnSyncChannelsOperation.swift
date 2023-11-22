//
//  CreateUnSyncChannelsOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 23.08.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

import SceytChat

open class CreateUnSyncChannelsOperation: SyncOperation {
    
    public private(set) var result: Result<[ChatChannel], Error>?
    private var fetching = false
    
    public override init() {
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
        
        createChannels()
    }
    
    open func finish(result: Result<[ChatChannel], Error>) {
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
    
    private func createChannels() {
        if !isCancelled {
            fetching = true
            var createdChannel = [ChatChannel]()
            logger.verbose("SyncService: createPendingChannels if Needed")
            let group = DispatchGroup()
            let channelCreator = Components.channelCreator.init()
            group.enter()
            Components.channelListProvider
                .fetchPendingChannel { channels in
                    for channel in channels {
                        logger.verbose("SyncService: createPendingChannels found channel with members: \(String(describing: channel.members?.map { $0.id }))")
                        group.enter()
                        let localChannelId = channel.id
                        channelCreator
                            .createChannelOnServerIfNeeded(channelId: channel.id) { sceytChannel, error in
                                logger.verbose("SyncService: createPendingChannels did create found channel with members: \(String(describing: sceytChannel?.members?.map { $0.id }))")
                                logger.errorIfNotNil(error, "SyncService: Creating Pending channel")
                                if let sceytChannel {
                                    createdChannel.append(sceytChannel)
                                    NotificationCenter.default
                                        .post(name: .didUpdateLocalCreateChannelOnEventChannelCreate,
                                              object: nil,
                                              userInfo: ["localChannelId": localChannelId, "channel": sceytChannel])
                                }
                                group.leave()
                        }
                    }
                    group.leave()
                }
            group.notify(queue: .global()) {[weak self] in
                self?.finish(result: .success(createdChannel))
            }
            
        } else {
            self.finish(result: .failure(OperationError.cancelled))
        }
    }
}
