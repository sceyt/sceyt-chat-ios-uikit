//
//  AttachmentSharpThumbnailRelay.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol AttachmentSharpThumbnailObserver: AnyObject {
    /// Called on the main thread whenever a sharp, file-backed thumbnail is applied to any
    /// `AttachmentLayout` for `attachment`. Observers decide relevance by comparing against
    /// their currently bound attachment (identity `==`, not instance `===`).
    func attachmentSharpThumbnailDidLoad(_ attachment: ChatMessage.Attachment, image: UIImage)
}

/// Instance-agnostic backstop for delivering sharp thumbnails to visible cells.
///
/// A layout's `onLoadThumbnail` is a single overwritable slot, the observer fan-out produces
/// duplicate `AttachmentLayout` instances for the same attachment, and back-to-back
/// reconfigures rebuild attachment views — so by the time an async sharp load lands, the slot
/// it fires can belong to a deallocated view while the live view is bound to a sibling
/// instance that never receives the load. Once that happens, `isThumbnailLoadedFromFile`
/// gates every later reload path and the cell stays on the blurry placeholder until a scroll.
///
/// The relay announces every file-backed thumbnail apply keyed by attachment identity, so any
/// live view showing that attachment can heal regardless of which layout instance won the
/// load. Only sharp file-backed images are relayed — a low-res placeholder can never
/// cross-paint through here, preserving the strict `===` guard on the closure path.
/// Main-thread only.
public final class AttachmentSharpThumbnailRelay {
    public static let `default` = AttachmentSharpThumbnailRelay()

    private let observers = NSHashTable<AnyObject>.weakObjects()

    public func add(_ observer: AttachmentSharpThumbnailObserver) {
        observers.add(observer)
    }

    public func post(_ attachment: ChatMessage.Attachment, image: UIImage) {
        // allObjects snapshots the live observers, so a handler that triggers a nested
        // post (setFileBackedThumbnail on its own layout) re-enters safely. Note that
        // reading a weak table retains+autoreleases the members — observers may outlive
        // their last strong reference until the enclosing pool drains.
        for case let observer as AttachmentSharpThumbnailObserver in observers.allObjects {
            observer.attachmentSharpThumbnailDidLoad(attachment, image: image)
        }
    }
}
