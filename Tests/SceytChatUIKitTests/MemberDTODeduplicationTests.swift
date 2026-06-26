//
//  MemberDTODeduplicationTests.swift
//  SceytChatUIKitTests
//
//  Covers the duplicate-member fix: MemberDTO has no Core Data uniqueness
//  constraint, so concurrent fetchOrCreate inserts on separate contexts can
//  persist two rows for the same (user, channel) — surfacing as the same user
//  (e.g. a duplicate "You") in two role sections of the member list.
//  fetchOrCreate must collapse such duplicates and never create new ones.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class MemberDTODeduplicationTests: XCTestCase {

    private var mockDB: MockDatabase!

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Inserts a raw MemberDTO row WITHOUT going through `fetchOrCreate`, so we can
    /// reproduce the duplicate rows that concurrent inserts on separate background
    /// contexts would persist (there is no uniqueness constraint to collapse them).
    @discardableResult
    private func insertRawMember(userId: String,
                                 channelId: ChannelId,
                                 in ctx: NSManagedObjectContext) -> MemberDTO {
        let member = MemberDTO.insertNewObject(into: ctx)
        member.channelId = Int64(channelId)
        member.user = UserDTO.fetchOrCreate(id: userId, context: ctx)
        return member
    }

    private func memberCount(userId: String,
                             channelId: ChannelId,
                             in ctx: NSManagedObjectContext) -> Int {
        MemberDTO.fetchAll(id: userId, channelId: channelId, context: ctx).count
    }

    // MARK: - Tests

    func testFetchOrCreate_collapsesDuplicateMemberRows() {
        let ctx = mockDB.container.viewContext
        let userId = "user-1"
        let channelId: ChannelId = 42

        // Two rows for the same (user, channel) — the duplicate-insert symptom.
        insertRawMember(userId: userId, channelId: channelId, in: ctx)
        insertRawMember(userId: userId, channelId: channelId, in: ctx)
        try? ctx.save()
        XCTAssertEqual(memberCount(userId: userId, channelId: channelId, in: ctx), 2,
                       "Precondition: two duplicate rows must be seeded")

        // fetchOrCreate is only ever called from write contexts and must heal duplicates.
        _ = MemberDTO.fetchOrCreate(id: userId, channelId: channelId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(memberCount(userId: userId, channelId: channelId, in: ctx), 1,
                       "fetchOrCreate should collapse duplicates to a single row")
    }

    func testFetchOrCreate_returnsExistingRowAndDoesNotDuplicate() {
        let ctx = mockDB.container.viewContext
        let userId = "user-2"
        let channelId: ChannelId = 7

        let first = MemberDTO.fetchOrCreate(id: userId, channelId: channelId, context: ctx)
        try? ctx.save()

        let second = MemberDTO.fetchOrCreate(id: userId, channelId: channelId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(first.objectID, second.objectID,
                       "fetchOrCreate must return the existing row, not insert a new one")
        XCTAssertEqual(memberCount(userId: userId, channelId: channelId, in: ctx), 1)
    }
}
