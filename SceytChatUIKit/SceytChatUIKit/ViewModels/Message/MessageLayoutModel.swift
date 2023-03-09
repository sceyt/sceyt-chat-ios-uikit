//
// MessageLayoutModel.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MessageLayoutModel {
    
    public static var defaults = Defaults()
    public static var appearance = MessageCell.appearance
    public static var textSizeCounter = TextSizeCounter()
    
    open var contentOptions = MessageContentOptions()
    open var updateOptions: MessageUpdateOptions = MessageUpdateOptions.all
    
    public private(set) var channel: ChatChannel
    public private(set) var message: ChatMessage
    public let userSendMessage: UserSendMessage?
    
    public var hasReactions: Bool {
        message.reactionScores?.isEmpty == false
    }
    public var hasReply: Bool {
        return message.parent != nil && message.repliedInThread == false
    }
    public var hasThreadReply: Bool {
        replyCount > 0
    }
    public var isForwarded: Bool {
        return message.forwardingDetails != nil
    }
    
    public private(set) var messageUserTitleSize: CGSize
    public private(set) var parentMessageUserTitleSize: CGSize
    public private(set) var textSize: CGSize
    public private(set) var parentTextSize: CGSize
    public private(set) var lastCharRect: CGRect
    public private(set) var replyCount = 0
    public private(set) var attachmentCount: AttachmentCount
    public private(set) var messageDeliveryStatus: ChatMessage.DeliveryStatus
    public private(set) var messageUserTitle: String
    public private(set) var parentMessageUserTitle: String
    public private(set) var attributedView: NSAttributedString
    public private(set) var parentAttributedView: NSAttributedString?
    public private(set) var reactions: [ReactionInfo]?
    public private(set) var links: [URL]
    public private(set) var linkPreviews: [LinkPreview]?
    public private(set) var reactionType: ReactionViewType = .withTotalScore
    public private(set) var estimatedReactionsNumberPerRow: Int = 0
    
    required public init(
        channel: ChatChannel,
        message: ChatMessage,
        userSendMessage: UserSendMessage? = nil,
        linkMentionedItem: Bool = true
    ) {
        
        links = []// LinkDetector.getLinks(text: message.body)
        self.channel = channel
        self.message = message
        messageDeliveryStatus = message.deliveryStatus
        replyCount = message.replyCount
        self.userSendMessage = userSendMessage
        let ac = Self.sortedAttachmentCounts(message: message)
        self.attachmentCount = AttachmentCount(
            numberOfImages: ac.images,
            numberOfFiles: ac.files,
            numberOfVoices: ac.voices
        )
        attributedView = Self.attributedView(
            message: message,
            userSendMessage: userSendMessage,
            deletedStateFont: Self.appearance.deletedMessageFont ?? Fonts.regularItalic.withSize(16),
            deletedStateColor: Self.appearance.deletedMessageColor ?? Colors.textGray,
            bodyFont: Self.appearance.messageFont ?? Fonts.regular.withSize(16),
            bodyColor: Self.appearance.messageColor ?? Colors.textBlack,
            linkColor: Self.appearance.linkColor ?? Colors.kitBlue,
            linkMentionedItem: linkMentionedItem
        )
        
        let size = Self.textSizeCounter.calculateSize(of: attributedView,
                                                      restrictingWidth: self.attachmentCount.isEmpty ? Self.defaults.messageWidth : Self.defaults.messageWithAttachmentWidth)
        messageUserTitle = Formatters.userDisplayName.format(message.user)
        if !message.incoming || !(channel.type.isGroup) {
            messageUserTitleSize = .zero
        } else {
            messageUserTitleSize = Self.textSizeCounter.calculateSize(
                of:
                    NSAttributedString(
                        string: messageUserTitle,
                        attributes: [.font: (Self.appearance.titleFont ?? Fonts.medium.withSize(12)) as Any]
                    ),
                restrictingWidth: Self.defaults.messageWidth
            ).textSize
        }
        
        if let parent = message.parent {
            parentMessageUserTitle = Formatters.userDisplayName.format(parent.user)
            parentMessageUserTitleSize = Self.textSizeCounter.calculateSize(
                of:
                    NSAttributedString(
                        string: parentMessageUserTitle,
                        attributes: [.font: (Self.appearance.titleFont ?? Fonts.medium.withSize(12)) as Any]
                    ),
                restrictingWidth: Self.defaults.messageWidth
            ).textSize
        } else {
            parentMessageUserTitle = ""
            parentMessageUserTitleSize = .zero
        }
        
        if let parent = message.parent {
            let parentAttributedView = Self.attributedView(
                message: parent,
                userSendMessage: userSendMessage,
                deletedStateFont: Self.appearance.deletedMessageFont ?? Fonts.regularItalic.withSize(16),
                deletedStateColor: Self.appearance.deletedMessageColor ?? Colors.textGray,
                bodyFont: Self.appearance.messageFont ?? Fonts.regular.withSize(16),
                bodyColor: Self.appearance.messageColor ?? Colors.textBlack,
                linkColor: Self.appearance.linkColor ?? Colors.kitBlue
            )
            let parentSize = Self.textSizeCounter.calculateSize(of: parentAttributedView,
                                                                restrictingWidth: self.attachmentCount.isEmpty ? Self.defaults.messageWidth : Self.defaults.messageWithAttachmentWidth)
            self.parentAttributedView = parentAttributedView
            parentTextSize = parentSize.textSize
        } else {
            parentTextSize = .zero
        }
        textSize = size.textSize
        lastCharRect = size.lastCharRect
        
        if textSize != .zero {
            contentOptions.insert(.text)
        }
        if messageUserTitleSize != .zero {
            contentOptions.insert(.name)
        }
        if attachmentCount.numberOfImages > 0 {
            contentOptions.insert(.image)
        }
        if attachmentCount.numberOfFiles > 0 {
            contentOptions.insert(.file)
        }
        if attachmentCount.numberOfVoices > 0 {
            contentOptions.insert(.voice)
        }
//        message.linkMetadatas?.forEach({
//            let link = LinkMetadata(
//                url: $0.url,
//                title: $0.title,
//                summary: $0.summary,
//                creator: $0.creator,
//                iconUrl: $0.iconUrl,
//                imageUrl: $0.imageUrl
//            )
//            link.loadImages()
//            addLinkPreview(linkMetadata: link)
//        })
//
        reactions = createReactions(message: message)
        if let reactions, !reactions.isEmpty {
            estimatedReactionsNumberPerRow = estimateReactionsNumberPerRow()
        }
    }
    
    @discardableResult
    open func update(
        channel: ChatChannel,
        message: ChatMessage) -> Bool {
            guard self.channel.id == channel.id,
                  ((self.message.id != 0 && self.message.id == message.id) ||
                   (self.message.id == 0 && self.message.tid == message.tid))
            else { return false }
            var updateOptions = MessageUpdateOptions()
            if messageDeliveryStatus != message.deliveryStatus {
                messageDeliveryStatus = message.deliveryStatus
                updateOptions.insert(.deliveryStatus)
            }
            if replyCount != message.replyCount {
                replyCount = message.replyCount
                updateOptions.insert(.replyCount)
            }
            if self.message.body != message.body || self.message.state != message.state {
                attributedView = Self.attributedView(
                    message: message,
                    userSendMessage: userSendMessage,
                    deletedStateFont: Self.appearance.deletedMessageFont ?? Fonts.regularItalic.withSize(16),
                    deletedStateColor: Self.appearance.deletedMessageColor ?? Colors.textGray,
                    bodyFont: Self.appearance.messageFont ?? Fonts.regular.withSize(16),
                    bodyColor: Self.appearance.messageColor ?? Colors.textBlack,
                    linkColor: Self.appearance.linkColor ?? Colors.kitBlue
                )
                let size = Self.textSizeCounter.calculateSize(of: attributedView,
                                                              restrictingWidth: self.attachmentCount.isEmpty ? Self.defaults.messageWidth : Self.defaults.messageWithAttachmentWidth)
                textSize = size.textSize
                lastCharRect = size.lastCharRect
                contentOptions.insert(.text)
                updateOptions.insert(.body)
            }
            let title = Formatters.userDisplayName.format(message.user)
            if messageUserTitle != title {
                messageUserTitle = title
                messageUserTitleSize = Self.textSizeCounter.calculateSize(
                    of:
                        NSAttributedString(
                            string: title,
                            attributes: [.font: (Self.appearance.titleFont ?? Fonts.medium.withSize(12)) as Any]
                        ),
                    restrictingWidth: Self.defaults.messageWidth
                ).textSize
                contentOptions.insert(.name)
                updateOptions.insert(.user)
            }
            
            if let parent = message.parent {
                let title = Formatters.userDisplayName.format(parent.user)
                if title != parentMessageUserTitle {
                    parentMessageUserTitle = Formatters.userDisplayName.format(parent.user)
                    parentMessageUserTitleSize = Self.textSizeCounter.calculateSize(
                        of:
                            NSAttributedString(
                                string: parentMessageUserTitle,
                                attributes: [.font: (Self.appearance.titleFont ?? Fonts.medium.withSize(12)) as Any]
                            ),
                        restrictingWidth: Self.defaults.messageWidth
                    ).textSize
                    updateOptions.insert(.parentMessageUser)
                }
                
                if self.message.parent?.body != message.parent?.body || self.message.parent?.state != message.parent?.state {
                    let parentAttributedView = Self.attributedView(
                        message: parent,
                        userSendMessage: userSendMessage,
                        deletedStateFont: Self.appearance.deletedMessageFont ?? Fonts.regularItalic.withSize(16),
                        deletedStateColor: Self.appearance.deletedMessageColor ?? Colors.textGray,
                        bodyFont: Self.appearance.messageFont ?? Fonts.regular.withSize(16),
                        bodyColor: Self.appearance.messageColor ?? Colors.textBlack,
                        linkColor: Self.appearance.linkColor ?? Colors.kitBlue
                    )
                    
                    let parentSize = Self.textSizeCounter.calculateSize(of: parentAttributedView,
                                                                        restrictingWidth: self.attachmentCount.isEmpty ? Self.defaults.messageWidth : Self.defaults.messageWithAttachmentWidth)
                    self.parentAttributedView = parentAttributedView
                    parentTextSize = parentSize.textSize
                    updateOptions.insert(.parentMessageBody)
                }
            }
            
            var hasUpdatesInAttachments = false
            if self.message.attachments?.count != message.attachments?.count {
                hasUpdatesInAttachments = true
            } else {
                let selfAttachments = self.message.attachments ?? []
                let newAttachments = message.attachments ?? []
                for item in zip(selfAttachments, newAttachments) {
                    if item.0.id != item.1.id ||
                        item.0.filePath != item.1.filePath ||
                        item.0.url != item.1.url ||
                        item.0.status != item.1.status {
                        hasUpdatesInAttachments = true
                        break
                    }
                }
            }
            
            if hasUpdatesInAttachments {
                let ac = Self.sortedAttachmentCounts(message: message)
                attachmentCount = AttachmentCount(
                    numberOfImages: ac.images,
                    numberOfFiles: ac.files,
                    numberOfVoices: ac.voices
                )
                sortedAttachments = getSortedAttachments(message: message)
                updateOptions.insert(.attachment)
            }
          
            if attachmentCount.numberOfImages > 0 {
                contentOptions.insert(.image)
            } else {
                contentOptions.remove(.image)
            }
            if attachmentCount.numberOfFiles > 0 {
                contentOptions.insert(.file)
            } else {
                contentOptions.remove(.file)
            }
            if attachmentCount.numberOfVoices > 0 {
                contentOptions.insert(.voice)
            } else {
                contentOptions.remove(.voice)
            }
            self.updateOptions = updateOptions
            self.channel = channel
            self.message = message
            let newReactions = createReactions(message: message)
            if newReactions != reactions {
                self.updateOptions.insert(.reaction)
                if !newReactions.isEmpty {
                    estimatedReactionsNumberPerRow = estimateReactionsNumberPerRow()
                }
            }
            reactions = newReactions
            return true
    }
    
    @discardableResult
    open func createReactions(message: ChatMessage) -> [ReactionInfo] {
        var selfReactions = message.selfReactions?.compactMap { me == $0.user.id ? $0.key : nil } ?? []
        var reactions = [ReactionInfo]()
        if let reactionScores = message.reactionScores, !reactionScores.isEmpty {
            var commonScore = 0
            reactions = reactionScores.map { rs in
                commonScore += rs.value
                let index = selfReactions.firstIndex(of: rs.key)
                if let index = index {
                    selfReactions.remove(at: index)
                }
                return .init(key: rs.key, score: UInt(rs.value), byMe: index != nil, width: 24)
            }.sorted(by: { $0.key > $1.key })
            if reactionType == .withTotalScore, commonScore > 1 {
                let key = "\(commonScore)"
                let width = key.size(withAttributes: [.font: MessageCell.appearance.reactionCommonScoreFont]).width
                reactions.append(.init(key: key, score: 0, byMe: false, isCommonScoreNumber: true, width: ceil(width)))
            }
        }
        return reactions
    }
    
    open func estimateReactionsNumberPerRow() -> Int {
        let width = max(
            textSize.width,
            attachmentCount.isEmpty ? Self.defaults.messageWidth : Self.defaults.messageWithAttachmentWidth
        )
        let emojiItemWidth = MessageCell.ReactionTotalView.Defaults.emojiWidth
        let insets = MessageCell.ReactionTotalView.Defaults.contentInsets
        let interItemSpacing = MessageCell.ReactionTotalView.Defaults.hInterItemSpacing
        let fitWidth = width - insets.left - insets.right
        var accumWidth: CGFloat = .zero
        
        var itemCount = 0
        repeat {
            accumWidth += emojiItemWidth + interItemSpacing
            itemCount += 1
        } while accumWidth < fitWidth

        return itemCount
    }
    
    open func getSortedAttachments(message: ChatMessage) -> [ChatMessage.Attachment]? {
        guard let attachments = message.attachments?.filter({ $0.type != "link" })
        else { return nil }
        return attachments.sorted { lh, rh in
            let ld = lh.type == "image" || lh.type == "video" ? 0 : 1
            let rd = rh.type == "image" || rh.type == "video" ? 0 : 1
            return ld < rd
        }
    }
    
    open class func sortedAttachmentCounts(message: ChatMessage) -> (images: Int, files: Int, voices: Int) {
        var images = 0, files = 0, voices = 0
        if let attachments = message.attachments {
            for attachment in attachments {
                switch attachment.type {
                case "image", "video":
                    images += 1
                case "voice":
                    voices += 1
                case "link":
                    continue
                default:
                    files += 1
                }
            }
        }
        return (images, files, voices)
    }
    
    open lazy var sortedAttachments: [ChatMessage.Attachment]? = {
        getSortedAttachments(message: message)
    }()
    
    open class func attributedView(message: ChatMessage,
                                   userSendMessage: UserSendMessage? = nil,
                                   multiLine: Bool = true,
                                   deletedStateFont: UIFont = Appearance.Fonts.regularItalic.withSize(16),
                                   deletedStateColor: UIColor = Appearance.Colors.textGray,
                                   bodyFont: UIFont = Appearance.Fonts.regular.withSize(16),
                                   bodyColor: UIColor = Appearance.Colors.textBlack,
                                   linkColor: UIColor = Appearance.Colors.kitBlue,
                                   linkMentionedItem: Bool = true
    ) -> NSAttributedString {
        let attributedView: NSAttributedString
        switch message.state {
        case .deleted:
            attributedView = NSAttributedString(string: L10n.Message.deleted,
                                                attributes: [.font: deletedStateFont,
                                                             .foregroundColor: deletedStateColor])
        default:
            let content = multiLine ? message.body : message.body.replacingOccurrences(of: "\n", with: " ")

            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: content,
                                                     attributes: [.font: bodyFont,
                                                                  .foregroundColor: bodyColor]))
            
            let mentionedUsers = message.mentionedUsers != nil ?
            message.mentionedUsers!.map { ($0.id, Formatters.userDisplayName.format($0)) } :
            userSendMessage?.mentionUsers
            if let mentionedUsers = mentionedUsers, mentionedUsers.count > 0,
               let metadata = message.metadata?.data(using: .utf8),
               let ranges = try? JSONDecoder().decode([UserId: MentionUserPos].self, from: metadata) {
                var lengths = 0
                for user in mentionedUsers.reversed() {
                    if let pos = ranges[user.id], pos.loc >= 0 {
                        var attributes: [NSAttributedString.Key : Any] = [.font: bodyFont as Any,
                                                                          .foregroundColor: linkColor,
                                                                          .customKey: user.id]
                        if linkMentionedItem {
                            attributes[.link] = Config.mentionUserURI + user.id
                        }
                        let mention = NSAttributedString(string: Config.mentionSymbol + user.displayName,
                                                         attributes: attributes)
                        guard text.length >= pos.loc + pos.len else {
                            debugPrint("Something wrong❗️❗️❗️", "body:", text.string, "mention:", mention.string, "pos:", pos.loc, pos.len, "user:", user.id)
                            continue
                        }
                        text.replaceCharacters(in: .init(location: pos.loc, length: pos.len), with: mention)
                        lengths += mention.length
                    }
                }
            }
            attributedView = text
            break
        }
        return attributedView
    }
    
    @discardableResult
    open func updateReactions(message: ChatMessage) -> Bool {
        guard self.message.id == message.id else { return false }
        self.message = message
        reactions = createReactions(message: message)
        return true
    }
    
    @discardableResult
    open func addLinkPreview(linkMetadata: LinkMetadata) -> Bool {
        let url = linkMetadata.url
        if let linkPreviews = linkPreviews,
           linkPreviews.contains(where: { $0.url == url}) {
            return false
        }
        var preview = LinkPreview(url: url, image: linkMetadata.image)
        if let description = linkMetadata.summary {
            let font = Fonts.regular.withSize(14)
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: description,
                                                     attributes: [.font: font, .foregroundColor: Appearance.Colors.textBlack]))
            preview.descriptionSize = Self.textSizeCounter
                .calculateSize(of: text,
                               restrictingWidth: Self.defaults.imageAttachmentSize.width,
                               maximumNumberOfLines: 3).textSize
            preview.description = text
        }
        if let title = linkMetadata.title {
            let font = Fonts.bold.withSize(16)
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: title,
                                                     attributes: [.font: font, .foregroundColor: Appearance.Colors.textBlack]))
            preview.titleSize = Self.textSizeCounter
                .calculateSize(of: text,
                               restrictingWidth: Self.defaults.imageAttachmentSize.width,
                               maximumNumberOfLines: 1).textSize
            preview.title = text
        }
        if linkPreviews == nil {
            linkPreviews = []
        }
        linkPreviews?.append(preview)
        if !contentOptions.contains(.link) {
            contentOptions.insert(.link)
        }
        return true
    }
    
    open func updateThreadReplyCount(message: Message) {
        replyCount = message.replyCount
    }
}

public extension MessageLayoutModel {
    
    struct MessageContentOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let name     = MessageContentOptions(rawValue: 1 << 0)
        public static let text     = MessageContentOptions(rawValue: 1 << 1)
        public static let image    = MessageContentOptions(rawValue: 1 << 2)
        public static let file     = MessageContentOptions(rawValue: 1 << 3)
        public static let link     = MessageContentOptions(rawValue: 1 << 4)
        public static let voice    = MessageContentOptions(rawValue: 1 << 5)

        public static let attachment: MessageContentOptions = [.image, .file, .voice]
        public static let all: MessageContentOptions = [.name, .text, .image, file, link, voice]
    }
    
    struct MessageUpdateOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let body                  = MessageUpdateOptions(rawValue: 1 << 0)
        public static let user                  = MessageUpdateOptions(rawValue: 1 << 1)
        public static let replyCount            = MessageUpdateOptions(rawValue: 1 << 2)
        public static let parentMessageUser     = MessageUpdateOptions(rawValue: 1 << 3)
        public static let parentMessageBody     = MessageUpdateOptions(rawValue: 1 << 4)
        public static let attachment            = MessageUpdateOptions(rawValue: 1 << 5)
        public static let deliveryStatus        = MessageUpdateOptions(rawValue: 1 << 6)
        public static let reaction              = MessageUpdateOptions(rawValue: 1 << 7)
        
        public static let all: MessageUpdateOptions = [.body, .user, .replyCount, parentMessageUser, .parentMessageBody, .attachment, deliveryStatus]
    }
    
    struct Defaults {
        public var messageWidth = 0.75 * UIScreen.main.bounds.width
        public var messageWithAttachmentWidth = CGFloat(244)
        public var messageSenderSize    = CGSize(width: 170, height: 18)
        public var imageAttachmentSize  = CGSize(width: 260, height: 200)
        public var fileAttachmentSize   = CGSize(width: CGFloat.infinity, height: 52)
        public var audioAttachmentSize  = CGSize(width: CGFloat.infinity, height: 54)
    }
    
    struct AttachmentCount {
        public let numberOfImages: Int
        public let numberOfFiles: Int
        public let numberOfVoices: Int

        public var isEmpty: Bool {
            numberOfImages == 0 && numberOfFiles == 0 && numberOfVoices == 0
        }
    }
    
    struct LinkPreview {
        public let url: URL
        public var image: UIImage?
        public var title: NSAttributedString?
        public var titleSize: CGSize = .zero
        public var description: NSAttributedString?
        public var descriptionSize: CGSize = .zero
    }

    struct ReactionInfo: Equatable {
        public let key: String
        public let score: UInt
        public let byMe: Bool
        public var isCommonScoreNumber = false
        public let width: CGFloat
    }

    enum ReactionViewType {
        case interactive
        case withTotalScore
    }

}
