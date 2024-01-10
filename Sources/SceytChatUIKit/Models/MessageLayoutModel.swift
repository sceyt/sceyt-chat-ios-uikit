//
//  MessageLayoutModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MessageLayoutModel {
    
    public static var defaults = Defaults()
    public static var appearance = MessageCell.appearance
    public static var textSizeMeasure = TextSizeMeasure.self
    
    open var contentOptions = MessageContentOptions()
    open var updateOptions: MessageUpdateOptions = []
    
    public private(set) var channel: ChatChannel
    public private(set) var message: ChatMessage
    public private(set) var attachments: [AttachmentLayout]
    public private(set) var linkAttachments: [AttachmentLayout]
    public private(set) var replyLayout: ReplyLayout?
    public private(set) var lastDisplayedMessageId: MessageId = 0
    
    public let userSendMessage: UserSendMessage?
    
    open var hasAttachments: Bool {
        !attachments.isEmpty
    }
    open var hasReactions: Bool {
        message.reactionScores?.isEmpty == false
    }
    open var hasReply: Bool {
        return message.parent != nil && message.repliedInThread == false
    }
    open var hasThreadReply: Bool {
        replyCount > 0
    }
    open var isForwarded: Bool {
        if message.state == .deleted { return false }
        
        guard let forwardingDetails = message.forwardingDetails else { return false }
        if let user = forwardingDetails.user, user.id == message.user.id {
            return false
        }
        return true
    }
    
    public private(set) var hasMediaAttachments: Bool = false
    public private(set) var hasFileAttachments: Bool = false
    public private(set) var hasVoiceAttachments: Bool = false
    public private(set) var showUserInfo: Bool = false
    public private(set) var messageUserTitleSize: CGSize = .zero
    public private(set) var parentMessageUserTitleSize: CGSize
    public private(set) var textSize: CGSize
    public private(set) var parentTextSize: CGSize
    public private(set) var infoViewMeasure: CGSize = .zero
    public private(set) var linkViewMeasure: CGSize = .zero
    public private(set) var lastCharRect: CGRect
    public private(set) var replyCount = 0
    public              var contentInsets: UIEdgeInsets = .zero
    public private(set) var messageDeliveryStatus: ChatMessage.DeliveryStatus
    public private(set) var messageUserTitle: String = ""
    public private(set) var parentMessageUserTitle: String
    public private(set) var attributedView: AttributedView
    public private(set) var parentAttributedView: AttributedView?
    public private(set) var reactions: [ReactionInfo]?
    public private(set) var groupedReactions: [ArraySlice<ReactionInfo>]?
    
    public private(set) var linkPreviews: [LinkPreview]?
    public private(set) var reactionType: ReactionViewType = .withTotalScore
    public private(set) var estimatedReactionsNumberPerRow: Int = 0
    
    public private(set) var attachmentsContainerSize: CGSize = .zero
    private var _measureSize: CGSize = .zero
    public private(set) var measureSize: CGSize {
        set(newValue) {
            _measureSize = newValue
        }
        get {
            CGSize(
                width: _measureSize.width + contentInsets.left + contentInsets.right,
                height: _measureSize.height + contentInsets.top + contentInsets.bottom)
        }
    }
    public var isLastDisplayedMessage: Bool {
        lastDisplayedMessageId != 0 && lastDisplayedMessageId == message.id
    }
    
    private static func restrictingWidth(attachments: [AttachmentLayout]) -> CGFloat {
        max(Self.defaults.messageWidth, attachments.map { $0.thumbnailSize.width }.max() ?? 0)
    }
    
    required public init(
        channel: ChatChannel,
        message: ChatMessage,
        userSendMessage: UserSendMessage? = nil,
        lastDisplayedMessageId: MessageId = 0
    ) {
        self.channel = channel
        self.message = message
        self.lastDisplayedMessageId = lastDisplayedMessageId
        messageDeliveryStatus = message.deliveryStatus
        replyCount = message.replyCount
        self.userSendMessage = userSendMessage
        attributedView = Self.attributedView(
            message: message,
            userSendMessage: userSendMessage
        )
        
        attachments = Self.attachmentLayout(message: message, channel: channel)
        linkAttachments = Self.linkAttachmentLayout(message: message, channel: channel)
        let restrictingTextWidth = Self.restrictingWidth(attachments: attachments) - 12 * 2
        
        let size = Self.textSizeMeasure
            .calculateSize(
                of: attributedView.content,
                config: .init(restrictingWidth: restrictingTextWidth))
        
        messageUserTitle = Formatters.userDisplayName.format(message.user)
        if !message.incoming ||
            channel.channelType == .direct ||
            channel.channelType == .broadcast {
            messageUserTitleSize = .zero
        } else {
            messageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: messageUserTitle,
                        attributes: [.font: (Self.appearance.titleFont ?? Fonts.bold.withSize(12)) as Any]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
        }
        
        if let parent = message.parent {
            let parentAttributedView = Self.attributedView(
                message: parent,
                userSendMessage: userSendMessage
            )
            let parentSize = Self.textSizeMeasure
                .calculateSize(
                    of: parentAttributedView.content,
                    config: .init(restrictingWidth: restrictingTextWidth))
            self.parentAttributedView = parentAttributedView
            parentTextSize = parentSize.textSize
            parentMessageUserTitle = Formatters.userDisplayName.format(parent.user)
            parentMessageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: parentMessageUserTitle,
                        attributes: [.font: (Self.appearance.titleFont ?? Fonts.bold.withSize(12)) as Any]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
            replyLayout = .init(
                message: parent,
                channel: channel,
                thumbnailSize: Self.defaults.imageRepliedAttachmentSize,
                attributedBody: parentAttributedView.content)
        } else {
            parentTextSize = .zero
            parentMessageUserTitle = ""
            parentMessageUserTitleSize = .zero
        }
        textSize = size.textSize
        lastCharRect = size.lastCharRect
        
        if textSize != .zero {
            contentOptions.insert(.text)
        }
        if messageUserTitleSize != .zero {
            contentOptions.insert(.name)
        }
        
        for attachment in attachments {
            switch attachment.type {
            case .image, .video:
                hasMediaAttachments = true
            case .voice:
                hasVoiceAttachments = true
            case .file:
                hasFileAttachments = true
            default:
                break
            }
        }
        if hasMediaAttachments {
            contentOptions.insert(.image)
        }
        if hasFileAttachments {
            contentOptions.insert(.file)
        }
        if hasVoiceAttachments {
            contentOptions.insert(.voice)
        }
        for link in Self.createLinkPreviews(message: message, linkAttachments: linkAttachments) {
            addLinkPreview(linkMetadata: link)
        }
       
        reactions = createReactions(message: message)
        attachmentsContainerSize = calculateAttachmentsContainerSize()
        if !isForwarded {
            if contentOptions.isEmpty || contentOptions == [.name] {
                let size = Self.textSizeMeasure
                    .calculateSize(
                        of: NSAttributedString(string: " "),
                        config: .init(restrictingWidth: restrictingTextWidth))
                contentOptions.insert(.text)
                textSize = size.textSize
            }
        }
        //        updateOptions.insert(.reload)
        measureSize = measure()
    }
    
    @discardableResult
    open func update(
        channel: ChatChannel,
        message: ChatMessage,
        force: Bool = false
    ) -> Bool {
        guard self.channel.id == channel.id,
              ((self.message.id != 0 && self.message.id == message.id) ||
               (self.message.id == 0 && self.message.tid == message.tid))
        else { return false }
        var updateOptions = self.updateOptions
        if messageDeliveryStatus != message.deliveryStatus {
            messageDeliveryStatus = message.deliveryStatus
            updateOptions.insert(.deliveryStatus)
        }
        if replyCount != message.replyCount {
            replyCount = message.replyCount
            updateOptions.insert(.replyCount)
        }
        var hasUpdatesInAttachments = false
        if self.message.attachments?.count != message.attachments?.count {
            hasUpdatesInAttachments = true
        } else {
            let selfAttachments = self.message.attachments ?? []
            let newAttachments = message.attachments ?? []
            for item in zip(selfAttachments, newAttachments) {
                if item.0.id != 0, item.0.id != item.1.id {// ||
                    //                        item.0.filePath != item.1.filePath ||
                    //                        item.0.url != item.1.url ||
                    //                        item.0.status != item.1.status {
                    hasUpdatesInAttachments = true
                    break
                }
            }
        }
        updateAttachmentLayouts(message: message)
        if hasUpdatesInAttachments {
            hasMediaAttachments = false
            hasVoiceAttachments = false
            hasFileAttachments = false
            for attachment in attachments {
                switch attachment.type {
                case .image, .video:
                    hasMediaAttachments = true
                case .voice:
                    hasVoiceAttachments = true
                case .file:
                    hasFileAttachments = true
                default:
                    break
                }
            }
            if hasMediaAttachments {
                contentOptions.insert(.image)
            } else {
                contentOptions.remove(.image)
            }
            if hasFileAttachments {
                contentOptions.insert(.file)
            } else {
                contentOptions.remove(.file)
            }
            if hasVoiceAttachments {
                contentOptions.insert(.voice)
            } else {
                contentOptions.remove(.voice)
            }
            if !attachments.isEmpty, !contentOptions.contains(.attachment) {
                updateOptions.insert(.attachment)
            }
        }
        
        let restrictingTextWidth = Self.restrictingWidth(attachments: attachments) - 12 * 2
        
        if force || self.message.body != message.body || self.message.state != message.state || self.message.bodyAttributes != message.bodyAttributes {
            attributedView = Self.attributedView(
                message: message,
                userSendMessage: userSendMessage
            )
            let size = Self.textSizeMeasure.calculateSize(of: attributedView.content,
                                                          config: .init(restrictingWidth: restrictingTextWidth))
            textSize = size.textSize
            lastCharRect = size.lastCharRect
            if textSize != .zero {
                contentOptions.insert(.text)
            }
            updateOptions.insert(.body)
        }
        let title = Formatters.userDisplayName.format(message.user)
        if !message.incoming ||
            channel.channelType == .direct ||
            channel.channelType == .broadcast {
            messageUserTitleSize = .zero
        } else if messageUserTitle != title {
            messageUserTitle = title
            messageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: title,
                        attributes: [.font: (Self.appearance.titleFont ?? Fonts.bold.withSize(12)) as Any]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
            contentOptions.insert(.name)
            updateOptions.insert(.user)
        }
        
        if messageUserTitleSize != .zero {
            contentOptions.insert(.name)
        }
        if self.message.user.avatarUrl != message.user.avatarUrl,
           !updateOptions.contains(.user) {
            updateOptions.insert(.user)
        }
        
        if let parent = message.parent {
            let title = Formatters.userDisplayName.format(parent.user)
            if title != parentMessageUserTitle {
                parentMessageUserTitle = Formatters.userDisplayName.format(parent.user)
                parentMessageUserTitleSize = Self.textSizeMeasure.calculateSize(
                    of:
                        NSAttributedString(
                            string: parentMessageUserTitle,
                            attributes: [.font: (Self.appearance.titleFont ?? Fonts.bold.withSize(12)) as Any]
                        ),
                    config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
                ).textSize
                updateOptions.insert(.parentMessageUser)
            }
            
            if force || self.message.parent?.body != message.parent?.body || self.message.parent?.state != message.parent?.state {
                let parentAttributedView = Self.attributedView(
                    message: parent,
                    userSendMessage: userSendMessage
                )
                
                let parentSize = Self.textSizeMeasure.calculateSize(of: parentAttributedView.content,
                                                                    config: .init(restrictingWidth: restrictingTextWidth))
                self.parentAttributedView = parentAttributedView
                parentTextSize = parentSize.textSize
                updateOptions.insert(.parentMessageBody)
            }
            replyLayout = .init(
                message: parent,
                channel: channel,
                thumbnailSize: Self.defaults.imageRepliedAttachmentSize,
                attributedBody: parentAttributedView?.content)
        } else {
            parentTextSize = .zero
            parentMessageUserTitle = ""
            parentMessageUserTitleSize = .zero
            parentAttributedView = nil
            replyLayout = nil
        }
        linkPreviews?.removeAll()
        for link in Self.createLinkPreviews(message: message, linkAttachments: linkAttachments) {
            addLinkPreview(linkMetadata: link)
            updateOptions.insert(.link)
        }
        
        var isUpdated = self.updateOptions != updateOptions
        self.updateOptions = updateOptions
        self.channel = channel
        self.message = message
        let newReactions = createReactions(message: message)
        if newReactions != reactions {
            isUpdated = true
            self.updateOptions.insert(.reaction)
        }
        reactions = newReactions
        attachmentsContainerSize = calculateAttachmentsContainerSize()
        if isUpdated || force {
            measureSize = measure()
        }
        return true
    }
    
    internal func replace(channel: ChatChannel) {
        self.channel = channel
    }
    
    open func updateMessageDeliveryStatus(_ deliveryStatus: ChatMessage.DeliveryStatus) {
        if messageDeliveryStatus != deliveryStatus {
            messageDeliveryStatus = deliveryStatus
            updateOptions.insert(.deliveryStatus)
        }
    }
    
    open func showUserInfo(_ show: Bool) {
        guard channel.isGroup
        else { return }
        if showUserInfo != show {
            if show,
               channel.channelType == .broadcast {
                // do not show
            } else {
                showUserInfo = show
                measureSize = measure()
                updateOptions.insert(.reload)
                if showUserInfo {
                    createMessageUserTitle()
                } else {
                    removeMessageUserTitle()
                }
            }
        }
    }
    
    private func createMessageUserTitle() {
        messageUserTitle = Formatters.userDisplayName.format(message.user)
        if !message.incoming ||
            channel.channelType == .direct ||
            channel.channelType == .broadcast {
            messageUserTitleSize = .zero
        } else {
            messageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: messageUserTitle,
                        attributes: [.font: (Self.appearance.titleFont ?? Fonts.bold.withSize(12)) as Any]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
        }
    }
    
    private func removeMessageUserTitle() {
        messageUserTitle = ""
        messageUserTitleSize = .zero
    }
    
    @discardableResult
    open func createReactions(message: ChatMessage) -> [ReactionInfo] {
        var selfReactions = message.userReactions?.compactMap { me == $0.user?.id ? $0.key : nil } ?? []
        var reactions = [ReactionInfo]()
        if let reactionScores = message.reactionScores, !reactionScores.isEmpty {
            estimatedReactionsNumberPerRow = estimateReactionsNumberPerRow()
            var commonScore = Int64(0)
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
                let width = key.size(withAttributes: [.font: Self.appearance.reactionCommonScoreFont]).width
                reactions.append(.init(key: key, score: 0, byMe: false, isCommonScoreNumber: true, width: ceil(width)))
            }
        } else {
            estimatedReactionsNumberPerRow = 0
        }
        if estimatedReactionsNumberPerRow != 0, !reactions.isEmpty {
            groupedReactions = reactions.chunked(into: estimatedReactionsNumberPerRow)
        }
        return reactions
    }
    
    open func estimateReactionsNumberPerRow() -> Int {
        let width = Self.defaults.messageWidth
        let emojiItemWidth = MessageCell.ReactionTotalView.Measure.emojiWidth
        let insets = MessageCell.ReactionTotalView.Measure.contentInsets
        let interItemSpacing = MessageCell.ReactionTotalView.Measure.itemSpacingH
        let fitWidth = width - insets.left - insets.right
        var accumWidth: CGFloat = .zero
        
        var itemCount = 0
        repeat {
            accumWidth += emojiItemWidth + interItemSpacing
            itemCount += 1
        } while accumWidth < fitWidth
        
        return itemCount
    }
    
    open class func attachmentLayout(message: ChatMessage, channel: ChatChannel) -> [AttachmentLayout] {
        (message.attachments?.compactMap {
            logger.verbose("[Attachment] attachmentLayout attachment \($0.description)")
            let layout = AttachmentLayout(attachment: $0, ownerMessage: message, ownerChannel: channel)
            return layout.type == .link ? nil : layout
        } ?? [])
        .sorted { lh, rh in
            let ld = lh.type == .image || lh.type == .video ? 0 : 1
            let rd = rh.type == .image || rh.type == .video ? 0 : 1
            return ld < rd
        }
    }
    
    open class func linkAttachmentLayout(message: ChatMessage, channel: ChatChannel) -> [AttachmentLayout] {
        (message.attachments?.compactMap {
            logger.verbose("[Attachment] attachmentLayout attachment \($0.description)")
            let layout = AttachmentLayout(attachment: $0, ownerMessage: message, ownerChannel: channel)
            return layout.type != .link ? nil : layout
        } ?? [])
    }
    
    open func updateAttachmentLayouts(message: ChatMessage) {
        attachments =
        (message.attachments?.compactMap { attachment in
            logger.verbose("[Attachment] attachmentLayout update attachment \(attachment.description)")
            if let index = attachments.firstIndex(where: { $0.attachment == attachment }) {
                attachments[index].update(attachment: attachment)
                return attachments[index]
            }
            let layout = AttachmentLayout(attachment: attachment, ownerMessage: message, ownerChannel: channel)
            return layout.type == .link ? nil : layout
        } ?? [])
        .sorted { lh, rh in
            let ld = lh.type == .image || lh.type == .video ? 0 : 1
            let rd = rh.type == .image || rh.type == .video ? 0 : 1
            return ld < rd
        }
        
        linkAttachments =
        (message.attachments?.compactMap { attachment in
            logger.verbose("[Attachment] link attachmentLayout update attachment \(attachment.description)")
            if let index = attachments.firstIndex(where: { $0.attachment == attachment }) {
                attachments[index].update(attachment: attachment)
                return attachments[index]
            }
            let layout = AttachmentLayout(attachment: attachment, ownerMessage: message, ownerChannel: channel)
            return layout.type != .link ? nil : layout
        } ?? [])
    }
    
    open class func attributedView(message: ChatMessage,
                                   userSendMessage: UserSendMessage? = nil,
                                   multiLine: Bool = true
    ) -> AttributedView {
        
        let deletedStateFont = appearance.deletedMessageFont ?? Fonts.regular.with(traits: .traitItalic).withSize(16)
        let deletedStateColor = appearance.deletedMessageColor ?? Colors.textGray
        let bodyFont = appearance.messageFont ?? Fonts.regular.withSize(16)
        let bodyColor = appearance.messageColor ?? Colors.textBlack
        let linkColor = appearance.linkColor ?? Colors.kitBlue
        let mentionColor = appearance.mentionUserColor ?? Colors.kitBlue
        
        switch message.state {
        case .deleted:
            return .init(content: NSAttributedString(string: L10n.Message.deleted,
                                                     attributes: [.font: deletedStateFont,
                                                                  .foregroundColor: deletedStateColor]))
        default:
            var content = multiLine ? message.body : message.body.replacingOccurrences(of: "\n", with: " ")
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { return .init(content: NSAttributedString()) }
            
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: content,
                                                     attributes: [.font: bodyFont,
                                                                  .foregroundColor: bodyColor]))
            
            var items = [ContentItem]()
            let matches = DataDetector.matches(text: content)
            for match in matches {
                let linkAttributes: [NSAttributedString.Key : Any] = [
                    NSAttributedString.Key.foregroundColor: linkColor,
                    NSAttributedString.Key.underlineColor: linkColor,
                    NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                text.addAttributes(linkAttributes, range: match.range)
                items.append(.link(match.range, match.url))
            }
            
            let mentionedUsers = message.mentionedUsers != nil ?
            message.mentionedUsers!.map { ($0.id, Formatters.userDisplayName.format($0)) } :
            userSendMessage?.mentionUsers
            if let mentionedUsers = mentionedUsers, mentionedUsers.count > 0,
               let metadata = message.metadata?.data(using: .utf8),
               let ranges = try? JSONDecoder().decode([MentionUserPos].self, from: metadata) {
                var lengths = 0
                for pos in ranges.reversed() {
                    if let user = mentionedUsers.last(where: { $0.0 == pos.id }), pos.loc >= 0 {
                        let attributes: [NSAttributedString.Key : Any] = [.font: bodyFont,
                                                                          .foregroundColor: mentionColor,
                                                                          .mention: pos.id]
                        let mention = NSAttributedString(string: Config.mentionSymbol + user.displayName,
                                                         attributes: attributes)
                        guard text.length >= pos.loc + pos.len else {
                            logger.error("Something wrong❗️❗️, body: \(text.string) mention: \(mention.string) pos: \(pos.loc), \(pos.len) user: \(pos.id)")
                            continue
                        }
                        text.safeReplaceCharacters(in: .init(location: pos.loc, length: pos.len), with: mention)
                        lengths += mention.length
                        items.append(.mention(.init(location: pos.loc, length: mention.length), pos.id))
                    }
                }
            }
            if let bodyAttributes = message.bodyAttributes {
                bodyAttributes.reduce([NSRange: [ChatMessage.BodyAttribute]]()) { partialResult, bodyAttribute in
                    let location = max(0, min(text.length - 1, bodyAttribute.offset))
                    let length = max(0, min(text.length - location, bodyAttribute.length))
                    let range = NSRange(location: location, length: length)
                    var array = partialResult[range] ?? []
                    array.append(bodyAttribute)
                    var partialResult = partialResult
                    partialResult[range] = array
                    return partialResult
                }
                .forEach { range, value in
                    var font = bodyFont
                    if value.contains(where: { $0.type == .monospace }) {
                        font = Formatters.font.toMonospace(font)
                    }
                    if value.contains(where: { $0.type == .bold }) {
                        font = Formatters.font.toBold(font)
                    }
                    if value.contains(where: { $0.type == .italic }) {
                        font = Formatters.font.toItalic(font)
                    }
                    if value.contains(where: { $0.type == .strikethrough }) {
                        text.addAttributes([.strikethroughStyle : NSUnderlineStyle.single.rawValue], range: range)
                    }
                    if value.contains(where: { $0.type == .underline }) {
                        text.addAttributes([.underlineStyle : NSUnderlineStyle.single.rawValue], range: range)
                    }
                    text.addAttributes([.font : font], range: range)
                }
                
                bodyAttributes
                    .filter { $0.type == .mention }
                    .sorted(by: { $0.offset > $1.offset })
                    .forEach { bodyAttribute in
                        let location = max(0, min(text.length - 1, bodyAttribute.offset))
                        let length = max(0, min(text.length - location, bodyAttribute.length))
                        let range = NSRange(location: location, length: length)
                        if
                            let userId = bodyAttribute.metadata,
                            let user = message.mentionedUsers?.first(where: { $0.id == userId }) {
                            var attributes = text.attributes(at: range.location, effectiveRange: nil)
                            attributes[.foregroundColor] = mentionColor
                            attributes[.mention] = userId
                            let mention = NSAttributedString(string: Config.mentionSymbol + user.displayName,
                                                             attributes: attributes)
                            text.safeReplaceCharacters(in: range, with: mention)
                            items.append(.mention(.init(location: bodyAttribute.offset, length: mention.length), userId))
                        }
                    }
            }
            return .init(content: text, items: items)
        }
    }
    
    open class func createLinkPreviews(message: ChatMessage, linkAttachments: [AttachmentLayout]) -> [LinkMetadata] {
        var attachments = linkAttachments
        var linkMetadatas = [LinkMetadata]()
        if let links = message.linkMetadatas, !links.isEmpty {
            linkMetadatas += links.map { data in
                var image: UIImage? = nil
                if !attachments.isEmpty, let firstIndex = attachments.firstIndex(where: { $0.attachment.url == data.url.absoluteString }) {
                    let first = attachments[firstIndex]
                    image = first.thumbnail ?? first.attachment.imageDecodedMetadata?.thumbnailImage
                    attachments.remove(at: firstIndex)
                }
                
                let link = LinkMetadata(
                    isThumbnailData: image != nil,
                    url: data.url,
                    title: data.title,
                    summary: data.summary,
                    creator: data.creator,
                    iconUrl: data.iconUrl,
                    image: image,
                    imageUrl: data.imageUrl
                    
                )
                return link
            }
        }
        if !attachments.isEmpty {
            for attachment in attachments where attachment.attachment.imageDecodedMetadata != nil {
                if let metadata = attachment.attachment.imageDecodedMetadata, 
                    let urlString = attachment.attachment.url,
                   let url = URL(string: urlString) {
                    let isImage = metadata.width > 0 && metadata.height > 0 && metadata.thumbnailImage != nil
                    let isText = (metadata.description?.count ?? 0) > 0
                    var isTitle: Bool {
                        if !isImage, !isText, (attachment.attachment.name?.count ?? 0) > 0 {
                            return true
                        }
                        return false
                    }
                    if isText || isImage || isTitle {
                        let link = LinkMetadata(
                            isThumbnailData: true,
                            url: url,
                            title: attachment.attachment.name,
                            summary: metadata.description,
                            image: metadata.thumbnailImage,
                            imageOriginalSize: CGSize(width: metadata.width, height: metadata.height)
                        )
                        linkMetadatas.append(link)
                    }
                }
            }
        }
       
        return linkMetadatas
    }
    
    @discardableResult
    open func addLinkPreview(linkMetadata: LinkMetadata) -> Bool {
        let url = linkMetadata.url
        if let linkPreviews = linkPreviews,
           linkPreviews.contains(where: { $0.url == url && $0.image == linkMetadata.image && $0.icon == linkMetadata.icon}) {
            return false
        }

        linkMetadata.loadImages()
        var preview = LinkPreview(url: url, isThumbnailData: linkMetadata.isThumbnailData, image: linkMetadata.image, icon: linkMetadata.icon)
        preview.metadata = linkMetadata
        preview.imageOriginalSize = linkMetadata.imageOriginalSize
        preview.iconOriginalSize = linkMetadata.iconOriginalSize
        if let description = linkMetadata.summary {
            let font = Self.appearance.linkDescriptionFont ?? Fonts.regular.withSize(13)
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: description,
                                                     attributes:
                                                        [.font: font,
                                                         .foregroundColor: Self.appearance.linkDescriptionColor ?? Appearance.Colors.textBlack
                                                        ])
            )
            
            preview.descriptionSize = Self.textSizeMeasure
                .calculateSize(of: text,
                               config: .init(restrictingWidth: Self.defaults.imageAttachmentSize.width - 16,
                                             maximumNumberOfLines: 2)).textSize
            preview.description = text
        }
        if let title = linkMetadata.title {
            let font = Self.appearance.linkTitleFont ?? Fonts.semiBold.withSize(14)
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: title,
                                                     attributes: [.font: font, .foregroundColor: Self.appearance.linkTitleColor ?? Appearance.Colors.textBlack]))
            preview.titleSize = Self.textSizeMeasure
                .calculateSize(of: text,
                               config: .init(restrictingWidth: Self.defaults.imageAttachmentSize.width - 16,
                                             maximumNumberOfLines: 1)).textSize
            preview.title = text
        }
        if linkPreviews == nil {
            linkPreviews = []
        }
        if let index = linkPreviews?.firstIndex(where: { $0.url == preview.url}) {
            linkPreviews?[index] = preview
        } else {
            linkPreviews?.append(preview)
        }
       
        if !(contentOptions.contains(.link) || contentOptions.contains(.file) || contentOptions.contains(.image) || contentOptions.contains(.voice)) {
            contentOptions.insert(.link)
        }
        return true
    }
    
    open func updateThreadReplyCount(message: Message) {
        replyCount = message.replyCount
    }
    
    open func measure() -> CGSize {
        infoViewMeasure = MessageCell.InfoView.measure(model: self, appearance: Self.appearance)
        linkViewMeasure = MessageCell.LinkStackView.measure(model: self, appearance: Self.appearance)
        if message.incoming {
            return Components.incomingMessageCell.measure(model: self, appearance: Self.appearance)
        } else {
            return Components.outgoingMessageCell.measure(model: self, appearance: Self.appearance)
        }
    }
    
    private func calculateAttachmentsContainerSize() -> CGSize {
        guard !attachments.isEmpty
        else { return .zero }
        
        var size = CGSize.zero
        for attachment in attachments {
            size.width = max(size.width, attachment.thumbnailSize.width)
            size.height += attachment.thumbnailSize.height
        }
        size.height += CGFloat(4 * (attachments.count - 1))
        return size
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
        public static let link                  = MessageUpdateOptions(rawValue: 1 << 8)
        public static let reload                = MessageUpdateOptions(rawValue: 1 << 9)
        
        public static let all: MessageUpdateOptions = [.body, .user, .replyCount, parentMessageUser, .parentMessageBody, .attachment, .link, deliveryStatus]
    }
    
    struct Defaults {
        public var messageWidthRatio: CGFloat = 0.75
        public internal(set) lazy var messageWidth: CGFloat = floor(messageWidthRatio * UIScreen.main.bounds.width)
        public var messageSenderNameWidth = CGFloat(170)
        public var imageAttachmentSize  = CGSize(width: 260, height: 200)
        public var imageRepliedAttachmentSize  = CGSize(width: 40, height: 40)
        public var fileAttachmentSize   = CGSize(width: CGFloat.infinity, height: 54)
        public var audioAttachmentSize  = CGSize(width: CGFloat.infinity, height: 54)
    }
    
    struct LinkPreview {
        public let url: URL
        public let isThumbnailData: Bool
        public var image: UIImage?
        public var icon: UIImage?
        public var title: NSAttributedString?
        public var titleSize: CGSize = .zero
        public var description: NSAttributedString?
        public var descriptionSize: CGSize = .zero
        public var imageOriginalSize: CGSize?
        public var iconOriginalSize: CGSize?
        public var metadata: LinkMetadata?
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
    
    enum ContentItem {
        case link(NSRange, URL?)
        case mention(NSRange, String)
        
        var range: NSRange {
            switch self {
            case let .link(range, _),
                let .mention(range, _):
                return range
            }
        }
        
        var url: URL? {
            switch self {
            case let .link(_, url):
                return url
            default:
                return nil
            }
        }
    }
    
    struct AttributedView {
        public let content: NSAttributedString
        public let items: [ContentItem]
        
        public init(content: NSAttributedString, items: [ContentItem] = []) {
            self.content = content
            self.items = items
        }
    }
}

extension MessageLayoutModel {
    
    open class AttachmentLayout {
        public private(set) var attachment: ChatMessage.Attachment
        public private(set) var ownerMessage: ChatMessage?
        public private(set) var ownerChannel: ChatChannel?
        public var thumbnail: UIImage?
        public var thumbnailSize: CGSize = .zero
        public var voiceWaveform: [Float]?
        public var type: AttachmentType {
            .init(rawValue: attachment.type) ?? .file
        }
        
        public var transferStatus: ChatMessage.Attachment.TransferStatus {
            attachment.status
        }
        
        open var mediaDuration: TimeInterval {
            switch type {
            case .image, .video:
                return TimeInterval(attachment.imageDecodedMetadata?.duration ?? 0)
            case .voice:
                return TimeInterval(attachment.voiceDecodedMetadata?.duration ?? 0)
            default:
                return 0
            }
        }
        
        open var name: String {
            attachment.name ?? ((attachment.url ?? attachment.filePath) as NSString?)?.lastPathComponent ?? ""
        }
        
        open var fileSize: String {
            let fileSize: UInt
            if attachment.uploadedFileSize > 0 {
                fileSize = attachment.uploadedFileSize
            } else if let filePath = attachment.filePath {
                fileSize = Components.storage.sizeOfItem(at: filePath)
            } else {
                fileSize = 0
            }
            return Formatters.fileSize.format(fileSize)
        }
        
        @Atomic private var isLoadedThumbnail: Bool = false
        public var onLoadThumbnail: ((UIImage?) -> Void)? {
            didSet {
                if isLoadedThumbnail {
                    onLoadThumbnail?(thumbnail)
                }
            }
        }
        
        @Atomic private var isThumbnailLoadedFromFile = false
        
        public init(
            attachment: ChatMessage.Attachment,
            ownerMessage: ChatMessage?,
            ownerChannel: ChatChannel?,
            thumbnailSize: CGSize? = nil,
            onLoadThumbnail: ((UIImage?) -> Void)? = nil,
            asyncLoadThumbnail: Bool = false
        ) {
            self.attachment = attachment
            self.ownerMessage = ownerMessage
            self.ownerChannel = ownerChannel
            self.thumbnailSize = thumbnailSize ?? calculateAttachmentsContainerSize()
            self.onLoadThumbnail = onLoadThumbnail
            if asyncLoadThumbnail {
                DispatchQueue.global(qos: .userInteractive)
                    .async { [weak self] in
                        self?.loadThumbnail()
                    }
            } else {
                loadThumbnail()
            }
        }
        
        open func loadThumbnail() {
            defer {
                isLoadedThumbnail = true
                if let onLoadThumbnail {
                    DispatchQueue.main.async { [weak self] in
                        onLoadThumbnail(self?.thumbnail)
                    }
                }
            }
            switch type {
            case .voice:
                thumbnail = .replyVoice
                voiceWaveform = attachment.voiceDecodedMetadata?.thumbnail.map { Float($0) }
            case .image, .video:
                if let path = fileProvider.thumbnailFile(for: attachment, preferred: thumbnailSize) {
                    logger.verbose("[Attachment]  thumbnail load from filePath \(attachment.description)")
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                        thumbnail = UIImage(data: data)
                        isThumbnailLoadedFromFile = true
                    } catch {
                        logger.errorIfNotNil(error, "load image from path \(path)")
                    }
                }
                if thumbnail == nil {
                    let metadata = attachment.imageDecodedMetadata
                    logger.verbose("[Attachment] thumbnail is nil make from metadata \(attachment.description)")
                    if let data = metadata?.thumbnailImage {
                        thumbnail = data
                    } else if let base64 = metadata?.thumbnail,
                              let image = Components.imageBuilder.image(thumbHash: base64) {
                        thumbnail = image
                    } else {
                        thumbnail = nil
                    }
                }
            case .file:
                if let path = fileProvider.thumbnailFile(for: attachment, preferred: thumbnailSize) {
                    logger.verbose("[Attachment]  thumbnail load from filePath \(attachment.description)")
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                        thumbnail = UIImage(data: data)
                        isThumbnailLoadedFromFile = true
                    } catch {
                        logger.errorIfNotNil(error, "load image from path \(path)")
                    }
                }
                if thumbnail == nil {
                    thumbnail = .replyFile
                }
            case .link:
                if thumbnail == nil {
                    let metadata = attachment.imageDecodedMetadata
                    if let data = metadata?.thumbnailImage {
                        thumbnail = data
                    } else if let base64 = metadata?.thumbnail,
                              let image = Components.imageBuilder.image(thumbHash: base64) {
                        thumbnail = image
                    } else {
                        thumbnail = nil
                    }
                }
            default:
                break
            }
        }
        
        open func update(attachment: ChatMessage.Attachment) {
            self.attachment = attachment
            if !isThumbnailLoadedFromFile {
                isLoadedThumbnail = false
                loadThumbnail()
            }
        }
        
        @discardableResult
        open func updateMessageIfNeeded(ownerMessage: ChatMessage) -> Bool {
            if self.ownerMessage == nil,
               self.attachment.messageId == ownerMessage.id {
                self.ownerMessage = ownerMessage
                return true
            }
            return false
        }
        
        private func calculateAttachmentsContainerSize() -> CGSize {
            let defaults = Components.messageLayoutModel.defaults
            var size = CGSize(
                width: defaults.imageAttachmentSize.width,
                height: 0
            )
            
            switch type {
            case .image, .video:
                if let data = attachment.imageDecodedMetadata,
                   data.width > 0,
                   data.height > 0 {
                    let thumbnailSize = CGSize(width: data.width, height: data.height)
                    size = preferredImageSize(
                        maxSize: defaults.imageAttachmentSize.width,
                        imageSize: thumbnailSize,
                        minSize: type == .video ? 120 : nil)
                } else {
                    size = defaults.imageAttachmentSize
                }
                
            case .file:
                size.height = defaults.fileAttachmentSize.height
                var config = TextSizeMeasure.Config()
                config.maximumNumberOfLines = 1
                config.font = MessageCell.appearance.attachmentFileNameFont
                let nameWidth = TextSizeMeasure.calculateSize(
                    of: name,
                    config: config).textSize.width
                config.font = MessageCell.appearance.attachmentFileSizeFont
                var sizeWidth = TextSizeMeasure.calculateSize(
                    of: "\(fileSize) • \(fileSize)",
                    config: config).textSize.width
                if let ownerChannel, let ownerMessage {
                    sizeWidth += MessageCell.InfoView.measure(channel: ownerChannel, message: ownerMessage, appearance: MessageCell.appearance).width
                }
                size.width = min(size.width, max(nameWidth, sizeWidth) + MessageCell.Layouts.attachmentIconSize + MessageCell.Layouts.horizontalPadding * 3)
            case .voice:
                size.height = defaults.audioAttachmentSize.height
            case .link:
                break
            }
            return size
        }
        
        private func preferredImageSize(maxSize: CGFloat, imageSize: CGSize, minSize: CGFloat? = nil) -> CGSize {
            let coefficient = imageSize.width / imageSize.height
            var scaleWidth = maxSize
            var scaleHeight = maxSize
            
            if !coefficient.isNaN, coefficient != 1 {
                var _minSize = maxSize / 3.0
                if let minSize {
                    _minSize = max(_minSize, minSize)
                }
                if (imageSize.width > imageSize.height) {
                    let height = maxSize / coefficient
                    scaleHeight = height >= _minSize ? height : _minSize
                } else {
                    let futureW = maxSize * coefficient
                    let coefficientWidth = futureW / maxSize
                    var preferredMaxSize = maxSize
                    
                    if coefficientWidth <= 0.8 {
                        preferredMaxSize = maxSize * 1.2
                    }
                    
                    let width = preferredMaxSize * coefficient
                    scaleWidth = width >= _minSize ? width : _minSize
                    scaleHeight = preferredMaxSize
                }
            }
            return CGSize(width: scaleWidth, height: scaleHeight)
        }
    }
}

public extension MessageLayoutModel.AttachmentLayout {
    
    enum AttachmentType: String {
        case image
        case video
        case voice
        case link
        case file
    }
}

extension MessageLayoutModel.AttachmentLayout: Equatable, Hashable {
    
    public static func == (lhs: MessageLayoutModel.AttachmentLayout, rhs: MessageLayoutModel.AttachmentLayout) -> Bool {
        lhs.attachment == rhs.attachment
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(attachment)
    }
}

extension MessageLayoutModel {
    
    open class ReplyLayout {
        
        public let message: ChatMessage
        public let thumbnailSize: CGSize?
        public var attributedBody = NSAttributedString()
        public private(set) var attachment: AttachmentLayout?
        public var user: ChatUser {
            message.user
        }
        open var icon: UIImage?
        
        public init(
            message: ChatMessage,
            channel: ChatChannel,
            thumbnailSize: CGSize?,
            attributedBody: NSAttributedString? = nil) {
                self.message = message
                self.thumbnailSize = thumbnailSize
                if let attachment = message.attachments?.first {
                    self.attachment = .init(
                        attachment: attachment,
                        ownerMessage: message,
                        ownerChannel: channel,
                        thumbnailSize: thumbnailSize ?? MessageCell.ReplyView.Measure.imageSize)
                }
                if let attributedBody, attributedBody.length > 0 {
                    let attributedBody = attributedBody.mutableCopy() as! NSMutableAttributedString
                    attributedBody.enumerateAttributes(in: NSRange(location: 0, length: attributedBody.length), using: { attributes, range, _ in
                        var attributes = attributes
                        attributes[.font] = (attributes[.font] as? UIFont)?.withSize(appearance.replyMessageFont?.pointSize ?? 14)
                        attributedBody.setAttributes(attributes, range: range)
                    })
                    self.attributedBody = attributedBody
                } else {
                    self.attributedBody = makeBody()
                }
                icon = makeIcon()
            }
        
        public func updateAttachment(message: ChatMessage) {
            guard self.message == message
            else { return }
            if let attachment = message.attachments?.first {
                self.attachment = .init(
                    attachment: attachment,
                    ownerMessage: message,
                    ownerChannel: self.attachment?.ownerChannel,
                    thumbnailSize: thumbnailSize ?? MessageCell.ReplyView.Measure.imageSize)
            }
        }
        
        open func makeBody() -> NSAttributedString {
            var body = message.body
            switch message.state {
            case .deleted:
                body = L10n.Message.deleted
            default:
                if body.isEmpty,
                   let attachment = message.attachments?.first {
                    switch AttachmentLayout.AttachmentType(rawValue: attachment.type) {
                    case .image:
                        body = L10n.Message.Attachment.image
                    case .video:
                        body = L10n.Message.Attachment.video
                    case .voice:
                        let body = NSMutableAttributedString(string: L10n.Message.Attachment.voice, attributes: [
                            .font: appearance.replyMessageFont as Any,
                            .foregroundColor: appearance.replyMessageColor as Any
                        ])
                        body.append(.init(string: " \(Formatters.videoAssetDuration.format(Double(attachment.voiceDecodedMetadata?.duration ?? 0)))", attributes: [
                            .font: appearance.replyMessageFont as Any,
                            .foregroundColor: appearance.replyMessageVoiceDurationColor as Any
                        ]))
                        return body
                    default:
                        body = L10n.Message.Attachment.file
                    }
                }
            }
            return .init(string: body, attributes: [
                .font: appearance.replyMessageFont as Any,
                .foregroundColor: appearance.replyMessageColor as Any
            ])
        }
        
        open func makeIcon() -> UIImage? {
            if let attachment = message.attachments?.first {
                switch attachment.type {
                case "voice":
                    break
                default:
                    break
                }
            }
            return nil
            
        }
    }
}

extension MessageLayoutModel: Hashable, Equatable {
    
    public static func == (lhs: MessageLayoutModel, rhs: MessageLayoutModel) -> Bool {
        lhs.message == rhs.message
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(message)
    }
    
}

extension MessageLayoutModel: Comparable {
    
    public static func < (lhs: MessageLayoutModel, rhs: MessageLayoutModel) -> Bool {
        lhs.message < rhs.message
    }
}
