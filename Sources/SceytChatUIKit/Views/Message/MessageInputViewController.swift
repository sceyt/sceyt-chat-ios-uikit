//
//  MessageInputViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import AVFoundation
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

    open lazy var cameraButton = UIButton()
        .withoutAutoresizingMask

    open lazy var viewOnceButton = UIButton()
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
    
    open lazy var recorderView: VoiceRecorderView = {
        let view = Components.messageInputVoiceRecorderView.init()
        view.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .noPermission:
                self.showNoMicrophonePermission()
            case .recordingUnavailable:
                self.showRecordingUnavailable()
            case let .recorded(url, metadata, viewOnce):
                self.recordedView.isHidden = false
                self.recordedView.setup(url: url, metadata: metadata, viewOnce: viewOnce)
            case let .send(url, metadata, viewOnce):
                if let url = Components.storage.copyFile(url) {
                    self.selectedMediaView.insert(view: AttachmentModel(voiceUrl: url, metadata: metadata))
                    self.isViewOnceEnabled = viewOnce
                    self.action = .send(false)
                }
            case .didStartRecording:
                self.action = .didStartRecording
            case .didStopRecording:
                self.action = .didStopRecording
            }
        }
        return view
    }()
    
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

    open var shouldHideCameraButton = true {
        didSet {
            updateState()
        }
    }

    open var cameraButtonWidth: CGFloat { 48.0 }
    open var recordButtonWidth: CGFloat { 52.0 }
    open var sendButtonWidth: CGFloat { 52.0 }
    open var viewOnceButtonWidth: CGFloat { 28.0 }

    open var shouldHidePollOption = false

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
    open var onCreatePoll: ((CreatePollModel) -> Void)?

    @Published public var action: Action?

    internal var isViewOnceEnabled: Bool = false {
        didSet {
            updateViewOnceButtonAppearance()
        }
    }

    private var selectedPhotoAssetIdentifiers = Set<String>()
    public private(set) var linkMetadata: LinkMetadata?
    public private(set) var lastDetectedLinkMetadata: LinkMetadata? {
        willSet {
            if newValue != nil {
                linkMetadata = newValue
            }
        }
    }
    public private(set) var didUserDismissLinkPreview = false
    private var actionViewHeightLayoutConstraint: NSLayoutConstraint!
    private var inputTextViewLeadingConstraint: NSLayoutConstraint?
    open var inputTextViewTrailingConstraint: NSLayoutConstraint?
    
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
            case let .send(url, metadata, viewOnce):
                self.recordedView.isHidden = true
                if let url = Components.storage.copyFile(url) {
                    self.selectedMediaView.insert(view: AttachmentModel(voiceUrl: url, metadata: metadata))
                    self.isViewOnceEnabled = viewOnce
                    self.action = .send(false)
                }
            }
        }
        
        actionView.cancelButton.addTarget(self, action: #selector(actionViewCancelAction), for: .touchUpInside)
        addMediaButton.addTarget(self, action: #selector(addMediaButtonAction(_:)), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendButtonAction(_:)), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraButtonAction(_:)), for: .touchUpInside)
        viewOnceButton.addTarget(self, action: #selector(viewOnceButtonAction(_:)), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: recorderView, action: #selector(Components.messageInputVoiceRecorderView.onLongPress))
        longPress.minimumPressDuration = 0.05
        recordButton.isUserInteractionEnabled = true
        recordButton.addGestureRecognizer(longPress)
        
        actionView.isHidden = true
        separatorViewCenter.isHidden = true

        setupAccessibilityIdentifiers()
    }

    /// Assigns accessibility identifiers to the composer controls so UI tests can
    /// locate the input field and the send button. The values are mirrored in the
    /// central registry (`SceytChatUIKit.AccessibilityIdentifiers.MessageInput`).
    open func setupAccessibilityIdentifiers() {
        typealias AID = SceytChatUIKit.AccessibilityIdentifiers.MessageInput
        inputTextView.accessibilityIdentifier = AID.inputField
        sendButton.accessibilityIdentifier = AID.sendButton
    }

    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        backgroundView.backgroundColor = appearance.backgroundColor
        addMediaButton.setImage(appearance.attachmentIcon, for: .normal)
        sendButton.setImage(appearance.sendMessageIcon, for: .normal)
        recordButton.image = appearance.voiceRecordIcon
        cameraButton.setImage(appearance.cameraIcon, for: .normal)
        updateViewOnceButtonAppearance()
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
        view.addSubview(cameraButton)
        view.addSubview(viewOnceButton)
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
        sendButton.resize(anchors: [.height(52), .width(sendButtonWidth)])

        recordButton.pin(to: view, anchors: [.trailing(), .bottom()])
        recordButton.resize(anchors: [.height(52), .width(recordButtonWidth)])

        cameraButton.trailingAnchor.pin(to: recordButton.leadingAnchor)
        cameraButton.pin(to: view, anchors: [.bottom()])
        cameraButton.resize(anchors: [.height(52), .width(cameraButtonWidth)])

        viewOnceButton.trailingAnchor.pin(to: inputTextView.trailingAnchor, constant: -4.0)
        viewOnceButton.pin(to: view, anchors: [.bottom()])
        viewOnceButton.resize(anchors: [.height(52), .width(viewOnceButtonWidth)])

        updateMediaButtonAppearance(isHidden: shouldHideMediaButton, animated: false)

        // Initial trailing constraint (will be updated by updateTrailingInputButtons)
        inputTextViewTrailingConstraint = inputTextView.trailingAnchor.pin(to: sendButton.leadingAnchor)
        inputTextView.topAnchor.pin(to: selectedMediaView.bottomAnchor, constant: 8).priority(.defaultLow)
        inputTextView.heightAnchor.pin(greaterThanOrEqualToConstant: 36)
        inputTextView.bottomAnchor.pin(to: view.bottomAnchor, constant: -8)
        
        recordedView.pin(to: view, anchors: [.leading, .trailing, .top])
        recordedView.isHidden = true
        
        updateState(false)
    }
    
    open override func setupDone() {
        super.setupDone()
        shouldHideRecordButton = !appearance.enableVoiceRecord
        shouldHideMediaButton = !appearance.enableSendAttachment
        canRunMentionUserLogic = appearance.enableMention
    }
    
    open func updateState(_ animated: Bool = true) {
        updateTrailingInputButtons(animated)
        updateViewOnceButtonVisibility()

        style = selectedMediaView.items.count > 0 ? .large : .small
        separatorViewCenter.isHidden = selectedMediaView.items.count == 0
        if sendButton.isHidden {
            sendButton.cancelTracking(with: nil)
        }

        if !selectedMediaView.items.isEmpty, lastDetectedLinkMetadata != nil {
            if case .reply = currentState {
                findLink()
            } else {
                removeActionView()
            }
        } else if selectedMediaView.items.isEmpty {
            findLink()
        }
    }
    
    /// Whether the input currently holds something worth sending.
    ///
    /// Returns `true` when there are selected media items, or when the input
    /// contains real typed text. Bare object replacement characters (`U+FFFC`)
    /// — left behind by inline non-text content such as `NSTextAttachment`s or
    /// adaptive image glyphs (iOS 18+ Genmoji) — are stripped first: that content
    /// can't be serialized by the send path (`UserSendMessage` sends only the
    /// plain string), so on its own it must not count as sendable. Genmoji input
    /// is additionally disabled at the text view via `supportsAdaptiveImageGlyph`,
    /// so this mainly guards against pasted or restored placeholder content.
    ///
    /// Override to customize what counts as sendable (e.g. to require text).
    open func hasSendableContent() -> Bool {
        if !selectedMediaView.items.isEmpty { return true }

        let plainText = (inputTextView.text ?? "").replacingOccurrences(of: "\u{fffc}", with: "")
        return !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    open func updateTrailingInputButtons(_ animated: Bool = true) {
        let shouldShowSendButton = hasSendableContent()
        let shouldShowViewOnceButton = appearance.enableViewOnce && selectedMediaView.items.count == 1

        // Update button visibility
        sendButton.isHidden = !shouldShowSendButton
        viewOnceButton.isHidden = !shouldShowViewOnceButton
        cameraButton.isHidden = shouldShowSendButton || shouldHideCameraButton
        recordButton.isHidden = shouldShowSendButton || shouldHideRecordButton

        // Update inputTextView right padding based on viewOnceButton visibility
        updateInputTextViewPadding(viewOnceButtonVisible: !viewOnceButton.isHidden)

        // Guard: Only update constraint if buttons are in view hierarchy (setupLayout has been called)
        guard inputTextViewTrailingConstraint != nil else { return }

        // Update inputTextView trailing constraint based on visible buttons
        if let inputTextViewTrailingConstraint {
            view.removeConstraint(inputTextViewTrailingConstraint)
        }

        if !sendButton.isHidden {
            inputTextViewTrailingConstraint = inputTextView.trailingAnchor.pin(to: sendButton.leadingAnchor)
        } else if !cameraButton.isHidden {
            inputTextViewTrailingConstraint = inputTextView.trailingAnchor.pin(to: cameraButton.leadingAnchor)
        } else if !recordButton.isHidden {
            inputTextViewTrailingConstraint = inputTextView.trailingAnchor.pin(to: recordButton.leadingAnchor)
        } else {
            // If all buttons are hidden, connect to view trailing
            inputTextViewTrailingConstraint = inputTextView.trailingAnchor.pin(to: view.trailingAnchor, constant: -8)
        }
    }

    open func updateInputTextViewPadding(viewOnceButtonVisible: Bool) {
        let rightPadding: CGFloat = viewOnceButtonVisible ? 34 : 12
        inputTextView.textContainerInset = .init(
            top: inputTextView.textContainerInset.top,
            left: inputTextView.textContainerInset.left,
            bottom: inputTextView.textContainerInset.bottom,
            right: rightPadding
        )
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

    open func updateViewOnceButtonAppearance() {
        viewOnceButton.backgroundColor = .clear
        if isViewOnceEnabled {
            viewOnceButton.setImage(appearance.viewOnceActiveIcon, for: .normal)
        } else {
            viewOnceButton.setImage(appearance.viewOnceIcon, for: .normal)
        }
    }

    open func updateViewOnceButtonVisibility() {
        let shouldShow = appearance.enableViewOnce && selectedMediaView.items.count == 1

        // Reset state when conditions change
        if !shouldShow && isViewOnceEnabled {
            isViewOnceEnabled = false
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
    
    /// Returns the first link found in the input text view, excluding mailto links
    open func getLink() -> URL? {
        guard let text = inputTextView.text, !text.isEmpty
        else {
            return nil
        }

        return DataDetector.matches(text: text).first(where: { $0.url?.scheme != "mailto" && $0.url != nil })?.url
    }

    open func findLink() {
        guard let text = inputTextView.text, !text.isEmpty
        else {
            if lastDetectedLinkMetadata != nil, self.currentState == nil {
                self.removeActionView()
            }
            return
        }

        guard let url = getLink() else {
            if lastDetectedLinkMetadata != nil, self.currentState == nil {
                self.removeActionView()
            }
            return
        }

        if let last = lastDetectedLinkMetadata, last.url == url {
            return
        }

        LinkMetadataProvider.default.fetch(url: url, forceFetch: true) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let metadata):
                // Check if the link is still the same
                if url != self.getLink() {
                    return
                }

                DispatchQueue.main.async {
                    self.addOrUpdateLinkPreview(linkDetails: metadata)
                }

            case .failure:
                DispatchQueue.main.async {
                    if url == self.getLink(),
                       self.lastDetectedLinkMetadata != nil,
                       self.currentState == nil {
                        self.removeActionView()
                    }
                }
            }
        }
    }
    
    open func showNoMicrophonePermission() {
        showAlert(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureErrorKey: "No permission!"]))
    }

    open func showRecordingUnavailable() {
        showAlert(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureErrorKey: "Recording unavailable"]))
    }
    
    @objc
    open func actionViewCancelAction() {
        let isEditState: Bool
        if case .edit = currentState { isEditState = true }
        else if case .edit = nextState { isEditState = true }
        else { isEditState = false }

        if !isEditState, lastDetectedLinkMetadata != nil {
            cachedMessage = inputTextView.attributedText
        }
        self.didUserDismissLinkPreview = true
        if isEditState {
            inputTextView.attributedText = cachedMessage
            cachedMessage = nil
        }
        nextState = nil
        isViewOnceEnabled = false
        removeActionView()
        selectedMediaView.removeAll()
        action = .cancel
        findLink()
    }
    
    @objc
    open func addMediaButtonAction(_ sender: UIButton) {
        inputTextView.resignFirstResponder()
        var sources: [AttachmentPickerSource] = [.media, .camera, .file]
        if !shouldHidePollOption {
            sources.append(.poll)
        }
        router
            .showAttachmentAlert(
                sources: sources,
                sourceView: sender)
        { [unowned self] source in
            switch source {
            case .media:
                openPhotoPicker()
            case .camera:
                openCameraPicker()
            case .file:
                openDocumentsPicker()
            case .poll:
                openPollPicker()
            case .none:
                return
            }
        }
    }

    @objc
    open func cameraButtonAction(_ sender: UIButton) {
        inputTextView.resignFirstResponder()
        openCameraPicker()
    }

    @objc
    open func viewOnceButtonAction(_ sender: UIButton) {
        isViewOnceEnabled.toggle()
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

    open func openPollPicker() {
        router.showCreatePoll { [unowned self] poll in
            guard let poll else { return }
            // Poll will be sent as a message - handle poll creation
            self.onCreatePoll?(poll)
        }
    }

    //    private static var _textIndex = 1000
    //        private static let loren = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
    //
    //    let links = ["http://www.sceyt.com", "http://www.google.com", "http://www.test.com", "http://www.example.com"]
    @objc
    open func sendButtonAction(_ sender: UIButton) {
        logger.verbose("[MESSAGE SEND] sendButtonAction")
        if case .reply(let model) = currentState,
            lastDetectedLinkMetadata === model.linkPreviews?.first?.metadata {
            lastDetectedLinkMetadata = nil
        }
        updateMediaButtonAppearance(isHidden: shouldHideMediaButton)
        selectedPhotoAssetIdentifiers.removeAll()
        action = .send(true)
        currentState = nil
        nextState = nil
        didUserDismissLinkPreview = false
        lastDetectedLinkMetadata = nil
        isViewOnceEnabled = false
    }
    
    open func addReply(layoutModel: MessageLayoutModel) {
        self.lastDetectedLinkMetadata = nil
        didUserDismissLinkPreview = false
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

        // Don't show thumbnails for view_once messages
        if message.isViewOnceMessage {
            image = nil
        } else if let attachment = message.attachments?.first {
            switch attachment.type {
            case "image":
                image = attachment.thumbnailImage
            case "video":
                image = attachment.thumbnailImage
                showPlayIcon = true
            case "voice":
                image = appearance.replyMessageAppearance.attachmentIconProvider.provideVisual(for: attachment)
            case "link":
                // Render like every other reply (sender + body text); use the link's
                // preview image only as the thumbnail, never replace the reply with a link card.
                if let metadata = layoutModel.linkPreviews?.first?.metadata {
                    image = metadata.image
                } else if let urlString = attachment.url, let url = URL(string: urlString)?.normalizedURL {
                    // 1. Synchronous in-memory hit → use its image right away.
                    if let cached = LinkMetadataProvider.default.metadata(for: url) {
                        image = cached.image
                    } else {
                        // 2. Cache miss → DB, then network API if still missing (also downloads the image).
                        // Drop the image into the existing reply thumbnail when it arrives.
                        LinkMetadataProvider.default.fetch(url: url, loadFromNetworkIfMissing: true) { [weak self] result in
                            guard let self, case .success(let metadata) = result, let image = metadata.image else { return }
                            DispatchQueue.main.async {
                                guard case .reply(let model) = self.currentState,
                                      model === layoutModel else { return }
                                self.actionView.imageView.image = image
                                self.actionView.imageView.isHidden = false
                            }
                        }
                    }
                }
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
            let font = appearance.replyMessageAppearance.bodyLabelAppearance.font
            let color = appearance.replyMessageAppearance.bodyLabelAppearance.foregroundColor

            let text = NSMutableAttributedString(
                string: attachmentName,
                attributes: [
                    .font: font,
                    .foregroundColor: color
                ]
            )

            // Add addCircleDashed icon at the beginning
            let tintedIcon = Images.addCircleDashed.withTintColor(color, renderingMode: .alwaysTemplate)
            let attachment = NSTextAttachment()
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - 16.0).rounded() / 2, width: 16.0, height: 16.0)
            attachment.image = tintedIcon
            let iconAttributedString = NSMutableAttributedString(attachment: attachment)
            iconAttributedString.append(NSAttributedString(string: " ", attributes: [.font: font]))
            text.insert(iconAttributedString, at: 0)

            actionView.messageLabel.attributedText = text
        } else {
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
        }

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
        self.didUserDismissLinkPreview = false
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
        // Prevent text attribute changes when recording audio
        if isRecording {
            return
        }
        
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
        // Prevent text input when recording audio
        if isRecording {
            return false
        }

        // Enforce the maximum message length on insertions/replacements.
        if !text.isEmpty {
            let currentLength = (textView.text as NSString).length
            let newLength = currentLength - range.length + (text as NSString).length
            if newLength > SceytChatUIKit.shared.config.maximumMessageLength {
                return false
            }
        }

        textView.typingAttributes[.foregroundColor] = appearance.inputAppearance.textInputAppearance.labelAppearance.foregroundColor
        
        if text == " " {
            (textView as? InputTextView)?.resetTypingAttributes()
        } else {
            textView.typingAttributes[.font] = inputTextView.font
        }

        if textView.text.count == range.location, !text.isEmpty {
            return true
        }

        // Only check for mention deletion when actually deleting (empty replacement text or range.length > 0)
        let isDeletion = text.isEmpty
        if isDeletion {
            let shouldDelete = deleteMentionText(in: range)
            return !shouldDelete
        }

        return true
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        if textView.text.isEmpty || (textView.selectedRange.location == 0 && textView.selectedRange.length == 0) {
            (textView as? InputTextView)?.resetTypingAttributes()
        }
    }
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        // Prevent text selection when recording audio
        if isRecording {
            return
        }
        
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
        // Prevent showing edit menu when recording audio
        if isRecording {
            return nil
        }
        
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
