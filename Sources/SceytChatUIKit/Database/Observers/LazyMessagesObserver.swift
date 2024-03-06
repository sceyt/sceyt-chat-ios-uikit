import Foundation
import CoreData
import SceytChat

open class LazyMessagesObserver: LazyDatabaseObserver<MessageDTO, ChatMessage> {

    public let defaultFetchPredicate: NSPredicate
    public var currentFetchPredicate: NSPredicate
    public private(set) var loadRangeProvider: LoadRangeProvider

    private let channelId: Int64

    public init(
        channelId: Int64,
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
            context: Config.database.backgroundReadOnlyObservableContext,
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
            self.currentFetchPredicate = fetchPredicate
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
        self.currentFetchPredicate = fetchPredicate
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
                let offset = self.calculateFetchOffset(range: range, highMessageId: messageId, fetchLimit: self.fetchLimit)
                self.load(from: offset, limit: fetchLimit, predicate: predicate, done: done)
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
                let offset = self.calculateFetchOffset(range: range, middleMessageId: messageId, fetchLimit: self.fetchLimit)
                self.loadNear(predicate: predicate, fetchOffset: offset) {
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
                let fetchOffset = self.calculateFetchOffset(range: range, lowestMessageId: messageId, fetchLimit: self.fetchLimit)
                self.load(from: fetchOffset, limit: self.fetchLimit, predicate: predicate, done: done)
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

    open func loadNear(
        predicate: NSPredicate? = nil,
        fetchOffset: Int = 0,
        fetchLimit: Int = 0,
        done: (() -> Void)? = nil
    ) {
        self.load(from: fetchOffset, limit: fetchLimit, predicate: predicate, done: done)
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
            return currentFetchPredicate
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        return defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, endMessageId))
    }

    private func calculateFetchOffset(range: LoadRangeDTO?, middleMessageId: MessageId, fetchLimit: Int) -> Int {
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

    private func calculateFetchOffset(range: LoadRangeDTO?, lowestMessageId: MessageId, fetchLimit: Int) -> Int {
        guard let range else {
            return 0
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        let predicate = defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, lowestMessageId))
        let totalCount = self.totalCountOfItems(predicate: predicate)

        return totalCount
    }

    private func calculateFetchOffset(range: LoadRangeDTO?, highMessageId: MessageId, fetchLimit: Int) -> Int {
        guard let range else {
            return 0
        }
        let startMessageId = range.startMessageId
        let endMessageId = range.endMessageId
        let predicate = defaultFetchPredicate
            .and(predicate: .init(format: "id >= %lld AND id <= %lld", startMessageId, highMessageId))
        let totalCount = self.totalCountOfItems(predicate: predicate) - fetchLimit

        return totalCount
    }
}
