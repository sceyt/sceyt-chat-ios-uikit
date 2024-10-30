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
    
    open var imageContentMode: UIView.ContentMode = .scaleAspectFit
    open lazy var backgroundView = UIView().withoutAutoresizingMask
    open lazy var titleLabel = UILabel()
    open lazy var subtitleLabel = UILabel()
    open lazy var titleView = UIStackView(column: titleLabel, subtitleLabel, alignment: .center)
    
    deinit {
        logger.debug("[PreviewerCarouselViewController] deinit")
        
        initialSourceView?.alpha = 1.0
    }
    
    public required init(
        sourceView: UIImageView,
        title: String? = nil,
        subtitle: String? = nil,
        previewDataSource: PreviewDataSource,
        initialIndex: Int = 0)
    {
        self.initialSourceView = sourceView
        self.sourceFrameRelativeToWindow = sourceView.frameRelativeToWindow()
        self.initialIndex = initialIndex
        self.previewDataSource = previewDataSource
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
    
    public let appearance = Components.mediaPreviewerViewController.appearance
    
    open func setup() {
        navigationItem.leftBarButtonItem = backButton
        navigationItem.rightBarButtonItem = shareButton
        navigationItem.titleView = titleView
        navigationController?.navigationBar.alpha = 0.0
        
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
        
        backButton.imageInsets = .init(top: 0, left: -8, bottom: 0, right: 0)
        
        titleLabel.font = appearance.titleLabelAppearance.font
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
        
        subtitleLabel.font = appearance.subtitleLabelAppearance.font
        subtitleLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
    }
    
    open func setupDone() {
        if let previewDataSource = previewDataSource,
           let previewItem = previewDataSource.previewItem(at: initialIndex)
        {
            let initialViewController = Components.mediaPreviewerViewController.init()
            initialViewController.imageContentMode = imageContentMode
            initialViewController.viewModel = Components.previewerViewModel
                .init(
                    index: initialIndex,
                    previewItem: previewItem)
            previewDataSource.observe(initialViewController.viewModel)
            setViewControllers([initialViewController], direction: .forward, animated: true)
        }
        
        view.subviews.forEach { ($0 as? UIScrollView)?.delaysContentTouches = false }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed,
           let viewController = viewControllers?.first as? MediaPreviewerViewController,
           initialIndex != viewController.viewModel.index
        {
            initialSourceView?.alpha = 1.0
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
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        guard let viewController = viewController as? MediaPreviewerViewController else { return nil }
        guard let previewDataSource = previewDataSource else { return nil }
        let index = viewController.viewModel.index
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
        guard let viewController = viewController as? MediaPreviewerViewController else { return nil }
        let index = viewController.viewModel.index
        guard index > 0
        else {
            resetPreviewViewControllerIfNeeded(currentIndex: index)
            return nil
        }
        return previewViewController(for: index - 1)
    }
    
    open func previewViewController(for index: Int) -> MediaPreviewerViewController? {
        guard let previewItem = previewDataSource?.previewItem(at: index)
        else { return nil }
        let viewController = Components.mediaPreviewerViewController.init()
        viewController.viewModel = Components.previewerViewModel
            .init(
                index: index,
                previewItem: previewItem)
        previewDataSource?.observe(viewController.viewModel)
        return viewController
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
        _ = viewControllers?
            .compactMap { $0 as? MediaPreviewerViewController }
            .map {
                let item = $0.viewModel.previewItem
                if let index = previewDataSource?.indexOfItem(item) {
                    $0.viewModel = Components.previewerViewModel.init(index: index, previewItem: item)
                }
                $0.bindPreviewItem()
                return $0
            }
//        setViewControllers(resetViewControllers, direction: .forward, animated: false)
    }
}
