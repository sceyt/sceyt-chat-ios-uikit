//
//  ContextMenu.swift
//  Emoji-Custom-Transition
//
//

import UIKit

public protocol ContextMenuDataSource: AnyObject {
    
    func emojis(contextMenu: ContextMenu, identifier: Identifier) -> [String]
    func selectedEmojis(contextMenu: ContextMenu, identifier: Identifier) -> [String]
    func items(contextMenu: ContextMenu, identifier: Identifier) -> [MenuItem]
}

public protocol ContextMenuDelegate: AnyObject {
    
    func didSelect(emoji: String, forViewWith identifier: Identifier)
    func didDeselect(emoji: String, forViewWith identifier: Identifier)
    func didSelectMoreAction(forViewWith identifier: Identifier)
}

public protocol ContextMenuSnapshotDelegate: AnyObject {

    func willMakeSnapshot(forViewWith identifier: Identifier)
    func didMakeSnapshot(forViewWith identifier: Identifier)
}

public protocol ContextMenuSnapshotProviding: AnyObject {

    func onPrepareSnapshot()
    func onFinishSnapshot()
}

public class Identifier: Equatable, Hashable {
    
    public let value: any Hashable
    
    public var userInfo: [AnyHashable: Any]?
    
    public init(value: any Hashable) {
        self.value = value
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value.hashValue)
    }
    
    public  static func == (lhs: Identifier, rhs: Identifier) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
}

final public class ContextMenu {
    
    public private(set) weak var parentController: UIViewController?
    public private(set) var alignments = [Identifier: HorizontalAlignment]()
    public private(set) var actionController: ActionController? {
        didSet {
            if actionController == nil {
                _menuItems = nil
            }
        }
    }
    
    private var longPressStartLocation: CGPoint?
    private var movementStarted = false
    
    public weak var dataSource: ContextMenuDataSource?
    public weak var delegate: ContextMenuDelegate?
    public weak var snapshotDelegate: ContextMenuSnapshotDelegate?
    
    private var _menuItems: [MenuItem]?
    
    public init(parent: UIViewController) {
        self.parentController = parent
    }
    
    public func connect(to view: UIView,
                 identifier: Identifier,
                 alignment: HorizontalAlignment = .center) {
        let gestureRecognizer = IdentifiableLongPressGestureRecognizer(
            target: self,
            action: #selector(onLongTap(gesture:)),
            identifier: identifier)
        view.addGestureRecognizer(gestureRecognizer)
        alignments[identifier] = alignment
    }
    
    public func reload(items: [MenuItem]? = nil) {
        _menuItems = items
        actionController?.menuController.reloadData()
    }
    
}

public extension ContextMenu {
    
    enum HorizontalAlignment {
        case leading
        case center
        case trailing
    }
}

private extension ContextMenu {
    
    @objc
    private func onLongTap(gesture: IdentifiableLongPressGestureRecognizer) {
        guard let view = gesture.view else { return }
        let point = gesture.location(in: actionController?.view)
        switch gesture.state {
        case .began:
            movementStarted = false
            longPressStartLocation = gesture.location(in: parentController?.view)
            snapshotDelegate?.willMakeSnapshot(forViewWith: gesture.identifier)
            actionController = ActionController(
                for: view,
                identifier: gesture.identifier,
                alignment: alignments[gesture.identifier] ?? .center
            )
            _menuItems = nil
            actionController?.loadViewIfNeeded()

            actionController?.emojiController.dataSource = self
            actionController?.emojiController.delegate = self

            actionController?.menuController.dataSource = self

            actionController?.modalPresentationStyle = .custom
            parentController?.present(actionController!, animated: true) { [weak self] in
                self?.snapshotDelegate?.didMakeSnapshot(forViewWith: gesture.identifier)
            }
        case .changed:
            guard let longPressStartLocation else { return }
            let xMovement = abs(point.x - longPressStartLocation.x)
            let yMovement = abs(point.y - longPressStartLocation.y)
            let threshold: CGFloat = 5
            let movement = min(xMovement, yMovement)
            guard movement > threshold || movementStarted else { return }
            movementStarted = true
            actionController?.highlightView(at: point)
        case .ended:
            actionController?.selectView(at: point)
            actionController?.setInnerPanGestureActive()
        default:
            actionController?.setInnerPanGestureActive()
        }
    }
    
}

extension ContextMenu: EmojiControllerDataSource {
    
    public var emojis: [String] {
        if let identifier = actionController?.identifier,
           let emojis = dataSource?.emojis(contextMenu: self, identifier: identifier) {
            return emojis
        }
        return []
    }

    public var selectedEmojis: [String] {
        if let identifier = actionController?.identifier {
            return dataSource?.selectedEmojis(contextMenu: self, identifier: identifier) ?? []
        }
        return []
    }
    
}

extension ContextMenu: EmojiControllerDelegate {
    
    public func didSelect(emoji: String) {
        if let identifier = actionController?.identifier {
            actionController?.dismiss(animated: true, completion: { [weak self] in
                self?.delegate?.didSelect(emoji: emoji, forViewWith: identifier)
            })
        }
    }

    public func didDeselect(emoji: String) {
        if let identifier = actionController?.identifier {
            actionController?.dismiss(animated: true, completion: { [weak self] in
                self?.delegate?.didDeselect(emoji: emoji, forViewWith: identifier)
            })
        }
    }
    
    public func didSelectMoreAction() {
        if let identifier = actionController?.identifier {
            actionController?.dismiss(animated: true, completion: { [weak self] in
                self?.delegate?.didSelectMoreAction(forViewWith: identifier)
            })
        }
    }
    
}

extension ContextMenu: MenuControllerDataSource {
    
    public var menuItems: [MenuItem] {
        if _menuItems == nil {
            if let actionController, let dataSource {
                _menuItems = dataSource.items(contextMenu: self, identifier: actionController.identifier)
            }
        }
        return _menuItems ?? []
    }
}

private final class IdentifiableLongPressGestureRecognizer: UILongPressGestureRecognizer {
    
    let identifier: Identifier
    
    init(target: Any?, action: Selector?, identifier: Identifier) {
        self.identifier = identifier
        super.init(target: target, action: action)
    }
    
}
