//
//  ActionController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ActionController: ViewController {

    open lazy var emojiContainer = UIView()
        .withoutAutoresizingMask
    
    open lazy var menuContainer = UIView()
        .withoutAutoresizingMask
    
    public private(set) var snapshot: UIView?
    
    public lazy var emojiController = Components.reactionPickerVC.init()
    public lazy var menuController = MenuController()
    
    public let horizontalAlignment: ContextMenu.HorizontalAlignment
    public let transition: ActionTransition

    private(set) weak var contextView: UIView?
    let identifier: Identifier
    public var emojiContainerAtTheTop: Bool {
        Self.emojiTopSpacing == (emojiContainer.frame.minY - view.safeAreaLayoutGuide.layoutFrame.minY)
    }

    private static let emojiTopSpacing: CGFloat = 12
    
    required public init (
        for contextView: UIView,
        identifier: Identifier,
        alignment: ContextMenu.HorizontalAlignment
    ) {
        self.contextView = contextView
        self.identifier = identifier
        self.transition = .init()
        self.horizontalAlignment = alignment
        super.init(nibName: nil, bundle: nil)
        transitioningDelegate = transition
    }
    
    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func setup() {
        super.setup()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onBackgroundTapped(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(onPan))
        panGestureRecognizer.isEnabled = false
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        guard let contextView, let window = contextView.window else { return }
        let snapshotFrame = contextView.superview?.convert(contextView.frame, to: view) ?? .zero
        let snapshotView: UIView?
        if snapshotFrame.height > window.bounds.height {
            snapshotView = preapreSlicedView(contextView: contextView, window: window)
                .withoutAutoresizingMask
        } else {
            snapshotView = contextView.snapshotView(afterScreenUpdates: true)?
                .withoutAutoresizingMask
        }
        
        guard let snapshot = snapshotView else { return }
        snapshot.clipsToBounds = true
        snapshot.layer.cornerRadius = 16
        self.snapshot = snapshot
        view.addSubview(snapshot)
        snapshot.topAnchor.pin(to: view.topAnchor, constant: snapshotFrame.minY).priority(.defaultLow)
        snapshot.leadingAnchor.pin(to: view.leadingAnchor, constant: snapshotFrame.minX)
        snapshot.resize(anchors: [.width(snapshotFrame.width), .height(snapshotFrame.height)])
        view.addSubview(emojiContainer)
        
        emojiController.addAsChild(to: self, containerView: emojiContainer)
        
        emojiContainer.leadingAnchor.pin(to: snapshot.leadingAnchor).priority(.defaultLow)
        emojiContainer.trailingAnchor.pin(to: snapshot.trailingAnchor).priority(.defaultLow)
        
        switch horizontalAlignment {
        case .leading:
            emojiContainer.leadingAnchor.pin(to: snapshot.leadingAnchor).priority(.defaultLow)
            emojiContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 12).priority(.defaultHigh)
        case .trailing:
            snapshot.trailingAnchor.pin(to: emojiContainer.trailingAnchor).priority(.defaultLow)
            view.trailingAnchor.pin(greaterThanOrEqualTo: emojiContainer.trailingAnchor, constant: 12).priority(.defaultHigh)
        case .center:
            emojiContainer.centerXAnchor.pin(to: snapshot.centerXAnchor).priority(.defaultLow)
            emojiContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 12).priority(.defaultHigh)
        }
        snapshot.topAnchor.pin(to: emojiContainer.bottomAnchor, constant: 8).priority(.init(500))
        emojiContainer.topAnchor
            .pin(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: Self.emojiTopSpacing)
            .priority(.defaultHigh)
        
        view.addSubview(menuContainer)
        menuController.addAsChild(to: self, containerView: menuContainer)
        switch horizontalAlignment {
        case .leading:
            menuContainer.leadingAnchor.pin(to: snapshot.leadingAnchor).priority(.defaultLow)
            menuContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 12).priority(.defaultHigh)
        case .center:
            menuContainer.centerXAnchor.pin(to: snapshot.centerXAnchor).priority(.defaultLow)
            menuContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 12).priority(.defaultHigh)
        case .trailing:
            snapshot.trailingAnchor.pin(to: menuContainer.trailingAnchor).priority(.defaultLow)
            view.trailingAnchor.pin(greaterThanOrEqualTo: menuContainer.trailingAnchor, constant: 12).priority(.defaultHigh)
        }
        menuContainer.widthAnchor.pin(to: view.widthAnchor, multiplier: Layouts.menuWidthRatio).priority(.defaultLow)
        menuContainer.topAnchor.pin(to: snapshot.bottomAnchor, constant: 8)
        view.safeAreaLayoutGuide.bottomAnchor.pin(greaterThanOrEqualTo: menuContainer.bottomAnchor, constant: 8).priority(.required)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .clear
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in
            self.dismiss(animated: true)
        }
        
    }
}

public extension ActionController {
    
    func highlightView(at point: CGPoint) {
        let snapshotFrame = snapshot?.frame ?? .zero
        let tapAreaHeightBelowEmoji: CGFloat = 0 // only allow to pan inside emojis container
        if emojiContainer.frame.contains(point) {
            let converted = view.convert(point, to: emojiController.view)
            emojiController.focusEmoji(at: converted)
            menuController.focusOption(at: nil)
        } else if point.y < (emojiContainer.frame.maxY + min(tapAreaHeightBelowEmoji, snapshotFrame.height) + (menuContainer.frame.minY - snapshotFrame.maxY))
                    && point.y >= emojiContainer.frame.maxY
                    && point.x >= emojiContainer.frame.minX
                    && point.x <= emojiContainer.frame.maxX {
            var newPoint = point
            newPoint.y = emojiContainer.frame.maxY - emojiContainer.frame.height / 2
            let converted = view.convert(newPoint, to: emojiController.view)
            emojiController.focusEmoji(at: converted)
            menuController.focusOption(at: nil)
        } else if menuContainer.frame.contains(point) {
            let converted = view.convert(point, to: menuController.view)
            menuController.focusOption(at: converted)
            emojiController.focusEmoji(at: nil)
        } else {
            emojiController.focusEmoji(at: nil)
            menuController.focusOption(at: nil)
        }
    }
    
    func selectHighlighted() {
        emojiController.selectHighlightedIfNeeded()
        menuController.selectHighlightedIfNeeded()
    }

    func setInnerPanGestureActive(_ active: Bool = true) {
        if let panGesture = view.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
            panGesture.isEnabled = active
        }
    }

}

private extension ActionController {

    @objc
    func onPan(sender: UIPanGestureRecognizer) {
        let location = sender.location(in: view)
        let velocity = sender.velocity(in: view)
        switch sender.state {
        case .began:
            guard velocity.y <= 0 else { return }
            highlightView(at: location)
        case .changed:
            guard velocity.y <= 0 else { return }
            highlightView(at: location)
        case .ended:
            selectHighlighted()
        case .failed, .cancelled:
            emojiController.cancelHighlightedIfNeeded()
        default:
            break
        }
    }
    
    @objc
    func onBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        if menuController.view.bounds.contains(gesture.location(in: menuController.view)) {
            return
        }
        dismiss(animated: true)
    }

    func preapreSlicedView(contextView: UIView, window: UIWindow) -> UIView  {
        var rects = [CGRect]()
        var remainder = contextView.bounds
        while remainder.height > .zero {
            let split = remainder.divided(atDistance: window.bounds.height, from: .minYEdge)
            rects.append(split.slice)
            remainder = split.remainder
        }
        let combined = rects
            .compactMap {
                contextView.resizableSnapshotView(
                    from: $0,
                    afterScreenUpdates: true,
                    withCapInsets: .zero
                )
            }
            .reduce(UIView()) { view, area in
                view.bounds.size.width = area.width
                area.frame.origin.y = view.bounds.height
                view.addSubview(area)
                view.bounds.size.height += area.height
                return view
            }
        return combined
    }

}

private extension UIViewController {

    func addAsChild(to viewController: UIViewController, containerView: UIView) {
        containerView.addSubview(view.withoutAutoresizingMask)
        view.leadingAnchor.pin(to: containerView.leadingAnchor)
        view.topAnchor.pin(to: containerView.topAnchor)
        containerView.trailingAnchor.pin(to: view.trailingAnchor)
        containerView.bottomAnchor.pin(to: view.bottomAnchor)
        viewController.addChild(self)
        self.didMove(toParent: viewController)
    }
    
    func remove(from parentViewController: UIViewController) {
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }

}

public extension ActionController {
    enum Layouts {
        public static var menuWidthRatio: CGFloat = 260 / 375
    }
}
