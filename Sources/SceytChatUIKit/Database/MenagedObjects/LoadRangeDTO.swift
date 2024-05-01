import CoreData
import Foundation
import SceytChat

@objc(LoadRangeDTO)
public class LoadRangeDTO: NSManagedObject {
    
    @NSManaged public var startMessageId: Int64
    @NSManaged public var endMessageId: Int64
    @NSManaged public var channelId: Int64
    
    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<LoadRangeDTO> {
        return NSFetchRequest<LoadRangeDTO>(entityName: entityName)
    }
    
    public static func fetchMatching(
        channelId: ChannelId,
        startMessageId: MessageId,
        endMessageId: MessageId,
        triggerMessageId: MessageId?,
        context: NSManagedObjectContext
    ) -> [LoadRangeDTO] {
        let request = fetchRequest()
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
        if let triggerMessageId {
            subpredicates.append(NSPredicate(
                format: "startMessageId == %lld OR endMessageId == %lld",
                triggerMessageId,
                triggerMessageId
            ))
        }
        
        let channelPredicate = NSPredicate(format: "channelId == %lld", channelId)
        
        let idMatchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [idMatchPredicate, channelPredicate])
        request.predicate = compoundPredicate
        request.sortDescriptor = NSSortDescriptor(keyPath: \LoadRangeDTO.endMessageId, ascending: false)
        return fetch(request: request, context: context)
    }
    
    public static func fetchAll(channelId: ChannelId, context: NSManagedObjectContext) -> [LoadRangeDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        request.sortDescriptor = NSSortDescriptor(keyPath: \LoadRangeDTO.endMessageId, ascending: true)
        return fetch(request: request, context: context)
    }
    
    public static func create(
        channelId: ChannelId,
        startMessageId: MessageId,
        endMessageId: MessageId,
        context: NSManagedObjectContext
    ) {
        let mo = insertNewObject(into: context)
        mo.channelId = Int64(channelId)
        mo.startMessageId = Int64(startMessageId)
        mo.endMessageId = Int64(endMessageId)
    }
    
    public func convert() -> ChatLoadRange {
        .init(dto: self)
    }
}
