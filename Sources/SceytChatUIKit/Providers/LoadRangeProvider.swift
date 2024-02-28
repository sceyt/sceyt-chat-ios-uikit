import Foundation

public final class LoadRangeProvider: Provider {
    
    func fetchPreviousLoadRange(
        channelId: Int64,
        lastMessageId: Int64,
        completion: @escaping (LoadRangeDTO?) -> Void
    ) {
        database.read { context in
            let request = LoadRangeDTO.fetchRequest()
            request.sortDescriptor = .init(keyPath: \LoadRangeDTO.endMessageId, ascending: true)
            let ranges = LoadRangeDTO.fetch(request: request, context: context)
            print()
        }
        database.read { context in
            return LoadRangeDTO.fetchPreviousRange(
                channelId: channelId,
                lastMessageId: lastMessageId,
                context: context
            )
        } completion: { result in
            switch result {
            case let .success(range):
                completion(range)
            case .failure:
                completion(nil)
            }
        }

    }
    
    func fetchLoadRanges(channelId: Int64, completion: @escaping ([LoadRangeDTO]) -> Void) {
        database.read { context in
            let request = LoadRangeDTO.fetchRequest()
            request.sortDescriptor = .init(keyPath: \LoadRangeDTO.endMessageId, ascending: true)
            let ranges = LoadRangeDTO.fetch(request: request, context: context)
            print()
        }
        database.read { context in
            return LoadRangeDTO.fetchAll(channelId: channelId, context: context)
        } completion: { result in
            switch result {
            case let .success(ranges):
                completion(ranges)
            case .failure:
                completion([])
            }
        }
    }
}
