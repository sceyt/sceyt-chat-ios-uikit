import SceytChat

public protocol SearchCoordinator {
    associatedtype Item

    mutating func next() -> Item?
    mutating func prev() -> Item?
    func current() -> Item?

    var hasNext: Bool { get }
    var hasPrev: Bool { get }

    mutating func resetCache()

    mutating func addCache(items: [Item])

    mutating func setCurrentIndex(_ index: Int)
}

public struct MessageSearchCoordinator: SearchCoordinator {

    public typealias Item = MessageId

    private var searchResults = [Item]()
    private(set) var currentIndex: Int = 0

    @Atomic public private(set) var state: State = .pending

    public mutating func next() -> Item? {
        let nextIndex = currentIndex + 1
        if searchResults.indices.contains(nextIndex) {
            currentIndex = nextIndex
            return searchResults[currentIndex]
        }
        return nil
    }

    public mutating func prev() -> Item? {
        let prevIndex = currentIndex - 1
        if prevIndex >= 0, searchResults.indices.contains(prevIndex) {
            currentIndex = prevIndex
            return searchResults[currentIndex]
        }
        return nil
    }

    public func current() -> Item? {
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
            state = .loaded
            completion(messages, error)
        }
    }
}

public extension MessageSearchCoordinator {
    enum State {
        case pending
        case loading
        case loaded
    }
}
