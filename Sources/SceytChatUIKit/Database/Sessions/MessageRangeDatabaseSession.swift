//
//  MessageRangeDatabaseSession.swift
//
//
//  Created by Ovsep Keropian on 17.03.24.
//

import Foundation
import CoreData
import SceytChat

public protocol MessageRangeDatabaseSession {
    
    
    func maxRange(channelId: ChannelId, messageId: MessageId) -> LoadRangeDTO?
    
    func matchingRanges(
        channelId: ChannelId,
        startMessageId: MessageId,
        endMessageId: MessageId,
        triggerMessageId: MessageId
    ) -> [LoadRangeDTO]
    
    func previousRange(
        channelId: ChannelId,
        lastMessageId: MessageId
    ) -> LoadRangeDTO?
    
    func nextRange(
        channelId: ChannelId,
        lastMessageId: MessageId
    ) -> LoadRangeDTO?
    
    func updateRanges(
        startMessageId: MessageId,
        endMessageId: MessageId,
        triggerMessage: MessageId?,
        channelId: ChannelId
    ) -> LoadRangeDTO?
}

extension NSManagedObjectContext: MessageRangeDatabaseSession {
    
    public func maxRange(channelId: ChannelId, messageId: MessageId) -> LoadRangeDTO? {
        let request = LoadRangeDTO.fetchRequest()
        let predicate = NSPredicate(format: "channelId == %ld AND startMessageId <= %ld AND endMessageId >= %ld", channelId, messageId, messageId)
        request.predicate = predicate
        
        let ranges = LoadRangeDTO.fetch(request: request, context: self)
        return ranges.max(by: { ($0.endMessageId - $0.startMessageId) < ($1.endMessageId - $1.startMessageId) })
    }
    
    public func matchingRanges(
        channelId: ChannelId,
        startMessageId: MessageId,
        endMessageId: MessageId,
        triggerMessageId: MessageId = 0
    ) -> [LoadRangeDTO] {
        
        var subpredicates = [NSPredicate]()
        subpredicates.append(NSPredicate(
            format: "startMessageId >= %lld AND startMessageId <= %lld ",
            startMessageId,
            endMessageId
        ))
        subpredicates.append(NSPredicate(
            format: "endMessageId >= %lld AND endMessageId <= %lld",
            startMessageId,
            endMessageId
        ))
        subpredicates.append(NSPredicate(
            format: "startMessageId <= %lld AND endMessageId >= %lld",
            startMessageId,
            endMessageId
        ))
        if triggerMessageId != startMessageId,
           triggerMessageId != endMessageId {
            subpredicates.append(NSPredicate(
                format: "startMessageId == %lld OR endMessageId == %lld",
                triggerMessageId,
                triggerMessageId
            ))
        }
        
        let channelPredicate = NSPredicate(format: "channelId == %lld", channelId)
        
        let idMatchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [idMatchPredicate, channelPredicate])
        
        let request = LoadRangeDTO.fetchRequest()
        request.predicate = predicate
        request.sortDescriptor = NSSortDescriptor(keyPath: \LoadRangeDTO.endMessageId, ascending: false)
        return LoadRangeDTO.fetch(request: request, context: self)
    }
    
    public func previousRange(
        channelId: ChannelId,
        lastMessageId: MessageId
    ) -> LoadRangeDTO? {
        let request = LoadRangeDTO.fetchRequest()
        request.predicate = NSPredicate(
            format: "startMessageId <= %lld AND endMessageId >= %lld AND channelId == %lld",
            lastMessageId,
            lastMessageId,
            channelId
        )
        
        request.sortDescriptor = .init(keyPath: \LoadRangeDTO.endMessageId, ascending: true)
        return LoadRangeDTO.fetch(request: request, context: self).last
    }
    
    public func nextRange(
        channelId: ChannelId,
        lastMessageId: MessageId
    ) -> LoadRangeDTO? {
        let request = LoadRangeDTO.fetchRequest()
        request.predicate = NSPredicate(
            format: "startMessageId <= %lld AND endMessageId >= %lld AND channelId == %lld",
            lastMessageId,
            lastMessageId,
            channelId
        )
        request.sortDescriptor = .init(keyPath: \LoadRangeDTO.endMessageId, ascending: true)
        return LoadRangeDTO.fetch(request: request, context: self).first
    }
    
    public func updateRanges(
        startMessageId: MessageId,
        endMessageId: MessageId,
        triggerMessage: MessageId? = nil,
        channelId: ChannelId
    ) -> LoadRangeDTO? {
        
        var ranges = matchingRanges(
            channelId: channelId,
            startMessageId: startMessageId,
            endMessageId: endMessageId,
            triggerMessageId: triggerMessage ?? startMessageId
        )
        
        let minDb = ranges.min(by: { $0.startMessageId < $1.startMessageId })?.startMessageId ?? Int64(startMessageId)
        let maxDb = ranges.max(by: { $0.endMessageId < $1.endMessageId })?.endMessageId ?? Int64(endMessageId)
        let min = min(MessageId(minDb), startMessageId)
        let max = max(MessageId(maxDb), endMessageId)
        
        if ranges.count == 1 &&
            min >= ranges[0].startMessageId &&
            max <= ranges[0].endMessageId {
            return ranges.first
        }
        
        var anyRange: LoadRangeDTO?
        if !ranges.isEmpty {
            anyRange = ranges.removeLast()
            if !ranges.isEmpty {
                logger.warn("there are \(ranges.count) range for channel \(channelId), will be deleted soon")
                try? batchDelete(ids: ranges.map { $0.objectID })
            }
        }
        
        if let anyRange {
            anyRange.startMessageId = Int64(min)
            anyRange.endMessageId = Int64(max)
            return anyRange
        }
        let dto = LoadRangeDTO
            .create(
                channelId: channelId,
                startMessageId: min,
                endMessageId: max,
                context: self
            )
        return dto
    }
}
