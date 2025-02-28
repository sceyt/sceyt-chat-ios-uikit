//
//  MessageInputViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit
import CoreText

open class MessageInputViewController: ViewController, UITextViewDelegate {
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
    
    open lazy var selectedMediaView = Components.messageInputSelectedMediaView
        .init()
        .withoutAutoresizingMask
    
    open lazy var inputTextView = Components.messageInputTextView
        .init()
        .withoutAutoresizingMask
    
    open lazy var actionView = Components.messageInputMessageActionsView
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
    
    open lazy var recorderView = VoiceRecorderView { [weak self] in
        guard let self else { return }
        switch $0 {
        case .noPermission:
            self.showNoMicrophonePermission()
        case let .recorded(url, metadata):
            self.recordedView.isHidden = false
            self.recordedView.setup(url: url, metadata: metadata)
        case let .send(url, metadata):
            if let url = Components.storage.copyFile(url) {
                self.selectedMediaView.insert(view: AttachmentModel(voiceUrl: url, metadata: metadata))
                self.action = .send(false)
            }
        case .didStartRecording:
            self.action = .didStartRecording
        case .didStopRecording:
            self.action = .didStopRecording
        }
    }
    
    open lazy var recordedView = Components.messageInputVoiceRecordPlaybackView.init()
        .withoutAutoresizingMask
    
    open var shouldHideRecordButton = false {
        didSet {
            updateState()
        }
    }
    
    open var shouldHideMediaButton = false {
        didSet {
            updateMediaButtonAppearance(isHidden: shouldHideMediaButton)
        }
    }
    
    public var canRunMentionUserLogic = true
    open var mentionUserListViewController: (() -> MessageInputViewController.MentionUsersListViewController)?
    open weak var presentedMentionUserListViewController: MessageInputViewController.MentionUsersListViewController? {
        didSet {
            presentedMentionUserListViewController?.parentAppearance = appearance.mentionUsersListAppearance
        }
    }
    public var isPresentedMentionUserListViewController: Bool {
        presentedMentionUserListViewController != nil
    }
    
    open lazy var router = Components.inputRouter
        .init(rootViewController: self)
    
    open var mentionTriggerPrefix: String { SceytChatUIKit.shared.config.mentionTriggerPrefix }
    open var onContentHeightUpdate: ((CGFloat, (()-> Void)?) -> Void)?
    
    @Published public var action: Action?
    
    private var selectedPhotoAssetIdentifiers = Set<String>()
    public private(set) var lastDetectedLinkMetadata: LinkMetadata?
    private var actionViewHeightLayoutConstraint: NSLayoutConstraint!
    private var inputTextViewLeadingConstraint: NSLayoutConstraint?
    
    deinit {
        recorderView.stop()
        recorderView.removeFromSuperview()
    }
    
    override open func setup() {
        super.setup()
        _ = view.withoutAutoresizingMask
        selectedMediaView._onUpdate = { [unowned self] in
            updateState()
        }
        selectedMediaView._onDelete = { [unowned self] view in
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
                    self.findLink()
                case let .contentSizeUpdate(old: _, new: new):
                    self.update(height: max(0, new))
                case .pastedImage:
                    guard let images = UIPasteboard.general.images else { return }
                    images.forEach { image in
                        guard let jpeg = Components.imageBuilder.init(image: image).jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality),
                              let url = Components.storage.storeData(jpeg, filename: UUID().uuidString + ".jpg") else {
                            return
                        }
                        self.selectedMediaView.insert(view: .init(mediaUrl: url, thumbnail: image))
                    }
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
                    self.selectedMediaView.insert(view: AttachmentModel(voiceUrl: url, metadata: metadata))
                    self.action = .send(false)
                }
            }
        }
        
        updateState()
        
        actionView.cancelButton.addTarget(self, action: #selector(actionViewCancelAction), for: .touchUpInside)
        addMediaButton.addTarget(self, action: #selector(addMediaButtonAction(_:)), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendButtonAction(_:)), for: .touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: recorderView, action: #selector(Components.messageInputVoiceRecorderView.onLongPress))
        longPress.minimumPressDuration = 0.05
        recordButton.isUserInteractionEnabled = true
        recordButton.addGestureRecognizer(longPress)
        
        actionView.isHidden = true
        separatorViewCenter.isHidden = true
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        backgroundView.backgroundColor = appearance.backgroundColor
        addMediaButton.setImage(appearance.attachmentIcon, for: .normal)
        sendButton.setImage(appearance.sendMessageIcon, for: .normal)
        recordButton.image = appearance.voiceRecordIcon
        separatorViewTop.backgroundColor = appearance.separatorColor
        separatorViewCenter.backgroundColor = appearance.separatorColor
        recorderView.parentAppearance = appearance.voiceRecorderAppearance
        recordedView.parentAppearance = appearance.voiceRecordPlaybackAppearance
        selectedMediaView.parentAppearance = appearance.selectedMediaAppearance
        inputTextView.parentAppearance = appearance.inputAppearance
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(actionView)
        view.addSubview(backgroundView)
        view.addSubview(selectedMediaView)
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
        
        selectedMediaView.leadingAnchor.pin(to: view.leadingAnchor)
        selectedMediaView.trailingAnchor.pin(to: view.trailingAnchor)
        selectedMediaView.topAnchor.pin(to: actionView.bottomAnchor)
        selectedMediaView.heightAnchor.pin(constant: 0)
        
        addMediaButton.pin(to: view, anchors: [.leading(), .bottom()])
        addMediaButton.resize(anchors: [.height(52), .width(52)])
        
        sendButton.pin(to: view, anchors: [.trailing(), .bottom()])
        sendButton.resize(anchors: [.height(52), .width(52)])
        
        recordButton.pin(to: sendButton)
        
        updateMediaButtonAppearance(isHidden: shouldHideMediaButton, animated: false)
        inputTextView.trailingAnchor.pin(to: sendButton.leadingAnchor)
        inputTextView.trailingAnchor.pin(to: recordButton.leadingAnchor)
        inputTextView.topAnchor.pin(to: selectedMediaView.bottomAnchor, constant: 8).priority(.defaultLow)
        inputTextView.heightAnchor.pin(greaterThanOrEqualToConstant: 36)
        inputTextView.bottomAnchor.pin(to: view.bottomAnchor, constant: -8)
        
        recordedView.pin(to: view, anchors: [.leading, .trailing, .top])
        recordedView.isHidden = true
    }
    
    open override func setupDone() {
        super.setupDone()
        shouldHideRecordButton = !appearance.enableVoiceRecord
        shouldHideMediaButton = !appearance.enableSendAttachment
        canRunMentionUserLogic = appearance.enableMention
    }
    
    open func updateState() {
        sendButton.isHidden = inputTextView.text.replacingOccurrences(of: "\u{fffc}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMediaView.items.isEmpty
        style = selectedMediaView.items.count > 0 ? .large : .small
        separatorViewCenter.isHidden = selectedMediaView.items.count == 0
        if sendButton.isHidden {
            sendButton.cancelTracking(with: nil)
        }
        recordButton.isHidden = !sendButton.isHidden || shouldHideRecordButton
        if !selectedMediaView.items.isEmpty, lastDetectedLinkMetadata != nil {
            removeActionView()
        } else if selectedMediaView.items.isEmpty {
            findLink()
        }
    }
    
    open func updateMediaButtonAppearance(isHidden: Bool, animated: Bool = true) {
        let changes = { [unowned self] in
            addMediaButton.alpha = isHidden ? 0 : 1
            
            if let inputTextViewLeadingConstraint {
                view.removeConstraint(inputTextViewLeadingConstraint)
            }
            
            if isHidden {
                inputTextViewLeadingConstraint = inputTextView.leadingAnchor.pin(to: view.leadingAnchor, constant: 8)
            } else {
                inputTextViewLeadingConstraint = inputTextView.leadingAnchor.pin(to: addMediaButton.trailingAnchor)
            }
            
            view.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: changes)
        } else {
            changes()
        }
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
           attributedText.string == mentionTriggerPrefix || attributedText.string.hasSuffix(" " + mentionTriggerPrefix) || attributedText.string.hasSuffix("\n" + mentionTriggerPrefix)
        {
            ms.exist = true
            ms.queryRange = NSRange(location: location - 1, length: 1)
            return ms
        }
        guard location <= text.length else {
            return ms
        }
        let lastRange = text.rangeOfCharacter(from: CharacterSet(charactersIn: mentionTriggerPrefix),                                              options: .backwards,
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
        let nextWord = isPresentedMentionUserListViewController ? true : !searchText.contains(" ")
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
        else {
            let ms = mentionTextRange(attributedText: attributedText, at: range.upperBound + 1)
            if ms.exist, ms.id != nil {
                let mutableAttributed = NSMutableAttributedString(attributedString: attributedText)
                mutableAttributed.safeReplaceCharacters(in: .init(location: range.upperBound, length: 0), with: " ")
                let selectedRange = inputTextView.selectedRange
                inputTextView.attributedText = mutableAttributed
                inputTextView.selectedRange = selectedRange
            }
            return false
        }
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
            NSAttributedString(string: text, attributes: [.font: appearance.mentionLabelAppearance.font,
                                                          .foregroundColor: appearance.mentionLabelAppearance.foregroundColor,
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
        if let viewController = presentedMentionUserListViewController {
            viewController.filter(text: ms.query)
            return
        }
        present { [weak self] id, displayName in
            defer { self?.dismiss() }
            guard let self = self,
                  let replacingRange = self.lastMentionQueryRange
                    //                  !isExist(attributedText: attributedText, userId: id)
            else { return }
            let mentionText = attributedString(self.mentionTriggerPrefix + displayName, key: id)
            let mutableAttributed = NSMutableAttributedString(attributedString: self.inputTextView.attributedText)
            mutableAttributed.insert(attributedSpace(), at: replacingRange.upperBound)
            mutableAttributed.safeReplaceCharacters(in: replacingRange, with: mentionText)
            self._updateMentionsText = mutableAttributed.string
            self.inputTextView.attributedText = mutableAttributed
            self.inputTextView.selectedRange = .init(location: replacingRange.location + mentionText.length + 1, length: 0)
        }
        if ms.exist, let query = ms.query {
            presentedMentionUserListViewController?.filter(text: query)
        }
    }
    
    private var findLinkTask: Task<Void, Error>?
    open func findLink() {
        
        func getUrl() -> URL? {
            guard let text = inputTextView.text, !text.isEmpty
            else {
                return nil
            }
            
            return DataDetector.matches(text: text).first(where: { $0.url?.scheme != "mailto" && $0.url != nil })?.url
        }
        
        guard let text = inputTextView.text, !text.isEmpty
        else {
            if lastDetectedLinkMetadata != nil, self.currentState == nil {
                self.removeActionView()
            }
            return
        }
//        if let findLinkTask, !findLinkTask.isCancelled {
//            findLinkTask.cancel()
//        }
            
        findLinkTask =  Task {[weak self] in
            func removeActionView() async {
                await MainActor.run { [weak self] in
                    guard let self
                    else { return }
                    if self.lastDetectedLinkMetadata != nil, self.currentState == nil  {
                        self.removeActionView()
                    }
                }
            }
            if let url = getUrl() {
                if let last = self?.lastDetectedLinkMetadata, last.url == url {
                    return
                }
                guard let metadata = await try? LinkMetadataProvider.default.fetch(url: url).get()
                else {
                    await removeActionView()
                    return
                }
                if url != getUrl() {
                    return
                }
                await MainActor.run { [weak self] in
                    guard let self
                    else { return }
                    self.addOrUpdateLinkPreview(linkDetails: metadata)
                    
                }
            } else  {
                await removeActionView()
            }
        }
        
    }
    
    open func showNoMicrophonePermission() {
        showAlert(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureErrorKey: "No permission!"]))
    }
    
    @objc
    open func actionViewCancelAction() {
        if lastDetectedLinkMetadata != nil {
            cachedMessage = inputTextView.attributedText
        }
        if case .edit = currentState {
            inputTextView.attributedText = cachedMessage
            cachedMessage = nil
        }
        removeActionView()
        selectedMediaView.removeAll()
        action = .cancel
        findLink()
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
        logger.verbose("[ATTACHMENT] openPhotoPicker")
        router.showPhotos(selectedPhotoAssetIdentifiers: selectedPhotoAssetIdentifiers)
        { [unowned self] assets, picker in
            logger.verbose("[ATTACHMENT] did select assets \(assets.count)")
            guard !assets.isEmpty else { return true }
            
            let semaphore = DispatchSemaphore(value: 1)
            DispatchQueue.global().async {
                logger.verbose("[ATTACHMENT] Start BG task to create attachments from assets")
                assets.forEach { asset in
                    semaphore.wait()
                    AttachmentModel.view(from: asset, completion: { [weak self] view in
                        logger.verbose("[ATTACHMENT] created attachment \(view?.name)")
                        guard let self else {
                            semaphore.signal()
                            return
                        }
                        if let view {
                            selectedPhotoAssetIdentifiers.insert(asset.localIdentifier)
                            logger.verbose("[ATTACHMENT] insert attachment in selectedMediaView")
                            selectedMediaView.insert(view: view)
                        }
                        semaphore.signal()
                    })
                }
                semaphore.wait()
                logger.verbose("[ATTACHMENT] did finish create attachments from assets")
                logger.verbose("[ATTACHMENT] dismiss PhotoViewController ")
                DispatchQueue.main.async { [weak self, weak picker] in
                    guard let self, let picker else {
                        logger.verbose("[ATTACHMENT] dismiss PhotoViewController failed")
                        semaphore.signal()
                        return
                    }
                    inputTextView.becomeFirstResponder()
                    picker.dismiss(animated: true) {
                        logger.verbose("[ATTACHMENT] did dismiss PhotoViewController")
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
                self.selectedMediaView.insert(view: AttachmentModel(fileUrl: $0))
            }
            DispatchQueue.main.async { [weak self] in
                self?.inputTextView.becomeFirstResponder()
            }
        }
    }
    
    open func openCameraPicker() {
        router.showCamera { [unowned self] attachmentView in
            guard let attachmentView else { return }
            self.selectedMediaView
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
        logger.verbose("[MESSAGE SEND] sendButtonAction \(inputTextView.text)")
        if case .reply(let model) = currentState,
            lastDetectedLinkMetadata === model.linkPreviews?.first?.metadata {
            lastDetectedLinkMetadata = nil
        }
        updateMediaButtonAppearance(isHidden: shouldHideMediaButton)
        selectedPhotoAssetIdentifiers.removeAll()
        action = .send(true)
        currentState = nil
        nextState = nil
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
        self.lastDetectedLinkMetadata = nil
        let hasActionView = !actionView.isHidden
        
        if case .edit = currentState {
            nextState = .reply(layoutModel)
            return
        } else {
            currentState = .reply(layoutModel)
            nextState = nil
        }
        let message = layoutModel.message
        let title = appearance.replyMessageAppearance.senderNameFormatter.format(message.user)
        var image: UIImage?
        var showPlayIcon = false
        if let attachment = message.attachments?.first {
            switch attachment.type {
            case "image":
                image = attachment.thumbnailImage
            case "video":
                image = attachment.thumbnailImage
                showPlayIcon = true
            case "voice":
                image = appearance.replyMessageAppearance.attachmentIconProvider.provideVisual(for: attachment)
            case "link":
                if let metadata = layoutModel.linkPreviews?.first?.metadata {
                    addOrUpdateLinkPreview(linkDetails: metadata)
                    return
                }
                image = nil
            default:
                image = appearance.replyMessageAppearance.attachmentIconProvider.provideVisual(for: attachment)
            }
        }
        let titleAttributedString = NSMutableAttributedString(
            string: L10n.Input.reply + ": ",
            attributes: [
                .font: appearance.replyMessageAppearance.titleLabelAppearance.font,
                .foregroundColor: appearance.replyMessageAppearance.titleLabelAppearance.foregroundColor
            ])
        titleAttributedString.append(
            .init(
                string: title,
                attributes: [
                    .font: appearance.replyMessageAppearance.senderNameLabelAppearance.font,
                    .foregroundColor: appearance.replyMessageAppearance.senderNameLabelAppearance.foregroundColor
                ]))
        actionView.titleLabel.attributedText = titleAttributedString
        
        actionView.messageLabel.attributedText = appearance.replyMessageAppearance.messageBodyFormatter.format(
            .init(
                message: message,
                bodyLabelAppearance: appearance.replyMessageAppearance.bodyLabelAppearance,
                mentionLabelAppearance: appearance.replyMessageAppearance.mentionLabelAppearance,
                attachmentDurationLabelAppearance: appearance.replyMessageAppearance.attachmentDurationLabelAppearance,
                attachmentDurationFormatter: appearance.replyMessageAppearance.attachmentDurationFormatter,
                attachmentNameFormatter: appearance.replyMessageAppearance.attachmentNameFormatter,
                mentionUserNameFormatter: appearance.replyMessageAppearance.mentionUserNameFormatter
            )
        )

        actionView.backgroundColor = appearance.replyMessageAppearance.backgroundColor
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.isHidden = true
        actionView.iconView.image = appearance.replyMessageAppearance.replyIcon
        actionView.imageView.isHidden = image == nil
        actionView.imageView.image = image
        actionView.playView.isHidden = !showPlayIcon
        
        actionViewHeightLayoutConstraint.constant = Layouts.actionViewHeight

        view.layoutIfNeeded() // fix: Bad animation on reply
        
        onContentHeightUpdate?(view.bounds.height + (hasActionView ? 0 : Layouts.actionViewHeight), nil)
    }

    var cachedMessage: NSAttributedString?
    open func addEdit(layoutModel: MessageLayoutModel) {
        self.lastDetectedLinkMetadata = nil
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
        var showPlayIcon = false
        if let attachment = message.attachments?.first {
            switch attachment.type {
            case "image":
                image = attachment.thumbnailImage
            case "video":
                image = attachment.thumbnailImage
                showPlayIcon = true
            case "voice":
                image = appearance.editMessageAppearance.attachmentIconProvider.provideVisual(for: attachment)
            case "link":
                if let metadata = layoutModel.linkPreviews?.first?.metadata {
                    addOrUpdateLinkPreview(linkDetails: metadata)
                    return
                }
                image = nil
            default:
                image = appearance.editMessageAppearance.attachmentIconProvider.provideVisual(for: attachment)
            }
        }
        
        let titleAttributedString = NSMutableAttributedString(
            string: L10n.Input.edit + ": ",
            attributes: [
                .font: appearance.editMessageAppearance.titleLabelAppearance.font,
                .foregroundColor: appearance.editMessageAppearance.titleLabelAppearance.foregroundColor
            ])
        actionView.titleLabel.attributedText = titleAttributedString
        
        actionView.messageLabel.attributedText = appearance.editMessageAppearance.messageBodyFormatter.format(
            .init(
                message: message,
                bodyLabelAppearance: appearance.editMessageAppearance.bodyLabelAppearance,
                mentionLabelAppearance: appearance.editMessageAppearance.mentionLabelAppearance,
                attachmentDurationLabelAppearance: appearance.editMessageAppearance.attachmentDurationLabelAppearance,
                attachmentDurationFormatter: appearance.editMessageAppearance.attachmentDurationFormatter,
                attachmentNameFormatter: appearance.editMessageAppearance.attachmentNameFormatter,
                mentionUserNameFormatter: appearance.editMessageAppearance.mentionUserNameFormatter
            )
        )
        
        cachedMessage = inputTextView.attributedText
        actionView.backgroundColor = appearance.editMessageAppearance.backgroundColor
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.isHidden = true
        actionView.iconView.image = appearance.editMessageAppearance.editIcon
        actionView.imageView.isHidden = image == nil
        actionView.imageView.image = image
        updateMediaButtonAppearance(isHidden: true)
        actionView.playView.isHidden = !showPlayIcon

        actionViewHeightLayoutConstraint.constant = Layouts.actionViewHeight

        view.layoutIfNeeded() // fix: Bad animation on reply edit

        onContentHeightUpdate?(view.bounds.height + (hasActionView ? 0 : Layouts.actionViewHeight), nil)
    }
    
    open func addOrUpdateLinkPreview(linkDetails: LinkMetadata) {
        guard selectedMediaView.items.isEmpty
        else { return }
        
        if let last = self.lastDetectedLinkMetadata,
            last.url == linkDetails.url {
            return
        }
        
        let hasActionView = !actionView.isHidden
        
        if hasActionView, lastDetectedLinkMetadata == nil {
            switch currentState {
            case .edit(let model):
                self.lastDetectedLinkMetadata = linkDetails
                self.nextState = .edit(model)
            case .reply(let model):
                self.lastDetectedLinkMetadata = linkDetails
                self.nextState = .reply(model)
            case .none:
                return
            }
        }
        let shouldUpdate = lastDetectedLinkMetadata != nil
        
        self.lastDetectedLinkMetadata = linkDetails
        let message = linkDetails.summary ?? ""
        
        let titleAttributedString = NSMutableAttributedString(
            string: linkDetails.url.absoluteString,
            attributes: [
                .font: appearance.linkPreviewAppearance.titleLabelAppearance.font,
                .foregroundColor: appearance.linkPreviewAppearance.titleLabelAppearance.foregroundColor
            ])
        actionView.titleLabel.attributedText = titleAttributedString
        
        let messageAttributedString = NSMutableAttributedString(
            string: message,
            attributes: [
                .font: appearance.linkPreviewAppearance.descriptionLabelAppearance.font,
                .foregroundColor: appearance.linkPreviewAppearance.descriptionLabelAppearance.foregroundColor
            ])

        actionView.messageLabel.attributedText = messageAttributedString
        
        actionView.backgroundColor = appearance.linkPreviewAppearance.backgroundColor
        actionView.isHidden = false
        separatorViewCenter.isHidden = false
        actionView.iconView.isHidden = true
        actionView.imageView.isHidden = false
        actionView.playView.isHidden = true
        if let icon = linkDetails.image {
            actionView.imageView.image = icon
        } else {
            actionView.imageView.image = appearance.linkPreviewAppearance.placeholderIcon
        }
        
        actionViewHeightLayoutConstraint.constant = Layouts.actionViewHeight

        if !shouldUpdate {
            view.layoutIfNeeded() // fix: Bad animation on reply
            
            onContentHeightUpdate?(view.bounds.height + (hasActionView ? 0 : Layouts.actionViewHeight), nil)
        }
    }

    private var isRemovingActionView = false
    open func removeActionView() {
        guard !actionView.isHidden, !isRemovingActionView else { return }
        lastDetectedLinkMetadata = nil
        isRemovingActionView = true
        updateMediaButtonAppearance(isHidden: shouldHideMediaButton)
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
            checkNextView()
        })
        currentState = nil
        func checkNextView() {
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
    }

    open private(set) var style = Style.small {
        didSet {
            if style != oldValue {
                let height = view.bounds.height
                let mediaHeight = selectedMediaView.constraints.first(where: { $0.firstAttribute == .height })
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
        guard let viewController = mentionUserListViewController?() else {
            return
        }
        presentedMentionUserListViewController = viewController
        parent.addChild(viewController)
        parent.view.addSubview(viewController.view)
        _ = viewController.view.withoutAutoresizingMask
        (parent as? ChannelViewController)?.collectionView.isUserInteractionEnabled = false
        viewController.view.pin(to: parent.view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])
        viewController.view.bottomAnchor.pin(to: view.topAnchor)
        
        viewController.didSelectMember = { [unowned self] in
            callback($0.id, self.appearance.mentionUserNameFormatter.format($0))
        }
    }

    open func dismiss() {
        guard let parent = parent else { return }
        guard let viewController = presentedMentionUserListViewController, viewController.parent != nil else { return }
        viewController.didSelectMember = nil
        (parent as? ChannelViewController)?.collectionView.isUserInteractionEnabled = true
        viewController.view.removeConstraints(viewController.view.constraints)
        viewController.removeFromParent()
        viewController.view.removeFromSuperview()
        presentedMentionUserListViewController = nil
    }
    
    open func toggleAttribute(component: ChatMessage.BodyAttribute.AttributeType, range: NSRange, textView: UITextView) {
        guard let mutableText = textView.attributedText.mutableCopy() as? NSMutableAttributedString
        else { return }
        
        let defaultFont = appearance.inputAppearance.textInputAppearance.labelAppearance.font
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
                font = defaultFont.toBold
            }
            if isItalic {
                font = font?.toItalic
            }
            if isMonospace {
                font = font?.toMonospace
            }
        case .italic:
            if isItalic {
                font = defaultFont
            } else {
                font = defaultFont.toItalic
            }
            if isBold {
                font = font?.toBold
            }
            if isMonospace {
                font = font?.toMonospace
            }
        case .monospace:
            if isMonospace {
                font = defaultFont
            } else {
                font = defaultFont.toMonospace
            }
            if isBold {
                font = font?.toBold
            }
            if isItalic {
                font = font?.toItalic
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
        textView.typingAttributes[.foregroundColor] = appearance.inputAppearance.textInputAppearance.labelAppearance.foregroundColor
        
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
            if textView.text[selectedRange.location] == mentionTriggerPrefix {
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
        
        let filteredSuggestedActions = suggestedActions.filter {
            if let action = $0 as? UIMenu, filteredActions.contains(action.identifier.rawValue) {
                return false
            } else {
                return true
            }
        }
        
        guard !textView.attributedText.string.isEmpty,
              textView.selectedRange.length > 0,
              appearance.enableTextStyling else {
            return UIMenu(children: filteredSuggestedActions)
        }
        
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

public extension MessageInputViewController {
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
        case deleteMedia(AttachmentModel)
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

public extension MessageInputViewController {
    enum Layouts {
        public static var actionViewHeight: CGFloat = 56
        public static var recorderShadowBlur: CGFloat = 24
    }
}
