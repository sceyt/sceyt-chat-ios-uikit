//
//  NotificationPayload.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 08.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

struct NotificationPayload {
    
    struct Message: Decodable {
        let id: String
        let parentId: String?
        let body: String
        let type: String
        let metadata: String
        let createdAt: String
        let updatedAt: String
        let state: String
        let deliveryStatus: String
        let transient: Bool
        let attachments: [Attachment]?
        let forwardingDetails: ForwardingDetails?
        let mentionedUsers: [User]?
        
        enum CodingKeys: String, CodingKey {
            case id, body, type, metadata, state, transient, attachments, mentionedUsers
            case parentId = "parent_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deliveryStatus = "delivery_status"
            case forwardingDetails = "forwarding_details"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            parentId = try? values.decode(String.self, forKey: .parentId)
            body = try values.decode(String.self, forKey: .body)
            type = try values.decode(String.self, forKey: .type)
            metadata = try values.decode(String.self, forKey: .metadata)
            createdAt = try values.decode(String.self, forKey: .createdAt)
            updatedAt = try values.decode(String.self, forKey: .updatedAt)
            state = try values.decode(String.self, forKey: .state)
            deliveryStatus = try values.decode(String.self, forKey: .deliveryStatus)
            transient = try values.decode(Bool.self, forKey: .transient)
            attachments = try values.decodeIfPresent([Attachment].self, forKey: .attachments)
            forwardingDetails = try? values.decodeIfPresent(ForwardingDetails.self, forKey: .forwardingDetails)
            let mentionedUsers = try? values.decodeIfPresent([User].self, forKey: .mentionedUsers)
            if let mentionedUsers {
                self.mentionedUsers = mentionedUsers
            } else {
                if let data = metadata.data(using: .utf8),
                   let usersPos = try? JSONDecoder().decode([MentionUserPos].self, from: data) {
                    let user = ChatClient.shared.user
                    let me = me
                    self.mentionedUsers = usersPos.map {
                        if $0.id == me {
                            return .init(
                                id: $0.id,
                                firstName: user.firstName ?? "",
                                lastName: user.lastName ?? "",
                                username: user.username ?? "",
                                metadataDict: user.metadataMap ?? [:],
                                presenceStatus: user.presence.status ?? "")
                        }
                        return .init(
                            id: $0.id,
                            firstName: "",
                            lastName: "",
                            username: "",
                            metadataDict: [:],
                            presenceStatus: "")
                    }
                } else {
                    self.mentionedUsers = nil
                }
            }
        }
        
        init(
            id: String,
            parentId: String?,
            body: String,
            type: String,
            metadata: String,
            createdAt: String,
            updatedAt: String,
            state: String,
            deliveryStatus: String,
            transient: Bool,
            attachments: [Attachment] = [],
            forwardingDetails: ForwardingDetails? = nil,
            mentionedUsers: [User]? = nil
        ) {
            self.id = id
            self.parentId = parentId
            self.body = body
            self.type = type
            self.metadata = metadata
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.state = state
            self.deliveryStatus = deliveryStatus
            self.transient = transient
            self.attachments = attachments
            self.forwardingDetails = forwardingDetails
            self.mentionedUsers = mentionedUsers;
        }
        
        struct Attachment: Codable {
            let data: String
            let type: String
            let name: String?
            let metadata: String?
            let size: Int?
        }
        
        struct ForwardingDetails: Codable {
            let channelId: String
            let messageId: String
            let hops: Int
            let userId: String
            
            enum CodingKeys: String, CodingKey {
                case channelId = "channel_id"
                case messageId = "message_id"
                case userId = "user_id"
                case hops
            }
        }
    }
    
    struct Channel: Decodable {
        let id: String
        let type: String
        let uri: String
        let subject: String
        let label: String
        let metadata: String
        let membersCount: Int64
        
        enum CodingKeys: String, CodingKey {
            case id, type, uri, subject, label, metadata
            case membersCount = "members_count"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            type = try values.decode(String.self, forKey: .type)
            uri = try values.decode(String.self, forKey: .uri)
            subject = try values.decode(String.self, forKey: .subject)
            label = try values.decode(String.self, forKey: .label)
            metadata = try values.decode(String.self, forKey: .metadata)
            membersCount = try values.decode(Int64.self, forKey: .membersCount)
        }
        
        init(
            id: String,
            type: String,
            uri: String,
            subject: String,
            label: String,
            metadata: String,
            membersCount: Int64)
        {
            self.id = id
            self.type = type
            self.uri = uri
            self.subject = subject
            self.label = label
            self.metadata = metadata
            self.membersCount = membersCount
        }
    }
    
    struct User: Decodable {
        let id: String
        let firstName: String
        let lastName: String
        let username: String
        let metadataDict: [String: String]
        let presenceStatus: String
        
        var displayName: String {
            [firstName, lastName].joined(separator: " ")
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case metadataDict = "metadata_map"
            case firstName = "first_name"
            case lastName = "last_name"
            case username
            case presenceStatus = "presence_status"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            firstName = try values.decode(String.self, forKey: .firstName)
            lastName = try values.decode(String.self, forKey: .lastName)
            username = try values.decode(String.self, forKey: .username)
            metadataDict = try values.decode([String: String].self, forKey: .metadataDict)
            presenceStatus = try values.decode(String.self, forKey: .presenceStatus)
        }
        
        init(
            id: String,
            firstName: String,
            lastName: String,
            username: String,
            metadataDict: [String: String],
            presenceStatus: String)
        {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.username = username
            self.metadataDict = metadataDict
            self.presenceStatus = presenceStatus
        }
    }
    
    struct Reaction: Decodable {
        let key: String
        let score: Int
        let reason: String
        let createdAt: Double
        
        enum CodingKeys: String, CodingKey {
            case key, score, reason
            case createdAt = "created_at"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            key = try values.decode(String.self, forKey: .key)
            score = try values.decode(Int.self, forKey: .score)
            reason = try values.decode(String.self, forKey: .reason)
            createdAt = try values.decode(Double.self, forKey: .createdAt)
        }
        
        init(
            key: String,
            score: Int,
            reason: String,
            createdAt: Double)
        {
            self.key = key
            self.score = score
            self.reason = reason
            self.createdAt = createdAt
        }
    }
    
    var message: Message?
    var channel: Channel?
    var user: User?
    var reaction: Reaction?
    var userInfo: [AnyHashable: Any]?
    
    init(from userInfo: [AnyHashable: Any]) throws {
        self.userInfo = userInfo
        guard let data = userInfo["data"] as? [AnyHashable: Any]
        else { return }
        if let string = data["message"] as? String,
           let data = string.data(using: .utf8) {
            message = try JSONDecoder().decode(Message.self, from: data)
        }
        
        if let string = data["channel"] as? String,
           let data = string.data(using: .utf8) {
            channel = try JSONDecoder().decode(Channel.self, from: data)
        }
        
        if let string = data["user"] as? String,
           let data = string.data(using: .utf8) {
            user = try JSONDecoder().decode(User.self, from: data)
        }
        
        if let string = data["reaction"] as? String,
           let data = string.data(using: .utf8) {
            reaction = try JSONDecoder().decode(Reaction.self, from: data)
        }
    }
}
