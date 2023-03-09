//
//  BaseView.swift
//  SceytChatUIKit
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
            navigationController?
                .navigationBar
                .topItem?
                .backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
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
