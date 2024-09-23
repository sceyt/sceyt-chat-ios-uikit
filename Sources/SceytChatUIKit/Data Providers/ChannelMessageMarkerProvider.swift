//
//  ChannelMessageMarkerProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelMessageMarkerProvider: DataProvider {

    public let channelId: ChannelId
    public let channelOperator: ChannelOperator
    private let markQueue = DispatchQueue(label: "com.sceyt.mark.message", qos: .userInitiated)
    
    public static var canMarkMessage: Bool = true {
        didSet {
            logger.debug("[MARKER CHECK] canMarkMessage: \(canMarkMessage)")
            if canMarkMessage {
                SyncService.sendPendingMarkers()
            }
        }
    }
    
    public required init(channelId: ChannelId) {
        self.channelId = channelId
        self.channelOperator = .init(channelId: channelId)
        super.init()
    }
    
    open func markIfNeeded(
        after toId: MessageId = 0,
        before fromId: MessageId = 0,
        markerName: String,
        storeBeforeSend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.performBgTask(resultQueue: markQueue) {
            let messageIds: [MessageId] = MessageDTO.fetch(predicate: .init(format: "channelId == %lld AND id => %lld AND id <= %lld AND incoming = YES", self.channelId, toId, fromId, markerName), context: $0)
                .compactMap {
                    return $0.userMarkers?.contains(where: { $0.user?.id == me && $0.name == markerName } ) == true ? nil : MessageId($0.id)
                }
            return messageIds
        } completion: { result in
            switch result {
            case .failure(let error):
                logger.errorIfNotNil(error, "")
                completion?(error)
            case .success(let ids):
                guard !ids.isEmpty
                else {
                    completion?(nil)
                    return
                }

                if storeBeforeSend {
                    self.database.write {
                        $0.update(messagePendingMarkers: ids, markerName: markerName)
                    }
                }
                guard SceytChatUIKit.shared.chatClient.connectionState == .connected,
                        Self.canMarkMessage
                else {
                    completion?(nil)
                    return
                }
                let chunked = ids.chunked(into: 50)
                let group = DispatchGroup()
                var resultError: Error?
                for chunk in chunked {
                    group.enter()
                    logger.debug("[MARKER CHECK] will mark: \(markerName) to \(chunk) in channelId \(self.channelId)")
                    self.mark(ids: Array(chunk), markerName: markerName) { error in
                        resultError = error
                        logger.debug("[MARKER CHECK] did mark: \(markerName) to \(chunk) \(error as Any)")
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    completion?(resultError)
                }
            }
        }
    }
    
    open func mark(
        ids: [MessageId],
        markerName: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        func completed(_ markerList: MessageListMarker?, error: Error?) {
            if let error {
                if error.sceytChatCode == .notAllowed ||
                    error.sceytChatCode == .markMessageNotfoundMessagesWithIds {
                    self.database.performWriteTask {
                        $0.delete(messagePendingMarkers: ids, markerName: markerName)
                    }
                }
                completion?(error)
            } else if let markerList {
                logger.debug("[MARKER CHECK] receive \(markerList.messageIds.count)")
                logger.debug("[MARKER CHECK] received mark: \(markerList.name) for \(markerList.messageIds) in channelId:\(markerList.channelId)")
                self.database.performWriteTask ({
                    $0.update(messageSelfMarkers: markerList)
                }, completion: completion)
            }
            
        }
        guard !ids.isEmpty
        else {
            completion?(nil)
            return
        }
        logger.debug("[MARKER CK] send \(ids.count)")
        switch DefaultMarker(rawValue: markerName) {
        case .received:
            channelOperator.markMessagesAsReceived(ids: ids.map { NSNumber(value: $0)}, completion: completed(_:error:))
        case .displayed:
            channelOperator.markMessagesAsDisplayed(ids: ids.map { NSNumber(value: $0)}, completion: completed(_:error:))
        default:
            channelOperator.markMessages(markerName: markerName, ids: ids.map { NSNumber(value: $0)}, completion: completed(_:error:))
        }
    }
}

extension ChannelMessageMarkerProvider {
    
    open func loadMarkers(_ query: MessageMarkerListQuery, completion: ((Error?) -> Void)? = nil) {
        guard chatClient.connectionState == .connected else {
            completion?(SceytChatError.notConnect)
            return
        }
        guard query.hasNext, !query.loading else {
            completion?(SceytChatError.queryInProgress)
            return
        }
        
        query.loadNext { [weak self] query, markers, error in
            guard let self else {
                completion?(error)
                return
            }
            
            if let error {
                logger.errorIfNotNil(error, "")
            } else {
                if let markers {
                    store(markers: markers, for: query.messageId, completion: completion)
                }
            }
        }
    }
    
    open func store(markers: [Marker],
                    for messageId: MessageId,
                    completion: ((Error?) -> Void)? = nil) {
        guard !markers.isEmpty else {
            completion?(nil)
            return
        }
        database.performWriteTask {
            $0.createOrUpdate(markers: markers, messageId: messageId)
            
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
            completion?(error)
        }
    }
}

public enum DefaultMarker: Hashable {
    
    case displayed
    case received
    case played
    case custom(String)
    
    public init(rawValue: String) {
        switch rawValue {
        case "displayed":
            self = .displayed
        case "received":
            self = .received
        case "played":
            self = .played
        default:
            self = .custom(rawValue)
        }
    }
    
    public var rawValue: String {
        switch self {
        case .displayed:
            "displayed"
        case .received:
            "received"
        case .played:
            "played"
        case .custom(let customMarkerName):
            customMarkerName
        }
    }
}

extension DefaultMarker: Comparable {
    
    public var rank: Int {
        switch self {
        case .received:     1
        case .displayed:    2
        case .played:       3
        case .custom:       4
        }
    }
    
    public static func < (lhs: DefaultMarker, rhs: DefaultMarker) -> Bool {
        lhs.rank < rhs.rank
    }
}
