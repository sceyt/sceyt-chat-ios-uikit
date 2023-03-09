//
//  ComposerVC.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit

open class ComposerVC: ViewController {
    
    open lazy var addMediaButton = UIButton()
        .withoutAutoresizingMask

    open lazy var sendButton = UIButton()
        .withoutAutoresizingMask

    open lazy var recordButton = UIImageView()
        .contentMode(.center)
        .withoutAutoresizingMask

    open lazy var separatorViewTop = UIView()
        .withoutAutoresizingMask

    open lazy var separatorViewCenter = UIView()
        .withoutAutoresizingMask

    open lazy var mediaView = Components.composerMediaView
        .init()
        .withoutAutoresizingMask

    open lazy var inputTextView = Components.composerInputTextView
        .init()
        .withoutAutoresizingMask

    open lazy var actionView = Components.composerActionView
        .init()
        .withoutAutoresizingMask

    open lazy var recorderView = RecorderView { [weak self] in
        guard let self else { return }
        switch $0 {
        case .noPermission:
            self.showNoMicrophonePermission()
        case let .send(url, metadata):
            if let url = Storage.copyFile(url) {
                self.mediaView.insert(view: AttachmentView(voiceUrl: url, metadata: metadata))
                self.action = .send(false)
            }
        }
    }

    public var isRecording: Bool { recorderView.superview != nil }

    public var canRunMentionUserLogic = true
    open var mentionUserListVC: (() -> MentioningUserListVC)?
    open weak var presentedMentionUserListVC: MentioningUserListVC?
    public var isPresentedMentionUserListVC: Bool {
        presentedMentionUserListVC != nil
    }
    open lazy var router = Components.composerRouter
        .init(rootVC: self)

    open var mentionSymbol: String { Config.mentionSymbol }
    open var onContentHeightUpdate: ((CGFloat) -> Void)?

    @Published public var action: Action?

    public static var actionViewHeight = CGFloat(64)

    private var selectedPhotoAssetIdentifiers = Set<String>()
    private var actionViewHeightLayoutConstraint: NSLayoutConstraint!

    deinit {
        recorderView.stop()
        recorderView.removeFromSuperview()
    }

    override open func setup() {
        super.setup()
        _ = view.withoutAutoresizingMask
        mediaView._onUpdate = { [unowned self] in
            updateState()
        }
        mediaView._onDelete = { [unowned self] view in
            action = .deleteMedia(view)
            if let id = view.photoAsset?.localIdentifier {
                selectedPhotoAssetIdentifiers.remove(id)
            }
        }
        inputTextView.delegate = self
        inputTextView.$event
            .compactMap { $0 }
            .sink { [unowned self] in
                switch $0 {
                case .update:
                    updateState()
                    updateMentions()
                case .paste:
                    break

                case let .contentSizeUpdate(old: _, new: new):
                    update(height: max(0, new))
                }

            }.store(in: &subscriptions)
        
        updateState()

        actionView.cancelButton.addTarget(self, action: #selector(replyCancelAction), for: .touchUpInside)
        addMediaButton.addTarget(self, action: #selector(addMediaButtonAction(_:)), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendButtonAction(_:)), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: recorderView, action: #selector(RecorderView.onLongPress))
        longPress.minimumPressDuration = 0.05
        recordButton.isUserInteractionEnabled = true
        recordButton.addGestureRecognizer(longPress)
    }

    override open func paste(_ sender: Any?) {
        if let image = UIPasteboard.general.image,
           let jpeg = Components.imageBuilder.init(image: image).jpegData(),
           let url = Storage.storeData(jpeg, filename: UUID().uuidString + ".jpg")
        {
            mediaView.insert(view: .init(mediaUrl: url, thumbnail: image))
            action = .send(true)
        } else if let string = UIPasteboard.general.string {
            inputTextView.text = ((inputTextView.text ?? "") as NSString).replacingCharacters(in: inputTextView.selectedRange, with: string)
        }
    }

    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = Colors.background
        addMediaButton.setImage(Images.attachment, for: .normal)
        sendButton.setImage(Images.messageSendAction, for: .normal)
        recordButton.image = Images.audioPlayerMic
        separatorViewTop.backgroundColor = Colors.background4
        separatorViewCenter.backgroundColor = Colors.background4
        actionView.isHidden = true
        separatorViewCenter.isHidden = true
    }

    override open func setupLayout() {
        super.setupLayout()

        view.addSubview(separatorViewTop)
        view.addSubview(separatorViewCenter)
        view.addSubview(actionView)
        view.addSubview(mediaView)
        view.addSubview(inputTextView)
        view.addSubview(addMediaButton)
        view.addSubview(sendButton)
        view.addSubview(recordButton)

        separatorViewTop.pin(to: view, anchors: [.leading(), .trailing(), .top()])
        separatorViewTop.resize(anchors: [.height(0.5)])

        separatorViewCenter.pin(to: view, anchors: [.leading(), .trailing()])
        separatorViewCenter.resize(anchors: [.height(0.5)])
        separatorViewCenter.topAnchor.pin(to: mediaView.bottomAnchor)

        actionView.leadingAnchor.pin(to: view.leadingAnchor, constant: 14)
        actionView.trailingAnchor.pin(to: view.trailingAnchor)
        actionView.topAnchor.pin(to: separatorViewTop.bottomAnchor)
        actionViewHeightLayoutConstraint = actionView.heightAnchor.pin(constant: 0)

        mediaView.leadingAnchor.pin(to: view.leadingAnchor)
        mediaView.trailingAnchor.pin(to: view.trailingAnchor)
        mediaView.topAnchor.pin(to: actionView.bottomAnchor)
        mediaView.heightAnchor.pin(constant: 0)

        addMediaButton.pin(to: view, anchors: [.leading(), .bottom()])
        addMediaButton.resize(anchors: [.height(52), .width(52)])

        sendButton.pin(to: view, anchors: [.trailing(), .bottom()])
        sendButton.resize(anchors: [.height(52), .width(52)])

        recordButton.pin(to: sendButton)

        inputTextView.leadingAnchor.pin(to: addMediaButton.trailingAnchor)
        inputTextView.trailingAnchor.pin(to: sendButton.leadingAnchor)
        inputTextView.trailingAnchor.pin(to: recordButton.leadingAnchor)
        inputTextView.topAnchor.pin(to: mediaView.bottomAnchor, constant: 8)
        inputTextView.bottomAnchor.pin(to: view.bottomAnchor, constant: -8)
    }

    open func updateState() {
        sendButton.isHidden = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mediaView.items.isEmpty
        recordButton.isHidden = !sendButton.isHidden
        style = mediaView.items.count > 0 ? .large : .small
        separatorViewCenter.isHidden = mediaView.items.count == 0
    }

    open func update(height: CGFloat) {
        guard view.bounds.height > 0, inputTextView.bounds.height > 0
        else { return }
        var updateHeight = CGFloat(Int(height + view.bounds.height - inputTextView.bounds.height))
        if updateHeight < style.preferredMinHeight {
            updateHeight = style.preferredMinHeight
        } else if updateHeight > style.preferredMaxHeight {
            updateHeight = style.preferredMaxHeight
        }
        onContentHeightUpdate?(updateHeight)
    }

    private var _updateMentionsText: String?
    
    open func mentionTextRange(attributedText: NSAttributedString, at location: Int) -> MentionString {
        var ms = MentionString(queryRange: NSRange(location: location, length: 0))
        guard location > 0 else { return ms }
        let text = inputTextView.text as NSString
        if attributedText.length == location,
            (attributedText.string == mentionSymbol || attributedText.string.hasSuffix(" " + mentionSymbol) || attributedText.string.hasSuffix("\n" + mentionSymbol)) {
            ms.exist = true
            ms.queryRange = NSRange(location: location - 1, length: 1)
            return ms
        }
        let lastRange = text.rangeOfCharacter(from: CharacterSet(charactersIn: mentionSymbol),
                                              options: .backwards,
                                              range: NSRange(location: 0, length: location))
        guard lastRange.location != NSNotFound else { return ms }
        if lastRange.location > 0,
            text.substring(with: .init(location: lastRange.location - 1, length: 1)) != " " {
            ms.exist = false
            ms.queryRange = NSRange(location: location - 1, length: 1)
            return ms
        }
        let range = NSRange(location: lastRange.upperBound, length: location - lastRange.upperBound)
        let searchText = text.substring(with: range)
        var effectiveRange = NSRange()
        let userId = attributedText.attributes(at: location - 1, effectiveRange: &effectiveRange)[.customKey] as? String
        let nextWord = isPresentedMentionUserListVC ? true : !searchText.contains(" ")
        guard nextWord || userId != nil else {
            return ms
        }
        ms.exist = true
        ms.id = userId
        ms.query = searchText
        ms.idRange = effectiveRange
        ms.queryRange = NSRange(location: lastRange.location, length: location - lastRange.location)
        return ms
    }
    
    open func deleteMentionText(in range: NSRange) -> Bool {
        guard let attributedText = inputTextView.attributedText
        else { return false }
        let ms = mentionTextRange(attributedText: attributedText, at: range.upperBound)
        guard ms.exist, ms.id != nil, let replacingRange = ms.idRange
        else { return false }
        let mutableAttributed = NSMutableAttributedString(attributedString: attributedText)
        mutableAttributed.replaceCharacters(in: replacingRange, with: "")
        self.inputTextView.attributedText = mutableAttributed
        DispatchQueue.main.async {[weak self] in
            guard let self else { return }
            let start = self.inputTextView.beginningOfDocument
            if let newPosition = self.inputTextView.position(from: start, offset: min(replacingRange.lowerBound, mutableAttributed.length)) {
                self.inputTextView.selectedTextRange = self.inputTextView.textRange(from: newPosition, to: newPosition)
            }
            
        }
        dismiss()
        return true
    }
    private var lastMentionQueryRange: NSRange?
    open func updateMentions() {
        guard canRunMentionUserLogic else { return }
        func attributedString(_ text: String, key: String) -> NSAttributedString {
            NSAttributedString(string: text, attributes: [.font: inputTextView.font as Any,
                                                          .foregroundColor: Colors.kitBlue,
                                                          .customKey: key])
        }

        func attributedSpace() -> NSAttributedString {
            NSAttributedString(string: " ", attributes: [.font: inputTextView.font as Any, .foregroundColor: UIColor.darkText])
        }

        
        func isExist(attributedText: NSAttributedString, userId: String) -> Bool {
            var ret = false
            attributedText
                .enumerateAttribute(.customKey,
                                    in: NSRange(location: 0, length: attributedText.length)) { obj, _, done in
                    if let id = obj as? String, id == userId {
                        ret = true
                        done.pointee = true
                    }
                }
            return ret
        }

        guard inputTextView.text != _updateMentionsText else { return }
        let text = inputTextView.text as NSString

        guard let attributedText = inputTextView.attributedText, text.length > 0 else {
            dismiss()
            return
        }
        let selectedLocation = inputTextView.selectedRange.location
        let ms = mentionTextRange(attributedText: attributedText, at: selectedLocation)
        guard ms.exist else {
            dismiss()
            return
        }
        
        lastMentionQueryRange = ms.queryRange
        if let vc = presentedMentionUserListVC {
            vc.filter(text: ms.query)
            return
        }
        present { [weak self] id, displayName in
            defer { self?.dismiss() }
            guard let self = self,
                  let replacingRange = self.lastMentionQueryRange,
                    !isExist(attributedText: attributedText, userId: id)
            else { return }
            let mentionText = attributedString(self.mentionSymbol + displayName, key: id)
            let mutableAttributed = NSMutableAttributedString(attributedString: self.inputTextView.attributedText)
            mutableAttributed.insert(attributedSpace(), at: replacingRange.upperBound)
            mutableAttributed.replaceCharacters(in: replacingRange, with: mentionText)
            self._updateMentionsText = mutableAttributed.string
            self.inputTextView.attributedText = mutableAttributed
            self.inputTextView.selectedRange = .init(location: replacingRange.location + mentionText.length + 1, length: 0)
        }
    }
    
    open func showNoMicrophonePermission() {
        showAlert(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureErrorKey: "No permission!"]))
    }

    @objc
    open func replyCancelAction() {
        removeActionView()
        mediaView.removeAll()
        inputTextView.text = nil
        action = .cancel
    }

    @objc
    open func addMediaButtonAction(_ sender: UIButton) {
        inputTextView.resignFirstResponder()
        router
            .showAttachmentAlert(
                sources: [.media, .camera, .file],
                sourceView: sender)
        { [unowned self] source in
            switch source {
            case .media:
                openPhotoPicker()
            case .camera:
                openCameraPicker()
            case .file:
                openDocumentsPicker()
            case .none:
                return
            }
        }
    }

    open func openPhotoPicker() {
        router.showPhotos(selectedPhotoAssetIdentifiers: selectedPhotoAssetIdentifiers)
            { [unowned self] assets in
                if let assets {
                    for (index, asset) in assets.enumerated() {
                        selectedPhotoAssetIdentifiers.insert(asset.localIdentifier)
                        AttachmentView.view(from: asset) { view in
                            if let view {
                                self.mediaView.insert(view: view, at: index)
                            }
                        }
                    }
                }
               
                DispatchQueue.main.async { [weak self] in
                    self?.inputTextView.becomeFirstResponder()
                }
            }
    }

    open func openDocumentsPicker() {
        router.showDocuments { [unowned self] urls in
            urls.forEach {
                self.mediaView.insert(view: AttachmentView(fileUrl: $0))
            }
            DispatchQueue.main.async { [weak self] in
                self?.inputTextView.becomeFirstResponder()
            }
        }
    }

    open func openCameraPicker() {
        router.showCamera { [unowned self] attachmentView in
            guard let attachmentView else { return }
            self.mediaView
                .insert(view: attachmentView)
            DispatchQueue.main.async { [weak self] in
                self?.inputTextView.becomeFirstResponder()
            }
        }
    }

//    private static var _textIndex = 100
//        private static let loren = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
    @objc
    open func sendButtonAction(_ sender: UIButton) {
        selectedPhotoAssetIdentifiers.removeAll()
        action = .send(true)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//            guard let self else { return }
//            let rnd = 9 + arc4random_uniform(UInt32(Self.loren.count - 10))
//            self.inputTextView.text = "\(Self._textIndex) \(Self.loren.substring(toIndex: Int(rnd)))"
//            Self._textIndex += 1
//            if Self._textIndex > 100, Self._textIndex % 100 == 0 {
//                return
//            }
//            self.sendButtonAction(self.sendButton)
//        }
    }

    open func addReply(message: ChatMessage, image: UIImage? = nil) {
        removeActionView()
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.image = .composerReplyMessage
        actionView.imageView.isHidden = image == nil
        actionView.imageView.image = image

        let title = Formatters.userDisplayName.format(message.user)
        let text: String
        if message.body.isEmpty,
           let attachment = message.attachments?.first
        {
            switch attachment.type {
            case "image":
                text = L10n.Message.Attachment.image
            case "video":
                text = L10n.Message.Attachment.video
            case "voice":
                text = L10n.Message.Attachment.voice
            default:
                text = L10n.Message.Attachment.file
            }
        } else {
            text = message.body
        }
        let titleAttributedString = NSMutableAttributedString(
            string: L10n.Composer.reply + " ",
            attributes: [.font: appearance.actionReplyTitleFont ?? Fonts.regular.withSize(12)])
        titleAttributedString.append(
            .init(
                string: title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "),
                attributes: [.font: appearance.actionReplierTitleFont ?? Fonts.bold.withSize(12)]))
        actionView.titleLabel.attributedText = titleAttributedString
        actionView.messageLabel.text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        actionViewHeightLayoutConstraint.constant = Self.actionViewHeight
        onContentHeightUpdate?(view.bounds.height + Self.actionViewHeight)
    }

    open func addEdit(message: ChatMessage, image: UIImage? = nil) {
        removeActionView()
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.image = .composerEditMessage
        actionView.imageView.isHidden = image == nil
        actionView.imageView.image = image
        let title = ""
        let text: String
        if message.body.isEmpty,
           let attachment = message.attachments?.first
        {
            switch attachment.type {
            case "image":
                text = L10n.Message.Attachment.image
            case "video":
                text = L10n.Message.Attachment.video
            case "voice":
                text = L10n.Message.Attachment.voice
            default:
                text = L10n.Message.Attachment.file
            }
        } else {
            text = message.body
        }
        let titleAttributedString = NSMutableAttributedString(
            string: L10n.Composer.edit + " ",
            attributes: [.font: appearance.actionReplyTitleFont ?? Fonts.regular.withSize(12)])
        titleAttributedString.append(
            .init(
                string: title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "),
                attributes: [.font: appearance.actionReplierTitleFont ?? Fonts.bold.withSize(12)]))
        actionView.titleLabel.attributedText = titleAttributedString
        actionView.messageLabel.text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        actionViewHeightLayoutConstraint.constant = Self.actionViewHeight

        onContentHeightUpdate?(view.bounds.height + Self.actionViewHeight)
    }

    open func removeActionView() {
        selectedPhotoAssetIdentifiers.removeAll()
        guard !actionView.isHidden else { return }
        actionView.titleLabel.text = nil
        actionView.messageLabel.text = nil
        actionViewHeightLayoutConstraint.constant = 0
        actionView.imageView.isHidden = true
        actionView.isHidden = true
        separatorViewCenter.isHidden = true
        onContentHeightUpdate?(view.bounds.height - Self.actionViewHeight)
    }

    open private(set) var style = Style.small {
        didSet {
            if style != oldValue {
                let height = view.bounds.height
                let mediaHeight = mediaView.constraints.first(where: { $0.firstAttribute == .height })
                let old = mediaHeight?.constant ?? 0
                let new = style.preferredMediaHeight
                mediaHeight?.constant = new
                switch style {
                case .small:
                    onContentHeightUpdate?(height - old)
                case .large:
                    onContentHeightUpdate?(height + new)
                }
            }
        }
    }

    open func present(_ callback: @escaping (String, String) -> Void) {
        guard let parent = parent else { return }
        guard let vc = mentionUserListVC?() else {
            return
        }
        presentedMentionUserListVC = vc
        parent.addChild(vc)
        parent.view.addSubview(vc.view)
        _ = vc.view.withoutAutoresizingMask
        (parent as? ChannelVC)?.collectionView.isUserInteractionEnabled = false
        vc.view.pin(to: parent.view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])
        vc.view.bottomAnchor.pin(to: view.topAnchor)
        vc.didSelectMember = { callback($0.id, Formatters.userDisplayName.format($0)) }
    }

    open func dismiss() {
        guard let parent = parent else { return }
        guard let vc = presentedMentionUserListVC, vc.parent != nil else { return }
        vc.didSelectMember = nil
        (parent as? ChannelVC)?.collectionView.isUserInteractionEnabled = true
        vc.view.removeConstraints(vc.view.constraints)
        vc.removeFromParent()
        vc.view.removeFromSuperview()
        presentedMentionUserListVC = nil
    }
}

extension ComposerVC: UITextViewDelegate {
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        inputTextView.typingAttributes = [.foregroundColor: UIColor.darkText, .font: inputTextView.font as Any]
        if textView.text.count == range.location, !text.isEmpty {
            return true
        }
        
        return !deleteMentionText(in: range)
    }

}

public extension ComposerVC {
    enum Style {
        case small
        case large

        public var preferredMediaHeight: CGFloat {
            switch self {
            case .small:
                return CGFloat(0)
            case .large:
                return CGFloat(88)
            }
        }

        public var preferredMinHeight: CGFloat {
            switch self {
            case .small:
                return CGFloat(52)
            case .large:
                return CGFloat(112)
            }
        }

        public var preferredMaxHeight: CGFloat {
            switch self {
            case .small:
                return CGFloat(200)
            case .large:
                return CGFloat(260)
            }
        }
    }

    enum Action {
        case send(Bool)
        case cancel
        case deleteMedia(AttachmentView)
    }
    
    struct MentionString {
        public var exist = false
        public var id: String?
        public var query: String?
        public var idRange: NSRange?
        public var queryRange: NSRange
        
        public init(
            exist: Bool = false,
            id: String? = nil,
            query: String? = nil,
            idRange: NSRange? = nil,
            queryRange: NSRange
        ) {
            self.exist = exist
            self.id = id
            self.query = query
            self.idRange = idRange
            self.queryRange = queryRange
        }
    }
}
