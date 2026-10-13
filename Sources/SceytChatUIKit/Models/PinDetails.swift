//
//  PinDetails.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

/// A message's pin state, as the server reports it on the message itself.
///
/// `isPinned` is authoritative. `pinnedUntil == nil` means the pin never lapses — it does
/// **not** mean unpinned.
public struct PinDetails {

    public let isPinned: Bool
    /// When the pin lapses; `nil` for an open-ended pin.
    public let pinnedUntil: Date?

    public init(isPinned: Bool, pinnedUntil: Date? = nil) {
        self.isPinned = isPinned
        self.pinnedUntil = pinnedUntil
    }

    /// Pinned and not lapsed — what the UI should render from.
    public var isCurrentlyPinned: Bool {
        guard isPinned else { return false }
        guard let pinnedUntil else { return true }
        return pinnedUntil > Date()
    }

    /// The pin was set but its deadline has passed.
    public var isExpired: Bool {
        guard isPinned, let pinnedUntil else { return false }
        return pinnedUntil <= Date()
    }
}

// MARK: - init with DTO

extension PinDetails {
    init(dto: PinDetailsDTO) {
        isPinned = dto.isPinned
        pinnedUntil = dto.pinnedUntil?.bridgeDate
    }
}
