//
//  EmojiViewController.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class EmojiVC: ViewController,
                        UICollectionViewDataSource,
                        UICollectionViewDelegate {

    open lazy var viewModel = instance(of: EmojiViewModel.self)
        .init()

    open var onEvent: ((Event) -> Void)?

    open lazy var collectionViewLayout = UICollectionViewFlowLayout()

    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        .withoutAutoresizingMask

    open lazy var headerView = HeaderView()
        .withoutAutoresizingMask

    open override func viewDidLoad() {
        super.viewDidLoad()
    }

    open override func setup() {
        super.setup()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(instance(of: EmojiCollectionViewCell.self))
        collectionView.register(instance(of: EmojiSectionHeaderView.self),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: EmojiSectionHeaderView.reuseId)
    }

    open override func setupAppearance() {
        super.setupAppearance()
        collectionViewLayout.itemSize = CGSize(width: 50, height: 50)
        collectionViewLayout.headerReferenceSize = CGSize(width: view.frame.size.width, height: 30)
        collectionViewLayout.scrollDirection = .vertical
        collectionView.backgroundColor = .white
        view.layer.cornerRadius = 14
        view.clipsToBounds = true
    }

    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(headerView)
        view.addSubview(collectionView)
        headerView.pin(to: view, anchors: [.leading(), .trailing(), .top()])
        headerView.heightAnchor.pin(constant: 36)
        collectionView.pin(to: view, anchors: [.leading(), .trailing(), .bottom()])
        collectionView.topAnchor.pin(to: headerView.bottomAnchor)
    }

    // MARK: UICollectionViewDataSource
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        viewModel.numberOfSections
    }

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfRows(at: section)
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: EmojiCollectionViewCell.self)
        cell.label.text = viewModel.code(at: indexPath)
        return cell
    }

    // MARK: UICollectionViewDelegate

    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                withReuseIdentifier: instance(of: EmojiSectionHeaderView.self).reuseId,
                                                                                for: indexPath) as! EmojiSectionHeaderView
            sectionHeader.bind(viewModel.groupTitle(at: indexPath.section))
            return sectionHeader
        } else {
            return UICollectionReusableView()
        }
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let code = viewModel.code(at: indexPath) else { return }
        onEvent?(.selectEmoji(code))
        dismiss(animated: true, completion: nil)
    }

    // MARK: Present

    @discardableResult
    public static func present(on view: UIViewController) -> EmojiVC {
        let emoji = instance(of: EmojiVC.self)
            .init()
        let nav = instance(of: EmojiViewInteractiveTransitionNavigationController.self)
            .init(rootViewController: emoji)
        view.present(nav, animated: true, completion: nil)
        return emoji
    }
}

public extension EmojiVC {
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
        case full
        case half
    }
}

extension EmojiVC {

    open class HeaderView: View {

        lazy var swipeView = UIImageView(image: Appearance.Images.swipeIndicator)
            .withoutAutoresizingMask

        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = Appearance.Colors.background
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(swipeView)
            swipeView.pin(to: self, anchors: [.centerX(), .top(8)])
            swipeView.resize(anchors: [.width(38), .height(4)])
        }
    }
}

open class EmojiViewPresentationController: UIPresentationController, UIGestureRecognizerDelegate {

    public override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    open lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
    open lazy var tapGesture: UITapGestureRecognizer = {
        let t = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        t.delegate = self
        return t
    }()

    open private(set) var state: EmojiVC.State = .half
    open private(set) var direction: CGFloat = 0
    open private(set) var shouldComplete: Bool = false
    open var topAnchor = CGFloat(64)

    lazy var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

    @objc
    open func tapAction(_ tap: UITapGestureRecognizer) {
        presentedViewController.dismiss(animated: true, completion: nil)
    }

    @objc
    open func panAction(_ pan: UIPanGestureRecognizer) {
        let endPoint = pan.translation(in: pan.view)

        switch pan.state {
        case .began:
            presentedView!.frame.size.height = containerView!.frame.height
        case .changed:
            let velocity = pan.velocity(in: pan.view?.superview)
            switch state {
            case .half:
                presentedView!.frame.origin.y = endPoint.y + containerView!.frame.height / 2
            case .full:
                presentedView!.frame.origin.y = endPoint.y
            }
            presentedView!.frame.origin.y = max(presentedView!.frame.origin.y, 0) + topAnchor
            direction = velocity.y

            break
        case .ended:
            if direction < 0 {
                changeState(to: .full)
            } else {
                if state == .full {
                    changeState(to: .half)
                } else if state == .half, direction < 1000 {
                    changeState(to: .half)
                } else {
                    presentedViewController.dismiss(animated: true, completion: nil)
                }
            }
            break
        default:
            break
        }
    }

    open func frameFor(state: EmojiVC.State) -> CGRect {
        guard let containerView = containerView else { return .zero }
        switch state {
        case .full:
            return CGRect(x: containerView.frame.origin.x, y: containerView.frame.origin.y + topAnchor, width: containerView.frame.width, height: containerView.frame.height - topAnchor)
        case .half:
            return CGRect(x: 0, y: containerView.frame.height / 2, width: containerView.frame.width, height: containerView.frame.height / 2)
        }
    }

    open func changeState(to state: EmojiVC.State) {
        let frame = frameFor(state: state)
        guard frame != .zero else { return }
        if let presentedView = presentedView {
            UIView.animate(withDuration: 0.2) {
                presentedView.frame = frame
            }
        }
        self.state = state
    }

    open override var frameOfPresentedViewInContainerView: CGRect {
        return CGRect(x: 0, y: containerView!.bounds.height / 2, width: containerView!.bounds.width, height: containerView!.bounds.height / 2)
    }

    open override func presentationTransitionWillBegin() {
        if let _ = self.containerView, let coordinator = presentingViewController.transitionCoordinator {
            blurEffectView.frame = presentingViewController.view.bounds
            blurEffectView.alpha = 0.01
            presentingViewController.view.addSubview(blurEffectView)
            coordinator.animate(alongsideTransition: { (_) in
                self.blurEffectView.alpha = 0.5
            }, completion: nil)
        }
    }

    open override func presentationTransitionDidEnd(_ completed: Bool) {
        presentedViewController.view.addGestureRecognizer(panGesture)
        presentedViewController.view.window?.addGestureRecognizer(tapGesture)
    }

    open override func dismissalTransitionWillBegin() {
        if let coordinator = presentingViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { (_) -> Void in
                self.blurEffectView.alpha = 0.01
            }, completion: { (_) in

            })
        }
    }

    open override func dismissalTransitionDidEnd(_ completed: Bool) {
        presentedViewController.view.removeGestureRecognizer(panGesture)
        presentedViewController.view.window?.removeGestureRecognizer(tapGesture)
        blurEffectView.removeFromSuperview()
    }

    // MARK: UIGestureRecognizerDelegate
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return presentedView?.frame.contains(gestureRecognizer.location(in: nil)) == false
    }
}

public class EmojiViewInteractiveTransitionNavigationController: UINavigationController {

    override required init(rootViewController: UIViewController) {
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
