import Foundation
import SceytChat

public final class ChatLoadRange {
    
    public let channelId: ChannelId
    public let startMessageId: MessageId
    public let endMessageId: MessageId
    
    public init(
        channelId: ChannelId,
        startMessageId: MessageId,
        endMessageId: MessageId
    ) {
        self.channelId = channelId
        self.startMessageId = startMessageId
        self.endMessageId = endMessageId
    }
    
    public init(dto: LoadRangeDTO) {
        channelId = ChannelId(dto.channelId)
        startMessageId = MessageId(dto.startMessageId)
        endMessageId = MessageId(dto.endMessageId)
    }
}
