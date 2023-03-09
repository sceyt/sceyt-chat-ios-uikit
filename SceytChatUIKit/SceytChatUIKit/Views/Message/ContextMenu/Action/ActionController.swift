//
//  ActionController.swift
//  Emoji-Custom-Transition
//
//

import UIKit

open class ActionController: ViewController {

    open lazy var emojiContainer = UIView()
        .withoutAutoresizingMask
    
    open lazy var menuContainer = UIView()
        .withoutAutoresizingMask
    
    public private(set) var snapshot: UIView?
    
    public lazy var emojiController = EmojiController()
    public lazy var menuController = MenuController()
    
    public let horizontalAlignment: ContextMenu.HorizontalAlignment
    public let transition: ActionTransition

    private(set) weak var contextView: UIView?
    let identifier: Identifier
    
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
            emojiContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 10).priority(.defaultHigh)
        case .trailing:
            snapshot.trailingAnchor.pin(to: emojiContainer.trailingAnchor).priority(.defaultLow)
            view.trailingAnchor.pin(greaterThanOrEqualTo: emojiContainer.trailingAnchor, constant: 10).priority(.defaultHigh)
        case .center:
            emojiContainer.centerXAnchor.pin(to: snapshot.centerXAnchor).priority(.defaultLow)
            emojiContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 10).priority(.defaultHigh)
        }
        snapshot.topAnchor.pin(to: emojiContainer.bottomAnchor, constant: 10).priority(.init(500))
        emojiContainer.topAnchor.pin(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).priority(.defaultHigh)

        view.addSubview(menuContainer)
        menuController.addAsChild(to: self, containerView: menuContainer)
        switch horizontalAlignment {
        case .leading:
            menuContainer.leadingAnchor.pin(to: snapshot.leadingAnchor).priority(.defaultLow)
            menuContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 10).priority(.defaultHigh)
        case .center:
            menuContainer.centerXAnchor.pin(to: snapshot.centerXAnchor).priority(.defaultLow)
            menuContainer.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: 10).priority(.defaultHigh)
        case .trailing:
            snapshot.trailingAnchor.pin(to: menuContainer.trailingAnchor).priority(.defaultLow)
            view.trailingAnchor.pin(greaterThanOrEqualTo: menuContainer.trailingAnchor, constant: 10).priority(.defaultHigh)
        }
        menuContainer.widthAnchor.pin(to: view.widthAnchor, multiplier: 0.7).priority(.defaultLow)
        menuContainer.topAnchor.pin(to: snapshot.bottomAnchor, constant: 10)
        view.safeAreaLayoutGuide.bottomAnchor.pin(greaterThanOrEqualTo: menuContainer.bottomAnchor, constant: 10).priority(.required)
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
        if emojiContainer.frame.contains(point) {
            let converted = view.convert(point, to: emojiController.view)
            emojiController.focusEmoji(at: converted)
        } else if menuContainer.frame.contains(point) {
            let converted = view.convert(point, to: menuController.view)
            menuController.focusOption(at: converted)
        } else {
            emojiController.focusEmoji(at: nil)
            menuController.focusOption(at: nil)
        }
    }
    
    func selectView(at point: CGPoint) {
        emojiController.selectHighlightedIfNeeded()
        if menuContainer.frame.contains(point) {
            let converted = view.convert(point, to: menuController.view)
            menuController.selectOption(at: converted)
        }
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
        switch sender.state {
        case .began:
            highlightView(at: location)
        case .changed:
            highlightView(at: location)
        case .ended:
            selectView(at: location)
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
        containerView.addSubview(self.view)
        self.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            view.topAnchor.constraint(equalTo: containerView.topAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        viewController.addChild(self)
        self.didMove(toParent: viewController)
    }
    
    func remove(from parentViewController: UIViewController) {
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }

}
