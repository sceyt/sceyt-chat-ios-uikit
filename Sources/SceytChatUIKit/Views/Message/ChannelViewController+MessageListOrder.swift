//
//  ChannelViewController+MessageListOrder.swift
//  SceytChatUIKit
//
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

public extension ChannelViewController {
    /// Which visual edge of the message list holds the newest message.
    ///
    /// Both modes share the same underlying invariant: the collection view's data
    /// source is presented newest-first (UI `IndexPath(item: 0, section: 0)` is the
    /// newest message) and the content-space origin (`contentOffset.y ≈ 0`) is the
    /// newest edge. The only difference is whether the collection view — and every
    /// cell / supplementary view inside it — is vertically mirrored, which is what
    /// turns the content-space top into the visual bottom.
    ///
    /// Because of that, the index-space mapping, pagination polarity and all
    /// offset math are identical in both modes; only presentation details branch.
    enum MessageListOrder {
        /// Default. The list is mirrored, so the newest message sits at the visual
        /// bottom, right above the input bar.
        case newestAtBottom

        /// The list is upright, so the newest message sits at the visual top, right
        /// below the navigation bar. The input bar stays at the bottom.
        case newestAtTop

        /// `true` when the collection view is vertically flipped.
        public var isMirrored: Bool { self == .newestAtBottom }

        /// Applied to the collection view, to every layout attribute, and to each
        /// cell / supplementary view — where it cancels the collection view's own
        /// flip so content reads upright.
        var contentTransform: CGAffineTransform { isMirrored ? .mirrorY : .identity }

        /// The supplementary kind that carries the day's date. A section's date
        /// separator must render on the section's OLDER-facing side: mirrored that
        /// is the content-space end (a FOOTER), upright it is the content-space
        /// start (a HEADER).
        var dateSeparatorKind: UICollectionView.SupplementaryViewKind { isMirrored ? .footer : .header }

        /// The kind that must never receive a size — the counterpart of
        /// ``dateSeparatorKind``.
        var emptySupplementaryKind: UICollectionView.SupplementaryViewKind { isMirrored ? .header : .footer }
    }
}
