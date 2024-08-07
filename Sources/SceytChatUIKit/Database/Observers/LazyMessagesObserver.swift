import Foundation
import CoreData
import SceytChat

open class LazyMessagesObserver: LazyDatabaseObserver<MessageDTO, ChatMessage> {
    
    public let defaultFetchPredicate: NSPredicate
    public var currentFetchPredicate: NSPredicate
    public private(set) var loadRangeProvider: LoadRangeProvider
    
    public let channelId: ChannelId
    
    public init(
        channelId: ChannelId,
        loadRangeProvider: LoadRangeProvider,
        itemCreator: @escaping (MessageDTO) -> ChatMessage
    ) {
        defaultFetchPredicate = NSPredicate(
            format: "channelId == %lld AND repliedInThread == false AND replied == false AND unlisted == false",
            channelId
        )
        currentFetchPredicate = defaultFetchPredicate
        self.loadRangeProvider = loadRangeProvider
        self.channelId = channelId
        super.init(
            context: SceytChatUIKit.shared.config.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [
                .init(keyPath: \MessageDTO.createdAt, ascending: true),
                .init(keyPath: \MessageDTO.id, ascending: true)
            ],
            sectionNameKeyPath: #keyPath(MessageDTO.daySectionIdentifier),
            fetchPredicate: defaultFetchPredicate,
            relationshipKeyPathsObserver: [
                #keyPath(MessageDTO.attachments.status),
                #keyPath(MessageDTO.attachments.filePath),
                #keyPath(MessageDTO.user.avatarUrl),
                #keyPath(MessageDTO.user.firstName),
                #keyPath(MessageDTO.user.lastName),
                #keyPath(MessageDTO.parent.state),
                #keyPath(MessageDTO.bodyAttributes),
                #keyPath(MessageDTO.linkMetadatas),
            ],
            itemCreator: itemCreator
        )
    }
    
    public override init(
        context: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor],
        sectionNameKeyPath: String? = nil,
        fetchPredicate: NSPredicate,
        relationshipKeyPathsObserver: [String]? = nil,
        itemCreator: @escaping (MessageDTO) -> ChatMessage,
        eventQueue: DispatchQueue = DispatchQueue.main
    ) {
        defaultFetchPredicate = fetchPredicate
        currentFetchPredicate = defaultFetchPredicate
        self.loadRangeProvider = .init()
        self.channelId = 0
        super.init(
            context: context,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            fetchPredicate: fetchPredicate,
            relationshipKeyPathsObserver: relationshipKeyPathsObserver,
            itemCreator: itemCreator,
            eventQueue: eventQueue
        )
    }
    
    open func startObserver(
        initialMessageId: MessageId,
        lastMessageId: MessageId,
        fetchPredicate: NSPredicate? = nil,
        fetchLimit: Int,
        completion: (() -> Void)? = nil
    ) {
        if let fetchPredicate {
            self.currentFetchPredicate = fetchPredicate
        }
        loadRanges(for: initialMessageId) { [weak self] ranges in
            guard let self else {
                return
            }
            let messagesFromRangePredicate = defaultFetchPredicate
            var range = ranges.last
//            if lastMessageId != 0,
//               let currentRange = range,
//               currentRange.endMessageId == lastMessageId {
//                messagesFromRangePredicate = self.createRangePredicate(startMessageId: currentRange.startMessageId, endMessageId: nil)
//            } else {
//                messagesFromRangePredicate = self.createRangePredicate(startMessageId: range?.startMessageId, endMessageId: range?.endMessageId)
//            }
            let fetchOffset = calculateMessageFetchOffset(
                predicate: messagesFromRangePredicate,
                messageId: initialMessageId,
                fetchLimit: fetchLimit,
                direction: initialMessageId == lastMessageId ? .prev : .near
            )
            
            self.startObserver(
                fetchOffset: fetchOffset,
                fetchLimit: fetchLimit,
                fetchPredicate: messagesFromRangePredicate,
                completion: completion
            )
        }
    }
    
    open func loadNear(
        at messageId: MessageId,
        done: ((NSPredicate?) -> Void)? = nil
    ) {
        logger.debug("[Message Observer] load near for channelId: \(channelId), at messageId: \(messageId)")
        guard isObserverStarted else {
            done?(nil)
            return
        }
        loadRangeProvider.fetchPreviousRange(
            channelId: channelId,
            lastMessageId: messageId
        ) { [weak self] range in
            guard let self else { return }
            if let range {
                let predicate = self.getMessagesFromRangePredicate(range: range)
                let offset = self.calculateFetchOffset(range: range, middleMessageId: messageId, fetchLimit: self.fetchLimit)
                self.loadNear(predicate: predicate, fetchOffset: offset) {
                    done?(predicate)
                }
            } else {
                done?(nil)
            }
        }
    }
    
    open func loadNear(
        predicate: NSPredicate? = nil,
        fetchOffset: Int = 0,
        fetchLimit: Int = 0,
        done: (() -> Void)? = nil
    ) {
        self.load(from: fetchOffset, limit: fetchLimit, predicate: predicate, done: done)
    }
    
    open func loadNext(
        after messageId: MessageId,
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        logger.debug("[Message Observer] load next for channelId: \(channelId), at messageId: \(messageId)")
        guard isObserverStarted else {
            done?()
            return
        }
        loadNext(done: done)
    }
    
    open func loadPrev(
        before messageId: MessageId,
        done: (() -> Void)? = nil
    ) {
        logger.debug("[Message Observer] load prev for channelId: \(channelId), at messageId: \(messageId)")
        guard isObserverStarted else {
            done?()
            return
        }
        loadPrev(done: done)
    }
    
    open func restartToNear(
        at messageId: MessageId,
        done: ((Bool) -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?(false)
            return
        }
        loadRangeProvider
            .maxRange(
                channelId: channelId,
                triggeredMessageId: messageId
            ) { [weak self] range in
                guard let self, let range else {
                    done?(false)
                    return
                }
                let predicate = self.getMessagesFromRangePredicate(range: range)
                let offset = self.calculateMessageFetchOffset(
                    predicate: predicate,
                    messageId: messageId,
                    direction: .near
                )
                self.restartObserver(
                    fetchPredicate: predicate,
                    offset: offset,
                    completion: completion
                )
                done?(true)
            }
    }
    
    open func calculateMessageFetchOffset(
        predicate: NSPredicate? = nil,
        messageId: MessageId = 0,
        fetchLimit: Int? = nil,
        direction: LoadDirection
    ) -> Int {
        var fetchOffset: Int
        if messageId == 0 {
            fetchOffset = totalCountOfItems(predicate: predicate) - (fetchLimit ?? self.fetchLimit)
        } else {
            let limit = fetchLimit ?? self.fetchLimit
            let fetchPredicate = predicate ?? self.fetchPredicate
            
            let beforePredicate = fetchPredicate
                .and(predicate: NSPredicate(format: "id <= %lld", messageId))
            
            let beforeCount = self.totalCountOfItems(predicate: beforePredicate)
            fetchOffset = beforeCount
            switch direction {
            case .next:
                let afterCount = totalCountOfItems(predicate: fetchPredicate) - fetchOffset
                if afterCount < limit {
                    fetchOffset -= limit - afterCount
                }
            case .prev:
                fetchOffset -= limit
            case .near:
                fetchOffset -= limit / 2
            }
        }
        return max(fetchOffset, 0)
    }
    
    open func updatePredicateForNextMessages(
        currentMessageId: MessageId,
        done: ((Bool) -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?(false)
            return
        }
        loadRangeProvider
            .maxRange(
                channelId: channelId,
                triggeredMessageId: currentMessageId
            ) { [weak self] range in
                guard let self, let range else {
                    done?(false)
                    return
                }
                loadRangeProvider
                    .fetchNextRange(
                        channelId: channelId,
                        lastMessageId: range.startMessageId
                    ) {[weak self] nextRange in
                        guard let self, let nextRange
                        else {
                            done?(false)
                            return
                        }
                        var endMessageId: MessageId? {
                            if nextRange.channelLastMessageId != 0,
                               nextRange.channelLastMessageId == nextRange.endMessageId {
                                return nil
                            }
                            return nextRange.endMessageId
                        }
                        let predicate = self.createRangePredicate(startMessageId: nextRange.startMessageId, endMessageId: endMessageId)
                        if range == nextRange,
                           self.fetchPredicate == predicate {
                            done?(true)
                            return
                        }
                        
                        let offset = calculateMessageFetchOffset(
                            predicate: predicate,
                            messageId: currentMessageId,
                            direction: .next) - fetchLimit
                        update(predicate: predicate, fetchOffset: offset)
                        done?(true)
                    }
            }
    }
    
    open func updatePredicateForPrevMessages(
        currentMessageId: MessageId,
        done: ((Bool) -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?(false)
            return
        }
        loadRangeProvider
            .maxRange(
                channelId: channelId,
                triggeredMessageId: currentMessageId
            ) { [weak self] range in
                guard let self, let range else {
                    done?(false)
                    return
                }
                loadRangeProvider
                    .fetchPreviousRange(
                        channelId: channelId,
                        lastMessageId: range.startMessageId
                    ) {[weak self] prevRange in
                        guard let self
                        else {
                            done?(false)
                            return
                        }
                        
                        let predicate: NSPredicate
                        if let prevRange {
                            var endMessageId: MessageId? {
                                if prevRange.channelLastMessageId != 0,
                                   prevRange.channelLastMessageId == prevRange.endMessageId {
                                    return nil
                                }
                                return prevRange.endMessageId
                            }
                            predicate = self.createRangePredicate(startMessageId: prevRange.startMessageId, endMessageId: endMessageId)
                        } else {
                            var endMessageId: MessageId? {
                                if range.channelLastMessageId != 0,
                                   range.channelLastMessageId == range.endMessageId {
                                    return nil
                                }
                                return range.endMessageId
                            }
                            predicate = self.createRangePredicate(startMessageId: nil, endMessageId: endMessageId)
                        }
                        let offset = calculateMessageFetchOffset(
                            predicate: predicate,
                            messageId: currentMessageId,
                            direction: .prev
                        )
                        update(predicate: predicate, fetchOffset: offset)
                        done?(true)
                    }
            }
    }
    
    open func resetRangePredicateIfNeeded(restartObserver: Bool = true) -> Bool {
        if fetchPredicate != defaultFetchPredicate {
            update(predicate: defaultFetchPredicate)
            if restartObserver {
                self.restartObserver(fetchPredicate: defaultFetchPredicate)
            }
            return true
        }
        return false
    }
    
    func calculateMessageFetchOffset(
        messageId: MessageId = 0,
        fetchLimit: UInt = ChannelVM.messagesFetchLimit) -> Int {
            var fetchOffset: Int
            if messageId == 0 {
                fetchOffset = totalCountOfItems() - Int(fetchLimit)
            } else {
                let beforePredicate = defaultFetchPredicate
                    .and(predicate: .init(format: "id < %lld", messageId))
                let beforeCount = totalCountOfItems(predicate: beforePredicate)
                fetchOffset = beforeCount
                let afterCount = totalCountOfItems(predicate: defaultFetchPredicate) - fetchOffset
                if  afterCount < fetchLimit {
                    fetchOffset -= Int(fetchLimit) - afterCount
                }
            }
            return max(fetchOffset, 0)
        }
}

fileprivate extension LazyMessagesObserver {
    
    func loadRanges(
        for lastMessageId: MessageId,
        completion: @escaping ([ChatLoadRange]) -> Void
    ) {
        if lastMessageId == 0 {
            loadRangeProvider.fetchLoadRanges(channelId: channelId) { ranges in
                completion(ranges)
            }
        } else {
            loadRangeProvider.fetchPreviousRange(
                channelId: channelId,
                lastMessageId: lastMessageId
            ) { range in
                if let range {
                    completion([range])
                } else {
                    completion([])
                }
            }
        }
    }
    
    func getMessagesFromRangePredicate(
        range: LoadRangeDTO?
    ) -> NSPredicate {
        guard let range else {
            return currentFetchPredicate
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        return defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, endMessageId))
    }
    
    func getMessagesFromRangePredicate(
        range: ChatLoadRange?
    ) -> NSPredicate {
        guard let range else {
            return currentFetchPredicate
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        return defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, endMessageId))
    }
    
    func createRangePredicate(
        startMessageId: MessageId?,
        endMessageId: MessageId?
    ) -> NSPredicate {
        var predicate = defaultFetchPredicate
        if let startMessageId {
            predicate = predicate.and(predicate: .init(format: "id >= %lld", startMessageId))
        }
        if let endMessageId {
            predicate = predicate.and(predicate: .init(format: "id <= %lld", endMessageId))
        }
        return predicate
    }
    
    func calculateFetchOffset(
        range: LoadRangeDTO?,
        middleMessageId: MessageId,
        fetchLimit: Int
    ) -> Int {
        guard let range else {
            return 0
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        let predicate = defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, middleMessageId))
        let totalCount = self.totalCountOfItems(predicate: predicate) - fetchLimit / 2
        
        return totalCount > 0 ? totalCount : 0
    }
    
    func calculateFetchOffset(
        range: ChatLoadRange?,
        middleMessageId: MessageId,
        fetchLimit: Int
    ) -> Int {
        guard let range else {
            return 0
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        let predicate = defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, middleMessageId))
        let totalCount = self.totalCountOfItems(predicate: predicate) - fetchLimit / 2
        
        return totalCount > 0 ? totalCount : 0
    }
    
    func calculateFetchOffset(
        range: LoadRangeDTO?,
        lowestMessageId: MessageId,
        fetchLimit: Int
    ) -> Int {
        guard let range else {
            return 0
        }
        let startMessageId = range.startMessageId
        let predicate = defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, lowestMessageId))
        let totalCount = self.totalCountOfItems(predicate: predicate)
        
        return totalCount
    }
    
    func calculateFetchOffset(
        range: LoadRangeDTO?,
        highMessageId: MessageId,
        fetchLimit: Int
    ) -> Int {
        guard let range else {
            return 0
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        let predicate = defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, highMessageId))
        let totalCount = self.totalCountOfItems(predicate: predicate) - fetchLimit
        
        return max(0, totalCount)
    }
}
