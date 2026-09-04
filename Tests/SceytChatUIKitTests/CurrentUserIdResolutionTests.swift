//
//  CurrentUserIdResolutionTests.swift
//  SceytChatUIKitTests
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  `SceytChatUIKit.currentUserId` consults the connection state last, and only
//  when the declared and live ids disagree. That reordering is a pure fast path:
//  these tests pin it to the ordering it replaced across the whole input space,
//  and assert that the fast paths never evaluate the expensive term at all.
//

import XCTest
import SceytChat
@testable import SceytChatUIKit

final class CurrentUserIdResolutionTests: XCTestCase {

    /// The implementation as it stood before the reordering — the oracle.
    private func askingConnectionFirst(
        live liveUserId: UserId,
        declared declaredUserId: UserId?,
        isConnected: Bool
    ) -> UserId? {
        if !liveUserId.isEmpty, isConnected {
            return liveUserId
        }
        if let declaredUserId, !declaredUserId.isEmpty {
            return declaredUserId
        }
        return liveUserId.isEmpty ? nil : liveUserId
    }

    private let liveValues: [UserId] = ["", "live-user", "declared-user"]
    private let declaredValues: [UserId?] = [nil, "", "declared-user", "live-user"]

    func test_resolution_matchesTheOrderingItReplaced_acrossEveryInput() {
        for live in liveValues {
            for declared in declaredValues {
                for isConnected in [true, false] {
                    let expected = askingConnectionFirst(
                        live: live, declared: declared, isConnected: isConnected
                    )
                    let actual = SceytChatUIKit.resolveCurrentUserId(
                        live: live, declared: declared, isConnected: isConnected
                    )
                    XCTAssertEqual(
                        actual, expected,
                        "live: \(live.isEmpty ? "<empty>" : live), "
                        + "declared: \(declared.map { $0.isEmpty ? "<empty>" : $0 } ?? "<nil>"), "
                        + "connected: \(isConnected)"
                    )
                }
            }
        }
    }

    // MARK: - The fast paths must not pay for the connection state

    /// Counts evaluations of the autoclosure, so "cheap" is asserted rather than
    /// assumed — a later edit that reads the connection state unconditionally
    /// would keep every value correct and still reintroduce the cost.
    private func resolve(
        live: UserId,
        declared: UserId?,
        isConnected: Bool = true,
        evaluations: inout Int
    ) -> UserId? {
        SceytChatUIKit.resolveCurrentUserId(
            live: live,
            declared: declared,
            isConnected: { evaluations += 1; return isConnected }()
        )
    }

    func test_nothingDeclared_returnsTheLiveIdWithoutAskingTheClient() {
        var evaluations = 0
        let resolved = resolve(live: "live-user", declared: nil, evaluations: &evaluations)
        XCTAssertEqual(resolved, "live-user")
        XCTAssertEqual(evaluations, 0)
    }

    func test_declaredEmpty_isTreatedAsNothingDeclared() {
        var evaluations = 0
        let resolved = resolve(live: "live-user", declared: "", evaluations: &evaluations)
        XCTAssertEqual(resolved, "live-user")
        XCTAssertEqual(evaluations, 0)
    }

    /// The steady state: signed in, declared id and client agree. This is the
    /// path every cell bind takes, so it is the one that must cost nothing.
    func test_declaredMatchesLive_returnsItWithoutAskingTheClient() {
        var evaluations = 0
        let resolved = resolve(live: "same-user", declared: "same-user", evaluations: &evaluations)
        XCTAssertEqual(resolved, "same-user")
        XCTAssertEqual(evaluations, 0)
    }

    func test_nothingDeclaredAndNoLiveUser_isNilWithoutAskingTheClient() {
        var evaluations = 0
        let resolved = resolve(live: "", declared: nil, evaluations: &evaluations)
        XCTAssertNil(resolved)
        XCTAssertEqual(evaluations, 0)
    }

    /// No live id means nothing for a connected client to be authoritative
    /// *about*, so the declared id wins without the question being asked.
    func test_declaredWithNoLiveUser_returnsDeclaredWithoutAskingTheClient() {
        var evaluations = 0
        let resolved = resolve(live: "", declared: "declared-user", evaluations: &evaluations)
        XCTAssertEqual(resolved, "declared-user")
        XCTAssertEqual(evaluations, 0)
    }

    // MARK: - The disagreement path still lets a connected client win

    func test_idsDisagreeAndConnected_theLiveIdWins() {
        var evaluations = 0
        let resolved = resolve(
            live: "live-user", declared: "declared-user", isConnected: true, evaluations: &evaluations
        )
        XCTAssertEqual(resolved, "live-user")
        XCTAssertEqual(evaluations, 1, "the connection state is the deciding term here")
    }

    /// The account-switch window `setCurrentUserId(_:)` exists for: the client
    /// still names the outgoing account, so the declared id must win.
    func test_idsDisagreeAndDisconnected_theDeclaredIdWins() {
        var evaluations = 0
        let resolved = resolve(
            live: "outgoing-user", declared: "incoming-user", isConnected: false, evaluations: &evaluations
        )
        XCTAssertEqual(resolved, "incoming-user")
        XCTAssertEqual(evaluations, 1)
    }
}
