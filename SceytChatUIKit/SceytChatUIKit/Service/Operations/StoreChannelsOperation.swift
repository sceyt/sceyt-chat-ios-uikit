//
//  StoreChannelsOperation.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat
import CoreData

open class StoreChannelsOperation: Operation {
    
    private let database: Database
    public var channels: [Channel]
    private let deleteNonExistences: Bool

    public init(
        database: Database,
        channels: [Channel] = [],
        deleteNonExistences: Bool = true) {
        self.database = database
        self.channels = channels
        self.deleteNonExistences = deleteNonExistences
    }
    
    open override func main() {
        print("[Operation] Store main", channels.count)
        guard !channels.isEmpty
        else { return }
        try? database.syncWrite {
            if self.deleteNonExistences {
                let ids = self.channels.map { $0.id }
                print("[Operation] Store main got", ids)
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                request.predicate = .init(format: "NOT (id IN %@)", ids)
                do {
                    try $0.batchDelete(fetchRequest: request)
                } catch {
                    print(error)
                    print("[Operation] Store main batchDelete error", error)
                }
            }
            
            for channel in self.channels {
                print("[Operation] Store main channel", channel.id)
                $0.createOrUpdate(channel: channel)
                if self.isCancelled {
                    print("[Operation] Store main channel isCancelled", true)
                    break
                }
            }
        }
    }
}
