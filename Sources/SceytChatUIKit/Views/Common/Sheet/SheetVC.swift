//
//  Sheet.swift
//  SceytChatUIKit
//
//  Created by Duc on 02/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit

public extension UIViewController {
    @discardableResult
    func showSheet(_ child: UIView,
                   style: SheetVC.Style = .bottom,
                   backgroundDismiss: Bool = true,
                   cornerRadius: CGFloat? = nil,
                   title: String? = nil,
                   onShow: (() -> Void)? = nil,
                   onDone: (() -> Void)? = nil,
                   animated: Bool = true) -> SheetVC
    {
        let vc = SheetVC(child: child,
                         style: style,
                         backgroundDismiss: backgroundDismiss,
                         cornerRadius: cornerRadius,
                         title: title,
                         onShow: onShow,
                         onDone: onDone)
        
        let presenter: UIViewController
        if let tabbar = tabBarController {
            presenter = tabbar
        } else if let nav = navigationController {
            presenter = nav
        } else {
            presenter = self
        }
        presenter.present(vc, animated: false) { [weak vc] in
            vc?.show(animated: animated)
        }
        return vc
    }
    
    @discardableResult
    func showBottomSheet(title: String? = nil, actions: [SheetAction], withCancel: Bool = false) -> SheetVC {
        let vc = SheetVC(child: BottomSheet(title: title,
                                            actions: actions + (withCancel ? [.init(title: L10n.Alert.Button.cancel, style: .cancel)] : [])),
                         style: .floating(),
                         cornerRadius: 0,
                         onCancel: {
                             actions.first(where: { $0.style == .cancel })?.handler?()
                         })
        let presenter: UIViewController
        if let tabbar = tabBarController {
            presenter = tabbar
        } else if let nav = navigationController {
            presenter = nav
        } else {
            presenter = self
        }
        presenter.present(vc, animated: false) { [weak vc] in
            vc?.show()
        }
        return vc
    }
    
    func dismissSheet(animated: Bool = true, completion: (() -> Void)? = nil) {
        var sheetVC: SheetVC?
        if let vc = self as? SheetVC {
            sheetVC = vc
        } else if let vc = presentedViewController as? SheetVC {
            sheetVC = vc
        }
        if let sheetVC {
            sheetVC.dismiss(animated: animated) {
                completion?()
            }
        } else {
            completion?()
        }
    }
}

open class SheetVC: ViewController {
    public enum Style {
        case bottom, floating(CGFloat? = nil), center
    }
    
    public init(child: UIView,
                style: Style = .bottom,
                backgroundDismiss: Bool = true,
                cornerRadius: CGFloat? = nil,
                title: String? = nil,
                onShow: (() -> Void)? = nil,
                onDone: (() -> Void)? = nil,
                onCancel: (() -> Void)? = nil)
    {
        self.style = style
        self.onShow = onShow
        self.onDone = onDone
        self.onCancel = onCancel
        self.child = child
        self.backgroundDismiss = backgroundDismiss
        self.cornerRadius = cornerRadius
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        commonInit()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        self.child = UIView()
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overCurrentContext
    }
    
    private var style: Style = .bottom
    private var onShow: (() -> Void)?
    private var onDone: (() -> Void)?
    private var onCancel: (() -> Void)?
    private var child: UIView?
    private var backgroundDismiss: Bool = true
    private var cornerRadius: CGFloat?
    private var keyboardObserver: KeyboardObserver?
    private var keyboardHeight: CGFloat = 0
        
    // MARK: - Views
    
    private lazy var bg = UIButton().withoutAutoresizingMask
    
    private lazy var titleLabel = UILabel().withoutAutoresizingMask

    private lazy var separator = UIView().withoutAutoresizingMask
    
    private lazy var doneButton = {
        $0.contentEdgeInsets = .init(top: 14, left: 14, bottom: 14, right: 14)
        $0.contentHuggingPriorityH(.required).contentCompressionResistancePriorityH(.required)
        return $0
    }(UIButton().withoutAutoresizingMask)
    
    private lazy var scrollView = UIScrollView().withoutAutoresizingMask
    
    private lazy var container = {
        guard let child else { return $0 }
        
        $0.addSubview(child.withoutAutoresizingMask)
        child.pin(to: $0, anchors: [.leading, .trailing, .bottom])

        if let onDone {
            $0.addSubview(titleLabel)
            $0.addSubview(doneButton)
            $0.addSubview(separator)
            titleLabel.leadingAnchor.pin(to: $0.leadingAnchor, constant: 16)
            titleLabel.centerYAnchor.pin(to: doneButton.centerYAnchor)
            titleLabel.trailingAnchor.pin(to: doneButton.leadingAnchor, constant: -8)
            
            doneButton.pin(to: $0, anchors: [.top, .trailing])
            separator.pin(to: $0, anchors: [.leading, .trailing])
            separator.topAnchor.pin(to: doneButton.bottomAnchor)
            separator.resize(anchors: [.height(1)])
            child.topAnchor.pin(to: separator.bottomAnchor)
        } else {
            child.topAnchor.pin(to: $0.topAnchor)
        }
        return $0
    }(UIView().withoutAutoresizingMask)
    
    private var topConstraint: NSLayoutConstraint?
    private var anchorConstraint: NSLayoutConstraint?

    // MARK: - Setup

    override
    open func setup() {
        super.setup()
        
        bg.addTarget(self, action: #selector(onBackgroundTapped), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(onDoneTapped), for: .touchUpInside)
    }
    
    @objc
    open func onBackgroundTapped() {
        dismiss { [weak self] in
            self?.onCancel?()
        }
    }
    
    @objc
    open func onDoneTapped() {
        dismiss { [weak self] in
            self?.onDone?()
        }
    }
    
    override
    open func setupAppearance() {
        super.setupAppearance()
        
        scrollView.delaysContentTouches = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.layer.cornerRadius = cornerRadius ?? Layouts.cornerRadius
        switch style {
        case .bottom:
            scrollView.layer.masksToBounds = true
            scrollView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            scrollView.backgroundColor = appearance.contentBackgroundColor
        case .floating, .center:
            scrollView.layer.masksToBounds = true
            scrollView.backgroundColor = .clear
        }
        
        view.backgroundColor = .clear
        
        titleLabel.font = appearance.titleFont
        titleLabel.textColor = appearance.titleColor
        
        separator.backgroundColor = appearance.separatorColor
        
        doneButton.setAttributedTitle(NSAttributedString(
            string: L10n.Nav.Bar.done,
            attributes: [
                .foregroundColor: appearance.doneColor ?? .kitBlue,
                .font: appearance.doneFont ?? Fonts.semiBold.withSize(16)
            ]), for: [])
    }
    
    override
    open func setupLayout() {
        super.setupLayout()
        
        scrollView.addSubview(container)
        container.pin(to: scrollView)
        container.widthAnchor.pin(to: scrollView.widthAnchor)
        
        view.addSubview(bg)
        view.addSubview(scrollView)
        bg.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        switch style {
        case .bottom:
            scrollView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing])
            topConstraint = scrollView.topAnchor.pin(to: view.bottomAnchor)
        case .floating:
            scrollView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(Layouts.floatingPadding), .trailing(-Layouts.floatingPadding)])
            topConstraint = scrollView.topAnchor.pin(to: view.bottomAnchor)
        case .center:
            scrollView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(Layouts.centerPadding), .centerX()])
            scrollView.centerYAnchor.pin(to: view.centerYAnchor, constant: -keyboardHeight/2)
            scrollView.transform = .init(scaleX: 1.1, y: 1.1)
            scrollView.alpha = 0
        }
        
        scrollView.heightAnchor.pin(lessThanOrEqualTo: view.heightAnchor, constant: -66).priority = .required
        scrollView.heightAnchor.pin(to: container.heightAnchor).priority = .defaultLow
    }
    
    open func show(animated: Bool = true) {
        func perform() {
            topConstraint?.isActive = false
            anchorConstraint?.isActive = false
            switch style {
            case .bottom:
                anchorConstraint = scrollView.bottomAnchor.pin(to: view.bottomAnchor, constant: -keyboardHeight)
            case .floating(let padding):
                let padding = padding ?? (view.safeAreaInsets.bottom > 0 ? 0 : 8)
                anchorConstraint = scrollView.bottomAnchor.pin(to: view.safeAreaLayoutGuide.bottomAnchor, constant: -keyboardHeight - padding)
            case .center:
                anchorConstraint = scrollView.centerYAnchor.pin(to: view.centerYAnchor, constant: -keyboardHeight/2)
                scrollView.transform = .identity
                scrollView.alpha = 1
            }
            view.backgroundColor = appearance.backgroundColor
            view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: Layouts.animationDuration) {
                perform()
            } completion: { [weak self] _ in
                self?.onShow?()
            }
        } else {
            perform()
            onShow?()
        }
    }
    
    override open func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated {
            UIView.animate(withDuration: Layouts.animationDuration, animations: { [weak self] in
                guard let self else { return }
                self.topConstraint?.isActive = false
                self.anchorConstraint?.isActive = false
                switch self.style {
                case .center:
                    self.child?.alpha = 0
                default:
                    self.topConstraint = self.scrollView.topAnchor.pin(to: self.view.bottomAnchor)
                }
                self.view.backgroundColor = .clear
                self.view.layoutIfNeeded()
            }, completion: { _ in
                super.dismiss(animated: false, completion: completion)
            })
        } else {
            super.dismiss(animated: false, completion: completion)
        }
    }

    override
    open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        keyboardObserver = KeyboardObserver()
            .willChangeFrame { [weak self] in
                self?.keyboardWillChangeFrameNotification(notification: $0)
            }
    }
    
    override
    open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        keyboardObserver = nil
    }
    
    @objc
    open func keyboardWillChangeFrameNotification(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        let screenHeight = ((notification.object as? UIScreen) ?? UIScreen.main).bounds.height
        if keyboardFrame.minY >= screenHeight {
            keyboardHeight = 0
        } else {
            keyboardHeight = screenHeight - keyboardFrame.minY
        }
                
        switch style {
        case .bottom:
            anchorConstraint?.constant = -keyboardHeight
        case .floating(let padding):
            let padding = padding ?? (view.safeAreaInsets.bottom > 0 ? 0 : 8)
            anchorConstraint?.constant = -keyboardHeight - padding
        case .center:
            anchorConstraint?.constant = -keyboardHeight/2
        }
        UIView.animate(withDuration: duration, delay: 0, options: .init(rawValue: curve), animations: view.layoutIfNeeded, completion: nil)
    }
}

extension BottomSheet: SheetProvider {}
extension Alert: SheetProvider {}

public protocol SheetProvider: UIResponder {
    var sheet: SheetVC? { get }
}

public extension SheetProvider {
    var sheet: SheetVC? {
        var parentResponder: UIResponder? = next
        while parentResponder != nil {
            if let sheetVC = parentResponder as? SheetVC {
                return sheetVC
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}

public extension SheetVC {
    enum Layouts {
        public static var cornerRadius: CGFloat = 10
        public static var floatingPadding: CGFloat = 8
        public static var centerPadding: CGFloat = 50
        public static var animationDuration: CGFloat = 0.25
    }
}
