import Foundation
import SceytChat

public final class LoadRangeProvider: Provider {
    
    func fetchPreviousLoadRange(
        channelId: ChannelId,
        lastMessageId: MessageId,
        completion: @escaping (LoadRangeDTO?) -> Void
    ) {
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
    
    func fetchNextLoadRange(
        channelId: ChannelId,
        lastMessageId: MessageId,
        completion: @escaping (LoadRangeDTO?) -> Void
    ) {
        database.read { context in
            return LoadRangeDTO.fetchNextRange(
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
    
    func fetchLoadRanges(channelId: ChannelId, completion: @escaping ([LoadRangeDTO]) -> Void) {
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
