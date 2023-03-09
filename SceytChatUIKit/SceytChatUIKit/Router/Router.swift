//
//  Router.swift
//  SceytChatUIKit
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
    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let nav = rootVC.navigationController {
            nav.dismiss(animated: animated, completion: completion)
        } else {
            rootVC.dismiss(animated: animated, completion: completion)
        }
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


