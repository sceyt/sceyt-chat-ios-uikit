//
//  ContextMenu.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol ContextMenuDataSource: AnyObject {
    func canShow(contextMenu: ContextMenu, identifier: Identifier) -> Bool
    func canShowEmojis(contextMenu: ContextMenu, identifier: Identifier) -> Bool
    func emojis(contextMenu: ContextMenu, identifier: Identifier) -> [String]
    func showPlusAfterEmojis(contextMenu: ContextMenu, identifier: Identifier) -> Bool
    func selectedEmojis(contextMenu: ContextMenu, identifier: Identifier) -> [String]
    func items(contextMenu: ContextMenu, identifier: Identifier) -> [MenuItem]
}

public extension ContextMenuDataSource {
    func canShow(contextMenu: ContextMenu, identifier: Identifier) -> Bool { true }
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

public class Identifier: NSObject {
    public let value: any Hashable
    
    public var userInfo: [AnyHashable: Any]?
    
    public init(value: any Hashable) {
        self.value = value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
    public static func == (lhs: Identifier, rhs: Identifier) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let obj = object as? Identifier
        else { return false }
        if obj === self {
            return true
        }
        return obj == self
    }
}

public final class ContextMenu {
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
    
    public func connect(
        to view: UIView,
        identifier: Identifier,
        alignment: HorizontalAlignment = .center
    ) {
        alignments[identifier] = alignment
    }
    
    public func disconnect(from view: UIView, identifier: Identifier) {
        alignments[identifier] = nil
        view.gestureRecognizers?.reversed().forEach {
            if $0 is IdentifiableLongPressGestureRecognizer {
                view.removeGestureRecognizer($0)
            }
        }
    }
    
    public func reload(items: [MenuItem]? = nil) {
        _menuItems = items
        actionController?.menuController.reloadData()
    }
    
    @objc
    public func handleLogPress(
        sender: UILongPressGestureRecognizer,
        on view: UIView?,
        identifier: Identifier) {
            guard
                dataSource?.canShow(contextMenu: self, identifier: identifier) != false,
                let view = view ?? sender.view
            else { return }
            var point = sender.location(in: view)
            if let v = actionController?.view {
                point = view.convert(point, to: v)
            }
            switch sender.state {
            case .began:
                initiateGesture(view: view, gesture: sender, identifier: identifier)
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
                actionController?.selectHighlighted()
                actionController?.setInnerPanGestureActive()
            default:
                actionController?.setInnerPanGestureActive()
            }
        }
}

public extension ContextMenu {
    
    enum HorizontalAlignment {
        case leading
        case center
        case trailing
        
        public var reversed: HorizontalAlignment {
            switch self {
            case .leading:
                return .trailing
            case .center:
                return .center
            case .trailing:
                return .leading
            }
        }
    }
}

private extension ContextMenu {
    
    func initiateGesture(view: UIView, gesture: UILongPressGestureRecognizer, identifier: Identifier) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                view.transform = SceytChatUIKit.shared.config.contextMenuContentViewScale
            },
            completion: { finished in
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0,
                    options: [.curveEaseInOut, .beginFromCurrentState],
                    animations: {
                        view.transform = .identity
                    }
                )
                self.presentContextMenu(view: view, gesture: gesture, identifier: identifier)
            }
        )
    }
    
    func presentContextMenu(view: UIView, gesture: UILongPressGestureRecognizer, identifier: Identifier) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        movementStarted = false
        var point = gesture.location(in: view)
        if let v = parentController?.view {
            point = view.convert(point, to: v)
        }
        longPressStartLocation = point
        snapshotDelegate?.willMakeSnapshot(forViewWith: identifier)
        actionController = ActionController(
            for: view,
            identifier: identifier,
            alignment: alignments[identifier] ?? .center
        )
        _menuItems = nil
        actionController?.loadViewIfNeeded()
        if dataSource?.canShowEmojis(contextMenu: self, identifier: identifier) == false {
            actionController?.emojiController.view.isHidden = true
        } else {
            actionController?.emojiController.dataSource = self
            actionController?.emojiController.delegate = self
        }
        actionController?.menuController.dataSource = self
        
        actionController?.modalPresentationStyle = .custom
        parentController?.present(actionController!, animated: true) { [weak self] in
            self?.snapshotDelegate?.didMakeSnapshot(forViewWith: identifier)
        }
    }
    
}

extension ContextMenu: ReactionPickerVCDataSource {
    public var showPlusAfterEmojis: Bool {
        if let identifier = actionController?.identifier,
           let showPlus = dataSource?.showPlusAfterEmojis(contextMenu: self, identifier: identifier) {
            return showPlus
        }
        return true
    }
    
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

extension ContextMenu: ReactionPickerVCDelegate {
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
        minimumPressDuration = 0.2
    }
}
