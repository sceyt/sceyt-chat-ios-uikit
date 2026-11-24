//
//  StorageSpace.swift
//  SceytChatUIKit
//
//  Whether the device has room for a download, and whether a transfer failed for lack of it.
//

import Foundation

public enum StorageSpace {

    /// True when `error`, or one it wraps, says the device ran out of space: Foundation's
    /// `fileWriteOutOfSpace`, or the `ENOSPC` of a raw write.
    public static func isFull(_ error: Error?) -> Bool {
        var current = error.map { $0 as NSError }
        var depth = 0
        while let error = current, depth < 5 {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError
                || error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC) {
                return true
            }
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return false
    }

    /// The bytes free for a file the user asked for, counting what the system would purge to
    /// make room; nil when the volume does not say.
    public static func availableCapacity(for url: URL = URL(fileURLWithPath: NSHomeDirectory())) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// Whether `size` bytes certainly do not fit. Unknown sizes and capacities fit: the
    /// write itself reports a full disk then.
    public static func cannotFit(_ size: Int64, available: Int64?) -> Bool {
        guard size > 0, let available else { return false }
        return available < size
    }

    /// The error a transfer fails with when it has no room: one `isFull` recognizes.
    public static func outOfSpaceError(needed: Int64, available: Int64) -> Error {
        CocoaError(.fileWriteOutOfSpace, userInfo: [
            NSLocalizedDescriptionKey: "Not enough storage: \(needed) B needed, \(available) B available"
        ])
    }
}
