//
//  ChatMessage+BodyAttribute.swift
//  SceytChatUIKit
//
//  Created by Duc on 17/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

typealias AttributeType = ChatMessage.BodyAttribute.AttributeType

public extension ChatMessage {
    struct BodyAttribute: Equatable {
        public let offset: Int
        public let length: Int
        public let type: AttributeType
        public let metadata: String?
        
        public init(offset: Int, length: Int, type: AttributeType, metadata: String? = nil) {
            self.offset = offset
            self.length = length
            self.type = type
            self.metadata = metadata
        }
        
        public init(dto: BodyAttributeDTO) {
            self.offset = dto.offset
            self.length = dto.length
            self.type = AttributeType(rawValue: dto.type) ?? .none
            self.metadata = dto.metadata
        }
        
        public init(bodyAttribute: Message.BodyAttribute) {
            self.offset = bodyAttribute.offset
            self.length = bodyAttribute.length
            self.type = AttributeType(rawValue: bodyAttribute.type) ?? .none
            self.metadata = bodyAttribute.metadata
        }
        
        public enum AttributeType: String {
            case none
            case bold
            case italic
            case monospace
            case strikethrough
            case underline
            case mention
            
            public var string: String {
                switch self {
                case .bold: return "Bold"
                case .italic: return "Italic"
                case .monospace: return "Monospace"
                case .strikethrough: return "Strikethrough"
                case .underline: return "Underline"
                default: return ""
                }
            }
            
        }
    }
}
