//
//  PreviewerVC.swift
//  SceytChatUIKit
//

import AVFoundation
import UIKit

open class PreviewerVC: ViewController,
    UIGestureRecognizerDelegate,
    UIScrollViewDelegate
{
    open lazy var router = Components.previewerRouter
        .init(rootVC: self)
    
    var targetView: UIImageView {
        if !scrollView.isHidden {
            return imageView
        } else {
            return playerView
        }
    }
        
    private let imageView: UIImageView = .init(frame: .zero)

    private(set) var playerView = {
        $0.backgroundColor = .clear
        $0.isUserInteractionEnabled = true
        return $0
    }(UIImageView())
    
    private let currentTimeLabel = {
        $0.setContentHuggingPriority(.required, for: .horizontal)
        $0.font = PreviewerVC.appearance.controlFont
        $0.textColor = PreviewerVC.appearance.tintColor
        $0.text = "0:00"
        return $0
    }(UILabel())

    private lazy var slider = {
        $0.setThumbImage(Images.videoPlayerThumb, for: [])
        $0.minimumTrackTintColor = PreviewerVC.appearance.minimumTrackTintColor
        $0.maximumTrackTintColor = PreviewerVC.appearance.maximumTrackTintColor
        $0.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        return $0
    }(UISlider())
    
    private var isSliderDragging = false {
        didSet {
            slider.setThumbImage(Images.videoPlayerThumb, for: [])
        }
    }

    private let durationLabel = {
        $0.setContentHuggingPriority(.required, for: .horizontal)
        $0.font = PreviewerVC.appearance.controlFont
        $0.textColor = PreviewerVC.appearance.tintColor
        $0.text = "0:00"
        $0.textAlignment = .right
        return $0
    }(UILabel())

    private let playerControlContainerView = {
        $0.backgroundColor = PreviewerVC.appearance.backgroundColor
        return $0
    }(UIView())

    private lazy var playerControlView = UIStackView(row: currentTimeLabel, slider, durationLabel)
    
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    
    private lazy var playPauseButton = {
        $0.contentEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        $0.setImage(Images.videoPlayerPlay, for: [])
        $0.addTarget(self, action: #selector(onTapPlay), for: .touchUpInside)
        return $0
    }(UIButton())
    
    private var backgroundView: UIView? {
        guard let _parent = parent as? PreviewerCarouselVC
        else { return nil }
        return _parent.backgroundView
    }
    
    let index: Int
    let previewItem: PreviewItem
    
    var navBar: PreviewNavBar? {
        guard let _parent = parent as? PreviewerCarouselVC
        else { return nil }
        return _parent.navBar
    }
    
    // MARK: Layout Constraints

    private var top: NSLayoutConstraint!
    private var leading: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!
    private var bottom: NSLayoutConstraint!
    
    private(set) lazy var scrollView = {
        $0.delegate = self
        $0.showsVerticalScrollIndicator = false
        $0.contentInsetAdjustmentBehavior = .never
        $0.backgroundColor = .clear
        return $0
    }(UIScrollView())
    
    private var lastLocation: CGPoint = .zero
    private var isAnimating: Bool = false
    private var maxZoomScale: CGFloat = 1.0
    
    public required init(
        index: Int,
        previewItem: PreviewItem)
    {
        self.index = index
        self.previewItem = previewItem
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func setup() {
        super.setup()
        addGestureRecognizers()
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .clear
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(playerView.withoutAutoresizingMask)
        playerView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        
        view.addSubview(playerControlContainerView.withoutAutoresizingMask)
        playerControlContainerView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        
        playerControlContainerView.addSubview(playerControlView.withoutAutoresizingMask)
        playerControlContainerView.addSubview(playPauseButton.withoutAutoresizingMask)
        
        playerControlView.pin(to: playerControlContainerView, anchors: [.leading(16), .trailing(-16), .top(16)])
        playPauseButton.pin(to: playerControlContainerView, anchors: [.centerX])
        playPauseButton.topAnchor.pin(to: playerControlView.bottomAnchor)
        playPauseButton.bottomAnchor.pin(to: playerControlContainerView.safeAreaLayoutGuide.bottomAnchor)
        
        currentTimeLabel.resize(anchors: [.width(44), .height(16)])
        durationLabel.resize(anchors: [.width(44), .height(16)])
        
        view.addSubview(scrollView.withoutAutoresizingMask)
        scrollView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        
        scrollView.addSubview(imageView.withoutAutoresizingMask)
        top = imageView.topAnchor.pin(to: scrollView.topAnchor)
        leading = imageView.leadingAnchor.pin(to: scrollView.leadingAnchor)
        trailing = imageView.trailingAnchor.pin(to: scrollView.trailingAnchor)
        bottom = imageView.bottomAnchor.pin(to: scrollView.bottomAnchor)
    }
    
    override open func setupDone() {
        super.setupDone()
        
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(onPlayToEnd),
                name: Notification.Name("AVPlayerItemDidPlayToEndTimeNotification"),
                object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.removeObserver(self, forKeyPath: "timeControlStatus")
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        switch previewItem {
        case let .attachment(attachment):
            switch attachment.type {
            case "video":
                scrollView.isHidden = true
                playerView.isHidden = false
                playerControlContainerView.isHidden = false
                
                let asset = AVAsset(url: attachment.originUrl)
                
                let assetKeys = ["playable", "duration"]
                asset.loadValuesAsynchronously(forKeys: assetKeys, completionHandler: {
                    DispatchQueue.main.async { [unowned self] in
                        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: assetKeys)
                        let player = AVPlayer(playerItem: playerItem)
                        self.player = player
                        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)), queue: DispatchQueue.main) { [weak self] _ in
                            guard let self else { return }
                            if self.player?.currentItem?.status == .readyToPlay {
                                self.currentTimeLabel.text = Formatters.videoAssetDuration.format(player.currentTime().seconds)
                                if !self.isSliderDragging {
                                    self.slider.setValue(Float(self.player!.currentTime().seconds / playerItem.duration.seconds), animated: self.player!.currentTime().seconds > 0)
                                }
                            }
                        }
                        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
                        
                        let playerLayer = AVPlayerLayer(player: player)
                        self.playerLayer = playerLayer
                        playerLayer.videoGravity = .resizeAspect
                        playerView.contentMode = .scaleAspectFit
                        playerView.layer.insertSublayer(playerLayer, at: 0)
                        playerView.image = attachment.originalImage
                        durationLabel.text = Formatters.videoAssetDuration.format(player.currentItem?.duration.seconds ?? 0)
                    }
                })
            default:
                scrollView.isHidden = false
                playerView.isHidden = true
                playerControlContainerView.isHidden = true
                imageView.image = attachment.originalImage
                imageView.layoutIfNeeded()
            }
            
            navBar?.set(
                title: previewItem.senderTitle,
                subtitle: Formatters.attachmentTimestamp.format(attachment.createdAt))
            
            let shareButton = UIBarButtonItem(
                image: Images.videoPlayerShare,
                style: .plain,
                target: self,
                action: #selector(onTapShare(_:)))
            shareButton.tintColor = PreviewerVC.appearance.tintColor
            navBar?.setRightBarButton(shareButton)
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        player?.seek(to: .zero)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.navBar?.alpha = 1.0
                self?.playerControlContainerView.alpha = 1.0
            } completion: { [weak self] _ in
                self?.player?.play()
            }
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        updateConstraintsForSize(view.bounds.size)
        updateMinMaxZoomScaleForSize(view.bounds.size)
        
        playerLayer?.frame = playerView.bounds
    }
    
    // MARK: Add Gesture Recognizers

    open func addGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(
            target: self, action: #selector(onPan(_:)))
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let pinchRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(onPinch(_:)))
        pinchRecognizer.numberOfTapsRequired = 1
        pinchRecognizer.numberOfTouchesRequired = 2
        scrollView.addGestureRecognizer(pinchRecognizer)
        
        let singleTapGesture = UITapGestureRecognizer(
            target: self, action: #selector(onTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(singleTapGesture)
        
        let doubleTapRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(onDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(doubleTapRecognizer)
        
        singleTapGesture.require(toFail: doubleTapRecognizer)
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
        navBar?.alpha = 1.0 - abs(diffY / view.center.y)
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
    open func onPinch(_ recognizer: UITapGestureRecognizer) {
        var newZoomScale = scrollView.zoomScale / 1.5
        newZoomScale = max(newZoomScale, scrollView.minimumZoomScale)
        scrollView.setZoomScale(newZoomScale, animated: true)
    }
    
    @objc
    open func onTap(_ recognizer: UITapGestureRecognizer) {
        let currentNavAlpha = navBar?.alpha ?? 0.0
        UIView.animate(withDuration: 0.3) {
            self.navBar?.alpha = currentNavAlpha > 0.5 ? 0.0 : 1.0
            self.playerControlContainerView.alpha = currentNavAlpha > 0.5 ? 0.0 : 1.0
        }
    }
    
    @objc
    open func onDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let pointInView = recognizer.location(in: imageView)
        zoomInOrOut(at: pointInView)
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
        if player?.timeControlStatus == .paused {
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
        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                if newStatus == .playing {
                    playPauseButton.setImage(Images.videoPlayerPause, for: [])
                } else {
                    playPauseButton.setImage(Images.videoPlayerPlay, for: [])
                }
            }
        }
    }
    
    @objc
    open func onPlayToEnd(_ notification: Notification) {
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
    open func onTapShare(_ sender: UIBarButtonItem) {
        router
            .showShareActionSheet(
                previewItem: previewItem,
                from: sender)
        { [unowned self] option in
            switch option {
            case .saveGallery:
                PreviewerVM.save(attachment: previewItem.attachment) { [weak self] event in
                    switch event {
                    case .photoSaved(nil):
                        self?.router.showAlert(message: L10n.Previewer.photoSaved)
                    case .videoSaved(nil):
                        self?.router.showAlert(message: L10n.Previewer.videoSaved)
                    default:
                        return
                    }
                }
            case .share:
                router.share([previewItem.attachment.originUrl], from: sender)
            case .cancel:
                return
            }
        }
    }
   
    // MARK: Adjusting the dimensions

    open func updateMinMaxZoomScaleForSize(_ size: CGSize) {
        let targetSize = imageView.bounds.size
        if targetSize.width == 0 || targetSize.height == 0 {
            return
        }
        
        let minScale = min(
            size.width / targetSize.width,
            size.height / targetSize.height)
        let maxScale = max(
            (size.width + 1.0) / targetSize.width,
            (size.height + 1.0) / targetSize.height)
        
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
        maxZoomScale = maxScale
        scrollView.maximumZoomScale = maxZoomScale * 1.1
    }
    
    open func zoomInOrOut(at point: CGPoint) {
        let newZoomScale = scrollView.zoomScale == scrollView.minimumZoomScale
            ? maxZoomScale : scrollView.minimumZoomScale
        let size = scrollView.bounds.size
        let w = size.width / newZoomScale
        let h = size.height / newZoomScale
        let x = point.x - (w * 0.5)
        let y = point.y - (h * 0.5)
        let rect = CGRect(x: x, y: y, width: w, height: h)
        scrollView.zoom(to: rect, animated: true)
    }
    
    open func updateConstraintsForSize(_ size: CGSize) {
        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        top.constant = yOffset
        bottom.constant = yOffset
        
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)
        leading.constant = xOffset
        trailing.constant = xOffset
        view.layoutIfNeeded()
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
    
    // MARK: ScrollView delegate

    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    open func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(view.bounds.size)
    }
}

public extension ChatMessage.Attachment {
    var originalImage: UIImage? {
        if let data = try? Data(contentsOf: originUrl) {
            return UIImage(data: data)
        }
        return thumbnailImage
    }
    
    var thumbnailImage: UIImage? {
        guard let path = fileProvider.thumbnailFile(for: self, preferred: MessageLayoutModel.defaults.imageAttachmentSize)
        else {
            if let data = imageDecodedMetadata?.thumbnailData {
                return UIImage(data: data)
            } else if let thumbnail = imageDecodedMetadata?.thumbnail,
                      let image = Components.imageBuilder.image(from: thumbnail)
            {
                return image
            }
            return nil
        }
        return UIImage(contentsOfFile: path)
    }
}
