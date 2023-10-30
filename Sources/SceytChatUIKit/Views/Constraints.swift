//
//  Constraints.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

@frozen
public enum LayoutAnchorType {

    @frozen
    public enum FuncType {
        case equal
        case lessThanOrEqual
        case greaterThanOrEqual
    }

    case leading(CGFloat = 0, FuncType = .equal)
    case trailing(CGFloat = 0, FuncType = .equal)
    case left(CGFloat = 0, FuncType = .equal)
    case right(CGFloat = 0, FuncType = .equal)
    case top(CGFloat = 0, FuncType = .equal)
    case bottom(CGFloat = 0, FuncType = .equal)
    case width(CGFloat = 0, FuncType = .equal)
    case height(CGFloat = 0, FuncType = .equal)
    case centerX(CGFloat = 0, FuncType = .equal)
    case centerY(CGFloat = 0, FuncType = .equal)
    case firstBaseline(CGFloat = 0, FuncType = .equal)
    case lastBaseline(CGFloat = 0, FuncType = .equal)
    
    public static var leading: LayoutAnchorType { LayoutAnchorType.leading() }
    public static var trailing: LayoutAnchorType { LayoutAnchorType.trailing() }
    public static var left: LayoutAnchorType { LayoutAnchorType.left() }
    public static var right: LayoutAnchorType { LayoutAnchorType.right() }
    public static var top: LayoutAnchorType { LayoutAnchorType.top() }
    public static var bottom: LayoutAnchorType { LayoutAnchorType.bottom() }
    public static var width: LayoutAnchorType { LayoutAnchorType.width() }
    public static var height: LayoutAnchorType { LayoutAnchorType.height() }
    public static var centerX: LayoutAnchorType { LayoutAnchorType.centerX() }
    public static var centerY: LayoutAnchorType { LayoutAnchorType.centerY() }
    public static var firstBaseline: LayoutAnchorType { LayoutAnchorType.firstBaseline() }
    public static var lastBaseline: LayoutAnchorType { LayoutAnchorType.lastBaseline() }
    
}

@frozen
public enum LayoutDimensionType {
    case width(CGFloat = 0, LayoutAnchorType.FuncType = .equal)
    case height(CGFloat = 0, LayoutAnchorType.FuncType = .equal)
    
    public static var width: LayoutDimensionType { LayoutDimensionType.width() }
    public static var height: LayoutDimensionType { LayoutDimensionType.height() }
}

public extension UIView {

    @discardableResult
    @inlinable
    func pin(to view: UIView,
             anchor: LayoutAnchorType,
             activate: Bool = true)
    -> NSLayoutConstraint {
        pin(to: view, anchors: [anchor], activate: activate).first!
    }

    @discardableResult
    @inlinable
    func pin(to view: UIView,
             anchors: [LayoutAnchorType] = [.leading(), .trailing(), .top(), .bottom()],
             activate: Bool = true)
    -> [NSLayoutConstraint] {
        anchors.map {
            switch $0 {
            case .leading(let constant, let type):
                switch type {
                case .equal:
                    return leadingAnchor.pin(to: view.leadingAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return leadingAnchor.pin(lessThanOrEqualTo: view.leadingAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor, constant: constant).activate(activate)
                }
            case .trailing(let constant, let type):
                switch type {
                case .equal:
                    return trailingAnchor.pin(to: view.trailingAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return trailingAnchor.pin(lessThanOrEqualTo: view.trailingAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return trailingAnchor.pin(greaterThanOrEqualTo: view.trailingAnchor, constant: constant).activate(activate)
                }
            case .left(let constant, let type):
                switch type {
                case .equal:
                    return leftAnchor.pin(to: view.leftAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return leftAnchor.pin(lessThanOrEqualTo: view.leftAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return leftAnchor.pin(greaterThanOrEqualTo: view.leftAnchor, constant: constant).activate(activate)
                }
            case .right(let constant, let type):
                switch type {
                case .equal:
                    return rightAnchor.pin(to: view.rightAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return rightAnchor.pin(lessThanOrEqualTo: view.rightAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return rightAnchor.pin(greaterThanOrEqualTo: view.rightAnchor, constant: constant).activate(activate)
                }
            case .top(let constant, let type):
                switch type {
                case .equal:
                    return topAnchor.pin(to: view.topAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return topAnchor.pin(lessThanOrEqualTo: view.topAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return topAnchor.pin(greaterThanOrEqualTo: view.topAnchor, constant: constant).activate(activate)
                }
            case .bottom(let constant, let type):
                switch type {
                case .equal:
                    return bottomAnchor.pin(to: view.bottomAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return bottomAnchor.pin(lessThanOrEqualTo: view.bottomAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return bottomAnchor.pin(greaterThanOrEqualTo: view.bottomAnchor, constant: constant).activate(activate)
                }
            case .width(let constant, let type):
                switch type {
                case .equal:
                    return widthAnchor.pin(to: view.widthAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return widthAnchor.pin(lessThanOrEqualTo: view.widthAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return widthAnchor.pin(greaterThanOrEqualTo: view.widthAnchor, constant: constant).activate(activate)
                }
            case .height(let constant, let type):
                switch type {
                case .equal:
                    return heightAnchor.pin(to: view.heightAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return heightAnchor.pin(lessThanOrEqualTo: view.heightAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return heightAnchor.pin(greaterThanOrEqualTo: view.heightAnchor, constant: constant).activate(activate)
                }
            case .centerX(let constant, let type):
                switch type {
                case .equal:
                    return centerXAnchor.pin(to: view.centerXAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return centerXAnchor.pin(lessThanOrEqualTo: view.centerXAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return centerXAnchor.pin(greaterThanOrEqualTo: view.centerXAnchor, constant: constant).activate(activate)
                }
            case .centerY(let constant, let type):
                switch type {
                case .equal:
                    return centerYAnchor.pin(to: view.centerYAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return centerYAnchor.pin(lessThanOrEqualTo: view.centerYAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return centerYAnchor.pin(greaterThanOrEqualTo: view.centerYAnchor, constant: constant).activate(activate)
                }
            case .firstBaseline(let constant, let type):
                switch type {
                case .equal:
                    return firstBaselineAnchor.pin(to: view.firstBaselineAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return firstBaselineAnchor.pin(lessThanOrEqualTo: view.firstBaselineAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return firstBaselineAnchor.pin(greaterThanOrEqualTo: view.firstBaselineAnchor, constant: constant).activate(activate)
                }
            case .lastBaseline(let constant, let type):
                switch type {
                case .equal:
                    return lastBaselineAnchor.pin(to: view.lastBaselineAnchor, constant: constant).activate(activate)
                case .lessThanOrEqual:
                    return lastBaselineAnchor.pin(lessThanOrEqualTo: view.lastBaselineAnchor, constant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return lastBaselineAnchor.pin(greaterThanOrEqualTo: view.lastBaselineAnchor, constant: constant).activate(activate)
                }
            }
        }
    }

    @discardableResult
    @inlinable
    func pin(to guide: UILayoutGuide,
             anchors: [LayoutAnchorType] = [.leading(), .trailing(), .top(), .bottom()],
             activate: Bool = true)
    -> [NSLayoutConstraint] {
        anchors.compactMap {
            switch $0 {
            case .leading(let constant, _):
                return leadingAnchor.pin(to: guide.leadingAnchor, constant: constant).activate(activate)
            case .trailing(let constant, _):
                return trailingAnchor.pin(to: guide.trailingAnchor, constant: constant).activate(activate)
            case .left(let constant, _):
                return leftAnchor.pin(to: guide.leftAnchor, constant: constant).activate(activate)
            case .right(let constant, _):
                return rightAnchor.pin(to: guide.rightAnchor, constant: constant).activate(activate)
            case .top(let constant, _):
                return topAnchor.pin(to: guide.topAnchor, constant: constant).activate(activate)
            case .bottom(let constant, _):
                return bottomAnchor.pin(to: guide.bottomAnchor, constant: constant).activate(activate)
            case .width(let constant, _):
                return widthAnchor.pin(to: guide.widthAnchor, constant: constant).activate(activate)
            case .height(let constant, _):
                return heightAnchor.pin(to: guide.heightAnchor, constant: constant).activate(activate)
            case .centerX(let constant, _):
                return centerXAnchor.pin(to: guide.centerXAnchor, constant: constant).activate(activate)
            case .centerY(let constant, _):
                return centerYAnchor.pin(to: guide.centerYAnchor, constant: constant).activate(activate)
            default:
                return nil
            }
        }
    }

    @discardableResult
    @inlinable
    func resize(anchors: [LayoutDimensionType],
             activate: Bool = true)
    -> [NSLayoutConstraint] {
        anchors.map {
            switch $0 {
            case .width(let constant, let type):
                switch type {
                case .equal:
                    return widthAnchor.constraint(equalToConstant: constant).activate(activate)
                case .lessThanOrEqual:
                    return widthAnchor.constraint(lessThanOrEqualToConstant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return widthAnchor.constraint(greaterThanOrEqualToConstant: constant).activate(activate)
                }
            case .height(let constant, let type):
                switch type {
                case .equal:
                    return heightAnchor.constraint(equalToConstant: constant).activate(activate)
                case .lessThanOrEqual:
                    return heightAnchor.constraint(lessThanOrEqualToConstant: constant).activate(activate)
                case .greaterThanOrEqual:
                    return heightAnchor.constraint(greaterThanOrEqualToConstant: constant).activate(activate)
                }
            }
        }
    }
}

public extension NSLayoutConstraint {

    @discardableResult
    @inlinable
    func priority(_ priority: UILayoutPriority) -> Self {
        self.priority = priority
        return self
    }

    @discardableResult
    @inlinable
    func priority(_ value: Float) -> Self {
        priority(UILayoutPriority(value))
    }

    @discardableResult
    @inlinable
    func activate(_ isActive: Bool) -> Self {
        self.isActive = isActive
        return self
    }
}

public extension NSLayoutAnchor {

    @discardableResult
    @objc func pin(to anchor: NSLayoutAnchor, constant: CGFloat = 0, activate: Bool = true) -> NSLayoutConstraint {
        constraint(equalTo: anchor, constant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(greaterThanOrEqualTo anchor: NSLayoutAnchor, constant: CGFloat = 0, activate: Bool = true) -> NSLayoutConstraint {
        constraint(greaterThanOrEqualTo: anchor, constant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(lessThanOrEqualTo anchor: NSLayoutAnchor, constant: CGFloat = 0, activate: Bool = true) -> NSLayoutConstraint {
        constraint(lessThanOrEqualTo: anchor, constant: constant).activate(activate)
    }
}

public extension NSLayoutDimension {
    
    @discardableResult
    @objc func pin(to anchor: NSLayoutDimension, multiplier: CGFloat = 1, constant: CGFloat = 0, activate: Bool = true) -> NSLayoutConstraint {
        constraint(equalTo: anchor, multiplier: multiplier, constant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier: CGFloat = 1, constant: CGFloat = 0, activate: Bool = true) -> NSLayoutConstraint {
        constraint(greaterThanOrEqualTo: anchor, multiplier: multiplier, constant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier: CGFloat = 1, constant: CGFloat = 0, activate: Bool = true) -> NSLayoutConstraint {
        constraint(lessThanOrEqualTo: anchor, multiplier: multiplier, constant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(constant: CGFloat, activate: Bool = true) -> NSLayoutConstraint {
        constraint(equalToConstant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(greaterThanOrEqualToConstant constant: CGFloat, activate: Bool = true) -> NSLayoutConstraint {
        constraint(greaterThanOrEqualToConstant: constant).activate(activate)
    }

    @discardableResult
    @objc func pin(lessThanOrEqualToConstant constant: CGFloat, activate: Bool = true) -> NSLayoutConstraint {
        constraint(lessThanOrEqualToConstant: constant).activate(activate)
    }
}

public extension UIView {
    @discardableResult
    func unpin<AnchorType>(firstAnchor: NSLayoutAnchor<AnchorType>, pinnedTo secondAnchor: NSLayoutAnchor<AnchorType>? = nil) -> [NSLayoutConstraint] {
        if let filtered = superview?.constraints.filter({ $0.firstAnchor == firstAnchor && $0.secondAnchor == secondAnchor }),
           !filtered.isEmpty {
            superview?.removeConstraints(filtered)
            return filtered
        }
        let filtered = constraints.filter({ $0.firstAnchor == firstAnchor && $0.secondAnchor == secondAnchor })
        if !filtered.isEmpty {
            removeConstraints(filtered)
            return filtered
        }
        return []
    }
}
