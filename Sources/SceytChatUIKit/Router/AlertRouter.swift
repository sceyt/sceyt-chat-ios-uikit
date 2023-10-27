//
//  AlertRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UIViewController {
    @discardableResult
    func showAlert(
        title: String? = nil,
        message: String? = nil,
        actions: [SheetAction]? = nil,
        preferredActionIndex: Int = 0,
        completion: (() -> Void)? = nil
    ) -> Alert {
        let alert = Alert(title: title,
                          message: message,
                          actions: actions ?? [.init(title: L10n.Alert.Button.cancel, style: .cancel)], 
                          preferredActionIndex: preferredActionIndex)
        (presentedViewController ?? self).showSheet(alert, style: .center, cornerRadius: 0)
        return alert
    }

    @discardableResult
    func showAlert(error: Error, completion: (() -> Void)? = nil) -> Alert {
        showAlert(title: L10n.Alert.Error.title, message: error.localizedDescription, completion: completion)
    }
}

public extension Router {
    @discardableResult
    func showAlert(title: String? = nil, message: String? = nil, actions: [SheetAction]? = nil, preferredActionIndex: Int = 0, completion: (() -> Void)? = nil) -> Alert {
        rootVC.showAlert(title: title, message: message, actions: actions, preferredActionIndex: preferredActionIndex, completion: completion)
    }

    @discardableResult
    func showAlert(error: Error, completion: (() -> Void)? = nil) -> Alert {
        rootVC.showAlert(error: error, completion: completion)
    }
}
