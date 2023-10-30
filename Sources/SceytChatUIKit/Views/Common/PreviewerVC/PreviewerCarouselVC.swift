//
//  PreviewerCarouselVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class PreviewerCarouselVC: UIPageViewController,
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate
{
    public weak var initialSourceView: UIImageView?
    
    open var sourceView: UIImageView? {
        guard let vc = viewControllers?.first as? PreviewerVC else {
            return nil
        }
        return initialIndex == vc.viewModel.index ? initialSourceView : nil
    }
    
    public var sourceFrameRelativeToWindow: CGRect?
    
    open var targetView: UIImageView? {
        guard let vc = viewControllers?.first as? PreviewerVC else {
            return nil
        }
        return vc.targetView
    }
    
    public var previewDataSource: PreviewDataSource?
    
    private let initialIndex: Int
    
    open var imageContentMode: UIView.ContentMode = .scaleAspectFit
    open lazy var backgroundView = UIView().withoutAutoresizingMask
    open lazy var titleLabel = UILabel()
    open lazy var subtitleLabel = UILabel()
    open lazy var titleView = UIStackView(column: titleLabel, subtitleLabel, alignment: .center)
    
    deinit {
        debugPrint("[PreviewerCarouselVC] deinit")
        
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
    
    public let appearance = Components.previewerVC.appearance
    
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
        
        view.backgroundColor = .background
        navigationController?.navigationBar.barTintColor = appearance.tintColor
        navigationController?.navigationBar.backgroundColor = appearance.backgroundColor
        navigationController?.navigationBar.standardAppearance = .init()
        navigationController?.navigationBar.standardAppearance.backgroundColor = appearance.backgroundColor
        navigationController?.navigationBar.scrollEdgeAppearance = .init()
        navigationController?.navigationBar.scrollEdgeAppearance?.backgroundColor = appearance.backgroundColor
        backgroundView.backgroundColor = appearance.backgroundColor
        backgroundView.alpha = 1
        
        backButton.imageInsets = .init(top: 0, left: -8, bottom: 0, right: 0)
        backButton.tintColor = appearance.tintColor
        
        shareButton.tintColor = appearance.tintColor
        
        titleLabel.font = appearance.titleFont
        titleLabel.textColor = appearance.tintColor
        
        subtitleLabel.font = appearance.subTitleFont
        subtitleLabel.textColor = appearance.tintColor.withAlphaComponent(0.5)
    }
    
    open func setupDone() {
        if let previewDataSource = previewDataSource,
           let previewItem = previewDataSource.previewItem(at: initialIndex)
        {
            let initialVC = Components.previewerVC.init()
            initialVC.imageContentMode = imageContentMode
            initialVC.viewModel = Components.previewerVM
                .init(
                    index: initialIndex,
                    previewItem: previewItem)
            previewDataSource.observe(initialVC.viewModel)
            setViewControllers([initialVC], direction: .forward, animated: true)
        }
        
        view.subviews.forEach { ($0 as? UIScrollView)?.delaysContentTouches = false }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed,
           let vc = viewControllers?.first as? PreviewerVC,
           initialIndex != vc.viewModel.index
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
        (viewControllers?.first as? PreviewerVC)?.shareButtonAction(sender)
    }
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        guard let vc = viewController as? PreviewerVC else { return nil }
        guard let previewDataSource = previewDataSource else { return nil }
        let index = vc.viewModel.index
        guard index <= (previewDataSource.numberOfImages - 2)
        else {
            resetPreviewVCIfNeeded(currentIndex: index)
            return nil
        }
        return previewVC(for: index + 1)
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard let vc = viewController as? PreviewerVC else { return nil }
        let index = vc.viewModel.index
        guard index > 0
        else {
            resetPreviewVCIfNeeded(currentIndex: index)
            return nil
        }
        return previewVC(for: index - 1)
    }
    
    open func previewVC(for index: Int) -> PreviewerVC? {
        guard let previewItem = previewDataSource?.previewItem(at: index)
        else { return nil }
        let vc = Components.previewerVC.init()
        vc.viewModel = Components.previewerVM
            .init(
                index: index,
                previewItem: previewItem)
        previewDataSource?.observe(vc.viewModel)
        return vc
    }
    
    open func resetPreviewVCIfNeeded(currentIndex: Int) {
        guard let previewDataSource = previewDataSource else { return }
        if previewDataSource.isLoading {
            previewDataSource.setOnLoading { [weak self] done in
                if let self, done {
                    self.resetPreviewVCs()
                }
            }
        } else if currentIndex == 0 || currentIndex > previewDataSource.numberOfImages - 2 {
            previewDataSource.setOnReload { [weak self] in
                self?.resetPreviewVCs()
            }
        } else {}
    }
    
    private func resetPreviewVCs() {
        _ = viewControllers?
            .compactMap { $0 as? PreviewerVC }
            .map {
                let item = $0.viewModel.previewItem
                if let index = previewDataSource?.indexOfItem(item) {
                    $0.viewModel = .init(index: index, previewItem: item)
                }
                $0.bindPreviewItem()
                return $0
            }
//        setViewControllers(resetVCs, direction: .forward, animated: false)
    }
}
