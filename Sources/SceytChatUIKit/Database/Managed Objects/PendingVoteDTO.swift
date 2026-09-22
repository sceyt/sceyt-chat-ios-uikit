//
//  PendingVoteDTO.swift
//  SceytChatUIKit
//
//  Created by Vahagn Manasyan on 28.10.25.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(PendingVoteDTO)
public class PendingVoteDTO: NSManagedObject {
    @NSManaged public var pollId: String?
    @NSManaged public var optionId: String?
    @NSManaged public var messageTid: Int64
    @NSManaged public var createdAt: Int64
    @NSManaged public var isAdd: Bool
    @NSManaged public var poll: PollDTO?
    @NSManaged public var user: UserDTO?
    
    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<PendingVoteDTO> {
        return NSFetchRequest<PendingVoteDTO>(entityName: entityName)
    }
    
    public static func fetch(
        pollId: String,
        optionId: String,
        userId: UserId,
        context: NSManagedObjectContext
    ) -> PendingVoteDTO? {
        let request = fetchRequest()
        request.predicate = .init(format: "pollId == %@ AND optionId == %@ AND user.id == %@", pollId, optionId, userId)
        return fetch(request: request, context: context).first
    }
    
    public static func fetch(
        pollId: String,
        userId: UserId,
        context: NSManagedObjectContext
    ) -> [PendingVoteDTO] {
        let request = fetchRequest()
        request.predicate = .init(format: "pollId == %@ AND user.id == %@", pollId, userId)
        return fetch(request: request, context: context)
    }

    public static func fetch(
        messageTid: Int64,
        context: NSManagedObjectContext
    ) -> [PendingVoteDTO] {
        let request = fetchRequest()
        request.predicate = .init(format: "messageTid == %lld", messageTid)
        return fetch(request: request, context: context)
    }
    
    public static func fetchOrCreate(
        pollId: String,
        optionId: String,
        userId: UserId,
        messageTid: Int64,
        context: NSManagedObjectContext
    ) -> PendingVoteDTO {
        if let vote = fetch(pollId: pollId, optionId: optionId, userId: userId, context: context) {
            // Set poll relationship if not already set
            if vote.poll == nil, let pollDTO = PollDTO.fetch(id: pollId, context: context) {
                // Use mutableSetValue to safely add to the inverse relationship
                let pendingVotesSet = pollDTO.mutableSetValue(forKey: "pendingVotes")
                pendingVotesSet.add(vote)
                vote.poll = pollDTO
            }
            return vote
        }

        let mo = insertNewObject(into: context)
        mo.pollId = pollId
        mo.optionId = optionId
        mo.messageTid = messageTid
        mo.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        mo.user = UserDTO.fetchOrCreate(id: userId, context: context)

        // Safely set poll relationship using mutable accessor for inverse relationship
        if let pollDTO = PollDTO.fetch(id: pollId, context: context) {
            let pendingVotesSet = pollDTO.mutableSetValue(forKey: "pendingVotes")
            pendingVotesSet.add(mo)
            mo.poll = pollDTO
        }

        return mo
    }
}

extension PendingVoteDTO: Identifiable { }

