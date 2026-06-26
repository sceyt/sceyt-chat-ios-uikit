//
//  ChannelMemberListProviderConcurrencyTests.swift
//  SceytChatUIKitTests
//
//  Regression guard for the duplicate-member ("duplicate You") race.
//  ChannelMemberListProvider.store(members:) is invoked from several places at
//  once — its three role loads (loadOwners/loadAdmins/loadOthers) complete on
//  different threads, and it overlaps the realtime event handlers. The fix routes
//  store() through the shared serial backgroundPerformContext (database.write) so
//  concurrent MemberDTO.fetchOrCreate inserts can no longer persist as two rows
//  for the same (channelId, userId). These tests hammer store() concurrently and
//  assert exactly one row survives.
//
//  Uses a real in-memory PersistentContainer (not MockDatabase): production's
//  database.write serializes on a single shared backgroundPerformContext, which
//  is exactly the behavior under test. MockDatabase spins up a fresh context per
//  write and would not model it.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

/// ChannelMemberListProvider whose `database` is an injected in-memory store.
private final class TestInMemoryMemberListProvider: ChannelMemberListProvider {

    private let injectedDatabase: Database

    init(channelId: ChannelId, database: Database) {
        self.injectedDatabase = database
        super.init(channelId: channelId)
    }

    required init(channelId: ChannelId) {
        fatalError("use init(channelId:database:) in tests")
    }

    override var database: Database { injectedDatabase }
}

final class ChannelMemberListProviderConcurrencyTests: XCTestCase {

    private var database: PersistentContainer!
    private let channelId: ChannelId = 909

    override func setUp() {
        super.setUp()
        // Real production Database with an in-memory store → write() serializes on
        // the single shared backgroundPerformContext, just like on device.
        database = PersistentContainer(modelName: "SceytChatModel",
                                       bundle: .module,
                                       storeType: .inMemory)
        seedChannel()
    }

    override func tearDown() {
        database = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Seeds the channel and, as a side effect, forces the lazy `backgroundPerformContext`
    /// to initialize on the main thread before the concurrent storm (lazy var init is not
    /// thread-safe).
    private func seedChannel() {
        let seeded = expectation(description: "channel seeded")
        database.write({ ctx in
            let (channel, _) = ChannelDTO.fetchOrCreate(id: self.channelId, context: ctx)
            channel.type = "group"
        }, completion: { _ in seeded.fulfill() })
        wait(for: [seeded], timeout: 5)
    }

    private func makeMember(id: String, role: String) -> Member {
        Member.Builder(id: id).roleName(role).build()
    }

    /// Drains all enqueued writes (FIFO on the serial context) and returns the row
    /// count for `(userId, channelId)` read on that same context.
    private func memberCountAfterDrain(userId: String) -> Int {
        var count = -1
        let drained = expectation(description: "writes drained + counted")
        database.write({ ctx in
            count = MemberDTO.fetchAll(id: userId, channelId: self.channelId, context: ctx).count
        }, completion: { _ in drained.fulfill() })
        wait(for: [drained], timeout: 15)
        return count
    }

    // MARK: - Tests

    /// Same user stored concurrently through many DIFFERENT provider instances on the
    /// same channel (e.g. members screen + admins screen both loading), alternating role
    /// to mimic a promote/demote storm. Must yield a single row.
    /// Providers are created up-front and retained for the whole test: store() captures
    /// `[weak self]`, so a provider deallocated before its async write runs would (correctly)
    /// skip the write — which would make this assertion meaningless rather than exercise the race.
    func testConcurrentStore_sameMember_manyProviders_doesNotDuplicate() {
        let userId = "racing-user"
        let iterations = 64
        let providers = (0..<iterations).map { _ in
            TestInMemoryMemberListProvider(channelId: channelId, database: database)
        }

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let role = (i % 2 == 0) ? "participant" : "admin"
            providers[i].store(members: [self.makeMember(id: userId, role: role)])
        }

        XCTAssertEqual(memberCountAfterDrain(userId: userId), 1,
                       "Concurrent store(members:) must not create duplicate MemberDTO rows")
    }

    /// A single provider instance whose store() is called from many threads at once
    /// (the realistic shape: the three role loads call back on different threads).
    func testConcurrentStore_singleProviderManyThreads_doesNotDuplicate() {
        let userId = "racing-user-2"
        let provider = TestInMemoryMemberListProvider(channelId: channelId, database: database)
        let iterations = 64

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let role = (i % 2 == 0) ? "participant" : "admin"
            provider.store(members: [self.makeMember(id: userId, role: role)])
        }

        XCTAssertEqual(memberCountAfterDrain(userId: userId), 1,
                       "Concurrent store(members:) on one provider must not duplicate")
    }

    /// A batch of distinct users stored concurrently must produce exactly one row each.
    func testConcurrentStore_manyDistinctMembers_eachStoredOnce() {
        let provider = TestInMemoryMemberListProvider(channelId: channelId, database: database)
        let userIds = (0..<40).map { "member-\($0)" }

        DispatchQueue.concurrentPerform(iterations: userIds.count * 2) { i in
            let userId = userIds[i % userIds.count]
            let role = (i % 2 == 0) ? "participant" : "admin"
            provider.store(members: [self.makeMember(id: userId, role: role)])
        }

        // Drain, then assert one row per distinct user.
        _ = memberCountAfterDrain(userId: userIds[0])
        for userId in userIds {
            let count = database.read { ctx in
                MemberDTO.fetchAll(id: userId, channelId: self.channelId, context: ctx).count
            }
            XCTAssertEqual((try? count.get()) ?? -1, 1, "Expected one row for \(userId)")
        }
    }
}
