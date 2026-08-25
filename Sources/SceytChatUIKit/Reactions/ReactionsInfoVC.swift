//
//  ReactionsInfoViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ReactionsInfoViewController: ViewController,
                        UIPageViewControllerDataSource,
                        UIPageViewControllerDelegate,
                        UICollectionViewDataSource,
                        UICollectionViewDelegateFlowLayout {
    
    open var onEvent: ((Event) -> Void)?

    open lazy var viewControllers: [UIViewController] = []

    open var userReactionsViewModel: [UserReactionViewModel] = [] {
        didSet {
            // Reuse existing VCs for unchanged VM instances to preserve live animations.
            let oldVCsByVM = Dictionary(
                zip(oldValue, viewControllers).map { (ObjectIdentifier($0), $1) },
                uniquingKeysWith: { first, _ in first }
            )
            viewControllers = userReactionsViewModel.map { vm in
                if let existing = oldVCsByVM[ObjectIdentifier(vm)] {
                    return existing
                }
                let viewController = Components.reactedUserListViewController.init()
                viewController.appearance = appearance
                viewController.viewModel = vm
                viewController.onEvent = { [weak self] event in
                    switch event {
                    case .onSelect(let reaction):
                        self?.onEvent?(.removeReaction(reaction))
                    case .showUserProfile(let user):
                        self?.onEvent?(.showUserProfile(user))
                    }
                }
                return viewController
            }
        }
    }
    open var reactionScoreViewModel: ReactionScoreViewModel!

    open lazy var pageController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)

    open lazy var collectionViewLayout = UICollectionViewFlowLayout()

    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        .withoutAutoresizingMask
    private var transition: ReactionTransition!
    private var hasSelectedInitialItem = false

    public required init() {
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
        view.layer.cornerCurve
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(Components.reactionsInfoHeaderCell)
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
        if let firstViewController = viewControllers.first {
            pageController.setViewControllers([firstViewController], direction: .forward, animated: false)
        }
    }
    
    open override func setupDone() {
        super.setupDone()
        reactionScoreViewModel.startObserver()
        reactionScoreViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .reloadData(let keys):
                    let currentKeys = self.userReactionsViewModel.compactMap { $0.reactionKey }
                    let keysChanged = currentKeys != keys
                    self.updateViewControllers(forKeys: keys)
                    UIView.performWithoutAnimation {
                        self.collectionView.reloadData()
                        self.collectionView.layoutIfNeeded()
                        
                        if let currentVC = self.pageController.viewControllers?.first,
                           let index = self.viewControllers.firstIndex(of: currentVC) {
                            self.collectionView.selectItem(at: .init(item: index, section: .zero), animated: false, scrollPosition: .centeredHorizontally)
                        }
                    }
                }
            }.store(in: &subscriptions)
    }

    open func updateViewControllers(forKeys keys: [String]) {
        let currentKeys = userReactionsViewModel.compactMap { $0.reactionKey }
        guard currentKeys != keys else { return }

        guard let messageId = userReactionsViewModel.first?.messageId else { return }

        // Capture the current page's reaction key before rebuilding
        let currentReactionKey = (pageController.viewControllers?.first as? ReactedUserListViewController)?.viewModel.reactionKey

        // Reuse existing VMs for unchanged keys, create new ones for new keys
        var newVMs: [UserReactionViewModel] = []
        newVMs.append(
            userReactionsViewModel.first(where: { $0.reactionKey == nil })
            ?? Components.userReactionViewModel.init(messageId: messageId, reactionKey: nil)
        )
        for key in keys {
            newVMs.append(
                userReactionsViewModel.first(where: { $0.reactionKey == key })
                ?? Components.userReactionViewModel.init(messageId: messageId, reactionKey: key)
            )
        }

        userReactionsViewModel = newVMs // rebuilds viewControllers via didSet

        // Stay on same reaction key, fall back to "All" (index 0) if it was removed
        let targetIndex = userReactionsViewModel.firstIndex(where: { $0.reactionKey == currentReactionKey }) ?? 0
        pageController.setViewControllers([viewControllers[targetIndex]], direction: .forward, animated: false)
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
        separator.backgroundColor = appearance.separatorColor
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
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.reactionsInfoHeaderCell)
        cell.parentAppearance = appearance.headerCellAppearance
        cell.data = reactionScoreViewModel.value(at: indexPath)
        return cell
    }
    
    open func collectionView(_ collectionView: UICollectionView,
                             willDisplay cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
        if indexPath.item == 0 && !hasSelectedInitialItem {
            // Select first item after layout
            DispatchQueue.main.async {
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
            }
            hasSelectedInitialItem = true
        }
    }

    // MARK: UICollectionViewDelegate
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let currentViewController = pageController.viewControllers?.first,
           let currentIndex = viewControllers.firstIndex(of: currentViewController) {
            let viewControllerToSelect = viewControllers[indexPath.item]
            pageController.setViewControllers(
                [viewControllerToSelect],
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

public extension ReactionsInfoViewController {
    enum Event {
        case removeReaction(ChatMessage.Reaction)
        case showUserProfile(ChatUser)
    }
}
