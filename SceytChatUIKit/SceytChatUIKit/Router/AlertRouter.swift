//
//  AlertRouter.swift
//  SceytChatUIKit
//

import UIKit

public extension UIViewController {
    func showAlert(title: String? = nil, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title ?? "", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: L10n.Alert.Button.ok, style: .cancel) { _ in
            completion?()
        }
        alert.addAction(action)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            (self.presentedViewController ?? self).present(alert, animated: true)
        }
    }

    func showAlert(error: Error, completion: (() -> Void)? = nil) {
        showAlert(title: L10n.Alert.Error.title, message: error.localizedDescription, completion: completion)
    }

    @discardableResult
    func presentAlert(
        preferredStyle: UIAlertController.Style = .actionSheet,
        title: String? = nil,
        message: String? = nil,
        alertActions: [UIAlertAction] = [],
        addCancelAction: Bool = true,
        canceled: (() -> Void)? = nil
    ) -> UIAlertController {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: preferredStyle)
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = .init(origin: view.bounds.center, size: .zero)
        }

        alertActions.forEach {
            alert.addAction($0)
        }

        if addCancelAction {
            let cancelAction = UIAlertAction(title: L10n.Alert.Button.cancel, style: .cancel) { _ in
                canceled?()
            }
            alert.addAction(cancelAction)
        }

        DispatchQueue.main.async { [weak self] in
            self?.present(alert, animated: true)
        }
        return alert
    }
}

public extension Router {
    func showAlert(title: String? = nil, message: String, completion: (() -> Void)? = nil) {
        rootVC.showAlert(title: title, message: message, completion: completion)
    }

    func showAlert(error: Error, completion: (() -> Void)? = nil) {
        rootVC.showAlert(error: error, completion: completion)
    }

    @discardableResult
    func presentAlert(
        preferredStyle: UIAlertController.Style = .actionSheet,
        title: String? = nil,
        message: String? = nil,
        alertActions: [UIAlertAction] = [],
        addCancelAction: Bool = true,
        canceled: (() -> Void)? = nil
    ) -> UIAlertController {
        rootVC.presentAlert(
            preferredStyle: preferredStyle,
            title: title,
            message: message,
            alertActions: alertActions,
            addCancelAction: addCancelAction,
            canceled: canceled
        )
    }
}
