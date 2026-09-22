//
//  SortValue.swift
//  SceytChatUIKit
//
//  Created by Sargis Mkhitaryan on 03.06.26.
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

public struct SortValue<T> {
    public let keyPath: PartialKeyPath<T>
    public let isAscending: Bool

    public init(keyPath: PartialKeyPath<T>, isAscending: Bool) {
        self.keyPath = keyPath
        self.isAscending = isAscending
    }
}

extension Array {
    /// Returns the elements of the sequence, sorted using the given sort values as the comparison between elements.
    ///
    /// The first `SortValue` is the primary key and subsequent `SortValue`s are for breaking the tie.
    func sorted(using sortValues: [SortValue<Element>]) -> [Element] {
        guard !sortValues.isEmpty else { return self }
        return sorted { lhs, rhs in
            for sortValue in sortValues {
                let lhsValue = lhs[keyPath: sortValue.keyPath]
                let rhsValue = rhs[keyPath: sortValue.keyPath]
                let isAscending = sortValue.isAscending
                if let result = nilComparison(lhs: lhsValue, rhs: rhsValue, isAscending: isAscending) {
                    return result
                } else if let result = areInIncreasingOrder(lhs: lhsValue, rhs: rhsValue, type: Date.self, isAscending: isAscending) {
                    return result
                } else if let result = areInIncreasingOrder(lhs: lhsValue, rhs: rhsValue, type: String.self, isAscending: isAscending) {
                    return result
                } else if let result = areInIncreasingOrder(lhs: lhsValue, rhs: rhsValue, type: Int.self, isAscending: isAscending) {
                    return result
                } else if let result = areInIncreasingOrder(lhs: lhsValue, rhs: rhsValue, type: Double.self, isAscending: isAscending) {
                    return result
                } else if let lBool = lhsValue as? Bool, let rBool = rhsValue as? Bool, lBool != rBool {
                    return isAscending ? lBool && !rBool : !lBool && rBool
                }
            }
            return false
        }
    }

    private func nilComparison(lhs: Any, rhs: Any, isAscending: Bool) -> Bool? {
        func isAnyNil(_ value: Any) -> Bool {
            if case Optional<Any>.none = value {
                return true
            }
            return false
        }
        switch (isAnyNil(lhs), isAnyNil(rhs)) {
        case (true, true): return nil
        case (true, false): return isAscending
        case (false, true): return !isAscending
        case (false, false): return nil
        }
    }

    private func areInIncreasingOrder<T>(lhs: Any, rhs: Any, type: T.Type, isAscending: Bool) -> Bool? where T: Comparable {
        guard let lhs = lhs as? T, let rhs = rhs as? T else { return nil }
        guard lhs != rhs else { return nil }
        return isAscending ? lhs < rhs : lhs > rhs
    }
}
