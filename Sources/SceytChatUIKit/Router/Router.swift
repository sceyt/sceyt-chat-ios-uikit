//
//  Router.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class Router<VC: UIViewController>: NSObject {

    public unowned var rootVC: VC

    public required init(rootVC: VC) {
        self.rootVC = rootVC
    }
    
    @objc
    func pop(animated: Bool = true) {
        rootVC.navigationController?.popViewController(animated: animated)
    }
    
    @objc
    func popToRoot(animated: Bool = true) {
        rootVC.navigationController?.popToRootViewController(animated: animated)
    }
    
    @objc
    func popTo(_ viewController: UIViewController, animated: Bool = true) {
        rootVC.navigationController?.popToViewController(viewController, animated: animated)
    }
    
    @objc
    func setViewControllers(_ viewControllers: [UIViewController], animated: Bool = true) {
        rootVC.navigationController?.setViewControllers(viewControllers, animated: animated)
    }
    
    @objc
    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let nav = rootVC.navigationController {
            nav.dismiss(animated: animated, completion: completion)
        } else {
            rootVC.dismiss(animated: animated, completion: completion)
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
            rootVC.view.endEditing(true)
            rootVC.showBottomSheet(
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
        let tmpVC = UIViewController()
        tmpVC.modalPresentationStyle = .overFullScreen
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let sourceView = sourceView as? UIView {
            activityViewController.popoverPresentationController?.sourceView = sourceView
            activityViewController.popoverPresentationController?.sourceRect = sourceView.bounds
        } else if let sourceView = sourceView as? UIBarButtonItem {
            activityViewController.popoverPresentationController?.barButtonItem = sourceView
            activityViewController.popoverPresentationController?.permittedArrowDirections = .up
        }
        activityViewController.completionWithItemsHandler = { [weak tmpVC] _, _, _, _ in
            if let presentingViewController = tmpVC?.presentingViewController {
                presentingViewController.dismiss(animated: false, completion: nil)
            } else {
                tmpVC?.dismiss(animated: false, completion: nil)
            }
        }
        
        let presenter: UIViewController
        if let presentedVC = rootVC.presentedViewController {
            presenter = presentedVC
        } else {
            presenter = rootVC
        }
        presenter.present(tmpVC, animated: false) { [weak tmpVC] in
            tmpVC?.present(activityViewController, animated: true, completion: nil)
        }
    }
}


