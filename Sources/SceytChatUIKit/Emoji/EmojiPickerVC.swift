//
//  EmojiViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

open class EmojiPickerViewController: ViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    EmojiSectionToolBarDelegate
{
    open var viewModel: EmojiListViewModel!

    open var onEvent: ((Event) -> Void)?

    open lazy var collectionViewLayout = UICollectionViewFlowLayout()

    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        .withoutAutoresizingMask

    open lazy var headerToolBar = EmojiSectionToolBar()
        .withoutAutoresizingMask

    override open func viewDidLoad() {
        super.viewDidLoad()
    }

    override open func setup() {
        super.setup()
        headerToolBar.delegate = self
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(Components.emojiPickerCell.self)
        collectionView.register(Components.emojiPickerSectionHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: Components.emojiPickerSectionHeaderView.reuseId)
    }

    override open func setupAppearance() {
        super.setupAppearance()
        collectionViewLayout.itemSize = Components.emojiListViewModel.itemSize
        collectionViewLayout.headerReferenceSize = CGSize(width: view.width, height: 30)
        collectionViewLayout.scrollDirection = .vertical
        collectionViewLayout.minimumInteritemSpacing = Components.emojiListViewModel.interItemSpacing
        collectionViewLayout.sectionInset = Components.emojiListViewModel.sectionInset
        collectionView.contentInset = .init(top: 8, left: 0, bottom: 0, right: 0)
        collectionView.backgroundColor = .clear
        view.layer.cornerRadius = 14
        view.clipsToBounds = true
        view.backgroundColor = appearance.backgroundColor
    }

    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(headerToolBar)
        view.addSubview(collectionView)
        headerToolBar.pin(to: view, anchors: [.leading(), .trailing(), .top()])
        headerToolBar.heightAnchor.pin(constant: 48)
        collectionView.pin(to: view, anchors: [.leading, .trailing, .bottom()])
        collectionView.topAnchor.pin(to: headerToolBar.bottomAnchor)
    }

    // MARK: UICollectionViewDataSource

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        viewModel.numberOfSections
    }

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfRows(at: section)
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.emojiPickerCell.self)
        cell.label.text = viewModel.code(at: indexPath)
        return cell
    }

    // MARK: UICollectionViewDelegate

    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                withReuseIdentifier: Components.emojiPickerSectionHeaderView.reuseId,
                                                                                for: indexPath) as! EmojiPickerViewController.SectionHeaderView
            sectionHeader.bind(viewModel.groupTitle(at: indexPath.section))
            return sectionHeader
        } else {
            return UICollectionReusableView()
        }
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let code = viewModel.code(at: indexPath) else { return }
        viewModel.didSelect(at: indexPath)
        onEvent?(.selectEmoji(code))
        dismiss(animated: true, completion: nil)
    }

    open var lowestVisibleSection = 0

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let newLowestVisibleSection = collectionView
            .indexPathsForVisibleItems
            .reduce(into: Set<Int>()) {
                $0.insert($1.section)
            }.min() ?? 0

        guard scrollingToSection == nil || newLowestVisibleSection == scrollingToSection else { return }
        scrollingToSection = nil
        if lowestVisibleSection != newLowestVisibleSection {
            headerToolBar.setSelectedSection(newLowestVisibleSection)
            lowestVisibleSection = newLowestVisibleSection
        }
    }

    // MARK: EmojiSectionToolBarDelegate

    open var scrollingToSection: Int?

    open func emojiSectionToolBar(_ sectionToolbar: EmojiSectionToolBar, didSelectSection: Int) {
        let section = didSelectSection
        if let attributes = collectionViewLayout.layoutAttributesForSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(item: 0, section: section)
        ) {
            scrollingToSection = section
            let y = attributes.frame.minY - collectionView.contentInset.top + collectionViewLayout.sectionInset.bottom
            collectionView.setContentOffset(CGPoint(x: .zero, y: y), animated: true)
        }
    }

    open func emojiSectionToolBarShouldShowRecentsSection(_ sectionToolbar: EmojiSectionToolBar) -> Bool {
        return viewModel.shouldShowRecentSections
    }
}

public extension EmojiPickerViewController {
    enum Event {
        case selectEmoji(String)

        public var key: String {
            switch self {
            case .selectEmoji(let e):
                return e
            }
        }
    }

    enum State {
        case large
        case small
    }
}

open class EmojiViewPresentationController: UIPresentationController, UIGestureRecognizerDelegate {
    override public init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    open lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
    open lazy var tapGesture: UITapGestureRecognizer = {
        let t = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        t.delegate = self
        return t
    }()

    open var state: EmojiPickerViewController.State = .small
    open private(set) var direction: CGFloat = 0
    open private(set) var shouldComplete: Bool = false
    open lazy var topAnchor: CGFloat = presentedView?.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 64

    private var smallHeight: CGFloat { (containerView?.height ?? 0) * smallHeightRatio }
    open var smallHeightRatio: CGFloat { Layouts.heightRatio }
    
    lazy var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

    @objc
    open func tapAction(_ tap: UITapGestureRecognizer) {
        presentedViewController.dismiss(animated: true, completion: nil)
    }

    @objc
    open func panAction(_ pan: UIPanGestureRecognizer) {
        guard let containerView, let presentedView else { return }

        let endPoint = pan.translation(in: pan.view)

        switch pan.state {
        case .began:
            presentedView.height = containerView.height
        case .changed:
            let velocity = pan.velocity(in: pan.view?.superview)
            switch state {
            case .small:
                presentedView.top = endPoint.y + containerView.height - smallHeight - topAnchor
            case .large:
                presentedView.top = endPoint.y
            }
            presentedView.top = max(presentedView.top, 0) + topAnchor
            direction = velocity.y
        case .ended:
            if direction < 0 {
                changeState(to: .large)
            } else {
                if state == .large {
                    changeState(to: .small)
                } else if state == .small, direction < 1000 {
                    changeState(to: .small)
                } else {
                    presentedViewController.dismiss(animated: true, completion: nil)
                }
            }
        default:
            break
        }
    }

    open func frameFor(state: EmojiPickerViewController.State) -> CGRect {
        guard let containerView = containerView else { return .zero }
        switch state {
        case .large:
            return CGRect(x: containerView.left, y: containerView.top + topAnchor, width: containerView.width, height: containerView.height - topAnchor)
        case .small:
            return CGRect(x: 0, y: containerView.height - smallHeight, width: containerView.width, height: smallHeight)
        }
    }

    open func changeState(to state: EmojiPickerViewController.State) {
        let frame = frameFor(state: state)
        guard frame != .zero else { return }
        if let presentedView = presentedView {
            UIView.animate(withDuration: 0.25) {
                presentedView.frame = frame
            }
        }
        self.state = state
    }

    override open var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        return CGRect(x: 0, y: containerView.height - smallHeight, width: containerView.width, height: smallHeight)
    }

    override open func presentationTransitionWillBegin() {
        if let _ = containerView, let coordinator = presentingViewController.transitionCoordinator {
            blurEffectView.frame = presentingViewController.view.bounds
            blurEffectView.alpha = 0.01
            presentingViewController.view.addSubview(blurEffectView)
            coordinator.animate(alongsideTransition: { _ in
                self.blurEffectView.alpha = 0.5
            }, completion: nil)
        }
    }

    override open func presentationTransitionDidEnd(_ completed: Bool) {
        presentedViewController.view.addGestureRecognizer(panGesture)
        presentedViewController.view.window?.addGestureRecognizer(tapGesture)
    }

    override open func dismissalTransitionWillBegin() {
        if let coordinator = presentingViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.blurEffectView.alpha = 0.01
            }, completion: { _ in

            })
        }
    }

    override open func dismissalTransitionDidEnd(_ completed: Bool) {
        presentedViewController.view.removeGestureRecognizer(panGesture)
        presentedViewController.view.window?.removeGestureRecognizer(tapGesture)
        blurEffectView.removeFromSuperview()
    }

    // MARK: UIGestureRecognizerDelegate

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return presentedView?.frame.contains(gestureRecognizer.location(in: nil)) == false
    }
}

public class EmojiViewInteractiveTransitionNavigationController: NavigationController {
    override public required init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        modalPresentationStyle = .custom
        transitioningDelegate = self
        navigationBar.isHidden = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

extension EmojiViewInteractiveTransitionNavigationController: UIViewControllerTransitioningDelegate {
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return EmojiViewPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

public extension EmojiViewPresentationController {
    enum Layouts {
        public static var heightRatio: CGFloat = 315 / 812
    }
}
