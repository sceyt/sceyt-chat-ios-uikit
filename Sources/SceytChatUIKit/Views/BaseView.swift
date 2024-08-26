//
//  BaseView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

public protocol Configurable {

    func setup()

    func setupLayout()

    func setupAppearance()
    
    func setupDone()
}

public protocol Bindable {
    associatedtype BindableData

    func bind(_ data: BindableData)
}

open class View: UIView, Configurable {
    
    private var isConfigured = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupAppearance()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
}

open class Control: UIControl, Configurable {

    private var isConfigured = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupAppearance()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
}

open class HighlightableControl: Control {
    open var backgroundColors: (normal: UIColor?, highlighted: UIColor?, selected: UIColor?) = (nil, UIColor.surface2, UIColor.surface2)
    
    open override var isSelected: Bool {
        didSet {
            backgroundColor = isSelected ? backgroundColors.selected : isHighlighted ? backgroundColors.highlighted : backgroundColors.normal
        }
    }
    
    open override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? backgroundColors.highlighted : isSelected ? backgroundColors.selected : backgroundColors.normal
        }
    }
}


open class Button: UIButton, Configurable {
    
    private var isConfigured = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupAppearance()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupDone()
        setupLayout()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
}

open class TextView: UITextView, Configurable {
    
    private var isConfigured = false

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
}

open class TableView: UITableView, Configurable {
    
    private var isConfigured = false
    
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        setup()
        setupAppearance()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }
    
    open func setup() {
        
    }
    
    open func setupLayout() {
        setNeedsLayout()
    }
    
    open func setupAppearance() {}
    
    open func setupDone() {}
}

open class TableViewCell: UITableViewCell, Configurable {
    
    private var isConfigured = false

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        
        subscriptions = []
    }
}

open class TableViewHeaderFooterView: UITableViewHeaderFooterView, Configurable {
    private var isConfigured = false
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }
    
    public override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setup()
        setupAppearance()
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }
    
    open func setup() {}
    
    open func setupLayout() {
        setNeedsLayout()
    }
    
    open func setupAppearance() {}
    
    open func setupDone() {}
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        
        subscriptions = []
    }
}

open class CollectionView: UICollectionView, Configurable {
    
    private var isConfigured = false
    
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setup()
        setupAppearance()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }
    
    open func setup() {}
    
    open func setupLayout() {
        setNeedsLayout()
    }
    
    open func setupAppearance() {}
    
    open func setupDone() {}
}

open class CollectionReusableView: UICollectionReusableView, Configurable {
    
    private var isConfigured = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupAppearance()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        
        subscriptions = []
    }
}

open class CollectionViewCell: UICollectionViewCell {

    private var isConfigured = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupAppearance()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAppearance()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !isConfigured else { return }
        setupLayout()
        setupDone()
        isConfigured = true
    }

    open func setup() {}

    open func setupLayout() {
        setNeedsLayout()
    }

    open func setupAppearance() {}
    
    open func setupDone() {}
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        
        subscriptions = []
    }

}

open class ViewController: UIViewController, Configurable {
    
    /// Remove NavigationBar back bar button default text
    public var removeBackBarButtonItemDefaultText = true

    open override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupAppearance()
        setupLayout()
        setupDone()
    }

    open func setup() {}

    open func setupLayout() {
        view.setNeedsLayout()
    }

    open func setupAppearance() {
        view.setNeedsDisplay()
        view.backgroundColor = .background
        navigationController?.navigationBar.barTintColor = .white
    }
    
    open func setupDone() {}
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if removeBackBarButtonItemDefaultText {
            let backBarButtonItem = navigationController?.navigationBar.topItem?.backBarButtonItem
            if backBarButtonItem == nil || !(backBarButtonItem is _EmptyBarButtonItem) {
                navigationController?.navigationBar.topItem?.backBarButtonItem =
                _EmptyBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            }
        }
    }
    
    class _EmptyBarButtonItem: UIBarButtonItem {
        override var title: String? {
            set {}
            get { "" }
        }
        
    }
}

open class TableViewController: UITableViewController, Configurable {

    open override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupAppearance()
        setupLayout()
        setupDone()
    }

    open func setup() {}

    open func setupLayout() {
        view.setNeedsLayout()
    }

    open func setupAppearance() {
        view.setNeedsDisplay()
        view.backgroundColor = .background
        navigationController?.navigationBar.barTintColor = .white
    }
    
    open func setupDone() {}
}

open class NavigationController: UINavigationController, Configurable {
    open var onPop: (() -> Bool)?
    open var onPush: (() -> Bool)?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        setupAppearance()
        setupLayout()
        setupDone()
    }
    
    open func setup() {
//        modalPresentationStyle = .fullScreen
    }
    
    open func setupAppearance() {
        navigationBar.tintColor = appearance.tintColor
        navigationBar.standardAppearance = appearance.standard
        navigationBar.scrollEdgeAppearance = appearance.standard
    }
    
    open func setupLayout() {
        view.setNeedsLayout()
    }
    
    open func setupDone() {}
    
    open override func popViewController(animated: Bool) -> UIViewController? {
        if onPop?() == true {
            return nil
        }
        onPop = nil
        return super.popViewController(animated: animated)
    }
    
    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if onPush?() == true {
            return
        }
        onPush = nil
        super.pushViewController(viewController, animated: animated)
    }
    
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations ?? .allButUpsideDown
    }
    
    open override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        topViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        topViewController?.preferredStatusBarStyle ?? .darkContent
    }

}

open class TabBarController: UITabBarController, Configurable {
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        setupAppearance()
        setupLayout()
        setupDone()
    }
    
    open func setup() {}
    
    open func setupAppearance() {}
    
    open func setupLayout() {
        view.setNeedsLayout()
    }
    
    open func setupDone() {}
    
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        selectedViewController?.supportedInterfaceOrientations ?? .allButUpsideDown
    }
    
    open override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        selectedViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        selectedViewController?.preferredStatusBarStyle ?? .darkContent
    }
}

public protocol AnyCancellableProvider: AnyObject {
    
    var subscriptions: Set<AnyCancellable> { get set }
}

public extension AnyCancellableProvider where Self: UIResponder {
    
    var subscriptions: Set<AnyCancellable> {
        get {
            var provider = anyCancellableProvider
            if provider == nil {
                provider = Set<AnyCancellable>()
                anyCancellableProvider = provider
            }
            return provider!
        }
        set {
            anyCancellableProvider = newValue
        }
    }
}

private extension UIResponder {
    static var anyCancellableProviderKey: UInt8 = 1
    
    class Object: NSObject {
        var cancellable: Set<AnyCancellable>?
        init(cancellable: Set<AnyCancellable>? = nil) {
            self.cancellable = cancellable
        }
    }
    
    var anyCancellableProvider: Set<AnyCancellable>? {
        get {
            let value = objc_getAssociatedObject(self, &Self.anyCancellableProviderKey)
            if let object = value as? Object {
                return object.cancellable
            } else {
                return nil
            }
        }
        set {
            objc_setAssociatedObject(self, &Self.anyCancellableProviderKey, Object(cancellable: newValue), .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension UIResponder: AnyCancellableProvider {
    
}

