//
//  ReactionTotalDuplicationTests.swift
//  SceytChatUIKitTests
//
//  Reproduces the duplicate-reaction-chip bug on the reactions info screen.
//
//  ReactionTotalDTO has NO Core Data uniqueness constraint on (message, key) —
//  dedupe relies entirely on fetch-before-insert inside `add(reaction:)` (socket
//  event path) and `createOrUpdate(reactionTotal:)` (message payload path, e.g. a
//  notification-service extension persisting a push). When the same message +
//  same reaction is delivered twice through writers that cannot see each other's
//  in-flight changes — push written by the NSE process while the main app writes
//  the socket event — both writers miss the fetch, both insert, and the reactions
//  screen (an FRC on `message.id == X` with no key dedupe) renders the same
//  reaction twice.
//
//  A store-level uniqueness constraint can't close the race window: the logical
//  key spans a relationship, and retrofitting a constraint fails lightweight
//  migration on any store already containing duplicates (which would wipe
//  production databases). The fix is instead layered, and these tests guard each
//  layer:
//   - ReactionTotalDTO.fetchOrCreate self-heals duplicate (message, key) rows on
//     every write that touches the key;
//   - add(reaction:) is idempotent per server reaction id, so replayed events
//     don't inflate count/score;
//   - ReactionScoreViewModel.uniqueTotals collapses by key on read, so the screen
//     never renders the same reaction twice even while dirty rows await healing.
//

@testable import SceytChatUIKit
import CoreData
import ObjectiveC
import SceytChat
import XCTest

final class ReactionTotalDuplicationTests: XCTestCase {

    private var database: PersistentContainer!
    private let channelId: ChannelId = 77
    private let messageId: MessageId = 424_242
    private let reactionKey = "👍"
    private let reactingUserId = "reacting-user"

    override func setUp() {
        super.setUp()
        // Real production Database with an in-memory store, same as
        // ChannelMemberListProviderConcurrencyTests: write() serializes on the
        // single shared backgroundPerformContext, exactly like on device.
        database = PersistentContainer(modelName: "SceytChatModel",
                                       bundle: .module,
                                       storeType: .inMemory)
        seedMessage()
    }

    override func tearDown() {
        database = nil
        super.tearDown()
    }

    // MARK: - SDK object fakes

    /// SceytChat model classes (SCTReaction & co.) mark `init` unavailable — the
    /// SDK only ever creates them from its internal C++ bridge. Their storage is
    /// plain `_name` ObjC ivars, so tests can allocate through the runtime and
    /// fill the readonly properties via KVC direct-ivar access. The database
    /// sessions under test only READ these objects, so this is safe.
    private func makeSDKObject<T: NSObject>(_ type: T.Type, properties: [String: Any]) -> T {
        guard let object = class_createInstance(type, 0) as? T else {
            fatalError("could not instantiate \(type)")
        }
        properties.forEach { object.setValue($0.value, forKey: $0.key) }
        return object
    }

    private func makeUser(id: String) -> User {
        makeSDKObject(User.self, properties: [
            "id": id,
            "presence": Presence.Builder().build(),
        ])
    }

    /// The reaction as the socket `didAdd` channel event delivers it.
    private func makeReaction(id: UInt64 = 555) -> Reaction {
        makeSDKObject(Reaction.self, properties: [
            "id": NSNumber(value: id),
            "messageId": NSNumber(value: messageId),
            "key": reactionKey,
            "score": NSNumber(value: UInt16(1)),
            "createdAt": Date(),
            "user": makeUser(id: reactingUserId),
        ])
    }

    /// The reaction total as a message payload carries it (push notification /
    /// message sync both funnel into `createOrUpdate(reactionTotal:dto:)`).
    private func makeReactionTotal(score: UInt = 1, count: UInt = 1) -> ReactionTotal {
        makeSDKObject(ReactionTotal.self, properties: [
            "key": reactionKey,
            "score": NSNumber(value: score),
            "count": NSNumber(value: count),
        ])
    }

    // MARK: - Helpers

    /// Seeds the channel + an incoming message with no reactions, and forces the
    /// lazy `backgroundPerformContext` to initialize before any concurrent use.
    private func seedMessage() {
        let seeded = expectation(description: "message seeded")
        database.write({ ctx in
            let (channel, _) = ChannelDTO.fetchOrCreate(id: self.channelId, context: ctx)
            channel.type = "group"
            let message = MessageDTO.fetchOrCreate(id: self.messageId, tid: 0, context: ctx)
            message.body = "hello"
            message.type = "text"
            message.channelId = Int64(self.channelId)
            message.incoming = true
            message.createdAt = Date().bridgeDate
        }, completion: { _ in seeded.fulfill() })
        wait(for: [seeded], timeout: 5)
    }

    /// Runs `perform` through the production serialized write path and waits.
    private func write(_ perform: @escaping (NSManagedObjectContext) -> Void) {
        let done = expectation(description: "write done")
        database.write({ ctx in perform(ctx) }, completion: { error in
            XCTAssertNil(error)
            done.fulfill()
        })
        wait(for: [done], timeout: 5)
    }

    /// Fetches the persisted totals for the message with the exact query the
    /// reactions info screen's observer uses (`message.id == X`, sorted by key).
    private func persistedTotals() -> [(key: String, count: Int64, score: Int64)] {
        var totals: [(String, Int64, Int64)] = []
        let read = expectation(description: "totals read")
        database.write({ ctx in
            let request = ReactionTotalDTO.fetchRequest()
            request.predicate = NSPredicate(format: "message.id == %lld", self.messageId)
            request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionTotalDTO.key, ascending: false)
            totals = ReactionTotalDTO.fetch(request: request, context: ctx)
                .map { ($0.key, $0.count, $0.score) }
        }, completion: { _ in read.fulfill() })
        wait(for: [read], timeout: 5)
        return totals
    }

    /// Fetches the stored ReactionDTO rows for the message + key, split by pending
    /// state (pending = the user's not-yet-confirmed tap, non-pending = server-confirmed).
    private func reactionRows(pending: Bool) -> [ReactionId] {
        var ids: [ReactionId] = []
        let read = expectation(description: "reaction rows read")
        database.write({ ctx in
            let request = ReactionDTO.fetchRequest()
            request.predicate = NSPredicate(format: "messageId == %lld AND key == %@ AND pending == %d",
                                            self.messageId, self.reactionKey, pending)
            ids = ReactionDTO.fetch(request: request, context: ctx).map { ReactionId($0.id) }
        }, completion: { _ in read.fulfill() })
        wait(for: [read], timeout: 5)
        return ids
    }

    // MARK: - Tests

    /// THE reported case: the same message + same reaction is written twice by two
    /// writers that cannot see each other's in-flight changes — WAAFI's
    /// notification-service extension persisting the push payload while the main
    /// app persists the socket `didAdd` event. Two separate processes are modeled
    /// as two independent background contexts whose fetch-before-insert both run
    /// before either save (exactly the cross-process timing: neither transaction
    /// is visible to the other).
    ///
    /// With no store-level constraint both inserts persist, so the guarded
    /// invariants are: (a) the reactions screen never renders the duplicate —
    /// uniqueTotals collapses by key; (b) the next write touching the key heals
    /// the store back to a single row.
    func testPushAndSocketWriteSameReaction_isolatedWriters_screenDedupesAndNextWriteHeals() {
        let pushContext = database.createBackgroundContext()   // NSE writing the push payload
        let socketContext = database.createBackgroundContext() // main app writing the socket event

        // Push writer: message payload carries the reaction total. Not saved yet.
        pushContext.performAndWait {
            guard let dto = MessageDTO.fetch(id: messageId, context: pushContext) else {
                return XCTFail("seeded message must exist")
            }
            pushContext.createOrUpdate(reactionTotal: [makeReactionTotal()],
                                       dto: dto,
                                       deleteNotExistReactions: true)
        }

        // Socket writer: same reaction as a channel event. The push writer hasn't
        // saved, so the fetch-before-insert inside add(reaction:) finds nothing.
        socketContext.performAndWait {
            XCTAssertNotNil(socketContext.add(reaction: makeReaction()),
                            "seeded message must exist for the socket event")
        }

        var saveErrors: [Error] = []
        pushContext.performAndWait {
            do { try pushContext.save() } catch { saveErrors.append(error) }
        }
        socketContext.performAndWait {
            do { try socketContext.save() } catch { saveErrors.append(error) }
        }
        XCTAssertTrue(saveErrors.isEmpty, "both writers must save cleanly: \(saveErrors)")

        // The race persists duplicate rows (documented limitation — no store constraint).
        // The screen must still show exactly one chip for the reaction:
        let chips = ReactionScoreViewModel.uniqueTotals(
            persistedTotals().map { ChatMessage.ReactionTotal(key: $0.key, score: UInt($0.score), count: UInt($0.count)) }
        )
        XCTAssertEqual(chips.count, 1,
                       """
                       Duplicate (message, key) rows reached the read path undeduped — the \
                       reactions info screen renders each as a chip, so the user sees the \
                       same reaction twice.
                       """)
        XCTAssertEqual(chips.first?.count, 1,
                       "One user reacted once — the rendered total must be 1")

        // The next write that touches the key — here the message payload being
        // re-persisted, which sync does constantly — must heal the store.
        write { ctx in
            guard let dto = MessageDTO.fetch(id: self.messageId, context: ctx) else {
                return XCTFail("seeded message must exist")
            }
            ctx.createOrUpdate(reactionTotal: [self.makeReactionTotal()],
                               dto: dto,
                               deleteNotExistReactions: true)
        }
        let healed = persistedTotals()
        XCTAssertEqual(healed.count, 1,
                       "fetchOrCreate must collapse the duplicate rows on the next write")
        XCTAssertEqual(healed.first?.count, 1,
                       "One user reacted once — the healed total count must be 1")
    }

    /// The same socket `didAdd` event processed twice (reconnect replay) through
    /// the production serialized write path. add(reaction:) is idempotent per
    /// server reaction id: the replay finds the already-stored ReactionDTO with
    /// the same id and must not re-apply the total increment.
    func testSameSocketEventDeliveredTwice_serializedWrites_mustNotInflateCount() {
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction())) }
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction())) } // exact same event replayed

        let totals = persistedTotals()
        XCTAssertEqual(totals.count, 1,
                       "Serialized writes on one context must never create a duplicate row")
        XCTAssertEqual(totals.first?.count, 1,
                       "The same reaction event replayed must not inflate the total count")
        XCTAssertEqual(totals.first?.score, 1,
                       "The same reaction event replayed must not inflate the total score")
    }

    /// Push persisted first (totals already include the reaction), THEN the socket
    /// event arrives with full visibility — the sequential double delivery inside
    /// one process.
    ///
    /// The transient double count here is inherent: the payload total does not say
    /// WHICH users it counts (others' reactions are not in the payload), so the
    /// socket increment cannot know it was already counted. What must hold: never
    /// a duplicate row, and the next authoritative payload write (sync re-persists
    /// message payloads constantly) SETs the total back — the inflation may not
    /// stick. When both deliveries land in one transaction the handler passes
    /// `updateTotal: false` instead (see the didAdd fallback test below).
    func testPushPersistedThenSocketEvent_neverDuplicatesRowAndSelfCorrectsOnNextPayload() {
        let applyPayload: () -> Void = {
            self.write { ctx in
                guard let dto = MessageDTO.fetch(id: self.messageId, context: ctx) else {
                    return XCTFail("seeded message must exist")
                }
                ctx.createOrUpdate(reactionTotal: [self.makeReactionTotal()],
                                   dto: dto,
                                   deleteNotExistReactions: true)
            }
        }

        applyPayload()
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction())) }

        XCTAssertEqual(persistedTotals().count, 1,
                       "Sequential visible writes must never create a duplicate row")

        // The next payload write is authoritative and must restore the true count.
        applyPayload()
        let totals = persistedTotals()
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.first?.count, 1,
                       "The authoritative payload total must overwrite the transient double count")
    }

    /// The `didAdd` fallback for a message not yet in the DB: the handler persists
    /// the event's message payload (whose totals already include the reaction) and
    /// then stores the ReactionDTO with `updateTotal: false` — incrementing after
    /// the payload SET would double-count.
    func testDidAddFallback_payloadThenAddWithoutTotalUpdate_mustNotDoubleCount() {
        write { ctx in
            guard let dto = MessageDTO.fetch(id: self.messageId, context: ctx) else {
                return XCTFail("seeded message must exist")
            }
            ctx.createOrUpdate(reactionTotal: [self.makeReactionTotal()],
                               dto: dto,
                               deleteNotExistReactions: true)
            XCTAssertNotNil(ctx.add(reaction: self.makeReaction(), updateTotal: false))
        }

        let totals = persistedTotals()
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.first?.count, 1,
                       "add(reaction:updateTotal:false) must not increment the payload-set total")
    }

    /// The user taps the same reaction twice before the server responds (double-tap).
    /// Both taps run addPendingReaction — the second must reuse the pending row, so
    /// the message never carries two pending reactions for one key, and totals stay
    /// untouched until the server confirms.
    func testUserAddsSameReactionTwice_beforeServerResponds_storesSinglePendingRow() {
        for _ in 0..<2 {
            write { ctx in
                XCTAssertNotNil(ctx.addPendingReaction(messageId: self.messageId,
                                                       key: self.reactionKey,
                                                       score: 1,
                                                       reason: nil,
                                                       enforceUnique: false))
            }
        }

        XCTAssertEqual(reactionRows(pending: true).count, 1,
                       "Double-tapping the same reaction must reuse the single pending row")
        XCTAssertTrue(persistedTotals().isEmpty,
                      "Pending reactions must not touch the totals until the server confirms")
    }

    /// The user's full add-reaction round trip runs twice for the same reaction —
    /// the double-add reaching the DB through the production sequence (e.g. the
    /// pending reaction re-sent after reconnect even though the server had already
    /// applied it): tap stores the pending row, the server response removes it and
    /// persists the payload whose userReactions/totals already include the
    /// reaction. Every write is a SET or a fetchOrCreate, so the second pass must
    /// change nothing.
    func testUserAddsSameReactionTwice_fullServerRoundTrips_writeSingleReaction() {
        for _ in 0..<2 {
            write { ctx in
                XCTAssertNotNil(ctx.addPendingReaction(messageId: self.messageId,
                                                       key: self.reactionKey,
                                                       score: 1,
                                                       reason: nil,
                                                       enforceUnique: false))
            }
            write { ctx in
                guard let dto = MessageDTO.fetch(id: self.messageId, context: ctx) else {
                    return XCTFail("seeded message must exist")
                }
                ctx.removePendingReaction(messageId: self.messageId, key: self.reactionKey)
                ctx.createOrUpdate(userReactions: [self.makeReaction()], dto: dto)
                ctx.createOrUpdate(reactionTotal: [self.makeReactionTotal()],
                                   dto: dto,
                                   deleteNotExistReactions: true)
            }
        }

        let totals = persistedTotals()
        XCTAssertEqual(totals.count, 1,
                       "The same reaction confirmed twice must keep a single total row")
        XCTAssertEqual(totals.first?.count, 1,
                       "The same reaction confirmed twice must not inflate the count")
        XCTAssertEqual(reactionRows(pending: false).count, 1,
                       "The same reaction confirmed twice must keep a single stored ReactionDTO")
        XCTAssertTrue(reactionRows(pending: true).isEmpty,
                      "No pending row may survive a completed round trip")
    }

    /// Mirror of MemberDTODeduplicationTests: once duplicate rows exist in the
    /// store (however they got there), fetchOrCreate must heal them instead of
    /// perpetuating both.
    ///
    /// CURRENTLY FAILS: fetchOrCreate returns the first match and leaves the
    /// duplicate in place.
    func testFetchOrCreate_collapsesDuplicateReactionTotalRows() {
        // Seed the two raw duplicate rows the isolated-writer race persists.
        write { ctx in
            guard let dto = MessageDTO.fetch(id: self.messageId, context: ctx) else {
                return XCTFail("seeded message must exist")
            }
            for _ in 0..<2 {
                let total = ReactionTotalDTO.insertNewObject(into: ctx)
                total.key = self.reactionKey
                total.count = 1
                total.score = 1
                total.message = dto
            }
        }
        XCTAssertEqual(persistedTotals().count, 2, "Precondition: two duplicate rows must be seeded")

        write { ctx in
            _ = ReactionTotalDTO.fetchOrCreate(messageId: self.messageId,
                                               key: self.reactionKey,
                                               context: ctx)
        }

        XCTAssertEqual(persistedTotals().count, 1,
                       "fetchOrCreate should collapse duplicate (message, key) rows to a single row")
    }

    /// The read-side guard on its own: duplicate keys collapse to one entry keeping
    /// the highest count (duplicates describe the same reaction — summing would
    /// double it), distinct keys and their order are preserved.
    func testUniqueTotals_collapsesDuplicateKeysKeepingMaxCount() {
        let totals = [
            ChatMessage.ReactionTotal(key: "👍", score: 1, count: 1),
            ChatMessage.ReactionTotal(key: "❤️", score: 3, count: 3),
            ChatMessage.ReactionTotal(key: "👍", score: 2, count: 2),
        ]

        let unique = ReactionScoreViewModel.uniqueTotals(totals)

        XCTAssertEqual(unique.map(\.key), ["👍", "❤️"])
        XCTAssertEqual(unique.first?.count, 2, "The duplicate with the higher count must win")
    }
}
