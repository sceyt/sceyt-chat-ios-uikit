import Foundation
import CoreData
import SceytChat

open class LazyMessagesObserver: LazyDatabaseObserver<MessageDTO, ChatMessage> {
    
    public var messageFetchPredicate: NSPredicate
    public private(set) var loadRangeProvider: LoadRangeProvider
    
    private let channelId: Int64
    
    public init(
        channelId: Int64,
        loadRangeProvider: LoadRangeProvider,
        itemCreator: @escaping (MessageDTO) -> ChatMessage
    ) {
        messageFetchPredicate = NSPredicate(
            format: "channelId == %lld AND repliedInThread == false AND replied == false AND unlisted == false",
            channelId
        )
        self.loadRangeProvider = loadRangeProvider
        self.channelId = channelId
        super.init(
            context: Config.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [
                .init(keyPath: \MessageDTO.createdAt, ascending: true),
                .init(keyPath: \MessageDTO.id, ascending: true)
            ],
            sectionNameKeyPath: #keyPath(MessageDTO.daySectionIdentifier),
            fetchPredicate: messageFetchPredicate,
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
    
    @available(*, unavailable)
    public required init(
        context: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor],
        sectionNameKeyPath: String? = nil,
        fetchPredicate: NSPredicate,
        relationshipKeyPathsObserver: [String]? = nil,
        itemCreator: @escaping (MessageDTO) -> ChatMessage,
        eventQueue: DispatchQueue = DispatchQueue.main
    ) {
        fatalError("Not implemented, use init(channelId:loadRangeProvider:itemCreator:) instead")
    }
    
    open func startObserver(
        initialMessageId: MessageId,
        fetchPredicate: NSPredicate? = nil,
        fetchLimit: Int,
        completion: (() -> Void)? = nil
    ) {
        if let fetchPredicate {
            self.messageFetchPredicate = fetchPredicate
        }
        loadRanges(for: initialMessageId) { [weak self] ranges in
            guard let self else {
                return
            }
            let range = ranges.last
            
            let messagesFromRangePredicate = self.getMessagesFromRangePredicate(range: range)
            
            let fetchOffset = calculateMessageFetchOffset(
                predicate: messagesFromRangePredicate,
                messageId: initialMessageId,
                fetchLimit: fetchLimit
            )

            self.startObserver(
                fetchOffset: max(fetchOffset, 0),
                fetchLimit: fetchLimit,
                fetchPredicate: messagesFromRangePredicate,
                completion: completion
            )
        }
    }

    open func restartObserver(
        initialMessageId: MessageId,
        messageFetchPredicate: NSPredicate,
        done: (() -> Void)? = nil
    ) {
        self.messageFetchPredicate = fetchPredicate
        loadRanges(for: initialMessageId) { [weak self] ranges in
            guard let self else {
                return
            }
            let range = ranges.last

            let messagesFromRangePredicate = self.getMessagesFromRangePredicate(range: range)

            let fetchOffset = calculateMessageFetchOffset(
                predicate: messagesFromRangePredicate,
                messageId: initialMessageId,
                fetchLimit: fetchLimit
            )

            self.restartObserver(
                fetchPredicate: messagesFromRangePredicate,
                offset: fetchOffset,
                completion: done
            )
        }
    }

    open func loadPrev(before messageId: MessageId, done: (() -> Void)? = nil) {
        print("<><> on load prev for channelId: \(channelId), messageId: \(messageId) <><>")
        guard isObserverStarted else {
            done?()
            return
        }
        loadRangeProvider.fetchPreviousLoadRange(
            channelId: channelId,
            lastMessageId: Int64(messageId)
        ) { [weak self] range in
            guard let self else { return }
            if let range {
                let predicate = self.getMessagesFromRangePredicate(range: range)
                self.loadPrev(predicate: predicate, done: done)
            } else {
                done?()
            }
        }
        
    }
    
    open func loadNear(at messageId: MessageId, done: ((NSPredicate?) -> Void)? = nil) {
        print("<><> on load near for channelId: \(channelId), messageId: \(messageId) <><>")
        guard isObserverStarted else {
            done?(nil)
            return
        }
        loadRangeProvider.fetchPreviousLoadRange(
            channelId: channelId,
            lastMessageId: Int64(messageId)
        ) { [weak self] range in
            guard let self else { return }
            if let range {
                let predicate = self.getMessagesFromRangePredicate(range: range)
                self.loadNear(predicate: predicate) {
                    done?(predicate)
                }
            } else {
                done?(nil)
            }
        }
    }

    open func resetToNear(at messageId: MessageId, done: (() -> Void)? = nil) {
        guard isObserverStarted else {
            done?()
            return
        }
        print("<><> on reset to near for channelId: \(channelId), messageId: \(messageId) <><>")
        loadRangeProvider.fetchPreviousLoadRange(
            channelId: channelId,
            lastMessageId: Int64(messageId)
        ) { [weak self] range in
            guard let self else { return }
            if let range {
                let predicate = self.getMessagesFromRangePredicate(range: range)

                let offset = self.calculateMessageFetchOffset(
                    predicate: predicate,
                    messageId: messageId
                )

                var fetchOffset = offset
                let afterCount = self.totalCountOfItems(predicate: predicate) - offset
                if afterCount > fetchLimit {
                    fetchOffset = max(0, offset - fetchLimit / 2)
                }

                self.restartObserver(
                    fetchPredicate: predicate,
                    offset: fetchOffset,
                    completion: done
                )
            } else {
                done?()
            }
        }
    }

    open func loadNext(
        after messageId: MessageId,
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        print("<><> on load next for channelId: \(channelId), messageId: \(messageId) <><>")
        guard isObserverStarted else {
            done?()
            return
        }
        
        loadRangeProvider.fetchNextLoadRange(
            channelId: channelId,
            lastMessageId: Int64(messageId)
        ) { [weak self] range in
            guard let self else { return }
            if let range {
                let predicate = self.getMessagesFromRangePredicate(range: range)
                self.loadNext(predicate: predicate, done: done)
            } else {
                done?()
            }
        }
    }

    open func calculateMessageFetchOffset(
        predicate: NSPredicate? = nil,
        messageId: MessageId = 0,
        fetchLimit: Int? = nil
    ) -> Int {
        var fetchOffset: Int
        if messageId == 0 {
            fetchOffset = totalCountOfItems(predicate: predicate) - (fetchLimit ?? self.fetchLimit)
        } else {
            let limit = fetchLimit ?? self.fetchLimit
            let fetchPredicate = predicate ?? self.fetchPredicate

            let beforePredicate = fetchPredicate
                .and(predicate: NSPredicate(format: "id < %lld", messageId))

            let beforeCount = self.totalCountOfItems(predicate: beforePredicate)
            fetchOffset = beforeCount
            let afterCount = totalCountOfItems(predicate: fetchPredicate) - fetchOffset
            if afterCount < limit {
                fetchOffset -= limit - afterCount
            }
        }
        return max(fetchOffset, 0)
    }

    open override func loadNear(predicate: NSPredicate? = nil, done: (() -> Void)? = nil) {
        print("<><> on load near <><>")
        super.loadNear(predicate: predicate, done: done)
    }
    
    private func loadRanges(
        for lastMessageId: MessageId,
        completion: @escaping ([LoadRangeDTO]) -> Void
    ) {
        if lastMessageId == 0 {
            loadRangeProvider.fetchLoadRanges(channelId: channelId) { ranges in
                completion(ranges)
            }
        } else {
            loadRangeProvider.fetchPreviousLoadRange(
                channelId: channelId,
                lastMessageId: Int64(lastMessageId)
            ) { range in
                if let range {
                    completion([range])
                } else {
                    completion([])
                }
            }
        }
    }
    
    private func getMessagesFromRangePredicate(range: LoadRangeDTO?) -> NSPredicate {
        guard let range else {
            return messageFetchPredicate
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        return messageFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, endMessageId))
    }
}
