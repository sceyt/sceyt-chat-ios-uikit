import Foundation
import SceytChat

public enum LoadDirection {
    case next, prev, near
}

open class LoadRangeProvider: Provider {
    
    public required override init() {
        super.init()
    }
    
    open func fetchPreviousRange(
        channelId: ChannelId,
        lastMessageId: MessageId,
        completion: @escaping (ChatLoadRange?) -> Void
    ) {
        database.read {
            let range = $0.previousRange(
                channelId: channelId,
                lastMessageId: lastMessageId
            )?.convert()
            if let id = ChannelDTO.fetch(id: channelId, context: $0)?.lastMessage?.id {
                range?.channelLastMessageId = MessageId(id)
            }
            return range
        } completion: { result in
            switch result {
            case let .success(range):
                completion(range)
            case .failure:
                completion(nil)
            }
        }

    }
    
    open func fetchNextRange(
        channelId: ChannelId,
        lastMessageId: MessageId,
        completion: @escaping (ChatLoadRange?) -> Void
    ) {
        database.read {
            let range = $0.nextRange(
                channelId: channelId,
                lastMessageId: lastMessageId
            )?.convert()
            if let id = ChannelDTO.fetch(id: channelId, context: $0)?.lastMessage?.id {
                range?.channelLastMessageId = MessageId(id)
            }
            return range
        } completion: { result in
            switch result {
            case let .success(range):
                completion(range)
            case .failure:
                completion(nil)
            }
        }
    }
    
    
    open func maxRange(
        channelId: ChannelId,
        triggeredMessageId: MessageId,
        completion: @escaping (ChatLoadRange?) -> Void
    ) {
        database.read {
            let range = $0.maxRange(
                    channelId: channelId,
                    messageId: triggeredMessageId)?
                .convert()
            if let id = ChannelDTO.fetch(id: channelId, context: $0)?.lastMessage?.id {
                range?.channelLastMessageId = MessageId(id)
            }
            return range
        } completion: { result in
            switch result {
            case let .success(range):
                completion(range)
            case .failure:
                completion(nil)
            }
        }
    }
    
    open func fetchLoadRanges(channelId: ChannelId, completion: @escaping ([ChatLoadRange]) -> Void) {
        database.read { context in
            return LoadRangeDTO.fetchAll(channelId: channelId, context: context).map { $0.convert() }
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
