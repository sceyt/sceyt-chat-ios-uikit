//
//  UIImageView+Extension.swift
//  SceytChatUIKit
//

import UIKit

public extension UIImageView {
    // Data holder tap recognizer
    private class TapWithDataRecognizer: UITapGestureRecognizer {
        weak var from: UIViewController?
        var previewer: PreviewDataSource?
        var item: PreviewItem?
    }
    
    private var vc: UIViewController? {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController
        else { return nil }
        return rootVC.presentedViewController != nil ? rootVC.presentedViewController : rootVC
    }
    
    func setup(
        previewer: AttachmentPreviewDataSource?,
        item: PreviewItem?,
        from: UIViewController? = nil)
    {
        var _tapRecognizer: TapWithDataRecognizer?
        gestureRecognizers?.forEach {
            if let _tr = $0 as? TapWithDataRecognizer {
                // if found, just use existing
                _tapRecognizer = _tr
            }
        }
            
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
        guard let sourceView = sender.view as? UIImageView else { return }
        var initialIndex = 0
        if let item = sender.item,
           let idx = sender.previewer?.indexOfItem(item)
        {
            initialIndex = idx
        }
        let imageCarousel = PreviewerCarouselVC(
            sourceView: sourceView,
            previewDataSource: sender.previewer,
            initialIndex: initialIndex)
        let presentFromVC = sender.from ?? vc
        presentFromVC?.present(imageCarousel, animated: true)
    }
}
