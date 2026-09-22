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
    func canShowEmojis(contextMenu: ContextMenu, identifier: Identifier) -> (canShowEmojis: Bool, emojisViewAppearance: ReactionPickerViewController.Appearance)
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
    
    public convenience init(value: any Hashable, userInfo: [AnyHashable: Any]) {
        self.init(value: value)
        self.userInfo = userInfo
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
                view.transform = SceytChatUIKit.shared.config.messageBubbleTransformScale
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
        if let presented = actionController, presented.presentingViewController != nil {
            logger.warn("[ContextMenu] Replacing a still-presented menu (id \(presented.identifier.value)) — possible double-presentation race")
        }
        movementStarted = false
        var point = gesture.location(in: view)
        if let v = parentController?.view {
            point = view.convert(point, to: v)
        }
        longPressStartLocation = point
        snapshotDelegate?.willMakeSnapshot(forViewWith: identifier)
        let actionController = ActionController(
            for: view,
            identifier: identifier,
            alignment: alignments[identifier] ?? .center
        )
        _menuItems = nil
        actionController.loadViewIfNeeded()

        // The whole context-menu layout is anchored to a snapshot of the long-pressed
        // view. The menu is presented ~0.2s after the press begins, and in that window
        // the view can leave the window or fail to snapshot (the list reloaded, the cell
        // was recycled, the message was deleted, etc.). When that happens
        // `ActionController.setupLayout` bails out and the controller is left empty, but
        // presenting it anyway still installs the full-screen blur/dim — leaving a stuck
        // blurred screen with nothing on top and no menu frame to tap away. Abort cleanly
        // in that case and let the user try again.
        guard actionController.snapshot != nil else {
            logger.warn("[ContextMenu] Skip present (id \(identifier.value)): no snapshot. \(type(of: view)) window=\(view.window != nil) superview=\(view.superview != nil). See setupLayout abort log for reason.")
            self.actionController = nil
            snapshotDelegate?.didMakeSnapshot(forViewWith: identifier)
            return
        }
        self.actionController = actionController

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let emojisConfig = dataSource?.canShowEmojis(contextMenu: self, identifier: identifier)
        if emojisConfig?.canShowEmojis == false {
            actionController.emojiController.view.isHidden = true
        } else {
            actionController.emojiController.parentAppearance = emojisConfig?.emojisViewAppearance
            actionController.emojiController.dataSource = self
            actionController.emojiController.delegate = self
        }
        actionController.menuController.dataSource = self

        actionController.modalPresentationStyle = .custom
        if parentController == nil {
            logger.warn("[ContextMenu] Skip present (id \(identifier.value)): parentController is nil (no-op)")
        }
        logger.debug("[ContextMenu] Presenting menu (id \(identifier.value))")
        parentController?.present(actionController, animated: true) { [weak self] in
            self?.snapshotDelegate?.didMakeSnapshot(forViewWith: identifier)
        }
    }
    
}

extension ContextMenu: ReactionPickerViewControllerDataSource {
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

extension ContextMenu: ReactionPickerViewControllerDelegate {
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
