//
//  MediaPreviewerVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import SceytChat
import UIKit

open class MediaPreviewerVC: ViewController, UIGestureRecognizerDelegate {
    open lazy var router = Components.previewerRouter
        .init(rootVC: self)
    
    open var viewModel: PreviewerVM!
    
    var targetView: UIImageView {
        if !scrollView.isHidden {
            return imageView
        } else {
            return playerView
        }
    }
    
    open var imageContentMode: UIView.ContentMode = .scaleAspectFit {
        didSet {
            imageView.contentMode = imageContentMode
            playerView.contentMode = imageContentMode
        }
    }
    
    open lazy var playerView = UIImageView()
        .withoutAutoresizingMask
    
    open lazy var playerControlView = UIStackView(row: currentTimeLabel, slider, durationLabel)
        .withoutAutoresizingMask
    
    open lazy var playerControlContainerView = UIView()
        .withoutAutoresizingMask
    
    open lazy var playPauseButton = UIButton()
        .withoutAutoresizingMask
    
    open lazy var scrollView = MediaPreviewerScrollView(contentMode: imageContentMode)
        .withoutAutoresizingMask
    
    public var imageView: UIImageView { scrollView.imageView }
    
    open lazy var currentTimeLabel = UILabel()
        .contentHuggingPriorityH(.required)
    
    open lazy var durationLabel = UILabel()
        .contentHuggingPriorityH(.required)

    open lazy var slider: UISlider = PreviewerSlider()
    
    public private(set) var isSliderDragging = false {
        didSet {
            if isSliderDragging, player?.timeControlStatus == .playing {
                player?.pause()
            } else if !isSliderDragging, player?.timeControlStatus == .paused {
                player?.play()
            }
        }
    }

    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var isPreparingToPlay = false
    
    public var backgroundView: UIView? {
        return carouselVC?.backgroundView
    }
    
    open var carouselVC: MediaPreviewerCarouselVC? {
        super.parent as? MediaPreviewerCarouselVC
    }
    
    // MARK: Layout Constraints
    
    private var lastLocation: CGPoint = .zero
    private var isAnimating: Bool = false
    private var isViewDidAppear = false
    private var isConfiguredPlayer = false
    private var isFirstAppear = true
    
    private var timeObserver: Any?

    deinit {
        logger.debug("[PreviewerVC] deinit")
    
        removeObservers()
        player?.pause()
        player?.currentItem?.cancelPendingSeeks()
        player?.currentItem?.asset.cancelLoading()
        try? Components.audioSession.notifyOthersOnDeactivation()
    }
    
    open func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        player?.removeObserver(self, forKeyPath: "timeControlStatus")
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }
    
    override open func setup() {
        super.setup()
        playerView.isUserInteractionEnabled = true
        playPauseButton.contentEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        playPauseButton.setImage(Images.videoPlayerPlay, for: [])
        playPauseButton.addTarget(self, action: #selector(onTapPlay), for: .touchUpInside)
        
        currentTimeLabel.text = "0:00"
        
        slider.setThumbImage(Images.videoPlayerThumb.imageWithInsets(insets: .init(
            top: PreviewerSlider.thumbPadding,
            left: PreviewerSlider.thumbPadding,
            bottom: PreviewerSlider.thumbPadding,
            right: PreviewerSlider.thumbPadding)), for: [])
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        durationLabel.text = "0:00"
        durationLabel.textAlignment = .right
        
        addGestureRecognizers()
        
        viewModel.$event
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.onEvent(event)
            }.store(in: &subscriptions)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .clear
        playerView.backgroundColor = .clear
        playerControlContainerView.backgroundColor = appearance.backgroundColor
        
        currentTimeLabel.font = appearance.controlFont
        currentTimeLabel.textColor = appearance.tintColor
        
        slider.minimumTrackTintColor = appearance.minimumTrackTintColor
        slider.maximumTrackTintColor = appearance.maximumTrackTintColor
        
        durationLabel.font = appearance.controlFont
        durationLabel.textColor = appearance.tintColor
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(playerView)
        playerView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        
        view.addSubview(playerControlContainerView)
        playerControlContainerView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        
        playerControlContainerView.addSubview(playerControlView)
        playerControlContainerView.addSubview(playPauseButton)
        
        playerControlView.pin(to: playerControlContainerView, anchors: [.leading(16), .trailing(-16), .top(10)])
        playPauseButton.pin(to: playerControlContainerView, anchors: [.centerX])
        playPauseButton.topAnchor.pin(to: playerControlView.bottomAnchor)
        playPauseButton.bottomAnchor.pin(to: playerControlContainerView.safeAreaLayoutGuide.bottomAnchor)
        
        currentTimeLabel.resize(anchors: [.width(44), .height(28)])
        durationLabel.resize(anchors: [.width(44), .height(28)])
        
        view.addSubview(scrollView)
        scrollView.pin(to: view)
    }
    
    override open func setupDone() {
        super.setupDone()
        bindPreviewItem()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIView.animate(withDuration: animated ? 0.3 : 0) { [weak self] in
            guard let self else { return }
            self.carouselVC?.navigationController?.navigationBar.alpha = 1.0
            self.playerControlContainerView.alpha = 1.0
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isViewDidAppear = true

        if isConfiguredPlayer {
            DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0 : 0.3)) { [weak self] in
                self?.play()
            }
        }
        
        carouselVC?.titleLabel.text = viewModel.previewItem.senderTitle
        carouselVC?.subtitleLabel.text = SceytChatUIKit.shared.formatters.mediaPreviewDateFormatter.format(viewModel.previewItem.attachment.createdAt)
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewDidAppear = false
        pause()
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        layout()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layout()
    }
    
    open func layout() {
        playerLayer?.frame = playerView.bounds
        scrollView.updateConstraintsForSize(scrollView.bounds.size)
        scrollView.updateMinMaxZoomScaleForSize(scrollView.bounds.size)
    }
    
    open func onEvent(_ event: PreviewerVM.Event) {
        switch event {
        case .photoSaved(nil):
            router.showAlert(message: L10n.Previewer.photoSaved)
        case .videoSaved(nil):
            router.showAlert(message: L10n.Previewer.videoSaved)
        case .didUpdateItem:
            isPreparingToPlay = false
            bindPreviewItem()
        default:
            return
        }
    }
    
    open func play() {
        configureAudioSessionForPlayback()
        player?.seek(to: .zero)
        player?.play()
    }
    
    open func pause() {
        player?.pause()
    }
    
    open func configureAudioSessionForPlayback() {
        do {
            try Components.audioSession.configure(category: .playback)
        } catch {
            logger.errorIfNotNil(error, "Setting category to .playback failed.")
        }
    }
    
    open func bindPreviewItem() {
        switch viewModel.previewItem {
        case let .attachment(attachment):
            if attachment.type == "video",
               let fileUrl = attachment.fileUrl
            {
                if isPreparingToPlay {
                    return
                } else {
                    isPreparingToPlay = true
                }
                scrollView.isHidden = true
                playerView.isHidden = false
                playerControlContainerView.isHidden = false
                
                let asset = AVAsset(url: fileUrl)
                
                let assetKeys = ["playable", "duration"]
                asset.loadValuesAsynchronously(forKeys: assetKeys) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.configurePlayer(asset: asset, assetKeys: assetKeys)
                        self.isConfiguredPlayer = true
                        if self.isViewDidAppear {
                            self.play()
                        }
                    }
                }
            } else {
                scrollView.isHidden = false
                playerView.isHidden = true
                playerControlContainerView.isHidden = true
                imageView.image = attachment.originalImage
                imageView.setNeedsLayout()
                scrollView.setNeedsLayout()
                imageView.layoutIfNeeded()
            }
        }
    }
    
    open func configurePlayer(asset: AVAsset, assetKeys: [String]) {
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: assetKeys)
        if let player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            player = AVPlayer(playerItem: playerItem)
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)),
                queue: DispatchQueue.main)
            { [weak self] _ in
                guard let self else { return }
                if self.player?.currentItem?.status == .readyToPlay {
                    self.currentTimeLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(self.player!.currentTime().seconds)
                    if !self.isSliderDragging {
                        self.slider.setValue(
                            Float(self.player!.currentTime().seconds / playerItem.duration.seconds),
                            animated: self.player!.currentTime().seconds > 0)
                    }
                }
            }
            player?.addObserver(
                self,
                forKeyPath: "timeControlStatus",
                options: [.old, .new],
                context: nil)
        }
        
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(onPlayToEnd),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: playerItem)
        
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerView.contentMode = imageContentMode
        playerView.layer.insertSublayer(playerLayer!, at: 0)
        playerView.image = viewModel.previewItem.attachment.originalImage
        durationLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(player!.currentItem?.duration.seconds ?? 0)
    }
    
    // MARK: Add Gesture Recognizers

    open func addGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(
            target: self, action: #selector(onPan(_:)))
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let singleTapGesture = UITapGestureRecognizer(
            target: self, action: #selector(onTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(singleTapGesture)
        
        singleTapGesture.require(toFail: scrollView.doubleTapRecognizer)
    }
    
    @objc
    open func onPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard
            isAnimating == false,
            scrollView.zoomScale == scrollView.minimumZoomScale
        else { return }
        
        player?.pause()
        
        if gestureRecognizer.state == .began {
            lastLocation = targetView.center
        }
        
        if gestureRecognizer.state != .cancelled {
            let translation: CGPoint = gestureRecognizer
                .translation(in: view)
            targetView.center = CGPoint(
                x: lastLocation.x + translation.x,
                y: lastLocation.y + translation.y)
        }
        
        let diffY = view.center.y - targetView.center.y
        backgroundView?.alpha = 1.0 - abs(diffY / view.center.y)
        carouselVC?.navigationController?.navigationBar.alpha = 1.0 - abs(diffY / view.center.y)
        playerControlContainerView.alpha = 1.0 - abs(diffY / view.center.y)
        if gestureRecognizer.state == .ended {
            if abs(diffY) > 60 {
                dismiss(animated: true)
            } else {
                executeCancelAnimation(targetView)
            }
        }
    }
    
    @objc
    open func onTap(_ recognizer: UITapGestureRecognizer) {
        let currentNavAlpha = carouselVC?.navigationController?.navigationBar.alpha ?? 0.0
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self else { return }
            self.carouselVC?.navigationController?.navigationBar.alpha = currentNavAlpha > 0.5 ? 0.0 : 1.0
            self.playerControlContainerView.alpha = currentNavAlpha > 0.5 ? 0.0 : 1.0
        }
    }
    
    open func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer) -> Bool
    {
        guard scrollView.zoomScale == scrollView.minimumZoomScale,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer
        else { return false }
            
        let velocity = panGesture.velocity(in: scrollView)
        return abs(velocity.y) > abs(velocity.x)
    }
    
    @objc
    open func onTapPlay() {
        if player?.timeControlStatus != .playing {
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    override open func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?)
    {
        if keyPath == "timeControlStatus",
           let change = change,
           let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
           let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int
        {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                if newStatus == .playing {
                    playPauseButton.setImage(.videoPlayerPause, for: [])
                } else {
                    playPauseButton.setImage(.videoPlayerPlay, for: [])
                }
            }
        }
    }
    
    @objc
    open func onPlayToEnd(_ notification: Notification) {
        guard notification.object as? AVPlayerItem == player?.currentItem
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.player?.seek(to: .zero)
            self?.playerControlContainerView.alpha = 1.0
        }
    }
    
    @objc
    open func sliderValueChanged(_ slider: UISlider, for event: UIEvent) {
        let phase = event.allTouches?.first?.phase
        switch phase {
        case .began:
            isSliderDragging = true
        case .ended:
            isSliderDragging = false
        default:
            break
        }
        
        let time = CMTime(seconds: Double(slider.value) * (player?.currentItem?.duration.seconds ?? 0), preferredTimescale: 60000)
        player?.seek(to: time)
    }
    
    @objc
    open func shareButtonAction(_ sender: UIBarButtonItem) {
        let previewItem = viewModel.previewItem
        router
            .showShareActionSheet(
                previewItem: previewItem,
                from: sender)
        { [unowned self] option in
            switch option {
            case .saveGallery:
                viewModel.save()
            case let .forward(channelIds):
                loader.show()
                viewModel.forward(channelIds: channelIds) { [weak self] in
                    guard let self else { return }
                    router.dismiss()
                    loader.hide()
                }
            case .share:
                router.share([previewItem.attachment.fileUrl ?? previewItem.attachment.originUrl], from: sender)
            case .cancel:
                return
            }
        }
    }
    
    // MARK: Animation Related stuff

    open func executeCancelAnimation(_ container: UIView) {
        isAnimating = true
        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                guard let self else { return }
                self.targetView.center = self.view.center
                self.backgroundView?.alpha = 1.0
            }) { [weak self] _ in
                self?.isAnimating = false
            }
    }
}

private class PreviewerSlider: UISlider {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var bounds: CGRect = self.bounds
        bounds = bounds.insetBy(dx: -44, dy: -14)
        return bounds.contains(point)
    }
    
    static let thumbPadding: CGFloat = 20
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let startingOffset = 0 - Float(Self.thumbPadding)
        let endingOffset = 2 * Float(Self.thumbPadding)
        let xTranslation = startingOffset + (minimumValue + endingOffset) / maximumValue * value
        return super.thumbRect(forBounds: bounds,
                               trackRect: rect.applying(CGAffineTransform(translationX: CGFloat(xTranslation), y: 0)),
                               value: value)
    }
}

private extension UIImage {
    func imageWithInsets(insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: size.width + insets.left + insets.right,
                   height: size.height + insets.top + insets.bottom), false, scale)
        _ = UIGraphicsGetCurrentContext()
        let origin = CGPoint(x: insets.left, y: insets.top)
        draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithInsets
    }
}
