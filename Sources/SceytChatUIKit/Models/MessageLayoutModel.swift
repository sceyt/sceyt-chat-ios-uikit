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

    /// Effectively immutable after `init` — and it must stay that way. It is a struct holding
    /// fonts, colors and formatters, so copying it retains a dozen objects; if anything ever
    /// wrote to it after construction it would need the same `stateLock` treatment as the
    /// properties below. Nothing in the SDK or the host app assigns it outside `init`.
    public var appearance: MessageCell.Appearance
    public static var textSizeMeasure = TextSizeMeasure.self
    
    open var contentOptions = MessageContentOptions()
    open var updateOptions: MessageUpdateOptions = []

    /// Monotonic content token, bumped whenever a render-affecting field changes
    /// in place (the same condition that recomputes `measureSize`). The snapshot
    /// diff reads this to reconfigure a cell whose *content* changed — without
    /// relying on observer-emitted reload hints. See ChannelViewController+SnapshotDiff.
    public private(set) var contentVersion: UInt = 0

    /// Everything guarded by `stateLock` below holds refcounted storage and is written on the
    /// CoreData private queue — LazyDatabaseObserver.didChangeObjects → reload(dto:) → the mapper
    /// closure in ChannelViewModel.createMessageObserver() → createLayoutModel(for:force:), which
    /// returns the *cached* model and calls update(channel:message:force:) on it in place — while
    /// the main thread reads the same instance to bind cells (ChannelViewController.onEvent →
    /// reconfigureItems → cellForItemAt → MessageCell.bind).
    ///
    /// ARC reads a strong property as two non-atomic steps: load the pointer, then retain it. The
    /// writer's store releases the old value. When that release drops the last reference between
    /// the reader's load and its retain, the reader retains an object already inside
    /// swift_deallocClassInstance and the runtime aborts with "deallocated with non-zero retain
    /// count" — a SIGABRT with no lastExceptionBacktrace. Assigning to a local *inside* the lock
    /// makes the load+retain atomic against the store+release, which is also inside the lock.
    /// Same fix, and same reason, as `AttachmentLayout.attachment` further down this file.
    ///
    /// One lock for the whole model: each critical section is a load plus a retain, so contention
    /// between the two queues is negligible, and `update()` touches these in natural groups
    /// (attachments+linkAttachments, reactions+groupedReactions) — leaving room to widen a
    /// critical section over a pair later without introducing a lock-ordering hazard. Recursive
    /// because no accessor nests inside another *today*, and the cost of a future one that does
    /// would be a deadlocked CoreData queue in production, i.e. a frozen chat screen.
    ///
    /// What this does NOT buy: a logically consistent snapshot. `update()` publishes these one at
    /// a time, so a concurrent bind can see the new `attachments` beside the old `contentOptions`
    /// or `measureSize`. Those are cosmetic and self-correcting — `update()` bumps
    /// `contentVersion` and the snapshot diff reconfigures the cell on the next main-thread hop.
    /// The POD properties (CGSize/CGRect/Bool/OptionSet) are deliberately left unguarded for the
    /// same reason: a torn read there costs one frame at a wrong height, not memory safety.
    /// Note in particular that `updateOptions` has a main-thread writer of its own —
    /// MessageCell.bind() ends with `data.updateOptions = []` — racing update()'s
    /// read-modify-write here; a lost update means an occasional missed reconfigure. Pre-existing,
    /// cosmetic, and out of scope for the crash fix.
    private let stateLock = NSRecursiveLock()

    private var _channel: ChatChannel
    public private(set) var channel: ChatChannel {
        get {
            // Assign to a local under the lock so the ARC retain of the returned value happens
            // before the unlock — the optimizer must not sink it past the release side.
            var v: ChatChannel!
            stateLock.lock()
            v = _channel
            stateLock.unlock()
            return v!
        }
        set {
            stateLock.lock()
            _channel = newValue
            stateLock.unlock()
        }
    }

    private var _message: ChatMessage
    public private(set) var message: ChatMessage {
        get {
            var v: ChatMessage!
            stateLock.lock()
            v = _message
            stateLock.unlock()
            return v!
        }
        set {
            stateLock.lock()
            _message = newValue
            stateLock.unlock()
        }
    }

    private var _attachments: [AttachmentLayout] = []
    public private(set) var attachments: [AttachmentLayout] {
        get {
            var v: [AttachmentLayout] = []
            stateLock.lock()
            v = _attachments
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _attachments = newValue
            stateLock.unlock()
        }
    }

    private var _linkAttachments: [AttachmentLayout] = []
    public private(set) var linkAttachments: [AttachmentLayout] {
        get {
            var v: [AttachmentLayout] = []
            stateLock.lock()
            v = _linkAttachments
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _linkAttachments = newValue
            stateLock.unlock()
        }
    }

    private var _replyLayout: ReplyLayout?
    public private(set) var replyLayout: ReplyLayout? {
        get {
            var v: ReplyLayout?
            stateLock.lock()
            v = _replyLayout
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _replyLayout = newValue
            stateLock.unlock()
        }
    }

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
    
    open var hasPoll: Bool {
        return message.poll != nil && message.type == "poll" && message.state != .deleted
    }

    open var isSystemMessage: Bool {
        return message.type == "system" && message.state != .deleted
    }

    public private(set) var hasMediaAttachments: Bool = false
    public private(set) var hasFileAttachments: Bool = false
    public private(set) var hasVoiceAttachments: Bool = false
    public private(set) var showUserInfo: Bool = false
    public private(set) var messageUserTitleSize: CGSize = .zero
    public private(set) var parentMessageUserTitleSize: CGSize = .zero
    public private(set) var textSize: CGSize = .zero
    public private(set) var truncatedTextSize: CGSize = .zero
    public private(set) var parentTextSize: CGSize = .zero
    public var isTextExpanded: Bool = false
    public var shouldShowReadMore: Bool = false
    public private(set) var readMoreButtonHeight: CGFloat = 0

    /// Determines if the read more button should be displayed
    /// Returns true only if the message has long text that should be truncated,
    /// is not currently expanded, and is not deleted
    public var shouldDisplayReadMoreButton: Bool {
        shouldShowReadMore && !isTextExpanded && message.state != .deleted && !message.isViewOnceMessage
    }
    public private(set) var infoViewMeasure: CGSize = .zero
    /// The pin state `infoViewMeasure` was taken for. The pin beside the timestamp lives
    /// inside that row, so a measure taken while the message was unpinned is the pin's
    /// width plus its spacing too narrow.
    ///
    /// Compared against the message itself on every update rather than only diffing the
    /// incoming message against the previous one: a pin can be installed by a path that
    /// leaves the measure behind, and from then on the diff reads as "no change" forever —
    /// the row stays short until the channel is reopened.
    private var measuredPinState = false

    /// The message state `infoViewMeasure` was taken for.
    ///
    /// The "edited" mark lives in the same row as the pin and the timestamp, so a measure
    /// taken while the message was unedited is the mark's width plus its spacing too narrow —
    /// and one taken while it *was* edited is that much too wide, which the bubble spends on
    /// an empty gap in front of the pin.
    ///
    /// Tracked against the message itself for the same reason as `measuredPinState`:
    /// `updateOptions` accumulates until a cell binds, so once `.body` is in the set a later
    /// state change diffs as "no change" and the row keeps the width it measured for the
    /// state before it.
    private var measuredMessageState: ChatMessage.State = .none

    /// The system-message text `systemMessageMeasure` was calculated for.
    ///
    /// A system row renders from its PARENT — an "X pinned: …" row shows the pinned
    /// message's body — so editing that parent changes this row's text, and with it the
    /// number of lines it needs. Tracked separately for the same reason
    /// `measuredPinState` is: `updateOptions` accumulates across updates, so once
    /// `.parentMessageBody` is in the set a later edit diffs as "no change" and the row
    /// keeps the height it measured for the old text.
    private var _measuredSystemMessageText: String?
    private var measuredSystemMessageText: String? {
        get {
            var v: String?
            stateLock.lock()
            v = _measuredSystemMessageText
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _measuredSystemMessageText = newValue
            stateLock.unlock()
        }
    }
    public private(set) var linkViewMeasure: CGSize = .zero
    public private(set) var pollViewMeasure: CGSize = .zero
    public private(set) var systemMessageMeasure: CGSize = .zero
    public private(set) var unsupportedViewMeasure: CGSize = .zero
    public private(set) var lastCharRect: CGRect = .zero
    public private(set) var replyCount = 0
    public var contentInsets: UIEdgeInsets = .zero {
        didSet {
            if oldValue != contentInsets {
                contentVersion &+= 1
            }
        }
    }
    public private(set) var messageDeliveryStatus: ChatMessage.DeliveryStatus = .pending
    private var _messageUserTitle: String = ""
    public private(set) var messageUserTitle: String {
        get {
            var v = ""
            stateLock.lock()
            v = _messageUserTitle
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _messageUserTitle = newValue
            stateLock.unlock()
        }
    }

    private var _parentMessageUserTitle: String = ""
    public private(set) var parentMessageUserTitle: String {
        get {
            var v = ""
            stateLock.lock()
            v = _parentMessageUserTitle
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _parentMessageUserTitle = newValue
            stateLock.unlock()
        }
    }

    private var _attributedView: AttributedView = .init(content: NSAttributedString())
    public private(set) var attributedView: AttributedView {
        get {
            var v: AttributedView!
            stateLock.lock()
            v = _attributedView
            stateLock.unlock()
            return v!
        }
        set {
            stateLock.lock()
            _attributedView = newValue
            stateLock.unlock()
        }
    }

    private var _parentAttributedView: AttributedView?
    public private(set) var parentAttributedView: AttributedView? {
        get {
            var v: AttributedView?
            stateLock.lock()
            v = _parentAttributedView
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _parentAttributedView = newValue
            stateLock.unlock()
        }
    }

    private var _reactions: [ReactionInfo]?
    public private(set) var reactions: [ReactionInfo]? {
        get {
            var v: [ReactionInfo]?
            stateLock.lock()
            v = _reactions
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _reactions = newValue
            stateLock.unlock()
        }
    }

    private var _groupedReactions: [ArraySlice<ReactionInfo>]?
    public private(set) var groupedReactions: [ArraySlice<ReactionInfo>]? {
        get {
            var v: [ArraySlice<ReactionInfo>]?
            stateLock.lock()
            v = _groupedReactions
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _groupedReactions = newValue
            stateLock.unlock()
        }
    }

    private var _linkPreviews: [LinkPreview]?
    public private(set) var linkPreviews: [LinkPreview]? {
        get {
            var v: [LinkPreview]?
            stateLock.lock()
            v = _linkPreviews
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _linkPreviews = newValue
            stateLock.unlock()
        }
    }
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
        lastDisplayedMessageId: MessageId = 0,
        appearance: MessageCell.Appearance
    ) {
        // These four are the only stored properties without a default, so assigning them makes
        // `self` fully initialized — everything below can then go through the guarded accessors
        // unchanged. `channel`/`message` write their backing storage directly because a computed
        // setter is not callable until initialization completes.
        self.appearance = appearance
        self.userSendMessage = userSendMessage
        _channel = channel
        _message = message

        self.lastDisplayedMessageId = lastDisplayedMessageId
        messageDeliveryStatus = message.deliveryStatus
        replyCount = message.replyCount
        attributedView = Self.attributedView(
            message: message,
            userSendMessage: userSendMessage,
            appearance: appearance
        )
        
        attachments = Self.attachmentLayout(message: message, channel: channel, appearance: appearance)
        linkAttachments = Self.linkAttachmentLayout(message: message, channel: channel, appearance: appearance)
        let restrictingTextWidth = Self.restrictingWidth(attachments: attachments) - 12 * 2
        
        let size = Self.textSizeMeasure
            .calculateSize(
                of: attributedView.content,
                config: .init(restrictingWidth: restrictingTextWidth))
        
        messageUserTitle = appearance.senderNameFormatter.format(message.user)
        if !message.incoming ||
            channel.channelType == .direct ||
            channel.channelType == .broadcast {
            messageUserTitleSize = .zero
        } else {
            messageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: messageUserTitle,
                        attributes: [
                            .font: appearance.senderNameLabelAppearance.font
                        ]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
        }
        
        if let parent = message.parent {
            let parentAttributedView = Self.attributedView(
                message: parent,
                userSendMessage: userSendMessage,
                appearance: appearance
            )
            let parentSize = Self.textSizeMeasure
                .calculateSize(
                    of: parentAttributedView.content,
                    config: .init(restrictingWidth: restrictingTextWidth))
            self.parentAttributedView = parentAttributedView
            parentTextSize = parentSize.textSize
            parentMessageUserTitle = appearance.replyMessageAppearance.senderNameFormatter.format(parent.user)
            parentMessageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: parentMessageUserTitle,
                        attributes: [
                            .font: appearance.replyMessageAppearance.titleLabelAppearance.font
                        ]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
            replyLayout = Components.messageReplyLayoutModel.init(
                message: parent,
                byMe: message.user.id == SceytChatUIKit.shared.currentUserId,
                channel: channel,
                thumbnailSize: Self.defaults.imageRepliedAttachmentSize,
                attributedBody: parentAttributedView.content,
                appearance: appearance)
        } else {
            parentTextSize = .zero
            parentMessageUserTitle = ""
            parentMessageUserTitleSize = .zero
        }
        textSize = size.textSize
        lastCharRect = size.lastCharRect

        // Calculate truncated text size and read more button height
        let content = attributedView.content
        let textLength = content.string.count
        if message.state == .deleted {
            isTextExpanded = false
            shouldShowReadMore = false
            truncatedTextSize = .zero
            readMoreButtonHeight = 0
        } else {
            if textLength > appearance.collapsedCharacterLimit {
                let truncatedString = String(content.string.prefix(appearance.collapsedCharacterLimit))
                let mutableAttributed = NSMutableAttributedString(attributedString: content)
                mutableAttributed.mutableString.setString(truncatedString)

                let truncatedSize = Self.textSizeMeasure.calculateSize(
                    of: mutableAttributed,
                    config: .init(restrictingWidth: restrictingTextWidth))
                truncatedTextSize = truncatedSize.textSize

                // Only show read more if truncation actually results in different height
                // This prevents showing "Read More" when text fits without visual truncation
                if truncatedTextSize.height < textSize.height {
                    shouldShowReadMore = true
                    // Calculate read more button height (font line height + padding)
                    let buttonFont = appearance.readMoreButtonAppearance.font
                    readMoreButtonHeight = buttonFont.lineHeight + 8 // 8 = top(4) + bottom(4) padding
                } else {
                    shouldShowReadMore = false
                    readMoreButtonHeight = 0
                }
            } else {
                shouldShowReadMore = false
                truncatedTextSize = .zero
                readMoreButtonHeight = 0
            }
        }

        if textSize != .zero {
            contentOptions.insert(.text)
        }
        if messageUserTitleSize != .zero {
            contentOptions.insert(.name)
        }

        // Hide text for viewOnce messages, but NOT if message has been opened (we want to show "Message self-destructed")
        if message.isViewOnceMessage && (message.attachments?.count ?? 0) == 1 && !message.hasOpenedMarker {
            contentOptions.remove(.text)
            textSize = .zero
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
        if hasPoll {
            contentOptions.insert(.poll)
        }
        if isSystemMessage {
            contentOptions.insert(.system)
            // System messages don't have attachments, links, or polls
            contentOptions.remove(.text)
            contentOptions.remove(.image)
            contentOptions.remove(.file)
            contentOptions.remove(.voice)
            contentOptions.remove(.link)
            contentOptions.remove(.poll)
            textSize = .zero
        }

        // Check if message is unsupported
        if Self.isMessageUnsupported(message) && message.state != .deleted {
            contentOptions.insert(.unsupported)
            contentOptions.remove(.text)
            contentOptions.remove(.image)
            contentOptions.remove(.file)
            contentOptions.remove(.voice)
            contentOptions.remove(.link)
            contentOptions.remove(.poll)
            textSize = .zero
        }

        if message.hasOpenedMarker {
            contentOptions.remove(.image)
            contentOptions.remove(.file)
            contentOptions.remove(.voice)
            contentOptions.remove(.link)
            contentOptions.remove(.poll)
        }
        
        if attachments.isEmpty {
            for link in Self.createLinkPreviews(message: message, linkAttachments: linkAttachments) {
                addLinkPreview(linkMetadata: link)
            }
        }

        reactions = createReactions(message: message)
        updateAttachmentRowMetrics()
        attachmentsContainerSize = calculateAttachmentsContainerSize()
        if !isForwarded && !contentOptions.contains(.unsupported) {
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
        // The pin beside the timestamp is part of the info view, so a pin/unpin changes
        // both what it renders and how wide it measures. Without this the cached
        // `infoViewMeasure` keeps the old width and the cell is never reconfigured.
        let didChangePinState = self.message.isPinned != message.isPinned
            || measuredPinState != message.isPinned
        if didChangePinState {
            updateOptions.insert(.pin)
        }
        // The "edited" mark shares the info row with the pin, so the same reasoning applies:
        // compare against what was last *measured*, not only against the previous message.
        let didChangeMessageState = self.message.state != message.state
            || measuredMessageState != message.state
        if didChangeMessageState {
            updateOptions.insert(.body)
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

        // The message just turned into a deleted one: it renders as the
        // "Message was deleted." text and nothing else. Clearing `attachments`
        // above is not enough — the content options set when the message still had
        // its media survives (the attachment comparison only reacts to a changed
        // *count*, and a stale relationship can report the same one). Left in, the
        // cell picks the text+attachment layout branch and lays the old thumbnail
        // out under the deleted text until the channel is reopened.
        if message.state == .deleted {
            hasMediaAttachments = false
            hasFileAttachments = false
            hasVoiceAttachments = false
            let staleContent: MessageContentOptions = [.attachment, .link, .unsupported]
            if !contentOptions.isDisjoint(with: staleContent) {
                contentOptions.subtract(staleContent)
                updateOptions.insert(.reload)
            }
            linkPreviews?.removeAll()
        }

        let restrictingTextWidth = Self.restrictingWidth(attachments: attachments) - 12 * 2
        
        var isEqualMentionedUsers: Bool {
            if self.message.mentionedUsers != message.mentionedUsers {
                return false
            }
            if let currentMentionedUsers = self.message.mentionedUsers, 
                let updatedMentionedUsers = message.mentionedUsers {
                var group = [UserId: ChatUser]()
                currentMentionedUsers.forEach { group[$0.id] = $0 }
                for user in updatedMentionedUsers {
                    if let currentUser = group[user.id] {
                        if currentUser.firstName != user.firstName || currentUser.lastName != user.lastName {
                            return false
                        }
                        
                    } else {
                        return false
                    }
                }
            }
            return true
        }
        
        if force ||
            self.message.body != message.body ||
            self.message.state != message.state ||
            self.message.bodyAttributes != message.bodyAttributes ||
            self.message.hasOpenedMarker != message.hasOpenedMarker ||
            !isEqualMentionedUsers {
            attributedView = Self.attributedView(
                message: message,
                userSendMessage: userSendMessage,
                appearance: appearance
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

        // Handle poll state changes
        let hasNewPoll = message.poll != nil && message.type == "poll" && message.state != .deleted
        if hasNewPoll {
            if !contentOptions.contains(.poll) {
                contentOptions.insert(.poll)
                updateOptions.insert(.poll)
            }
            // Check if poll data changed (votes, votesPerOption, closed state)
            if let currentPoll = self.message.poll, let newPoll = message.poll {
                if currentPoll.votesPerOption != newPoll.votesPerOption ||
                   currentPoll.votes.count != newPoll.votes.count ||
                   currentPoll.ownVotes.count != newPoll.ownVotes.count ||
                   currentPoll.closed != newPoll.closed {
                    updateOptions.insert(.poll)
                }
            }
        } else {
            if contentOptions.contains(.poll) {
                contentOptions.remove(.poll)
                updateOptions.insert(.poll)
            }
        }
        let title = appearance.senderNameFormatter.format(message.user)
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
                        attributes: [
                            .font: appearance.senderNameLabelAppearance.font
                        ]
                    ),
                config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
            ).textSize
            contentOptions.insert(.name)
            updateOptions.insert(.user)
        }
        
        if messageUserTitleSize != .zero {
            contentOptions.insert(.name)
        }

        // Hide text for viewOnce messages, but NOT if message has been opened (we want to show "Message self-destructed")
        if message.isViewOnceMessage && (message.attachments?.count ?? 0) == 1 && !message.hasOpenedMarker {
            contentOptions.remove(.text)
            textSize = .zero
        }

        if self.message.user.avatarUrl != message.user.avatarUrl,
           !updateOptions.contains(.user) {
            updateOptions.insert(.user)
        }
        
        let prevHasReply = self.message.parent != nil && self.message.repliedInThread == false
        let newHasReply = message.parent != nil && message.repliedInThread == false

        if let parent = message.parent {
            let title = appearance.senderNameFormatter.format(parent.user)
            if title != parentMessageUserTitle {
                parentMessageUserTitle = appearance.replyMessageAppearance.senderNameFormatter.format(parent.user)
                parentMessageUserTitleSize = Self.textSizeMeasure.calculateSize(
                    of:
                        NSAttributedString(
                            string: parentMessageUserTitle,
                            attributes: [
                                .font: appearance.replyMessageAppearance.titleLabelAppearance.font
                            ]
                        ),
                    config: .init(restrictingWidth: Self.defaults.messageSenderNameWidth, lastFragmentUsedRect: false)
                ).textSize
                updateOptions.insert(.parentMessageUser)
            }

            if force || self.message.parent?.body != message.parent?.body || self.message.parent?.state != message.parent?.state {
                let parentAttributedView = Self.attributedView(
                    message: parent,
                    userSendMessage: userSendMessage,
                    appearance: appearance
                )

                let parentSize = Self.textSizeMeasure.calculateSize(of: parentAttributedView.content,
                                                                    config: .init(restrictingWidth: restrictingTextWidth))
                self.parentAttributedView = parentAttributedView
                parentTextSize = parentSize.textSize
                updateOptions.insert(.parentMessageBody)
            }
            // Rebuild only when something the layout is built FROM actually changed. It used to
            // be rebuilt on every update, and ReplyLayout.init is expensive: it constructs a
            // nested AttachmentLayout, resizes an icon and re-runs the reply-body formatter — on
            // whichever thread called update(), which is the CoreData queue for every change
            // notification the channel receives.
            //
            // `ReplyLayout.message` is a `let`, so a different parent always needs a new instance;
            // for the same parent, updateAttachment() refreshes the attachment in place.
            let existingReply = replyLayout
            let needsNewReplyLayout = existingReply == nil
                || existingReply?.message.id != parent.id
                || existingReply?.message.tid != parent.tid
                || force
                || updateOptions.contains(.parentMessageBody)
                || updateOptions.contains(.parentMessageUser)
            if needsNewReplyLayout {
                replyLayout = Components.messageReplyLayoutModel.init(
                    message: parent,
                    byMe: message.user.id == SceytChatUIKit.shared.currentUserId,
                    channel: channel,
                    thumbnailSize: Self.defaults.imageRepliedAttachmentSize,
                    attributedBody: parentAttributedView?.content,
                    appearance: appearance)
            } else {
                existingReply?.updateAttachment(message: parent)
            }
        } else {
            parentTextSize = .zero
            parentMessageUserTitle = ""
            parentMessageUserTitleSize = .zero
            parentAttributedView = nil
            replyLayout = nil
        }

        // hasReply gates measureSize through reply space in measure(). When it
        // flips and no other field is dirty, force a measureSize recompute —
        // otherwise the cell keeps the old (reply-sized) height while bind()
        // hides replyView, or vice versa.
        if prevHasReply != newHasReply {
            updateOptions.insert(.reload)
        }
        if attachments.isEmpty {
            // This used to `linkPreviews?.removeAll()` and rebuild the whole array. Emptying it
            // first defeated addLinkPreview's own dedup guard, so every change notification for a
            // link message — an edit, a reaction, a pin, a delivery receipt — re-ran a JPEG resize
            // and disk write (loadThumbnail) plus two text-measurement passes per preview, and
            // churned the array the main thread reads while binding cells.
            //
            // Add/refresh in place instead, then drop the previews whose URL is no longer in the
            // body. That removal is the one thing the removeAll was genuinely covering.
            let links = Self.createLinkPreviews(message: message, linkAttachments: linkAttachments)
            for link in links {
                if addLinkPreview(linkMetadata: link) {
                    self.updateOptions.remove(.link)
                    updateOptions.insert(.link)
                }
            }
            if let previews = linkPreviews, !previews.isEmpty {
                let kept = previews.filter { preview in
                    links.contains { $0.url.isEqual(url: preview.url) }
                }
                if kept.count != previews.count {
                    linkPreviews = kept
                    self.updateOptions.remove(.link)
                    updateOptions.insert(.link)
                }
            }
            if (linkPreviews?.isEmpty ?? true), contentOptions.contains(.link) {
                contentOptions.remove(.link)
                updateOptions.insert(.link)
            }
        }
        
        // Download-completion edge: force exactly one reconfigure when a media attachment reaches
        // .done. The attachment comparison above and the classic reload path deliberately ignore
        // filePath/status (to avoid reload churn during transfer), so without this a download that
        // completes while the cell is visible would never reconfigure it — leaving a blurry
        // placeholder until the user scrolls (especially when the sharp load landed on a duplicate
        // AttachmentLayout instance or no live transfer-completion callback fired). Inserting
        // .reload keeps the reload hint alive through makeEvents and bumps contentVersion, so the
        // cell re-binds once and the AttachmentView's bind-time self-heal swaps blurry→sharp.
        //
        // Gate on the .done transition specifically — NOT "gained a filePath". The downloader
        // writes filePath BEFORE flipping status to .done (SCTSession: updateLocalFileLocation
        // then success), so a filePath-based edge would fire while status is still .downloading
        // (when the view's self-heal, gated on .done, cannot run) and then miss the real .done
        // edge. Aligning to .done matches the self-heal gate exactly.
        let didFinishDownloadingMedia = (message.attachments ?? []).contains { new in
            guard new.type == "image" || new.type == "video",
                  new.status == .done,
                  let old = (self.message.attachments ?? []).first(where: { $0 == new })
            else { return false }
            return old.status != .done
        }
        if didFinishDownloadingMedia {
            updateOptions.insert(.reload)
        }

        func isActiveTransfer(_ status: ChatMessage.Attachment.TransferStatus) -> Bool {
            status == .pending || status == .downloading || status == .uploading
        }
        let didChangeTransferState = (message.attachments ?? []).contains { new in
            guard let old = (self.message.attachments ?? []).first(where: { $0 == new })
            else { return false }
            return isActiveTransfer(old.status) != isActiveTransfer(new.status)
        }
        if didChangeTransferState {
            updateOptions.insert(.reload)
        }

        // Read off the incoming message: `isSystemMessage` consults `self.message`, which
        // is still the previous one this far up the method.
        var didChangeSystemMessageText = false
        if message.type == ChatMessage.MessageType.system, message.state != .deleted {
            let text = SceytChatUIKit.shared.formatters.systemMessageBodyFormatter.format(message)
            didChangeSystemMessageText = measuredSystemMessageText != text
            if didChangeSystemMessageText {
                updateOptions.insert(.reload)
            }
        }

        // Not folded into the options diff: `updateOptions` accumulates across updates, so
        // once `.pin` is set the diff would read as unchanged on every later toggle. The
        // same is true of `.reload` and the system text, hence its own flag.
        var isUpdated = self.updateOptions != updateOptions || didChangePinState
            || didChangeMessageState || didChangeSystemMessageText
        self.updateOptions = updateOptions
        self.channel = channel
        self.message = message
        let newReactions = createReactions(message: message)
        if newReactions != reactions {
            isUpdated = true
            self.updateOptions.insert(.reaction)
        }
        reactions = newReactions
        // After `self.message`/`self.channel` are in place: the reserve tracks the InfoView, which
        // grows with the delivery state, the "edited" mark and the broadcast view count.
        updateAttachmentRowMetrics()
        let previousAttachmentsContainerSize = attachmentsContainerSize
        attachmentsContainerSize = calculateAttachmentsContainerSize()
        if previousAttachmentsContainerSize != attachmentsContainerSize {
            // The `.file` branch of the cells pins `bubbleView.widthAnchor` to a *constant*, so a
            // row that grew (a byte count that was unknown at first layout, say) only reaches the
            // screen if the cell reconfigures. `measureSize` below is gated on `isUpdated` too.
            isUpdated = true
            self.updateOptions.insert(.reload)
        }
        if isUpdated || force {
            // One read of the guarded property, so the measured length and the truncated string
            // are guaranteed to come from the same value.
            let content = attributedView.content
            let textLength = content.string.count
            if message.state == .deleted {
                isTextExpanded = false
                shouldShowReadMore = false
                truncatedTextSize = .zero
                readMoreButtonHeight = 0
            } else {
                if textLength > appearance.collapsedCharacterLimit {
                    let truncatedString = String(content.string.prefix(appearance.collapsedCharacterLimit))
                    let mutableAttributed = NSMutableAttributedString(attributedString: content)
                    mutableAttributed.mutableString.setString(truncatedString)

                    let truncatedSize = Self.textSizeMeasure.calculateSize(
                        of: mutableAttributed,
                        config: .init(restrictingWidth: restrictingTextWidth))
                    truncatedTextSize = truncatedSize.textSize

                    // Only show read more if truncation actually results in different height
                    // This prevents showing "Read More" when text fits without visual truncation
                    if truncatedTextSize.height < textSize.height {
                        shouldShowReadMore = true
                        // Calculate read more button height (font line height + padding)
                        let buttonFont = appearance.readMoreButtonAppearance.font
                        readMoreButtonHeight = buttonFont.lineHeight + 8 // 8 = top(4) + bottom(4) padding
                    } else {
                        shouldShowReadMore = false
                        readMoreButtonHeight = 0
                    }
                } else {
                    shouldShowReadMore = false
                    truncatedTextSize = .zero
                    readMoreButtonHeight = 0
                }
            }
            measureSize = measure()
        }
        if isUpdated {
            contentVersion &+= 1
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
        guard !channel.isDirect
        else { return }
        if showUserInfo != show {
            if show,
               channel.channelType == .broadcast {
                // do not show
            } else {
                showUserInfo = show
                measureSize = measure()
                updateOptions.insert(.reload)
                contentVersion &+= 1
                if showUserInfo {
                    createMessageUserTitle()
                } else {
                    removeMessageUserTitle()
                }
            }
        }
    }
    
    private func createMessageUserTitle() {
        messageUserTitle = appearance.senderNameFormatter.format(message.user)
        if !message.incoming ||
            channel.channelType == .direct ||
            channel.channelType == .broadcast {
            messageUserTitleSize = .zero
        } else {
            messageUserTitleSize = Self.textSizeMeasure.calculateSize(
                of:
                    NSAttributedString(
                        string: messageUserTitle,
                        attributes: [
                            .font: appearance.senderNameLabelAppearance.font
                        ]
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
        var selfReactions = message.userReactions?.compactMap { SceytChatUIKit.shared.currentUserId == $0.user?.id ? $0.key : nil } ?? []
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
            let maxDisplayedCount = SceytChatUIKit.shared.config.maxDisplayedReactionsCount
            if maxDisplayedCount > 0, reactions.count > maxDisplayedCount {
                reactions = reactions
                    .sorted(by: { $0.score != $1.score ? $0.score > $1.score : $0.key > $1.key })
                    .prefix(maxDisplayedCount)
                    .sorted(by: { $0.key > $1.key })
            }
            if reactionType == .withTotalScore, commonScore > 1 {
                let key = "\(commonScore)"
                let width = key.size(withAttributes: [
                    .font: appearance.reactionCountLabelAppearance.font
                ]).width
                reactions.append(.init(key: key, score: 0, byMe: false, width: ceil(width)))
            }
        } else {
            estimatedReactionsNumberPerRow = 0
        }
        if estimatedReactionsNumberPerRow != 0, !reactions.isEmpty {
            // `reactions` here is the LOCAL built above, not the lock-guarded property of the
            // same name — the caller assigns the return value to that. Do not "simplify" this
            // into a self-read.
            groupedReactions = reactions.chunked(into: estimatedReactionsNumberPerRow)
        }
        return reactions
    }
    
    open func estimateReactionsNumberPerRow() -> Int {
        let width = Self.defaults.messageWidth
        let emojiItemWidth = Components.messageCellReactionTotalView.Measure.emojiWidth
        let insets = Components.messageCellReactionTotalView.Measure.contentInsets
        let interItemSpacing = Components.messageCellReactionTotalView.Measure.itemSpacingH
        let fitWidth = width - insets.left - insets.right
        var accumWidth: CGFloat = .zero
        
        var itemCount = 0
        repeat {
            accumWidth += emojiItemWidth + interItemSpacing
            itemCount += 1
        } while accumWidth < fitWidth
        
        return itemCount
    }
    
    open class func attachmentLayout(message: ChatMessage, channel: ChatChannel, appearance: MessageCell.Appearance) -> [AttachmentLayout] {
        // Hide attachments if message has opened marker
        if message.hasOpenedMarker {
            return []
        }

        // A deleted message renders as the "Message was deleted." text only. The
        // delete drops the attachment rows (MessageDatabaseSession.deleteAttachmentsFor),
        // but the message can still reach us carrying them — the batch delete is not
        // always visible on the relationship the observer converted from yet. Deriving
        // this from the state keeps the deleted body from being rendered on top of a
        // stale thumbnail.
        if message.state == .deleted {
            return []
        }

        return (message.attachments?.compactMap {
            logger.verbose("[Attachment] attachmentLayout attachment \($0.description)")
            let layout = Components.messageAttachmentLayoutModel.init(attachment: $0, ownerMessage: message, ownerChannel: channel, asyncLoadThumbnail: true, appearance: appearance)
            return layout.type == .link ? nil : layout
        } ?? [])
        .sorted { lh, rh in
            let ld = lh.type == .image || lh.type == .video ? 0 : 1
            let rd = rh.type == .image || rh.type == .video ? 0 : 1
            return ld < rd
        }
    }
    
    open class func linkAttachmentLayout(message: ChatMessage, channel: ChatChannel, appearance: MessageCell.Appearance) -> [AttachmentLayout] {
        // Hide link attachments if message has opened marker
        if message.hasOpenedMarker {
            return []
        }

        // Deleted messages show no link previews either — see `attachmentLayout`.
        if message.state == .deleted {
            return []
        }

        return (message.attachments?.compactMap {
            logger.verbose("[Attachment] attachmentLayout attachment \($0.description)")
            let layout = Components.messageAttachmentLayoutModel.init(attachment: $0, ownerMessage: message, ownerChannel: channel, asyncLoadThumbnail: true, appearance: appearance)
            return layout.type != .link || $0.imageDecodedMetadata?.hideLinkDetails == true ? nil : layout
        } ?? [])
    }
    
    /// Hands every attachment row the two geometry facts only the bubble knows: how much trailing
    /// space the date/tick InfoView needs over it, and how wide the row may get.
    ///
    /// The InfoView is a sibling of the attachment stack pinned to the bubble's bottom-right, so
    /// it overlaps the *bottom-most* row and nothing above it — reserving on every row would
    /// truncate size labels that nothing is covering.
    open func updateAttachmentRowMetrics() {
        // A file-only bubble may run wider than the media cap; one that also holds an image or
        // video keeps that cap, because media rows take the stack's width at a fixed height and
        // would be stretched out of aspect by a wider file row. The -4 is the stack's own inset,
        // which the cell adds back when it turns this width into the bubble's.
        let cap = hasMediaAttachments
            ? Self.defaults.imageAttachmentSize.width
            : min(Self.defaults.fileAttachmentSize.width, Self.defaults.messageWidth - 4)
        // One read of the guarded property, not one per loop iteration. The element mutations
        // below are on class instances, so there is no writeback to the array and no CoW copy —
        // and their didSets reach AttachmentLayout's own lock, which is a different lock.
        let rows = attachments
        let reserve: CGFloat
        if rows.last?.type == .file, message.state != .deleted {
            reserve = Components.messageCellInfoView
                .measure(channel: channel, message: message, appearance: appearance).width
                + MessageCell.Layouts.attachmentFileInfoSpacing
        } else {
            reserve = 0
        }
        for (index, layout) in rows.enumerated() {
            layout.maxRowWidth = cap
            layout.reservedTrailingWidth = index == rows.count - 1 ? reserve : 0
        }
    }

    open func updateAttachmentLayouts(message: ChatMessage) {
        // Hide attachments if message has opened marker
        if message.hasOpenedMarker {
            attachments = []
            linkAttachments = []
            return
        }

        // Deleted messages keep no attachments — see `attachmentLayout`.
        if message.state == .deleted {
            attachments = []
            linkAttachments = []
            return
        }

        // One snapshot of each array, taken BEFORE either property is reassigned: the reuse
        // lookups below have to search the previous layouts. Reading `attachments` inside the
        // closure would also be a second lock-guarded access, with the index taken from a
        // different read than the one it subscripts.
        //
        // `linkAttachments` used to search `previousAttachments` — i.e. the array the line above
        // had just reassigned, with every `.link` layout filtered out. The lookup could therefore
        // never match, so a brand-new AttachmentLayout was built for every link attachment on
        // every single update, each one dispatching a fresh loadThumbnail() and each one starting
        // with `thumbnail == nil` (which is what made link images flick back to the placeholder).
        let previousAttachments = attachments
        let previousLinkAttachments = linkAttachments

        attachments =
        (message.attachments?.compactMap { attachment in
            logger.verbose("[Attachment] attachmentLayout update attachment \(attachment.description)")
            if let existing = previousAttachments.first(where: { $0.attachment == attachment }) {
                existing.update(attachment: attachment)
                return existing
            }
            let layout = Components.messageAttachmentLayoutModel.init(attachment: attachment, ownerMessage: message, ownerChannel: channel, asyncLoadThumbnail: true, appearance: appearance)
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
            if let existing = previousLinkAttachments.first(where: { $0.attachment == attachment }) {
                existing.update(attachment: attachment)
                return existing
            }
            // Was `AttachmentLayout(...)`, bypassing the factory used for media rows above.
            let layout = Components.messageAttachmentLayoutModel.init(attachment: attachment, ownerMessage: message, ownerChannel: channel, asyncLoadThumbnail: true, appearance: appearance)
            return layout.type != .link || attachment.imageDecodedMetadata?.hideLinkDetails == true ? nil : layout
        } ?? [])
    }
    
    open class func attributedView(message: ChatMessage,
                                   userSendMessage: UserSendMessage? = nil,
                                   appearance: MessageCell.Appearance
    ) -> AttributedView {
        let (attributedString, contentItems) = appearance.messageBodyFormatter.format(
            .init(
                message: message,
                userSendMessage: userSendMessage,
                deletedStateText: appearance.deletedStateText,
                bodyLabelAppearance: appearance.bodyLabelAppearance,
                linkLabelAppearance: appearance.linkLabelAppearance,
                phoneNumberLabelAppearance: appearance.phoneNumberLabelAppearance,
                mentionLabelAppearance: appearance.mentionLabelAppearance,
                deletedLabelAppearance: appearance.deletedMessageLabelAppearance,
                mentionUserNameFormatter: appearance.mentionUserNameFormatter
            )
        )
        return .init(content: attributedString, items: contentItems)
    }
    
    open class func createLinkPreviews(message: ChatMessage, linkAttachments: [AttachmentLayout]) -> [LinkMetadata] {
        guard message.state != .deleted
        else { return [] }
        var attachments = linkAttachments
        var linkMetadatas = [LinkMetadata]()
        if let links = message.linkMetadatas, !links.isEmpty {
            linkMetadatas += links.compactMap { data in
                let hasHiddenDetails = message.attachments?.first(where: { attachment in
                    guard let urlString = attachment.url,
                          let attachmentURL = URL(string: urlString) else {
                        return false
                    }
                    return attachmentURL.isEqual(url: data.url)
                })?.imageDecodedMetadata?.hideLinkDetails == true

                if hasHiddenDetails {
                    return nil
                }
                var image: UIImage? = nil
                if !attachments.isEmpty, let firstIndex = attachments.firstIndex(where: {
                    if let urlStr = $0.attachment.url, let url = URL(string: urlStr) {
                        return url.isEqual(url: data.url)
                    }
                    return $0.attachment.url == data.url.absoluteString
                }) {
                    let first = attachments[firstIndex]
                    if let thumbnail = first.thumbnail {
                        image = thumbnail
                    } else {
                        image = first.attachment.imageDecodedMetadata?.thumbnailImage
                    }
                    
                    attachments.remove(at: firstIndex)
                }
                
                let link = LinkMetadata(
                    isThumbnailData: true,
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
            for attachment in attachments where attachment.attachment.imageDecodedMetadata != nil && attachment.type == .link {
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
        guard message.state != .deleted
        else { return false }
        let url = linkMetadata.url
        // Before the dedup check below, not after. The check asks whether the stored preview
        // already has the same image/icon state as this metadata, and a metadata object freshly
        // converted from its DTO reports "no image" until loadImages() reads it off disk — so
        // checking first would make a preview whose image has since arrived look unchanged, and
        // it would never refresh. This is cheap when there is nothing new (a path lookup, and
        // UIImage(contentsOfFile:) decodes lazily); the expensive work is all below the guard.
        linkMetadata.loadImages()
        // Skip only when nothing that this preview RENDERS has changed. The url/image/icon triple
        // is not enough: `update()` used to empty the array before refilling it, so this guard
        // never actually fired and its gaps never showed. Now that the array is refreshed in
        // place it is load-bearing, and the missing comparisons are exactly the cases that matter
        // — Open Graph text arriving after the first fetch, and a placeholder `isThumbnailData`
        // preview being replaced by the real fetched metadata. Both keep the same image state, so
        // the old triple would have skipped them and left the stale title on screen.
        if let linkPreviews = linkPreviews,
           linkPreviews.contains(where: {
               $0.url.isEqual(url: url)
               && $0.hasImage == linkMetadata.hasImage
               && $0.hasIcon == linkMetadata.hasIcon
               && $0.isThumbnailData == linkMetadata.isThumbnailData
               && $0.title?.string == linkMetadata.title
               && $0.description?.string == linkMetadata.summary
           }) {
            return false
        }

        var preview = LinkPreview(url: url, isThumbnailData: linkMetadata.isThumbnailData, icon: linkMetadata.icon)
        preview.metadata = linkMetadata
        preview.iconOriginalSize = linkMetadata.iconOriginalSize
        if let imageSize = linkMetadata.imageOriginalSize ?? linkMetadata.image?.size {
            if imageSize.width < 200 {
                preview.imageOriginalSize = imageSize
                preview.isCompactLayout = true
            } else {
                preview.imageOriginalSize = AttachmentLayout.preferredImageSize(maxSize: Self.defaults.imageAttachmentSize.width, imageSize: imageSize)
            }
        } else {
            preview.imageOriginalSize = linkMetadata.imageOriginalSize
        }
        if let image = linkMetadata.image {
            let thumbnailSize =
                AttachmentLayout
                .preferredImageSize(maxSize: Self.defaults.imageAttachmentSize.width, imageSize: image.size)
            linkMetadata.loadThumbnail(of: thumbnailSize)
        }
        preview.image = linkMetadata.thumbnail ?? linkMetadata.image
        if let description = linkMetadata.summary {
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: description,
                                                     attributes:
                                                        [.font: appearance.linkPreviewAppearance.descriptionLabelAppearance.font,
                                                         .foregroundColor: appearance.linkPreviewAppearance.descriptionLabelAppearance.foregroundColor
                                                        ])
            )
            
            preview.descriptionSize = Self.textSizeMeasure
                .calculateSize(of: text,
                               config: .init(restrictingWidth: Self.defaults.imageAttachmentSize.width - 12,
                                             maximumNumberOfLines: 3)).textSize
            preview.description = text
        }
        if let title = linkMetadata.title {
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: title,
                                                     attributes: [
                                                        .font: appearance.linkPreviewAppearance.titleLabelAppearance.font,
                                                        .foregroundColor: appearance.linkPreviewAppearance.titleLabelAppearance.foregroundColor
                                                     ]))
            preview.titleSize = Self.textSizeMeasure
                .calculateSize(of: text,
                               config: .init(restrictingWidth: Self.defaults.imageAttachmentSize.width - 12,
                                             maximumNumberOfLines: 2)).textSize
            preview.title = text
        }
        // One snapshot, mutated locally, written back once. Reading the array, taking an index
        // into it and then subscripting a *second* read would be two separate accesses now that
        // `linkPreviews` is lock-guarded — and the concurrent writer could have shortened it in
        // between, trapping with "Index out of range".
        var previews = linkPreviews ?? []
        if let index = previews.firstIndex(where: { $0.url.isEqual(url: preview.url) }) {
            previews[index] = preview
        } else {
            previews.append(preview)
        }
        linkPreviews = previews
        if !hasPoll && !(contentOptions.contains(.link) || contentOptions.contains(.file) || contentOptions.contains(.image) || contentOptions.contains(.voice)) {
            contentOptions.insert(.link)
        }
        return true
    }
    
    open func updateThreadReplyCount(message: Message) {
        replyCount = message.replyCount
    }

    /// Determines if a message is unsupported by the current app version
    /// Override this method to customize the logic for detecting unsupported messages
    /// By default, uses the `messageTypeSupportProvider` from `SceytChatUIKit.shared.visualProviders`
    /// to determine if a message type is supported
    open class func isMessageUnsupported(_ message: ChatMessage) -> Bool {
        return !SceytChatUIKit.shared.visualProviders.messageTypeSupportProvider.provideVisual(for: message)
    }

    open func measure() -> CGSize {
        infoViewMeasure = Components.messageCellInfoView.measure(model: self, appearance: appearance)
        measuredPinState = message.isPinned
        measuredMessageState = message.state
        linkViewMeasure = hasPoll ? .zero : Components.messageCellLinkStackView.measure(model: self, appearance: appearance)
        pollViewMeasure = hasPoll ? Components.messageCellPollView.measure(model: self, appearance: appearance) : .zero
        if isSystemMessage {
            measuredSystemMessageText = SceytChatUIKit.shared.formatters.systemMessageBodyFormatter.format(message)
            systemMessageMeasure = Components.channelSystemMessageCell.measure(model: self, appearance: appearance)
        } else {
            measuredSystemMessageText = nil
            systemMessageMeasure = .zero
        }
        unsupportedViewMeasure = Components.messageCellUnsupportedMessageView.measure(model: self, appearance: appearance)

        if isSystemMessage {
            return systemMessageMeasure
        }

        if message.incoming {
            return Components.channelIncomingMessageCell.measure(model: self, appearance: appearance)
        } else {
            return Components.channelOutgoingMessageCell.measure(model: self, appearance: appearance)
        }
    }
    
    private func calculateAttachmentsContainerSize() -> CGSize {
        let rows = attachments
        guard !rows.isEmpty
        else { return .zero }
        
        var size = CGSize.zero
        for attachment in rows {
            size.width = max(size.width, attachment.thumbnailSize.width)
            size.height += attachment.thumbnailSize.height
        }
        size.height += CGFloat(4 * (rows.count - 1))
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
        public static let poll     = MessageContentOptions(rawValue: 1 << 6)
        public static let system   = MessageContentOptions(rawValue: 1 << 7)
        public static let unsupported = MessageContentOptions(rawValue: 1 << 8)

        public static let attachment: MessageContentOptions = [.image, .file, .voice]
        public static let all: MessageContentOptions = [.name, .text, .image, .file, .link, .voice, .poll, .system, .unsupported]
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
        public static let poll                  = MessageUpdateOptions(rawValue: 1 << 10)
        public static let pin                   = MessageUpdateOptions(rawValue: 1 << 11)
        
        public static let all: MessageUpdateOptions = [.body, .user, .replyCount, parentMessageUser, .parentMessageBody, .attachment, .link, deliveryStatus, .poll, .pin]
    }
    
    struct Defaults {
        public var messageWidthRatio: CGFloat = 0.72
        public internal(set) lazy var messageWidth: CGFloat = floor(messageWidthRatio * UIScreen.main.bounds.width)
        public var messageSenderNameWidth = CGFloat(170)
        public var imageAttachmentSize  = CGSize(width: 260, height: 200)
        public var imageRepliedAttachmentSize  = CGSize(width: 40, height: 40)
        /// Height = the icon slot plus the row's own top and bottom inset: 48 + (8 - 2) + 8. The
        /// top is 2 short because the stack is already inset from the bubble there and flush at
        /// its bottom, so both edges read as `attachmentFilePadding` — see `MessageCell.Layouts`.
        public var fileAttachmentSize   = CGSize(width: CGFloat.infinity, height: 62)
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
        public var isCompactLayout: Bool = false
    }
    
    struct ReactionInfo: Equatable {
        public let key: String
        public let score: UInt
        public let byMe: Bool
        public let width: CGFloat
    }
    
    enum ReactionViewType {
        case interactive
        case withTotalScore
    }
    
    enum ContentItem {
        case link(NSRange, URL?)
        case mention(NSRange, String)
        case phone(NSRange, String?)
        
        public var range: NSRange {
            switch self {
            case let .link(range, _),
                let .mention(range, _),
                let .phone(range, _):
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
        // `attachment` is read on a background thread (loadThumbnail) and written on the
        // main thread (update/init). The lock makes the read+retain atomic with the
        // concurrent write+release, preventing use-after-free crashes.
        private let _attachmentLock = NSLock()
        private var _attachmentValue: ChatMessage.Attachment!
        public private(set) var attachment: ChatMessage.Attachment {
            get {
                // Assign under the lock so the ARC retain of the returned value
                // happens before the lock is released — prevents the main thread's
                // concurrent release from dropping the refcount to zero mid-retain.
                var v: ChatMessage.Attachment!
                _attachmentLock.lock()
                v = _attachmentValue
                _attachmentLock.unlock()
                return v!
            }
            set {
                _attachmentLock.lock()
                _attachmentValue = newValue
                _attachmentLock.unlock()
            }
        }
        public private(set) var ownerMessage: ChatMessage?
        public private(set) var ownerChannel: ChatChannel?
        public var appearance: MessageCell.Appearance
        public var thumbnail: UIImage?
        public var thumbnailSize: CGSize = .zero

        /// Trailing space this row must keep clear for the bubble's date/tick InfoView, plus the
        /// gap that separates them. `MessageLayoutModel` sets it on the bottom-most row only —
        /// the InfoView is pinned to the bubble's bottom-right, so it overlaps nothing above that
        /// row. Stays zero wherever there is no InfoView at all (the shared-media and
        /// global-search lists build their layouts directly).
        public var reservedTrailingWidth: CGFloat = 0 {
            didSet {
                guard oldValue != reservedTrailingWidth else { return }
                recalculateThumbnailSizeIfNeeded()
            }
        }

        /// Cap for this row's measured width. `MessageLayoutModel` lets a file-only bubble grow to
        /// the message width, but keeps the media cap when the bubble also carries an image or
        /// video: media rows take the stack's width at a fixed height
        /// (`AttachmentStackView.addImageView`), so a wider file row would stretch a sibling out
        /// of aspect.
        public var maxRowWidth: CGFloat = Components.messageLayoutModel.defaults.imageAttachmentSize.width {
            didSet {
                guard oldValue != maxRowWidth else { return }
                recalculateThumbnailSizeIfNeeded()
            }
        }

        /// True when the caller pinned `thumbnailSize` up front — the shared-media and
        /// global-search lists do, because their cells have a fixed geometry. Nothing here may
        /// re-derive a size under those.
        private let hasFixedThumbnailSize: Bool

        public var voiceWaveform: [Float]?
        /// Cached link metadata for link-type attachments. Set once on first load; checked before re-fetching.
        public var linkMetadata: LinkMetadata?
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
        
        /// Memoized because the fallback branch is a `stat` on the main thread, and the file
        /// cell asks for it on every bind — i.e. once per file row per scroll pass. Cleared
        /// by `update(attachment:)`, which is the only thing that can change the answer.
        @Atomic private var cachedFileSizeBytes: UInt?

        open var fileSizeBytes: UInt {
            if let cachedFileSizeBytes { return cachedFileSizeBytes }
            let resolved: UInt
            if attachment.uploadedFileSize > 0 {
                resolved = attachment.uploadedFileSize
            } else if let filePath = attachment.filePath {
                resolved = Components.storage.sizeOfItem(at: filePath)
            } else {
                resolved = 0
            }
            cachedFileSizeBytes = resolved
            return resolved
        }

        open func fileSize(using formatter: any UIntFormatting) -> String {
            formatter.format(UInt64(fileSizeBytes))
        }

        /// The widest line `AttachmentFileView.setProgress` can put under the name:
        /// "<downloaded> • <total>". The two halves are formatted *independently*, so the
        /// downloaded one can be longer than the total — "999.99KB • 1.50MB" runs 14pt past the
        /// "1.50MB • 1.50MB" this row used to be measured against, which is exactly how much of
        /// the line then truncated as soon as a transfer started.
        ///
        /// Deliberately status-independent: the row is always sized for the widest state it can
        /// reach, so the bubble does not resize the moment a transfer begins or ends.
        open func widestTransferSizeText(using formatter: any UIntFormatting) -> String {
            let total = UInt64(fileSizeBytes)
            let formattedTotal = formatter.format(total)
            // The long values sit just below a unit boundary ("999.99KB", "1023.99KB"). Cover the
            // decimal and the binary boundaries both, so a host-supplied formatter of either kind
            // is measured against its own worst case.
            let boundaries: [UInt64] = [1_000, 1_000_000, 1_000_000_000, 1 << 10, 1 << 20, 1 << 30]
            var widest = formattedTotal
            for boundary in boundaries where boundary - 1 < total {
                let candidate = formatter.format(boundary - 1)
                // Character count as the proxy for width: every candidate is digits, a decimal
                // separator and a unit, so counting avoids measuring half a dozen strings per
                // row. A miss costs a few points, which the size label's trailing constraint
                // absorbs by truncating.
                if candidate.count > widest.count { widest = candidate }
            }
            return "\(widest) • \(formattedTotal)"
        }
        
        @Atomic private var isLoadedThumbnail: Bool = false
        public var onLoadThumbnail: ((UIImage?) -> Void)? {
            didSet {
                if isLoadedThumbnail {
                    onLoadThumbnail?(thumbnail)
                }
            }
        }
        
        @Atomic internal private(set) var isThumbnailLoadedFromFile = false
        
        public required init(
            attachment: ChatMessage.Attachment,
            ownerMessage: ChatMessage?,
            ownerChannel: ChatChannel?,
            thumbnailSize: CGSize? = nil,
            onLoadThumbnail: ((UIImage?) -> Void)? = nil,
            asyncLoadThumbnail: Bool = false,
            appearance: MessageCell.Appearance
        ) {
            _attachmentValue = attachment  // direct backing-store write — computed setter uses self, which requires all stored props initialized first
            self.ownerMessage = ownerMessage
            self.ownerChannel = ownerChannel
            self.appearance = appearance
            // Before the size below: this is what tells `recalculateThumbnailSizeIfNeeded` never
            // to re-derive a size the caller pinned.
            self.hasFixedThumbnailSize = thumbnailSize != nil
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
            // Snapshot all inputs before any concurrent work. The switch below runs
            // only on local variables so the background thread never reads or writes
            // through self. All writes to self are deferred to the main-thread block.
            let attachment = self.attachment
            let attachmentType = AttachmentType(rawValue: attachment.type) ?? .file
            let thumbnailSize = self.thumbnailSize
            let appearance = self.appearance

            var resultThumbnail: UIImage?
            var resultWaveform: [Float]?
            var resultLoadedFromFile = false

            switch attachmentType {
            case .voice:
                resultThumbnail = appearance.attachmentIconProvider.provideVisual(for: attachment)
                resultWaveform = attachment.voiceDecodedMetadata?.thumbnail.map { Float($0) }
            case .image, .video:
                if let path = fileProvider.thumbnailFile(for: attachment, preferred: thumbnailSize) {
                    logger.verbose("[Attachment]  thumbnail load from filePath \(attachment.description)")
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                        if let image = UIImage(data: data) {
                            resultThumbnail = image
                            resultLoadedFromFile = true
                        } else {
                            logger.error("[Attachment] thumbnail decode failed, path \(path)")
                        }
                    } catch {
                        logger.errorIfNotNil(error, "load image from path \(path)")
                    }
                }
                if resultThumbnail == nil, attachmentType == .video,
                   let path = fileProvider.cachedVideoThumbnailPath(attachment: attachment) {
                    // Downloaded "video_thumb" poster: sharp preview available before
                    // the video itself is local. File-backed semantics so the
                    // no-downgrade guards keep it over the thumbHash blur.
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                        if let image = UIImage(data: data) {
                            resultThumbnail = image
                            resultLoadedFromFile = true
                        } else {
                            logger.error("[Attachment] video_thumb decode failed, path \(path)")
                        }
                    } catch {
                        logger.errorIfNotNil(error, "load video_thumb from path \(path)")
                    }
                }
                if resultThumbnail == nil {
                    let metadata = attachment.imageDecodedMetadata
                    logger.verbose("[Attachment] thumbnail is nil make from metadata \(attachment.description)")
                    if let data = metadata?.thumbnailImage {
                        resultThumbnail = data
                    } else if let base64 = metadata?.thumbnail,
                              let image = Components.imageBuilder.image(thumbHash: base64) {
                        resultThumbnail = image
                    } else {
                        resultThumbnail = appearance.attachmentIconProvider.provideVisual(for: attachment)
                    }
                }
            case .file:
                if let path = fileProvider.thumbnailFile(for: attachment, preferred: thumbnailSize) {
                    logger.verbose("[Attachment]  thumbnail load from filePath \(attachment.description)")
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                        if let image = UIImage(data: data) {
                            resultThumbnail = image
                            resultLoadedFromFile = true
                        } else {
                            logger.error("[Attachment] thumbnail decode failed, path \(path)")
                        }
                    } catch {
                        logger.errorIfNotNil(error, "load image from path \(path)")
                    }
                }
                if resultThumbnail == nil {
                    // Same blurred-placeholder path as image/video: previewable documents carry
                    // a thumbHash in metadata; decode it until the sharp on-disk thumbnail
                    // exists (pre-download on the receiver, mid-upload on the sender).
                    let metadata = attachment.imageDecodedMetadata
                    if let data = metadata?.thumbnailImage {
                        resultThumbnail = data
                    } else if let base64 = metadata?.thumbnail,
                              let image = Components.imageBuilder.image(thumbHash: base64) {
                        resultThumbnail = image
                    } else {
                        resultThumbnail = appearance.attachmentIconProvider.provideVisual(for: attachment)
                    }
                }
            case .link:
                if resultThumbnail == nil {
                    let metadata = attachment.imageDecodedMetadata
                    if let data = metadata?.thumbnailImage {
                        resultThumbnail = data
                    } else if let base64 = metadata?.thumbnail,
                              let image = Components.imageBuilder.image(thumbHash: base64) {
                        resultThumbnail = image
                    } else {
                        resultThumbnail = appearance.linkPreviewAppearance.placeholderIcon
                    }
                }
            default:
                break
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Accept the result when it belongs to the current attachment object, OR when it
                // was loaded from a real on-disk thumbnail file for the same logical attachment
                // (same id/tid). The observer fan-out can swap self.attachment for a fresh
                // ChatMessage.Attachment with the same identity while this load runs; a strict
                // pointer-identity guard would then discard the sharp thumbnail and leave the
                // cell stuck on the blurry thumbHash placeholder.
                let isSameObject = self.attachment === attachment
                let isSameFileBackedAttachment = resultLoadedFromFile && self.attachment == attachment
                guard isSameObject || isSameFileBackedAttachment else { return }
                // Never let a low-res fallback (metadata/thumbHash) clobber an already-loaded
                // sharp file-backed thumbnail — guards against a stale pre-download load landing
                // after the sharp one (ordering inversion).
                if !resultLoadedFromFile, self.isThumbnailLoadedFromFile { return }
                self.thumbnail = resultThumbnail
                self.voiceWaveform = resultWaveform
                self.isThumbnailLoadedFromFile = resultLoadedFromFile
                self.isLoadedThumbnail = true
                self.onLoadThumbnail?(resultThumbnail)
                // onLoadThumbnail is a single overwritable slot: with duplicate layout
                // instances and attachment-view churn it can be owned by an already-dead
                // view when the sharp load lands, and the model then reads "healed" while
                // no live view ever painted. Announce sharp file-backed applies
                // instance-agnostically so any live view showing this attachment can heal.
                if resultLoadedFromFile, let image = resultThumbnail {
                    AttachmentSharpThumbnailRelay.default.post(attachment, image: image)
                }
            }
        }
        
        /// `thumbnailSize` is derived once in `init`, but a file row's width depends on the name
        /// and the byte count — both of which routinely arrive *after* the first layout (the
        /// upload ack, the download's metadata). Left stale, the bubble keeps a width measured
        /// against the old, shorter text while the labels render the new, longer one, and the size
        /// line runs under the bubble's timestamp.
        ///
        /// Files only: re-deriving an image/video size here would resize media bubbles mid-scroll.
        open func recalculateThumbnailSizeIfNeeded() {
            guard !hasFixedThumbnailSize, type == .file else { return }
            let size = calculateAttachmentsContainerSize()
            guard size != thumbnailSize else { return }
            thumbnailSize = size
        }

        open func update(attachment: ChatMessage.Attachment) {
            self.attachment = attachment
            cachedFileSizeBytes = nil
            recalculateThumbnailSizeIfNeeded()
            if !isThumbnailLoadedFromFile {
                isLoadedThumbnail = false
                DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                    self?.loadThumbnail()
                }
            } else {
                logger.debug("[Attachment] update(attachment:) SKIPPED loadThumbnail because isThumbnailLoadedFromFile=true")
            }
        }

        open func resetThumbnail() {
            thumbnail = nil
            isThumbnailLoadedFromFile = false
            isLoadedThumbnail = false
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.loadThumbnail()
            }
        }

        /// Applies a sharp thumbnail that was already loaded from a real on-disk file and notifies
        /// observers. Unlike `resetThumbnail()` this updates the model state in place (so later cell
        /// rebinds to this layout stay sharp) with no nil/blur window. Safe to call after a download
        /// completes regardless of which duplicate layout instance won the async load race — the
        /// caller targets the instance bound to the visible cell. Must be called on the main thread.
        open func setFileBackedThumbnail(_ image: UIImage) {
            // Never downgrade: one attachment has several size-keyed thumbnail files (message
            // bubble vs reply preview), so a smaller sibling result must not replace an
            // already-loaded bigger one. isThumbnailLoadedFromFile stays true afterwards —
            // gating every reload path — so a downgrade would stick until the layout is
            // rebuilt (Case 6).
            if isThumbnailLoadedFromFile, let current = thumbnail {
                let currentPxMaxSide = max(current.size.width, current.size.height) * current.scale
                let incomingPxMaxSide = max(image.size.width, image.size.height) * image.scale
                if incomingPxMaxSide < currentPxMaxSide {
                    logger.debug("[IMGQ] setFileBackedThumbnail skipped — would downgrade \(Int(currentPxMaxSide)) -> \(Int(incomingPxMaxSide)) px maxSide, id=\(attachment.id) layout=\(ObjectIdentifier(self))")
                    return
                }
            }
            thumbnail = image
            isThumbnailLoadedFromFile = true
            isLoadedThumbnail = true
            onLoadThumbnail?(image)
            // Re-broadcast so sibling layout instances of the same attachment heal too.
            // Observers gate on their layout state before re-applying, so the nested
            // post a healing observer triggers terminates after one round trip.
            AttachmentSharpThumbnailRelay.default.post(attachment, image: image)
        }
        
        @discardableResult
        open func updateMessageIfNeeded(ownerMessage: ChatMessage) -> Bool {
            if self.ownerMessage == nil,
               self.attachment.messageId == ownerMessage.id {
                self.ownerMessage = ownerMessage
                recalculateThumbnailSizeIfNeeded()
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
                    size = Self.preferredImageSize(
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
                config.font = appearance.attachmentFileNameLabelAppearance.font
                let nameWidth = TextSizeMeasure.calculateSize(
                    of: name,
                    config: config).textSize.width
                config.font = appearance.attachmentFileSizeLabelAppearance.font
                // Widest thing the size label ever shows: the mid-transfer
                // "<downloaded> • <total>" form that `setProgress` writes.
                // (This used to interpolate the `fileSize(using:)` *method*, so every file
                // bubble was measured against the literal string "(Function) • (Function)".)
                let sizeTextWidth = TextSizeMeasure.calculateSize(
                    of: widestTransferSizeText(using: appearance.attachmentFileSizeFormatter),
                    config: config).textSize.width
                // Chrome around the labels: the slot's leading inset (row-relative, so minus the
                // stack's own) + the slot itself, then the gap to the labels and their trailing
                // inset (both `horizontalPadding`).
                let slotLeading = MessageCell.Layouts.attachmentFilePadding - MessageCell.Layouts.attachmentStackBubbleInset
                let chrome = slotLeading + MessageCell.Layouts.attachmentFileIconSize + MessageCell.Layouts.horizontalPadding * 2
                // Only the size line shares its row with the bubble's InfoView; the name line owns
                // the full width. Reserving *inside* the `max` — as this used to — let a long file
                // name silently swallow the space the timestamp needs, which is how the size text
                // ended up drawn under the clock.
                size.width = min(maxRowWidth, max(nameWidth, sizeTextWidth + reservedTrailingWidth) + chrome)
            case .voice:
                size.height = defaults.audioAttachmentSize.height
            case .link:
                break
            }
            return size
        }
        
        public static func preferredImageSize(maxSize: CGFloat, imageSize: CGSize, minSize: CGFloat? = nil) -> CGSize {
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
        public let byMe: Bool
        public let thumbnailSize: CGSize?
        public var attributedBody = NSAttributedString()
        public var appearance: MessageCell.Appearance
        public private(set) var attachment: AttachmentLayout?
        public var user: ChatUser {
            message.user
        }
        open var icon: UIImage?
        
        public required init(
            message: ChatMessage,
            byMe: Bool,
            channel: ChatChannel,
            thumbnailSize: CGSize?,
            attributedBody: NSAttributedString? = nil,
            appearance: MessageCell.Appearance) {
                self.message = message
                self.byMe = byMe
                self.thumbnailSize = thumbnailSize
                self.appearance = appearance

                // Don't show attachment for view_once messages
                if message.isViewOnceMessage {
                    self.attachment = nil
                } else if let attachment = message.attachments?.first {
                    // asyncLoadThumbnail: the synchronous branch does Data(contentsOf:) plus an
                    // image decode on the calling thread, and this initializer runs on the
                    // CoreData queue during every change notification. ReplyView wires
                    // `onLoadThumbnail` and also heals via AttachmentSharpThumbnailRelay, so the
                    // thumbnail simply arrives a frame later.
                    self.attachment = .init(
                        attachment: attachment,
                        ownerMessage: message,
                        ownerChannel: channel,
                        thumbnailSize: thumbnailSize ?? Components.messageCellReplyView.Measure.imageSize,
                        asyncLoadThumbnail: true,
                        appearance: appearance)
                }

                // Show custom text for view_once messages
                if message.isViewOnceMessage {
                    let attachmentType = message.attachments?.first?.type
                    let attachmentName: String
                    switch attachmentType {
                    case "video":
                        attachmentName = L10n.Attachment.video
                    case "image":
                        attachmentName = L10n.Attachment.image
                    case "voice":
                        attachmentName = L10n.Attachment.voice
                    case "file":
                        attachmentName = L10n.Attachment.file
                    default:
                        attachmentName = ""
                    }
                    let font = appearance.replyMessageAppearance.subtitleLabelAppearance.font
                    let color = appearance.replyMessageAppearance.subtitleLabelAppearance.foregroundColor

                    let text = NSMutableAttributedString(
                        string: attachmentName,
                        attributes: [
                            .font: font as Any,
                            .foregroundColor: color as Any
                        ]
                    )

                    // Add addCircleDashed icon at the beginning
                    let tintedIcon = Images.addCircleDashed.withTintColor(color, renderingMode: .alwaysTemplate)
                    let attachment = NSTextAttachment()
                    attachment.bounds = CGRect(x: 0, y: (font.capHeight - 16.0).rounded() / 2, width: 16.0, height: 16.0)
                    attachment.image = tintedIcon
                    let iconAttributedString = NSMutableAttributedString(attachment: attachment)
                    iconAttributedString.append(NSAttributedString(string: " ", attributes: [.font: font as Any]))
                    text.insert(iconAttributedString, at: 0)

                    self.attributedBody = text
                } else {
                    self.attributedBody = appearance.replyMessageAppearance.messageBodyFormatter.format(
                        .init(
                            message: message,
                            deletedStateText: appearance.deletedStateText,
                            bodyLabelAppearance: appearance.replyMessageAppearance.subtitleLabelAppearance,
                            mentionLabelAppearance: appearance.replyMessageAppearance.mentionLabelAppearance,
                            attachmentDurationLabelAppearance: appearance.replyMessageAppearance.attachmentDurationLabelAppearance,
                            deletedLabelAppearance: appearance.replyMessageAppearance.deletedLabelAppearance,
                            attachmentDurationFormatter: appearance.replyMessageAppearance.attachmentDurationFormatter,
                            attachmentNameFormatter: appearance.replyMessageAppearance.attachmentNameFormatter,
                            mentionUserNameFormatter: appearance.mentionUserNameFormatter,
                            replyUserNameFormatter: SceytChatUIKit.shared.formatters.replyUserNameFormatter
                        )
                    )
                }
                icon = makeIcon()
            }
        
        public func updateAttachment(message: ChatMessage) {
            guard self.message == message
            else { return }
            if let attachment = message.attachments?.first {
                // Reuse the existing layout when it already describes this attachment: building a
                // new one throws away a thumbnail that is already loaded, so the reply image would
                // flick back to its placeholder on every update.
                if let existing = self.attachment, existing.attachment == attachment {
                    existing.update(attachment: attachment)
                    return
                }
                self.attachment = Components.messageAttachmentLayoutModel.init(
                    attachment: attachment,
                    ownerMessage: message,
                    ownerChannel: self.attachment?.ownerChannel,
                    thumbnailSize: thumbnailSize ?? Components.messageCellReplyView.Measure.imageSize,
                    asyncLoadThumbnail: true,
                    appearance: appearance)
            }
        }
                
        open func makeIcon() -> UIImage? {
            // Check for poll first
            if message.poll != nil {
                let pollIcon = UIImage.chatActionPoll
                let targetSize = CGSize(width: 16, height: 16)
                let resizedIcon = resizeImage(pollIcon, to: targetSize)
                return resizedIcon?.withRenderingMode(.alwaysTemplate)
            }

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

        private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            defer { UIGraphicsEndImageContext() }
            image.draw(in: CGRect(origin: .zero, size: size))
            return UIGraphicsGetImageFromCurrentImageContext()
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

    // MARK: - Read More Functionality
    open func updateTextSizeForExpanded() {
        guard contentOptions.contains(.text), shouldShowReadMore, !isTextExpanded else { return }

        // Text is already at full size, just need to mark as expanded
        isTextExpanded = true

        // Recalculate measure size (this will use full textSize instead of truncatedTextSize)
        measureSize = measure()
    }
}

extension MessageLayoutModel: Comparable {
    
    public static func < (lhs: MessageLayoutModel, rhs: MessageLayoutModel) -> Bool {
        lhs.message < rhs.message
    }
}

fileprivate extension MessageLayoutModel.LinkPreview {
    
    var hasImage: Bool {
        image != nil
    }
    
    var hasIcon: Bool {
        icon != nil
    }
}

fileprivate extension LinkMetadata {
    
    var hasImage: Bool {
        image != nil
    }
    
    var hasIcon: Bool {
        icon != nil
    }
}
