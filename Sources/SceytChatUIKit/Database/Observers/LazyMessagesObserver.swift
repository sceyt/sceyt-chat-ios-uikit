import Foundation
import CoreData

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
        initialMessageId: Int64,
        fetchLimit: Int,
        completion: (() -> Void)? = nil
    ) {
        loadRanges(for: initialMessageId) { [weak self] ranges in
            guard let self else {
                return
            }
            let range = ranges.last
            
            let messagesFromRangePredicate = self.getMessagesFromRangePredicate(range: range)
            
            var fetchOffset = 0
            
            let beforePredicate = messagesFromRangePredicate
                .and(predicate: NSPredicate(format: "id < %lld", initialMessageId))
            
            let beforeCount = self.totalCountOfItems(predicate: beforePredicate)
            fetchOffset = beforeCount
            let afterCount = totalCountOfItems(predicate: messagesFromRangePredicate) - fetchOffset
            if afterCount < fetchLimit {
                fetchOffset -= Int(fetchLimit) - afterCount
            }
            
            self.startObserver(
                fetchOffset: max(fetchOffset, 0),
                fetchLimit: fetchLimit,
                fetchPredicate: messagesFromRangePredicate,
                completion: completion
            )
        }
    }
    
    open func loadPrev(before messageId: Int64, done: (() -> Void)? = nil) {
        guard isObserverStarted else {
            done?()
            return
        }
        loadRangeProvider.fetchPreviousLoadRange(channelId: channelId, lastMessageId: messageId) { [weak self] range in
            guard let self else { return }
            if let range {
                print("<><> on load prev for channelId: \(channelId), messageId: \(messageId) <><>")
                let predicate = self.getMessagesFromRangePredicate(range: range)
                self.loadPrev(predicate: predicate, done: done)
            } else {
                done?()
            }
        }
        
    }
    
    open func loadNear(at messageId: Int64, restart: Bool = false, done: (() -> Void)? = nil) {
        guard isObserverStarted else {
            done?()
            return
        }
        loadRangeProvider.fetchPreviousLoadRange(channelId: channelId, lastMessageId: messageId) { [weak self] range in
            guard let self else { return }
            if let range {
                let predicate = self.getMessagesFromRangePredicate(range: range)
                if restart {
                    self.restartObserver(fetchPredicate: predicate, completion: done)
                } else {
                    self.loadNear(predicate: predicate, done: done)
                }
            } else {
                done?()
            }
        }
    }
    
    open func loadNext(
        after messageId: Int64,
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?()
            return
        }
        
        loadRangeProvider.fetchNextLoadRange(channelId: channelId, lastMessageId: messageId) { [weak self] range in
            guard let self else { return }
            if let range {
                print("<><> on load next for channelId: \(channelId), messageId: \(messageId) <><>")
                let predicate = self.getMessagesFromRangePredicate(range: range)
                self.loadNext(predicate: predicate, done: done)
            } else {
                done?()
            }
        }
    }
    
    open override func loadNear(predicate: NSPredicate? = nil, done: (() -> Void)? = nil) {
        print("<><> on load near <><>")
        super.loadNear(predicate: predicate, done: done)
    }
    
    private func loadRanges(
        for lastMessageId: Int64,
        completion: @escaping ([LoadRangeDTO]) -> Void
    ) {
        if lastMessageId == 0 {
            loadRangeProvider.fetchLoadRanges(channelId: channelId) { ranges in
                completion(ranges)
            }
        } else {
            loadRangeProvider.fetchPreviousLoadRange(channelId: channelId, lastMessageId: lastMessageId) { range in
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
