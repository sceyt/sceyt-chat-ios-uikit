//
//  UIControl+Extension.swift
//  SceytChatUIKit
//

import UIKit
import ObjectiveC

public extension UIControl {
    
    private struct AssociatedKey {
        static var touchUpInside = "touchUpInside"
        static var editingDidEndOnExit = "editingDidEndOnExit"
        static var editingChanged = "editingChanged"
        static var valueChanged = "valueChanged"
    }
    
    @discardableResult
    func onTouchUpInside(_ action: @escaping () -> Void) -> Self {
        setAction(action, key: &AssociatedKey.touchUpInside)
        addTarget(self, action: #selector(_onTouchUpInside(_:)), for: .touchUpInside)
        return self
    }
    
    @discardableResult
    func onEditingDidEndOnExit(_ action: @escaping () -> Void) -> Self {
        setAction(action, key: &AssociatedKey.editingDidEndOnExit)
        addTarget(self, action: #selector(_onEditingDidEndOnExit(_:)), for: .editingDidEndOnExit)
        return self
    }
    
    @discardableResult
    func onEditingChanged(_ action: @escaping () -> Void) -> Self {
        setAction(action, key: &AssociatedKey.editingChanged)
        addTarget(self, action: #selector(_onEditingChanged(_:)), for: .editingChanged)
        return self
    }
    
    @discardableResult
    func onValueChanged(_ action: @escaping () -> Void) -> Self {
        setAction(action, key: &AssociatedKey.valueChanged)
        addTarget(self, action: #selector(_onValueChanged(_:)), for: .valueChanged)
        return self
    }
    
    @objc
    private func _onTouchUpInside(_ sender: UIControl) {
        if sender.allControlEvents.contains(.touchUpInside) {
            getAction(key: &AssociatedKey.touchUpInside)?()
        }
    }
    
    @objc
    private func _onEditingDidEndOnExit(_ sender: UIControl) {
        if sender.allControlEvents.contains(.editingDidEndOnExit) {
            getAction(key: &AssociatedKey.editingDidEndOnExit)?()
        }
    }
    
    @objc
    private func _onEditingChanged(_ sender: UIControl) {
        if sender.allControlEvents.contains(.editingChanged) {
            getAction(key: &AssociatedKey.editingChanged)?()
        }
    }
    
    @objc
    private func _onValueChanged(_ sender: UIControl) {
        if sender.allControlEvents.contains(.valueChanged) {
            getAction(key: &AssociatedKey.valueChanged)?()
        }
    }
    
    private func setAction(_ action: @escaping () -> Void, key: inout String) {
        objc_setAssociatedObject(self, &key, action, .OBJC_ASSOCIATION_RETAIN)
    }
    
    private func getAction(key: inout String) -> (() -> Void)? {
        objc_getAssociatedObject(self, &key) as? (() -> Void)
    }
}
