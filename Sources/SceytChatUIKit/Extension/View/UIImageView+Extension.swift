//
//  UIImageView+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UIImageView {
    // Data holder tap recognizer
    private class TapWithDataRecognizer: UITapGestureRecognizer {
        weak var from: UIViewController?
        var previewer: (() -> PreviewDataSource?)?
        var item: PreviewItem?
    }
    
    private var vc: UIViewController? {
        guard let rootVC = window?.rootViewController
        else { return nil }
        return rootVC.presentedViewController != nil ? rootVC.presentedViewController : rootVC
    }
    
    func setup(
        previewer: (() -> AttachmentPreviewDataSource?)?,
        item: PreviewItem?,
        from: UIViewController? = nil) {
        var _tapRecognizer: TapWithDataRecognizer? = gestureRecognizers?.first(where: { $0 is TapWithDataRecognizer }) as? TapWithDataRecognizer
            
        isUserInteractionEnabled = true
        clipsToBounds = true
            
        if _tapRecognizer == nil {
            _tapRecognizer = TapWithDataRecognizer(
                target: self, action: #selector(showImageViewer(_:)))
            _tapRecognizer!.numberOfTouchesRequired = 1
            _tapRecognizer!.numberOfTapsRequired = 1
        }
        // Pass the Data
        _tapRecognizer!.previewer = previewer
        _tapRecognizer!.item = item
        _tapRecognizer!.from = from
        addGestureRecognizer(_tapRecognizer!)
    }
    
    @objc
    private func showImageViewer(_ sender: TapWithDataRecognizer) {
        guard
            let previewer = sender.previewer?(),
            previewer.canShowPreviewer(),
            let sourceView = sender.view as? UIImageView
        else { return }
        var initialIndex = 0
        if let item = sender.item,
           let idx = previewer.indexOfItem(item) {
            initialIndex = idx
        }
        
        let imageCarousel = Components.previewerCarouselVC
            .init(
                sourceView: sourceView,
                previewDataSource: previewer,
                initialIndex: initialIndex)
        UIApplication.shared.sendAction(#selector(resignFirstResponder), to: nil, from: nil, for: nil)
        let presentFromVC = sender.from ?? vc
        presentFromVC?.present(Components.previewerNavigationController.init(imageCarousel), animated: true)
    }
}
