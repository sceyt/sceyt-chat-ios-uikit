//
//  ComposerVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit
import CoreText

open class ComposerVC: ViewController, UITextViewDelegate {
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
    
    open lazy var backgroundView = UIView()
        .withoutAutoresizingMask
    
    public var isRecording: Bool { recorderView.recorder?.audioRecorder?.isRecording == true }
    
    public private(set) var currentState: State? {
        didSet {
            action = .didActivateState(currentState)
        }
    }
    public private(set) var nextState: State?
    
    open lazy var recorderView = RecorderView { [weak self] in
        guard let self else { return }
        switch $0 {
        case .noPermission:
            self.showNoMicrophonePermission()
        case let .recorded(url, metadata):
            self.recordedView.isHidden = false
            self.recordedView.setup(url: url, metadata: metadata)
        case let .send(url, metadata):
            if let url = Components.storage.copyFile(url) {
                self.mediaView.insert(view: AttachmentView(voiceUrl: url, metadata: metadata))
                self.action = .send(false)
            }
        case .didStartRecording:
            self.action = .didStartRecording
        case .didStopRecording:
            self.action = .didStopRecording
        }
    }
    
    open lazy var recordedView = RecordedView()
        .withoutAutoresizingMask
    
    open var shouldHideRecordButton = false {
        didSet {
            updateState()
        }
    }
    
    public var canRunMentionUserLogic = true
    open var mentionUserListVC: (() -> MentioningUserListVC)?
    open weak var presentedMentionUserListVC: MentioningUserListVC?
    public var isPresentedMentionUserListVC: Bool {
        presentedMentionUserListVC != nil
    }
    
    open lazy var router = Components.composerRouter
        .init(rootVC: self)
    
    open var mentionSymbol: String { Config.mentionSymbol }
    open var onContentHeightUpdate: ((CGFloat, (()-> Void)?) -> Void)?
    
    @Published public var action: Action?
    
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                switch $0 {
                case .textChanged:
                    self.updateState()
                    self.updateMentions()
                case let .contentSizeUpdate(old: _, new: new):
                    self.update(height: max(0, new))
                }
            }.store(in: &subscriptions)
        
        inputTextView
            .formatEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                switch $0 {
                case .bold:
                    self.toggleAttribute(component: .bold, range: self.inputTextView.selectedRange, textView: self.inputTextView)
                case .italic:
                    self.toggleAttribute(component: .italic, range: self.inputTextView.selectedRange, textView: self.inputTextView)
                case .monospace:
                    self.toggleAttribute(component: .monospace, range: self.inputTextView.selectedRange, textView: self.inputTextView)
                case .strikethrough:
                    self.toggleAttribute(component: .strikethrough, range: self.inputTextView.selectedRange, textView: self.inputTextView)
                case .underline:
                    self.toggleAttribute(component: .underline, range: self.inputTextView.selectedRange, textView: self.inputTextView)
                }
            }.store(in: &subscriptions)

        recordedView.onEvent = { [weak self] in
            guard let self else { return }
            switch $0 {
            case .cancel:
                self.recordedView.isHidden = true
            case let .send(url, metadata):
                self.recordedView.isHidden = true
                if let url = Components.storage.copyFile(url) {
                    self.mediaView.insert(view: AttachmentView(voiceUrl: url, metadata: metadata))
                    self.action = .send(false)
                }
            }
        }
        
        updateState()
        
        actionView.cancelButton.addTarget(self, action: #selector(actionViewCancelAction), for: .touchUpInside)
        addMediaButton.addTarget(self, action: #selector(addMediaButtonAction(_:)), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendButtonAction(_:)), for: .touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: recorderView, action: #selector(RecorderView.onLongPress))
        longPress.minimumPressDuration = 0.05
        recordButton.isUserInteractionEnabled = true
        recordButton.addGestureRecognizer(longPress)
        
        actionView.isHidden = true
        separatorViewCenter.isHidden = true
    }
    
    override open func paste(_ sender: Any?) {
        if let image = UIPasteboard.general.image,
           let jpeg = Components.imageBuilder.init(image: image).jpegData(),
           let url = Components.storage.storeData(jpeg, filename: UUID().uuidString + ".jpg")
        {
            mediaView.insert(view: .init(mediaUrl: url, thumbnail: image))
            action = .send(true)
        } else if let string = UIPasteboard.general.string {
            inputTextView.text = ((inputTextView.text ?? "") as NSString).replacingCharacters(in: inputTextView.selectedRange, with: string)
        }
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        backgroundView.backgroundColor = appearance.backgroundColor
        addMediaButton.setImage(.attachment, for: .normal)
        sendButton.setImage(.messageSendAction, for: .normal)
        recordButton.image = .audioPlayerMic
        separatorViewTop.backgroundColor = appearance.dividerColor
        separatorViewCenter.backgroundColor = appearance.dividerColor
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(actionView)
        view.addSubview(backgroundView)
        view.addSubview(mediaView)
        view.addSubview(inputTextView)
        view.addSubview(addMediaButton)
        view.addSubview(sendButton)
        view.addSubview(recordButton)
        view.addSubview(recordedView)
        view.addSubview(separatorViewCenter)
        view.addSubview(separatorViewTop)
        
        backgroundView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        backgroundView.topAnchor.pin(to: inputTextView.topAnchor, constant: -8)
        
        separatorViewTop.pin(to: view, anchors: [.leading(), .trailing(), .top()])
        separatorViewTop.resize(anchors: [.height(0.5)])
        
        separatorViewCenter.pin(to: view, anchors: [.leading(), .trailing()])
        separatorViewCenter.resize(anchors: [.height(0.5)])
        separatorViewCenter.bottomAnchor.pin(to: inputTextView.topAnchor, constant: -8)
        
        actionView.pin(to: view, anchors: [.leading, .trailing])
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
        inputTextView.topAnchor.pin(to: mediaView.bottomAnchor, constant: 8).priority(.defaultLow)
        inputTextView.heightAnchor.pin(greaterThanOrEqualToConstant: 36)
        inputTextView.bottomAnchor.pin(to: view.bottomAnchor, constant: -8)
        
        recordedView.pin(to: view, anchors: [.leading, .trailing, .top])
        recordedView.isHidden = true
    }
    
    open func updateState() {
        sendButton.isHidden = inputTextView.text.replacingOccurrences(of: "\u{fffc}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mediaView.items.isEmpty
        recordButton.isHidden = !sendButton.isHidden
        style = mediaView.items.count > 0 ? .large : .small
        separatorViewCenter.isHidden = mediaView.items.count == 0
        if sendButton.isHidden {
            sendButton.cancelTracking(with: nil)
        }
        recordButton.isHidden = !sendButton.isHidden || shouldHideRecordButton
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
        onContentHeightUpdate?(updateHeight, nil)
    }
    
    private var _updateMentionsText: String?
    
    open func mentionTextRange(attributedText: NSAttributedString, at location: Int) -> MentionString {
        var ms = MentionString(queryRange: NSRange(location: location, length: 0))
        let text = inputTextView.text as NSString
        if attributedText.length == location,
           attributedText.string == mentionSymbol || attributedText.string.hasSuffix(" " + mentionSymbol) || attributedText.string.hasSuffix("\n" + mentionSymbol)
        {
            ms.exist = true
            ms.queryRange = NSRange(location: location - 1, length: 1)
            return ms
        }
        let lastRange = text.rangeOfCharacter(from: CharacterSet(charactersIn: mentionSymbol),
                                              options: .backwards,
                                              range: NSRange(location: 0, length: location))
        guard lastRange.location != NSNotFound else { return ms }
        if lastRange.location > 0,
           text.substring(with: .init(location: lastRange.location - 1, length: 1)) != " "
        {
            ms.exist = false
            ms.queryRange = NSRange(location: location - 1, length: 1)
            return ms
        }
        let range = NSRange(location: lastRange.upperBound, length: location - lastRange.upperBound)
        let searchText = text.substring(with: range)
        var effectiveRange = NSRange()
        let userId = attributedText.attributes(at: location - 1, effectiveRange: &effectiveRange)[.mention] as? String
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
        mutableAttributed.safeReplaceCharacters(in: replacingRange, with: "")
        inputTextView.attributedText = mutableAttributed
        DispatchQueue.main.async { [weak self] in
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
                                                          .mention: key])
        }
        
        func attributedSpace() -> NSAttributedString {
            NSAttributedString(string: " ", attributes: [.font: inputTextView.font as Any, .foregroundColor: UIColor.darkText])
        }
        
        func isExist(attributedText: NSAttributedString, userId: String) -> Bool {
            var ret = false
            attributedText
                .enumerateAttribute(.mention,
                                    in: NSRange(location: 0, length: attributedText.length))
            { obj, _, done in
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
                  let replacingRange = self.lastMentionQueryRange
                    //                  !isExist(attributedText: attributedText, userId: id)
            else { return }
            let mentionText = attributedString(self.mentionSymbol + displayName, key: id)
            let mutableAttributed = NSMutableAttributedString(attributedString: self.inputTextView.attributedText)
            mutableAttributed.insert(attributedSpace(), at: replacingRange.upperBound)
            mutableAttributed.safeReplaceCharacters(in: replacingRange, with: mentionText)
            self._updateMentionsText = mutableAttributed.string
            self.inputTextView.attributedText = mutableAttributed
            self.inputTextView.selectedRange = .init(location: replacingRange.location + mentionText.length + 1, length: 0)
        }
        if ms.exist, let query = ms.query {
            presentedMentionUserListVC?.filter(text: query)
        }
    }
    
    open func showNoMicrophonePermission() {
        showAlert(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureErrorKey: "No permission!"]))
    }
    
    @objc
    open func actionViewCancelAction() {
        if case .edit = currentState {
            inputTextView.attributedText = cachedMessage
            cachedMessage = nil
        }
        removeActionView()
        mediaView.removeAll()
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
        log.verbose("[ATTACHMENT] openPhotoPicker")
        router.showPhotos(selectedPhotoAssetIdentifiers: selectedPhotoAssetIdentifiers)
        { [unowned self] assets, picker in
            log.verbose("[ATTACHMENT] did select assets \(assets.count)")
            guard !assets.isEmpty else { return true }
            
            let semaphore = DispatchSemaphore(value: 1)
            DispatchQueue.global().async {
                log.verbose("[ATTACHMENT] Start BG task to create attachments from assets")
                assets.forEach { asset in
                    semaphore.wait()
                    AttachmentView.view(from: asset, completion: { [weak self] view in
                        log.verbose("[ATTACHMENT] created attachment \(view?.name)")
                        guard let self else {
                            semaphore.signal()
                            return
                        }
                        if let view {
                            selectedPhotoAssetIdentifiers.insert(asset.localIdentifier)
                            log.verbose("[ATTACHMENT] insert attachment in mediaView")
                            mediaView.insert(view: view)
                        }
                        semaphore.signal()
                    })
                }
                semaphore.wait()
                log.verbose("[ATTACHMENT] did finish create attachments from assets")
                log.verbose("[ATTACHMENT] dismiss PhotoVC ")
                DispatchQueue.main.async { [weak self, weak picker] in
                    guard let self, let picker else {
                        log.verbose("[ATTACHMENT] dismiss PhotoVC failed")
                        semaphore.signal()
                        return
                    }
                    inputTextView.becomeFirstResponder()
                    picker.dismiss(animated: true) {
                        log.verbose("[ATTACHMENT] did dismiss PhotoVC")
                        semaphore.signal()
                    }
                }
            }
            
            return false
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
    
    //    private static var _textIndex = 1000
    //        private static let loren = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
    //
    //    let links = ["http://www.sceyt.com", "http://www.google.com", "http://www.test.com", "http://www.example.com"]
    @objc
    open func sendButtonAction(_ sender: UIButton) {
        addMediaButton.isHidden = false
        selectedPhotoAssetIdentifiers.removeAll()
        action = .send(true)
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        //            guard let self else { return }
        //            let rnd1 = arc4random_uniform(UInt32(min(Self.loren.count, 40)))
        //            let rnd2 = arc4random_uniform(UInt32(min(Self.loren.count, 30)))
        //            let link1 = links.randomElement() ?? ""
        //            let link2 = links.randomElement() ?? ""
        //            let link3 = links.randomElement() ?? ""
        //            self.inputTextView.text = "\(Self._textIndex) \(link1) \(Self.loren.substring(toIndex: Int(rnd1))) \(link2) \(Self.loren.substring(toIndex: Int(rnd2))) \(link3)"
        //            Self._textIndex += 1
        //            if Self._textIndex > 1000, Self._textIndex % 1000 == 0 {
        //                return
        //            }
        //            self.sendButtonAction(self.sendButton)
        //        }
    }
    
    open func addReply(layoutModel: MessageLayoutModel) {
        let hasActionView = !actionView.isHidden
        
        if case .edit = currentState {
            nextState = .reply(layoutModel)
            return
        } else {
            currentState = .reply(layoutModel)
            nextState = nil
        }
        let message = layoutModel.message
        let title = Formatters.userDisplayName.format(message.user)
        var text = layoutModel.attributedView.content.string.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        var image: UIImage?
        if let attachment = message.attachments?.first {
            switch attachment.type {
            case "image":
                if text.isEmpty {
                    text = L10n.Message.Attachment.image
                }
                image = attachment.thumbnailImage
            case "video":
                if text.isEmpty {
                    text = L10n.Message.Attachment.video
                }
                image = attachment.thumbnailImage
            case "voice":
                if text.isEmpty {
                    text = L10n.Message.Attachment.voice
                }
                image = Images.replyVoice
            case "link":
                if text.isEmpty {
                    text = L10n.Message.Attachment.link
                }
                image = nil
            default:
                if text.isEmpty {
                    text = L10n.Message.Attachment.file
                }
                image = .replyFile
            }
        }
        let titleAttributedString = NSMutableAttributedString(
            string: L10n.Composer.reply + ": ",
            attributes: [.font: appearance.actionReplyTitleFont ?? Fonts.regular.withSize(13)])
        titleAttributedString.append(
            .init(
                string: title,
                attributes: [.font: appearance.actionReplierTitleFont ?? Fonts.semiBold.withSize(13)]))
        actionView.titleLabel.attributedText = titleAttributedString
        
        let messageAttributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: appearance.actionMessageFont ?? Fonts.regular.withSize(13),
                .foregroundColor: appearance.actionMessageColor ?? .textGray
            ])
        if let duration = message.attachments?.first?.voiceDecodedMetadata?.duration {
            messageAttributedString.append(.init(
                string: " " + Formatters.videoAssetDuration.format(TimeInterval(duration)),
                attributes: [
                    .font: appearance.actionMessageFont ?? Fonts.regular.withSize(13),
                    .foregroundColor: appearance.actionMessageVoiceDurationColor ?? .kitBlue
                ]))
        }
        actionView.messageLabel.attributedText = messageAttributedString
        
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.isHidden = true
        actionView.iconView.image = .composerReplyMessage
        actionView.imageView.isHidden = image == nil
        actionView.imageView.image = image
        
        actionViewHeightLayoutConstraint.constant = Layouts.actionViewHeight

        view.layoutIfNeeded() // fix: Bad animation on reply
        
        onContentHeightUpdate?(view.bounds.height + (hasActionView ? 0 : Layouts.actionViewHeight), nil)
    }

    var cachedMessage: NSAttributedString?
    open func addEdit(layoutModel: MessageLayoutModel) {
        let hasActionView = !actionView.isHidden

        let state = currentState
        currentState = nil
        nextState = nil
        if case .reply(let model) = state {
            nextState = .reply(model)
        } else {
            nextState = nil
        }
        currentState = .edit(layoutModel)
        let message = layoutModel.message
        var image: UIImage?
        var text = layoutModel.attributedView.content.string
        if let attachment = message.attachments?.first {
            switch attachment.type {
            case "image":
                if text.isEmpty {
                    text = L10n.Message.Attachment.image
                }
                image = attachment.thumbnailImage
            case "video":
                if text.isEmpty {
                    text = L10n.Message.Attachment.video
                }
                image = attachment.thumbnailImage
            case "voice":
                if text.isEmpty {
                    text = L10n.Message.Attachment.voice
                }
                image = Images.replyVoice
            case "link":
                if text.isEmpty {
                    text = L10n.Message.Attachment.link
                }
                image = nil
            default:
                if text.isEmpty {
                    text = L10n.Message.Attachment.file
                }
                image = .replyFile
            }
        }
        let titleAttributedString = NSMutableAttributedString(
            string: L10n.Composer.edit + ": ",
            attributes: [.font: appearance.actionReplyTitleFont ?? Fonts.regular.withSize(12)])
        actionView.titleLabel.attributedText = titleAttributedString
        
        let messageAttributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: appearance.actionMessageFont ?? Fonts.regular.withSize(13),
                .foregroundColor: appearance.actionMessageColor ?? .textGray
            ])
        if let duration = message.attachments?.first?.voiceDecodedMetadata?.duration {
            messageAttributedString.append(.init(
                string: " " + Formatters.videoAssetDuration.format(TimeInterval(duration)),
                attributes: [
                    .font: appearance.actionMessageFont ?? Fonts.regular.withSize(13),
                    .foregroundColor: appearance.actionMessageVoiceDurationColor ?? .kitBlue
                ]))
        }
        actionView.messageLabel.attributedText = messageAttributedString
        
        cachedMessage = inputTextView.attributedText
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.isHidden = true
        actionView.iconView.image = .composerEditMessage
        actionView.imageView.isHidden = image == nil
        actionView.imageView.image = image
        addMediaButton.isHidden = true

        actionViewHeightLayoutConstraint.constant = Layouts.actionViewHeight

        view.layoutIfNeeded() // fix: Bad animation on reply edit

        onContentHeightUpdate?(view.bounds.height + (hasActionView ? 0 : Layouts.actionViewHeight), nil)
    }

    private var isRemovingActionView = false
    open func removeActionView() {
        guard !actionView.isHidden, !isRemovingActionView else { return }
        
        isRemovingActionView = true
        addMediaButton.isHidden = false
        selectedPhotoAssetIdentifiers.removeAll()
        guard !actionView.isHidden else { return }
        actionViewHeightLayoutConstraint.constant = 0
        onContentHeightUpdate?(view.bounds.height - Layouts.actionViewHeight, { [weak self] in
            guard let self else { return }
            self.actionView.titleLabel.text = nil
            self.actionView.messageLabel.text = nil
            self.actionView.imageView.isHidden = true
            self.actionView.isHidden = true
            self.separatorViewCenter.isHidden = true
            self.isRemovingActionView = false
        })
        currentState = nil
        if let state = nextState {
            nextState = nil
            DispatchQueue.main.async {
                switch state {
                case .edit(let model):
                    self.addEdit(layoutModel: model)
                case .reply(let model):
                    self.addReply(layoutModel: model)
                }
            }
        }
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
                    onContentHeightUpdate?(height - old, nil)
                case .large:
                    onContentHeightUpdate?(height + new, nil)
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
    
    open func toggleAttribute(component: ChatMessage.BodyAttribute.AttributeType, range: NSRange, textView: UITextView) {
        guard let mutableText = textView.attributedText.mutableCopy() as? NSMutableAttributedString
        else { return }
        
        let defaultFont = InputTextView.appearance.textFont
        let attributes = mutableText.attributes(at: range.location, effectiveRange: nil)
        
        var isBold = false
        var isItalic = false
        var isMonospace = false
        if let oldFont = attributes[.font] as? UIFont {
            isBold = oldFont.isBold
            isItalic = oldFont.isItalic
            isMonospace = oldFont.isMonospace
        }
        var font: UIFont?

        switch component {
        case .bold:
            if isBold {
                font = defaultFont
            } else {
                font = Formatters.font.toBold(defaultFont)
            }
            if isItalic {
                font = Formatters.font.toItalic(font!)
            }
            if isMonospace {
                font = Formatters.font.toMonospace(font!)
            }
        case .italic:
            if isItalic {
                font = defaultFont
            } else {
                font = Formatters.font.toItalic(defaultFont)
            }
            if isBold {
                font = Formatters.font.toBold(font!)
            }
            if isMonospace {
                font = Formatters.font.toMonospace(font!)
            }
        case .monospace:
            if isMonospace {
                font = defaultFont
            } else {
                font = Formatters.font.toMonospace(defaultFont)
            }
            if isBold {
                font = Formatters.font.toBold(font!)
            }
            if isItalic {
                font = Formatters.font.toItalic(font!)
            }
        case .strikethrough:
            if attributes[.strikethroughStyle] == nil {
                mutableText.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                mutableText.removeAttribute(.strikethroughStyle, range: range)
            }
        case .underline:
            if attributes[.underlineStyle] == nil {
                mutableText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                mutableText.removeAttribute(.underlineStyle, range: range)
            }
        default:
            break
        }
        if let font {
            mutableText.removeAttribute(.font, range: range)
            mutableText.addAttribute(.font, value: font, range: range)
        }
        textView.attributedText = mutableText
        textView.selectedRange = range
    }

    // MARK: UITextViewDelegate

    open func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textView.typingAttributes[.foregroundColor] = InputTextView.appearance.textColor
        
        if text == " " {
            (textView as? InputTextView)?.resetTypingAttributes()
        } else {
            textView.typingAttributes[.font] = inputTextView.font
        }

        if textView.text.count == range.location, !text.isEmpty {
            return true
        }

        return !deleteMentionText(in: range)
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        if textView.text.isEmpty || (textView.selectedRange.location == 0 && textView.selectedRange.length == 0) {
            (textView as? InputTextView)?.resetTypingAttributes()
        }
    }
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        var selectedRange = textView.selectedRange
        if selectedRange.length > 0 {
            if textView.text[selectedRange.location] == mentionSymbol {
                selectedRange = .init(location: selectedRange.location + 1, length: selectedRange.length - 1)
            }
            let mentionRange = mentionTextRange(attributedText: textView.attributedText, at: selectedRange.location)
            if mentionRange.exist, mentionRange.id != nil, let idRange = mentionRange.idRange {
                let startLocation = min(idRange.location, selectedRange.location)
                let endLocation = max(selectedRange.location + selectedRange.length, idRange.location + idRange.length)
                textView.selectedRange = .init(location: startLocation, length: endLocation - startLocation)
            }
        }
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let menuItemsCount = UIMenuController.shared.menuItems?.count ?? 0
        if menuItemsCount > 1 {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let filteredActions: Set<String> = Set([
            "com.apple.menu.format",
            "com.apple.menu.replace"
        ])
        
        let suggestedActions = suggestedActions.filter {
            if let action = $0 as? UIMenu, filteredActions.contains(action.identifier.rawValue) {
                return false
            } else {
                return true
            }
        }
        
        guard !textView.attributedText.string.isEmpty,
              textView.selectedRange.length > 0
        else { return UIMenu(children: suggestedActions) }
        
        let actions: [UIAction] = [
            UIAction(title: AttributeType.bold.string, image: nil) { [weak self] action in
                if let self {
                    self.toggleAttribute(component: .bold, range: range, textView: textView)
                }
            },
            UIAction(title: AttributeType.italic.string, image: nil) { [weak self] action in
                if let self {
                    self.toggleAttribute(component: .italic, range: range, textView: textView)
                }
            },
            UIAction(title: AttributeType.monospace.string, image: nil) { [weak self] action in
                if let self {
                    self.toggleAttribute(component: .monospace, range: range, textView: textView)
                }
            },
            UIAction(title: AttributeType.strikethrough.string, image: nil) { [weak self] action in
                if let self {
                    self.toggleAttribute(component: .strikethrough, range: range, textView: textView)
                }
            },
            UIAction(title: AttributeType.underline.string, image: nil) { [weak self] action in
                if let self {
                    self.toggleAttribute(component: .underline, range: range, textView: textView)
                }
            },
        ]
        
        var updatedActions = suggestedActions
        let formatMenu = UIMenu(title: "Format", image: nil, children: actions)
        updatedActions.insert(formatMenu, at: 1)
        
        return UIMenu(children: updatedActions)
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
                return CGFloat(72)
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
    
    enum State {
        case edit(MessageLayoutModel)
        case reply(MessageLayoutModel)
    }

    enum Action {
        case send(Bool)
        case cancel
        case didActivateState(State?)
        case deleteMedia(AttachmentView)
        case didStartRecording, didStopRecording
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
            queryRange: NSRange)
        {
            self.exist = exist
            self.id = id
            self.query = query
            self.idRange = idRange
            self.queryRange = queryRange
        }
    }
    
}

public extension ComposerVC {
    enum Layouts {
        public static var actionViewHeight: CGFloat = 56
        public static var recorderShadowBlur: CGFloat = 24
    }
}
