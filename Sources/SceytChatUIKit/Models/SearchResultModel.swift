import SceytChat

public protocol SearchCoordinator {
    associatedtype Item

    func nextItem() -> Item?
    func prevItem() -> Item?
    func currentItem() -> Item?
    
    var hasNext: Bool { get }
    var hasPrev: Bool { get }

    @discardableResult
    mutating func next() -> Bool
    @discardableResult
    mutating func prev() -> Bool
    
    mutating func resetCache()

    mutating func addCache(items: [Item])

    mutating func setCurrentIndex(_ index: Int)
}

public struct MessageSearchCoordinator: SearchCoordinator {

    public typealias Item = MessageId

    private var searchResults = [Item]()
    private(set) var currentIndex: Int = 0

    @Atomic public private(set) var state: State = .pending

    public func nextItem() -> Item? {
        let nextIndex = currentIndex + 1
        if searchResults.indices.contains(nextIndex) {
            return searchResults[nextIndex]
        }
        return nil
    }

    public func prevItem() -> Item? {
        let prevIndex = currentIndex - 1
        if prevIndex >= 0, searchResults.indices.contains(prevIndex) {
            return searchResults[prevIndex]
        }
        return nil
    }
    
    @discardableResult
    public mutating func next() -> Bool {
        let nextIndex = currentIndex + 1
        if searchResults.indices.contains(nextIndex) {
            currentIndex = nextIndex
            return true
        }
        return false
    }
    
    @discardableResult
    public mutating func prev() -> Bool {
        let prevIndex = currentIndex - 1
        if prevIndex >= 0, searchResults.indices.contains(prevIndex) {
            currentIndex = prevIndex
            return true
        }
        return false
    }

    public func currentItem() -> Item? {
        if searchResults.indices.contains(currentIndex) {
            return searchResults[currentIndex]
        }
        return nil
    }

    public var hasNext: Bool {
        let nextIndex = currentIndex + 1
        return searchResults.indices.contains(nextIndex)
    }

    public var hasPrev: Bool {
        let prevIndex = currentIndex - 1
        return prevIndex >= 0 && searchResults.indices.contains(prevIndex)
    }

    public mutating func resetCache() {
        currentIndex = 0
        searchResults.removeAll(keepingCapacity: true)
    }

    public var cacheCount: Int {
        searchResults.count
    }

    public mutating func addCache(items: [Item]) {
        searchResults += items
    }

    public mutating func setCurrentIndex( _ index: Int) {
        currentIndex = index
    }

    public private(set) var searchQuery: MessageListQuery?
    public let channelId: ChannelId
    public let searchQueryLimit: Int
    init(
        channelId: ChannelId,
        searchFields: [MessageListQuery.SearchField],
        limit: Int = 50
    ) {
        self.channelId = channelId
        self.searchQueryLimit = limit
        if !searchFields.isEmpty, limit > 0 {
            searchQuery =
            MessageListQuery
                .Builder(channelId: channelId)
                .limit(UInt(limit))
                .searchFields(searchFields)
                .build()
        }
    }

    func loadNextMessages(_ completion: @escaping ([Message]?, Error?) -> Void) {
        guard let searchQuery, searchQuery.hasNext
        else {
            completion(nil, nil)
            return
        }
        state = .loading
        searchQuery.loadNext { _, messages, error in
            if let error {
                state = .loadFailed
            } else {
                state = .loaded
            }
            completion(messages, error)
        }
    }
}

public extension MessageSearchCoordinator {
    enum State {
        case pending
        case loading
        case loaded
        case loadFailed
    }
}
