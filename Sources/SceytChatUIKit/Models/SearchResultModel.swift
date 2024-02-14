import SceytChat

public struct SearchResultModel: Equatable {
    var searchResults = [MessageId]()
    var lastViewedSearchResult: MessageId?
    
    var nextResult: MessageId? {
        if let lastViewedSearchResult, let index = searchResults.firstIndex(of: lastViewedSearchResult) {
            return searchResults[safe: index - 1]
        }
        return nil
    }
    
    var previousResult: MessageId? {
        if let lastViewedSearchResult, let index = searchResults.firstIndex(of: lastViewedSearchResult) {
            return searchResults[safe: index + 1]
        }
        return nil
    }
    
    var lastViewedSearchResultReversedIndex: Int? {
        if let lastViewedSearchResult, let index = searchResults.firstIndex(of: lastViewedSearchResult) {
            return index + 1
        }
        return nil
    }
}
