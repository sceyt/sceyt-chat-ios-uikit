//
//  MediaPreviewerCarouselViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class MediaPreviewerCarouselViewController: UIPageViewController,
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate
{
    public weak var initialSourceView: UIImageView?
    
    open var sourceView: UIImageView? {
        guard let viewController = viewControllers?.first as? MediaPreviewerViewController else {
            return nil
        }
        return initialIndex == viewController.viewModel.index ? initialSourceView : nil
    }
    
    public var sourceFrameRelativeToWindow: CGRect?
    
    open var targetView: UIImageView? {
        guard let viewController = viewControllers?.first as? MediaPreviewerViewController else {
            return nil
        }
        return viewController.targetView
    }
    
    public var previewDataSource: PreviewDataSource?

    private let initialIndex: Int
    public var viewOnce: Bool = false
    public var messageText: String?
    
    private var screenshotObserver: NSObjectProtocol?
    private lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.alpha = 0
        return blurView
    }()
    
    open var imageContentMode: UIView.ContentMode = .scaleAspectFit
    open lazy var backgroundView = UIView().withoutAutoresizingMask
    open lazy var titleLabel = UILabel()
    open lazy var subtitleLabel = UILabel()
    open lazy var titleView = UIStackView(column: titleLabel, subtitleLabel, alignment: .center)
    
    deinit {
        logger.debug("[PreviewerCarouselViewController] deinit")
        
        initialSourceView?.alpha = 1.0
        NotificationCenter.default.removeObserver(self)
    }
    
    public required init(
        sourceView: UIImageView,
        title: String? = nil,
        subtitle: String? = nil,
        previewDataSource: PreviewDataSource,
        initialIndex: Int = 0,
        viewOnce: Bool = false,
        messageText: String? = nil)
    {
        self.initialSourceView = sourceView
        self.sourceFrameRelativeToWindow = sourceView.frameRelativeToWindow()
        self.initialIndex = initialIndex
        self.previewDataSource = previewDataSource
        self.viewOnce = viewOnce
        self.messageText = messageText
        let pageOptions = [UIPageViewController.OptionsKey.interPageSpacing: 20]

        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: pageOptions)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupAppearance()
        setupLayout()
        setupDone()
        updateRightBarButtonItems()

        if viewOnce {
            setupScreenshotDetection()
        }
    }
    
    open lazy var backButton = UIBarButtonItem(
        image: Images.videoPlayerBack,
        style: .plain,
        target: self,
        action: #selector(dismiss(_:)))
    
    open lazy var shareButton = UIBarButtonItem(
        image: Images.videoPlayerShare,
        style: .plain,
        target: self,
        action: #selector(shareButtonAction(_:)))

    open lazy var oneTimeButton = UIBarButtonItem(
        image: Images.addCircleDashed,
        style: .plain,
        target: self,
        action: #selector(oneTimeButtonAction(_:)))

    public let appearance = Components.mediaPreviewerViewController.appearance
    
    open func setup() {
        navigationItem.leftBarButtonItem = backButton
        navigationItem.titleView = titleView
        navigationController?.navigationBar.alpha = 0.0

        typealias AID = SceytChatUIKit.AccessibilityIdentifiers.MediaPreviewer
        titleLabel.accessibilityIdentifier = AID.title
        subtitleLabel.accessibilityIdentifier = AID.subtitle
        backButton.accessibilityIdentifier = AID.backButton
        shareButton.accessibilityIdentifier = AID.shareButton
        oneTimeButton.accessibilityIdentifier = AID.viewOnceButton

        dataSource = self
        delegate = self
    }

    open func setupLayout() {
        view.setNeedsLayout()
        view.addSubview(backgroundView)
        backgroundView.pin(to: view)
        view.sendSubviewToBack(backgroundView)
    }

    open func setupAppearance() {
        view.setNeedsDisplay()

        view.backgroundColor = appearance.backgroundColor

        backgroundView.backgroundColor = appearance.backgroundColor
        backgroundView.alpha = 1

        titleLabel.font = appearance.titleLabelAppearance.font
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor

        subtitleLabel.font = appearance.subtitleLabelAppearance.font
        subtitleLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
    }
    
    open func setupDone() {
        if let previewDataSource = previewDataSource,
           let previewItem = previewDataSource.previewItem(at: initialIndex)
        {
            let initialViewController: ViewController

            // Check if the attachment is audio
            if case let .attachment(attachment) = previewItem, attachment.type == "voice" {
                let audioViewController = Components.mediaPreviewerAudioViewController.init()
                audioViewController.viewOnce = self.viewOnce
                audioViewController.messageText = self.messageText
                audioViewController.viewModel = Components.previewerViewModel
                    .init(
                        index: initialIndex,
                        previewItem: previewItem)
                previewDataSource.observe(audioViewController.viewModel)
                initialViewController = audioViewController
            } else {
                let imageViewController = Components.mediaPreviewerViewController.init()
                imageViewController.viewOnce = self.viewOnce
                imageViewController.messageText = self.messageText
                imageViewController.imageContentMode = imageContentMode
                imageViewController.viewModel = Components.previewerViewModel
                    .init(
                        index: initialIndex,
                        previewItem: previewItem)
                previewDataSource.observe(imageViewController.viewModel)
                initialViewController = imageViewController
            }

            setViewControllers([initialViewController], direction: .forward, animated: true)
        }
        
        view.subviews.forEach { ($0 as? UIScrollView)?.delaysContentTouches = false }
    }

    private func setupScreenshotDetection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil)
        
        guard viewOnce else { return }
        // Add blur effect view to the view hierarchy
        view.addSubview(blurEffectView)
        view.bringSubviewToFront(blurEffectView)
        // Listen for app going to background to hide sensitive content
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideContent),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showContent),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc
    private func handleScreenshot() {
        guard let previewDataSource = previewDataSource,
              let previewItem = previewDataSource.previewItem(at: initialIndex)
        else { return }

        // Don't show screenshot alert for voice messages
        if case let .attachment(attachment) = previewItem, attachment.type == "voice" {
            return
        }

        showScreenshotAlert()
    }

    private func showScreenshotAlert() {
        self.showAlert(title: L10n.ViewOnce.Screenshot.Alert.title,
                       message: L10n.ViewOnce.Screenshot.Alert.message,
                       actions: [SheetAction(title: L10n.Alert.Button.ok)])
    }
    
    @objc
    private func hideContent() {
        UIView.animate(withDuration: 0.2) {
            self.blurEffectView.alpha = 1
        }
    }
    
    @objc
    private func showContent() {
        UIView.animate(withDuration: 0.2) {
            self.blurEffectView.alpha = 0
        }
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            let currentIndex: Int?
            if let mediaVC = viewControllers?.first as? MediaPreviewerViewController {
                currentIndex = mediaVC.viewModel.index
            } else if let audioVC = viewControllers?.first as? MediaPreviewerAudioViewController {
                currentIndex = audioVC.viewModel.index
            } else {
                currentIndex = nil
            }

            if let currentIndex = currentIndex, initialIndex != currentIndex {
                initialSourceView?.alpha = 1.0
            }
        }
    }
    
    @objc
    private func dismiss(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc
    open func shareButtonAction(_ sender: UIBarButtonItem) {
        (viewControllers?.first as? MediaPreviewerViewController)?.shareButtonAction(sender)
    }

    @objc
    open func oneTimeButtonAction(_ sender: UIBarButtonItem) {
        let viewOnceInfoVC = ViewOnceInfoViewController()
        viewOnceInfoVC.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            if let sheet = viewOnceInfoVC.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = false
                sheet.preferredCornerRadius = 10
            }
        }

        present(viewOnceInfoVC, animated: true)
    }

    open func updateRightBarButtonItems() {
        var items: [UIBarButtonItem] = []
        if shouldShowOneTimeButton() {
            items.append(oneTimeButton)
        } else {
            items.append(shareButton)
        }
        navigationItem.rightBarButtonItems = items
    }

    open func shouldShowOneTimeButton() -> Bool {
        return viewOnce
    }

    override open var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        guard !viewOnce else { return nil }

        let index: Int
        if let mediaVC = viewController as? MediaPreviewerViewController {
            index = mediaVC.viewModel.index
        } else if let audioVC = viewController as? MediaPreviewerAudioViewController {
            index = audioVC.viewModel.index
        } else {
            return nil
        }

        guard let previewDataSource = previewDataSource else { return nil }
        guard index <= (previewDataSource.numberOfImages - 2)
        else {
            resetPreviewViewControllerIfNeeded(currentIndex: index)
            return nil
        }
        return previewViewController(for: index + 1)
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard !viewOnce else { return nil }

        let index: Int
        if let mediaVC = viewController as? MediaPreviewerViewController {
            index = mediaVC.viewModel.index
        } else if let audioVC = viewController as? MediaPreviewerAudioViewController {
            index = audioVC.viewModel.index
        } else {
            return nil
        }

        guard index > 0
        else {
            resetPreviewViewControllerIfNeeded(currentIndex: index)
            return nil
        }
        return previewViewController(for: index - 1)
    }
    
    open func previewViewController(for index: Int) -> ViewController? {
        guard let previewItem = previewDataSource?.previewItem(at: index)
        else { return nil }

        // Check if the attachment is audio
        if case let .attachment(attachment) = previewItem, attachment.type == "voice" {
            let viewController = Components.mediaPreviewerAudioViewController.init()
            viewController.viewOnce = self.viewOnce
            viewController.messageText = self.messageText
            viewController.viewModel = Components.previewerViewModel
                .init(
                    index: index,
                    previewItem: previewItem)
            previewDataSource?.observe(viewController.viewModel)
            return viewController
        } else {
            let viewController = Components.mediaPreviewerViewController.init()
            viewController.viewOnce = self.viewOnce
            viewController.messageText = self.messageText
            viewController.viewModel = Components.previewerViewModel
                .init(
                    index: index,
                    previewItem: previewItem)
            previewDataSource?.observe(viewController.viewModel)
            return viewController
        }
    }
    
    open func resetPreviewViewControllerIfNeeded(currentIndex: Int) {
        guard let previewDataSource = previewDataSource else { return }
        if previewDataSource.isLoading {
            previewDataSource.setOnLoading { [weak self] done in
                if let self, done {
                    self.resetPreviewViewControllers()
                }
            }
        } else if currentIndex == 0 || currentIndex > previewDataSource.numberOfImages - 2 {
            previewDataSource.setOnReload { [weak self] in
                self?.resetPreviewViewControllers()
            }
        } else {}
    }
    
    private func resetPreviewViewControllers() {
        _ = viewControllers?.compactMap { viewController -> ViewController? in
            if let mediaVC = viewController as? MediaPreviewerViewController {
                let item = mediaVC.viewModel.previewItem
                if let index = previewDataSource?.indexOfItem(item) {
                    mediaVC.viewModel = Components.previewerViewModel.init(index: index, previewItem: item)
                }
                mediaVC.bindPreviewItem()
                return mediaVC
            } else if let audioVC = viewController as? MediaPreviewerAudioViewController {
                let item = audioVC.viewModel.previewItem
                if let index = previewDataSource?.indexOfItem(item) {
                    audioVC.viewModel = Components.previewerViewModel.init(index: index, previewItem: item)
                }
                audioVC.bindPreviewItem()
                return audioVC
            }
            return nil
        }
//        setViewControllers(resetViewControllers, direction: .forward, animated: false)
    }
}
