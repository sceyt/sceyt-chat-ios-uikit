//
//  FilePreviewController.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//
//
import UIKit
import QuickLook

open class FilePreviewController: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {

    private static var retain: FilePreviewController?

    open lazy var viewer = QLPreviewController()

    open private(set) var items: [Item]

    public init(items: [Item], selected: Int = 0) {

        self.items = items
        super.init()
        viewer.delegate = self
        viewer.dataSource = self
        viewer.currentPreviewItemIndex = selected
    }

    private var _callback: ((State) -> Void)?

    open func present(on vc: UIViewController, callback: ((State) -> Void)? = nil) {
        Self.retain = self
        _callback = callback
        vc.present(viewer, animated: true) {
            self._callback?(.didPresent)
        }
    }

    open func previewControllerWillDismiss(_ controller: QLPreviewController) {
        _callback?(.willDismiss)
    }

    open func previewControllerDidDismiss(_ controller: QLPreviewController) {
        Self.retain = nil
        _callback?(.didDismiss)
    }

    open func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        items.count
    }

    open func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        items[index].url as NSURL
    }
}

public extension FilePreviewController {

    struct Item {
        public let url: URL
        public let title: String?

        public init(title: String? = nil, url: URL) {
            self.title = title
            self.url = url
        }
    }

    enum State {
        case didPresent
        case willDismiss
        case didDismiss
    }
}
