//
//  Router.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class Router<ViewController: UIViewController>: NSObject {

    public unowned var rootViewController: ViewController

    public required init(rootViewController: ViewController) {
        self.rootViewController = rootViewController
    }
    
    @objc
    public func pop(animated: Bool = true) {
        rootViewController.navigationController?.popViewController(animated: animated)
    }
    
    @objc
    public func popToRoot(animated: Bool = true) {
        rootViewController.navigationController?.popToRootViewController(animated: animated)
    }
    
    @objc
    public func popTo(_ viewController: UIViewController, animated: Bool = true) {
        rootViewController.navigationController?.popToViewController(viewController, animated: animated)
    }
    
    @objc
    public func setViewControllers(_ viewControllers: [UIViewController], animated: Bool = true) {
        rootViewController.navigationController?.setViewControllers(viewControllers, animated: animated)
    }
    
    @objc
    public func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let nav = rootViewController.navigationController {
            nav.dismiss(animated: animated, completion: completion)
        } else {
            rootViewController.dismiss(animated: animated, completion: completion)
        }
    }
    
    @available(iOSApplicationExtension, unavailable)
    open func showLink(_ link: URL) {
        if link.scheme == nil,
            let httpLink = URL(string: "http://\(link.absoluteString)") {
            UIApplication.shared.open(httpLink)
        } else {
            UIApplication.shared.open(link)
        }
    }
    
    open func showLinkAlert(
        _ link: URL,
        actions: [(String, SheetAction.Style)],
        completion: ((String) -> Void)? = nil) {
            rootViewController.view.endEditing(true)
            rootViewController.showBottomSheet(
                title: link.absoluteString,
                actions: actions.map { action in
                        .init(
                            title: action.0,
                            style: action.1,
                            handler: { completion?(action.0) })
                }, withCancel: true)
        }
}

public extension Router {
    
    func share(_ items: [Any], from sourceView: Any?) {
        // FIX: https://stackoverflow.com/questions/59413850/uiactivityviewcontroller-dismissing-current-view-controller-after-sharing-file
        let tmpViewController = UIViewController()
        tmpViewController.modalPresentationStyle = .overFullScreen
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let sourceView = sourceView as? UIView {
            activityViewController.popoverPresentationController?.sourceView = sourceView
            activityViewController.popoverPresentationController?.sourceRect = sourceView.bounds
        } else if let sourceView = sourceView as? UIBarButtonItem {
            activityViewController.popoverPresentationController?.barButtonItem = sourceView
            activityViewController.popoverPresentationController?.permittedArrowDirections = .up
        }
        activityViewController.completionWithItemsHandler = { [weak tmpViewController] _, _, _, _ in
            if let presentingViewController = tmpViewController?.presentingViewController {
                presentingViewController.dismiss(animated: false, completion: nil)
            } else {
                tmpViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        let presenter: UIViewController
        if let presentedViewController = rootViewController.presentedViewController {
            presenter = presentedViewController
        } else {
            presenter = rootViewController
        }
        presenter.present(tmpViewController, animated: false) { [weak tmpViewController] in
            tmpViewController?.present(activityViewController, animated: true, completion: nil)
        }
    }
}


