//
//  PreviewerCarouselVC.swift
//  SceytChatUIKit
//

import UIKit

public protocol PreviewDataSource: AnyObject {
    func numberOfImages() -> Int
    func previewItem(at index: Int) -> PreviewItem
    func indexOfItem(_ item: PreviewItem) -> Int?
}

public class PreviewerCarouselVC: UIPageViewController, PreviewerTransitionViewControllerConvertible {
    weak var initialSourceView: UIImageView?
    var sourceView: UIImageView? {
        guard let vc = viewControllers?.first as? PreviewerVC else {
            return nil
        }
        return initialIndex == vc.index ? initialSourceView : nil
    }
    
    var targetView: UIImageView? {
        guard let vc = viewControllers?.first as? PreviewerVC else {
            return nil
        }
        return vc.targetView
    }
    
    weak var previewDataSource: PreviewDataSource?
    
    private let initialIndex: Int
    
    private let imageContentMode: UIView.ContentMode = .scaleAspectFill
        
    private(set) var navBar = PreviewNavBar()
    
    private(set) var backgroundView: UIView = {
        $0.backgroundColor = PreviewerVC.appearance.backgroundColor
        $0.alpha = 1
        return $0
    }(UIView())
    
    private(set) lazy var navItem = UINavigationItem()
    
    private let imageViewerPresentationDelegate: ImageViewerTransitionPresentationManager
    
    public init(
        sourceView: UIImageView,
        title: String? = nil,
        subtitle: String? = nil,
        previewDataSource: PreviewDataSource?,
        initialIndex: Int = 0)
    {
        self.initialSourceView = sourceView
        self.initialIndex = initialIndex
        self.previewDataSource = previewDataSource
        let pageOptions = [UIPageViewController.OptionsKey.interPageSpacing: 20]
            
        self.imageViewerPresentationDelegate = ImageViewerTransitionPresentationManager(imageContentMode: imageContentMode)
        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: pageOptions)
        
        transitioningDelegate = imageViewerPresentationDelegate
        modalPresentationStyle = .custom
        modalPresentationCapturesStatusBarAppearance = true
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addBackgroundView() {
        view.addSubview(backgroundView.withoutAutoresizingMask)
        backgroundView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        view.sendSubviewToBack(backgroundView)
    }
    
    private func addNavBar() {
        let backButton = UIBarButtonItem(
            image: Images.videoPlayerBack,
            style: .plain,
            target: self,
            action: #selector(dismiss(_:)))
        backButton.tintColor = PreviewerVC.appearance.tintColor
        navItem.leftBarButtonItem = backButton
        
        navBar.alpha = 0.0
        navBar.setItem(navItem)
        view.addSubview(navBar.withoutAutoresizingMask)
        navBar.pin(to: view, anchors: [.leading, .trailing, .top])
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        addBackgroundView()
        addNavBar()
        
        dataSource = self
        
        if let previewDataSource = previewDataSource {
            let initialVC: PreviewerVC = .init(
                index: initialIndex,
                previewItem: previewDataSource.previewItem(at: initialIndex))
            setViewControllers([initialVC], direction: .forward, animated: true)
        }
    }
    
    @objc
    private func dismiss(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    deinit {
        initialSourceView?.alpha = 1.0
    }
    
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
}

extension PreviewerCarouselVC: UIPageViewControllerDataSource {
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        guard let vc = viewController as? PreviewerVC else { return nil }
        guard let previewDataSource = previewDataSource else { return nil }
        guard vc.index > 0 else { return nil }
            
        let newIndex = vc.index - 1
        return PreviewerVC(
            index: newIndex,
            previewItem: previewDataSource.previewItem(at: newIndex))
    }
    
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard let vc = viewController as? PreviewerVC else { return nil }
        guard let previewDataSource = previewDataSource else { return nil }
        guard vc.index <= (previewDataSource.numberOfImages() - 2) else { return nil }
            
        let newIndex = vc.index + 1
        return PreviewerVC(
            index: newIndex,
            previewItem: previewDataSource.previewItem(at: newIndex))
    }
}

class PreviewNavBar: View {
    let navBar: UINavigationBar = {
        $0.isTranslucent = true
        $0.setBackgroundImage(UIImage(), for: .default)
        $0.shadowImage = UIImage()
        return $0
    }(UINavigationBar())
    
    override func setup() {
        super.setup()
        
        backgroundColor = PreviewerVC.appearance.backgroundColor
    }
    
    override func setupLayout() {
        super.setupLayout()
        
        addSubview(navBar.withoutAutoresizingMask)
        navBar.pin(to: self, anchors: [.leading, .trailing, .bottom])
        navBar.topAnchor.pin(to: safeAreaLayoutGuide.topAnchor)
    }
    
    func setItem(_ item: UINavigationItem) {
        navBar.items = [item]
    }
    
    func set(title: String?, subtitle: String?) {
        let titleLabel = UILabel()
        titleLabel.font = PreviewerVC.appearance.titleFont
        titleLabel.textColor = PreviewerVC.appearance.tintColor
        titleLabel.text = title
        let subtitleLabel = UILabel()
        subtitleLabel.font = PreviewerVC.appearance.subTitleFont
        subtitleLabel.textColor = PreviewerVC.appearance.tintColor.withAlphaComponent(0.5)
        subtitleLabel.text = subtitle
        navBar.topItem?.titleView = UIStackView(column: titleLabel, subtitleLabel, alignment: .center)
    }
    
    func setRightBarButton(_ barButtonItem: UIBarButtonItem) {
        navBar.topItem?.rightBarButtonItem = barButtonItem
    }
}
