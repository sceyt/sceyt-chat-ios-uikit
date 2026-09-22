//
//  ChannelDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

public protocol ChannelDatabaseSession {
    
    @discardableResult
    func createOrUpdate(channel: Channel) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(channel: ChatChannel) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(channels: [Channel]) -> [ChannelDTO]
    
    func markAsRead(channelId: ChannelId)
    
    @discardableResult
    func add(members: [Member], channelId: ChannelId) -> ChannelDTO?
    
    @discardableResult
    func update(owner: Member, channelId: ChannelId) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO
    
    @discardableResult
    func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO]
    
    @discardableResult
    func createOrUpdate(member: ChatChannelMember, channelId: ChannelId) -> MemberDTO
    
    func delete(members: [Member], channelId: ChannelId)
    
    func deleteMember(id: UserId, from channelId: ChannelId)
    
    func updateChannelDTOs(for userId: UserId)
    
    @discardableResult
    func update(draft message: NSAttributedString?, date: Date?, channelId: ChannelId) -> ChannelDTO?
}

extension NSManagedObjectContext: ChannelDatabaseSession {
    
    @discardableResult
    public func createOrUpdate(channel: Channel) -> ChannelDTO {
        return createOrUpdate(channel: channel, forceUpdate: false)
    }
    
    @discardableResult
    public func createOrUpdate(channel: Channel, forceUpdate: Bool) -> ChannelDTO {
        let (channelDTO, created) = ChannelDTO.fetchOrCreate(id: channel.id, context: self)
        return apply(channel: channel, to: channelDTO, created: created, forceUpdate: forceUpdate)
    }

    /// The local row a channel payload's `lastMessage` would overwrite, when that payload is the
    /// SDK's own cached copy of one of *our* sends rather than anything the server told us —
    /// meaning it must be ignored. `nil` means the payload is safe to apply.
    ///
    /// The SDK hands out a live reference to its local message cache here. Right after a send
    /// times out it flips that copy to `deliveryStatus == .failed` while leaving `id == 0`, and a
    /// channel-list page read a few milliseconds later carries it. Applying it runs
    /// `MessageDTO.map` over the row we created in `storePending` and downgrades `pending ->
    /// failed`, which is what raises the warning tick even though the message reached the
    /// receiver. Worse, `MessageDTO.fetchOrCreate` matches by tid and then assigns the incoming
    /// id, so an `id == 0` payload can also reset a row that had already been repaired.
    ///
    /// An outgoing message with no server id can only exist locally, so when we already hold that
    /// row there is nothing to learn from this payload: the row is resolved by the send ack, or by
    /// `PendingSendReconciler` once a marker proves the message landed. If we *don't* hold it, the
    /// write goes ahead as before so a message is never silently dropped.
    private func staleCachedLastMessageRow(_ message: Message, channelId: ChannelId) -> MessageDTO? {
        guard !message.incoming, message.id == 0, message.tid != 0 else { return nil }
        return MessageDTO.fetch(tid: Int64(message.tid), channelId: Int64(channelId), context: self)
    }

    /// Records a skip only when it prevented real damage — a row that already carries its server
    /// id would have had it zeroed. Skipping a payload for a row that is still `id == 0` is the
    /// routine case and says nothing worth logging.
    private func noteSkippedLastMessage(_ message: Message, row: MessageDTO, channelId: ChannelId, path: String) {
        guard row.id != 0 else { return }
        MessageSendTrace.log(
            "channel.lastMessage.clobberPrevented", tid: Int64(message.tid),
            channelId: channelId, messageId: MessageId(row.id),
            "path=\(path) \(MessageSendTrace.describe(dto: row)) \(MessageSendTrace.describe(ack: message))"
        )
    }

    @discardableResult
    private func apply(channel: Channel, to channelDTO: ChannelDTO, created: Bool, forceUpdate: Bool) -> ChannelDTO {
        let dto = channelDTO.map(channel)

        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfPendingMarkers(name: DefaultMarker.displayed.rawValue, in: dto))
        }

        if let createBy = channel.createdBy {
            dto.createdBy = createOrUpdate(user: createBy)
        }

        var lastReaction: ReactionDTO?
        if let reactions = channel.lastReactions {
            let reactionDTOs = createOrUpdate(reactions: reactions)
            lastReaction = reactionDTOs.max(by: { $0.id < $1.id })
            if dto.lastReaction == nil {
                dto.lastReaction = lastReaction
            } else if let lid = dto.lastReaction?.id,
                let nlid = lastReaction?.id,
                nlid != lid {
                dto.lastReaction = lastReaction
            }
        } else {
            dto.lastReaction = nil
        }

        if created || forceUpdate {
            if let message = channel.lastMessage {
                if let stale = staleCachedLastMessageRow(message, channelId: channel.id) {
                    noteSkippedLastMessage(message, row: stale, channelId: channel.id, path: "createOrUpdate")
                } else {
                    createOrUpdate(message: message, channelId: channel.id)
                }
            }
        }

        if let messages = channel.messages {
            createOrUpdate(messages: messages, channelId: channel.id)
        }

        if let members = channel.members {
            createOrUpdate(members: members, channelId: channel.id)
        }

        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }

        if let messagesClearedAt = channel.messagesClearedAt {
            try? deleteAllMessages(
                channelId: channel.id,
                before: messagesClearedAt
            )
        }
        return dto
    }

    @discardableResult
    public func createOrUpdateByURI(channel: Channel) -> ChannelDTO {
        let dto = (ChannelDTO.fetchChannelByURI(channel: ChatChannel(channel: channel), context: self) ?? (ChannelDTO.fetchOrCreate(id: channel.id, context: self)).0.map(channel))
        
        dto.id = Int64(channel.id)
        
        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfPendingMarkers(name: DefaultMarker.displayed.rawValue, in: dto))
        }
        if let createBy = channel.createdBy {
            dto.createdBy = createOrUpdate(user: createBy)
        }
        
        var lastReaction: ReactionDTO?
        if let reactions = channel.lastReactions {
            let reactionDTOs = createOrUpdate(reactions: reactions)
            lastReaction = reactionDTOs.max(by: { $0.id < $1.id })
            if dto.lastReaction == nil {
                dto.lastReaction = lastReaction
            } else if let lid = dto.lastReaction?.id,
                      let nlid = lastReaction?.id,
                      nlid != lid {
                dto.lastReaction = lastReaction
            }
        } else {
            dto.lastReaction = nil
        }
        
        
        if let message = channel.lastMessage {
            if let stale = staleCachedLastMessageRow(message, channelId: channel.id) {
                noteSkippedLastMessage(message, row: stale, channelId: channel.id, path: "update")
            } else {
                createOrUpdate(message: message, channelId: channel.id)
            }
        }
        
        if let messages = channel.messages {
            createOrUpdate(messages: messages, channelId: channel.id)
        }
        if let members = channel.members {
            createOrUpdate(members: members, channelId: channel.id)
        }
        
        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        if let messagesClearedAt = channel.messagesClearedAt {
            try? deleteAllMessages(
                channelId: channel.id,
                before: messagesClearedAt
            )
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(channel: ChatChannel) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channel.id, context: self).0.map(channel)
        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfPendingMarkers(name: DefaultMarker.displayed.rawValue, in: dto))
        }
        
        if let members = channel.members {
            for member in members {
                let mdto = createOrUpdate(member: member, channelId: channel.id)
                if mdto.channel !== dto {
                    mdto.channel = dto
                }
            }
        }
        
        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(channels: [Channel]) -> [ChannelDTO] {
        guard !channels.isEmpty else { return [] }

        let ids = channels.map { $0.id }
        var dtosById: [Int64: ChannelDTO] = Dictionary(
            uniqueKeysWithValues: ChannelDTO.fetch(ids: ids, context: self).map { ($0.id, $0) }
        )

        return channels.map { channel in
            let key = Int64(channel.id)
            if let existing = dtosById[key] {
                return apply(channel: channel, to: existing, created: false, forceUpdate: true)
            }
            let new = ChannelDTO.insertNewObject(into: self)
            new.id = key
            dtosById[key] = new
            return apply(channel: channel, to: new, created: true, forceUpdate: true)
        }
    }
    
    public func markAsRead(channelId: ChannelId) {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = .init(
            format: "channelId == %lld AND incoming == true AND (deliveryStatus == %d OR deliveryStatus == %d)",
            channelId,
            ChatMessage.DeliveryStatus.sent.intValue,
            ChatMessage.DeliveryStatus.received.intValue
        )
        MessageDTO.fetch(request: request, context: self)
            .forEach {
                $0.deliveryStatus = Int16(ChatMessage.DeliveryStatus.displayed.intValue)
            }
    }
    
    public func deleteChannel(id: ChannelId) {
        try? deleteAllMessages(channelId: id)
        ChannelSyncStateDTO.delete(channelId: id, context: self)
        DraftMessageDTO.delete(channelId: id, context: self)
        // Their messages are gone, so retrying these would only fail with `channelNotExists`.
        PendingMessageDeleteDTO.deleteAll(channelId: id, context: self)
        if let dto = ChannelDTO.fetch(id: id, context: self) {
            let deletedObjects: [AnyHashable: Any] = [
                NSDeletedObjectsKey: [dto.objectID]
            ]
            delete(dto)
            mergeChangesWithViewContext(fromRemoteContextSave: deletedObjects)
        }
    }
    
    @discardableResult
    public func add(members: [Member], channelId: ChannelId) -> ChannelDTO? {
        guard let dto = ChannelDTO.fetch(id: channelId, context: self)
        else { return nil }
        members.forEach { member in
            let memberDto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self).map(member)
            memberDto.user = createOrUpdate(user: member)
            memberDto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
        }
        
        return dto
    }
    
    @discardableResult
    public func update(owner: Member, channelId: ChannelId) -> ChannelDTO {
        let (dto, _) = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        dto.owner = MemberDTO.fetchOrCreate(id: owner.id, channelId: channelId, context: self)
        return dto
    }
    
    /// Realigns `MemberDTO.channel` with the ChannelDTO that `MemberDTO.channelId` names.
    ///
    /// A member row states its channel twice — in the `channelId` attribute and in the
    /// `channel` relationship — and nothing in Core Data keeps the two in sync. When they
    /// drift apart the channel the member really belongs to reports `members.@count == 0`,
    /// which hides direct channels from the channel list, while an unrelated channel
    /// reports members it doesn't own. `channelId` is the authoritative side: message rows,
    /// member lookups and channel search are all keyed by it.
    /// - Returns: the number of member rows that were relinked.
    @discardableResult
    public func repairMemberChannelLinks() -> Int {
        let request = MemberDTO.fetchRequest()
        request.fetchBatchSize = 500
        request.relationshipKeyPathsForPrefetching = [#keyPath(MemberDTO.channel)]
        let diverged = MemberDTO.fetch(request: request, context: self)
            .filter { $0.channel?.id != $0.channelId }
        guard !diverged.isEmpty else { return 0 }

        // Chunked so a badly drifted store doesn't build one enormous `id IN (…)`.
        var channelsById = [Int64: ChannelDTO]()
        let ids = Array(Set(diverged.compactMap { $0.channelId > 0 ? ChannelId($0.channelId) : nil }))
        for chunk in ids.chunked(into: 500) {
            for dto in ChannelDTO.fetch(ids: Array(chunk), context: self) {
                channelsById[dto.id] = dto
            }
        }

        var relinked = 0
        for member in diverged {
            // A row whose channel isn't in the store belongs to no local channel: nil is
            // the honest link, and leaving it pointing elsewhere corrupts that channel's
            // member count.
            let channel = channelsById[member.channelId]
            guard member.channel !== channel else { continue }
            member.channel = channel
            relinked += 1
        }
        return relinked
    }

    @discardableResult
    public func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self).map(member)
        dto.user = createOrUpdate(user: member)
        if !member.id.isEmpty {
            dto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
        } else {
            dto.role = nil
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(member: ChatChannelMember, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self)
        dto.user = createOrUpdate(user: member)
        if !member.id.isEmpty, let role = member.roleName {
            dto.role = RoleDTO.fetchOrCreate(name: role, context: self)
        } else {
            dto.role = nil
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO] {
        members.map { createOrUpdate(member: $0, channelId: channelId) }
    }
    
    public func delete(members: [Member], channelId: ChannelId) {
        guard let channel = ChannelDTO.fetch(id: channelId, context: self)
        else { return }
        let toDelete = members.compactMap {
            MemberDTO.fetch(id: $0.id, channelId: channelId, context: self)
        }
        toDelete
            .forEach {
                delete($0)
            }
    }
    
    public func deleteMember(id: UserId, from channelId: ChannelId) {
        if let member = MemberDTO.fetch(id: id, channelId: channelId, context: self) {
            delete(member)
        }
    }
    
    public func updateChannelDTOs(for userId: UserId) {
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: MemberDTO.entityName)
        fetchRequest.predicate = NSPredicate(format: "user.id == %@", userId)
        fetchRequest.propertiesToFetch = ["channelId"]
        fetchRequest.resultType = .dictionaryResultType
        
        if let results = MemberDTO.fetch(request: fetchRequest, context: self) as? [[String: Int64]] {
            let channelIds = results.compactMap { $0.values.first.map { ChannelId($0) }}
            let fetchRequest = ChannelDTO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(type == %@) AND (id IN %@)", SceytChatUIKit.shared.config.channelTypesConfig.direct, channelIds)
            let channels = ChannelDTO.fetch(request: fetchRequest, context: self)
            channels.forEach { dto in
                dto.toggle.toggle()
            }
        }
    }
    
    @discardableResult
    public func update(draft message: NSAttributedString?, date: Date? = nil, channelId: ChannelId) -> ChannelDTO? {
        let dto = ChannelDTO.fetch(id: channelId, context: self)
        dto?.draft = message
        dto?.draftDate = date?.bridgeDate
        // A plain-text draft has no attachments and no reply/edit target; leaving stale values
        // would preview "Draft: Image" or "Draft: Reply" for a draft that has neither.
        dto?.draftAttachmentType = nil
        dto?.draftActionType = nil
        return dto
    }

    public func draft(channelId: ChannelId) -> DraftMessage? {
        DraftMessageDTO.fetch(channelId: channelId, context: self)?.convert(context: self)
    }

    /// Persists the whole input-bar state, and mirrors the composed text into
    /// `ChannelDTO.draft`/`draftDate` so the channel list preview and `sortingKey` keep working
    /// without reaching across into the draft row.
    @discardableResult
    public func update(draft: DraftMessage, date: Date? = nil) -> ChannelDTO? {
        applyDraft(draft, date: date)
    }

    @discardableResult
    func applyDraft(_ draft: DraftMessage, date: Date?) -> ChannelDTO? {
        // No channel row means no draft. Without this guard a channelId-keyed side table would
        // collect rows for channels that do not exist — the same reason the Android DAO checks
        // `existsChannel` before inserting.
        guard let channel = ChannelDTO.fetch(id: draft.channelId, context: self) else { return nil }

        let body = draft.channelListBody
        channel.draft = body
        // The first attachment's type is all the list needs to render "Draft: Image"; it mirrors
        // how `ChannelLastMessageBodyFormatter` previews an attachment-only message.
        channel.draftAttachmentType = (draft.attachments.first ?? draft.voiceRecording)?.type.rawValue
        channel.draftActionType = draft.target.map { $0.isReply ? "reply" : "edit" }
        // Everything the cell can preview also sorts as a draft — including a bare reply target,
        // which shows as "Draft: Reply", so leaving it pending should surface the channel the same
        // way a typed draft does.
        let showsInList = body != nil
            || !draft.attachments.isEmpty
            || draft.voiceRecording != nil
            || draft.target != nil
        channel.draftDate = showsInList ? date?.bridgeDate : nil

        guard draft.hasContent else {
            channel.draftAttachmentType = nil
            channel.draftActionType = nil
            DraftMessageDTO.delete(channelId: draft.channelId, context: self)
            return channel
        }

        let dto = DraftMessageDTO.fetchOrCreate(channelId: draft.channelId, context: self)
        // Stored separately from `channel.draft`: while editing, the list previews the edit but the
        // draft row keeps the parked pre-edit text, which cancelling restores.
        dto.body = draft.normalizedBody
        dto.editBody = draft.editBody
        dto.createdAt = (draft.createdAt ?? date ?? Date()).bridgeDate
        dto.viewOnce = draft.viewOnce
        dto.isReply = draft.target?.isReply ?? false
        dto.targetMessageId = Int64(draft.target?.message.id ?? 0)
        dto.targetMessageTid = draft.target.map { Int64($0.message.tid) } ?? 0

        // Replaced wholesale rather than diffed: the strip is an ordered list, and a rewrite also
        // prunes rows whose files disappeared and were skipped on the last restore.
        DraftAttachmentDTO.deleteAll(channelId: draft.channelId, context: self)
        var rows = draft.attachments.enumerated().map { index, model -> DraftAttachmentDTO in
            let attachment = DraftAttachmentDTO.insertNewObject(into: self)
            attachment.map(model, channelId: draft.channelId, order: index)
            return attachment
        }
        if let recording = draft.voiceRecording {
            let attachment = DraftAttachmentDTO.insertNewObject(into: self)
            attachment.map(
                recording,
                channelId: draft.channelId,
                order: rows.count,
                isVoiceRecording: true
            )
            rows.append(attachment)
        }
        dto.attachments = Set(rows)
        return channel
    }
    
    internal func deleteMembers(predicate: NSPredicate) {
        // Must delete through the context, not NSBatchDeleteRequest: role rows
        // (RoleDTO) are shared across all channels, and a batch delete leaves
        // dangling references to the removed members in the materialized
        // RoleDTO.members inverse. The next save that touches that role then
        // traps in _forceRegisterLostFault (EXC_BREAKPOINT).
        let request = MemberDTO.fetchRequest()
        request.predicate = predicate
        MemberDTO.fetch(request: request, context: self)
            .forEach {
                delete($0)
            }
    }
    
    internal func numberOfPendingMarkers(name: String, in channel: ChannelDTO) -> Int64 {
        return 0;
        
        let predicate = NSPredicate(format: "pendingMarkerNames != nil")
            .and(predicate: .init(format: "(channelId == %lld", channel.id, channel.id))
        let count = MessageDTO.fetch(predicate: predicate, context: self).filter { message in
            message.pendingMarkerNames?.contains(name) == true
        }.count
        logger.debug("[MARKER CHECK] numberOfPendingMarkers (\(name)) count: \(count), from server \(channel.newMessageCount)")
        return Int64(count)
    }
}
