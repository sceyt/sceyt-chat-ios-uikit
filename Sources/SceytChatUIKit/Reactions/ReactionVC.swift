//
//  ReactionVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ReactionVC: ViewController,
                        UIPageViewControllerDataSource,
                        UIPageViewControllerDelegate,
                        UICollectionViewDataSource,
                        UICollectionViewDelegateFlowLayout {
    
    open var onEvent: ((Event) -> Void)?

    open lazy var viewControllers: [UIViewController] = []

    open var userReactionsViewModel: [UserReactionViewModel] = [] {
        didSet {
            viewControllers = userReactionsViewModel.map {
                let vc = UserReactionListVC()
                vc.viewModel = $0
                vc.onEvent = { [weak self] event in
                    switch event {
                    case .onSelect(let reaction):
                        self?.onEvent?(.removeReaction(reaction))
                    }
                }
                return vc
            }
        }
    }
    open var reactionScoreViewModel: ReactionScoreViewModel!

    open lazy var pageController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)

    open lazy var collectionViewLayout = UICollectionViewFlowLayout()

    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        .withoutAutoresizingMask
    private var transition: ReactionTransition!

    public init() {
        super.init(nibName: nil, bundle: nil)
        transition = .init()
        transitioningDelegate = transition
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        transition = .init()
        transitioningDelegate = transition
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
    }

    open override func setup() {
        super.setup()
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(Components.reactionScoreCell)
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumLineSpacing = .zero
        collectionViewLayout.minimumInteritemSpacing = .zero
        collectionView.contentInset = .init(top: 0, left: 12, bottom: 0, right: 12)
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.reloadData()
        collectionView.selectItem(at: .init(item: .zero, section: .zero), animated: false, scrollPosition: .top)
        pageController.dataSource = self
        pageController.delegate = self
        if let firstVC = viewControllers.first {
            pageController.setViewControllers([firstVC], direction: .forward, animated: false)
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = appearance.backgroundColor
        collectionView.backgroundColor = appearance.backgroundColor
        pageController.view.backgroundColor = appearance.backgroundColor
    }
    
    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(collectionView)
        collectionView.pin(to: view, anchors: [.top(4), .leading, .trailing])
        collectionView.resize(anchors: [.height(46)])
        
        let separator = UIView().withoutAutoresizingMask
        separator.backgroundColor = .borders
        view.addSubview(separator)
        separator.pin(to: view, anchors: [.leading, .trailing])
        separator.topAnchor.pin(to: collectionView.bottomAnchor, constant: 4)
        separator.resize(anchors: [.height(1)])
        
        view.addSubview(pageController.view)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        pageController.view.topAnchor.pin(to: separator.bottomAnchor, constant: 4)
        pageController.view.pin(to: view, anchors: [.leading, .trailing, .bottom])
        addChild(pageController)
        pageController.didMove(toParent: self)
    }

    // MARK: UICollectionViewDataSource
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        reactionScoreViewModel.numberOfItems()
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.reactionScoreCell)
        cell.data = reactionScoreViewModel.value(at: indexPath)
        return cell
    }

    // MARK: UICollectionViewDelegate
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let currentVC = pageController.viewControllers?.first,
           let currentIndex = viewControllers.firstIndex(of: currentVC) {
            let vcToSelect = viewControllers[indexPath.item]
            pageController.setViewControllers(
                [vcToSelect],
                direction: currentIndex > indexPath.item ? .reverse : .forward,
                animated: true
            )
        }
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = reactionScoreViewModel.width(at: indexPath)
        return CGSize(width: width, height: 46)
    }

    // MARK: UIPageViewControllerDataSource
    open func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = viewControllers.firstIndex(of: viewController) else {
            return nil
        }
        let previousIndex = viewControllerIndex - 1
        guard previousIndex >= 0 else {
            return nil
        }
        guard viewControllers.count > previousIndex else {
            return nil
        }
        return viewControllers[previousIndex]
    }
    
    open func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = viewControllers.firstIndex(of: viewController) else {
            return nil
        }
        let nextIndex = viewControllerIndex + 1
        let viewControllersCount = viewControllers.count
        guard viewControllersCount != nextIndex else {
            return nil
        }
        guard viewControllersCount > nextIndex else {
            return nil
        }
        return viewControllers[nextIndex]
    }

    // MARK: UIPageViewControllerDelegate
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        if completed, let currentViewController = pageViewController.viewControllers?.first,
           let index = viewControllers.firstIndex(of: currentViewController) {
            collectionView.selectItem(at: .init(item: index, section: .zero), animated: true, scrollPosition: .centeredHorizontally)
        }
    }

}
public extension ReactionVC {

    enum Event {
        case removeReaction(ChatMessage.Reaction)
    }

}
