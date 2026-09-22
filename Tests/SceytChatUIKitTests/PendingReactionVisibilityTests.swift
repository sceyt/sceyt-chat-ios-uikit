//
//  PendingReactionVisibilityTests.swift
//  SceytChatUIKitTests
//
//  The reactions info screen (ReactionsInfoViewController) must show the user's own
//  reactions while they are still pending — a reaction the user just tapped but the
//  server hasn't acknowledged yet.
//
//  A pending reaction is stored as a ReactionDTO with `pending == true` and NO
//  ReactionTotalDTO row (totals are authoritative server state). The screen's header
//  chips were built from the totals alone, so a pending-only reaction rendered as a
//  single "All 0" chip — the count the user reported as 0 — even though the message
//  cell showed the chip (ChatMessage sums totals + pending reactions).
//
//  Three layers have to hold for pending reactions to appear:
//   - ReactionScoreViewModel.merge counts pending keys alongside the totals, so the
//     header shows a chip and a page for a pending-only reaction;
//   - deleteNotExistReactions (run by the "All" page's first server load, which is
//     exactly when the screen opens) must not delete the local pending row;
//   - add(reaction:) must clear `pending` on the row the server reaction confirms,
//     otherwise the same reaction is counted by both the total and the pending row.
//

@testable import SceytChatUIKit
import CoreData
import ObjectiveC
import SceytChat
import XCTest

final class PendingReactionVisibilityTests: XCTestCase {

    private var database: PersistentContainer!
    private var savedUserId: UserId?
    private let channelId: ChannelId = 91
    private let messageId: MessageId = 515_151
    private let reactionKey = "🔥"
    private let otherKey = "👍"
    private let me = "current-user"

    override func setUp() {
        super.setUp()
        savedUserId = UserDefaults.currentUserId
        // addPendingReaction / add(reaction:) resolve the reacting user through
        // SceytChatUIKit.shared.currentUserId, which falls back to UserDefaults when
        // the client isn't connected.
        UserDefaults.currentUserId = me
        database = PersistentContainer(modelName: "SceytChatModel",
                                       bundle: .module,
                                       storeType: .inMemory)
        seedMessage()
    }

    override func tearDown() {
        UserDefaults.currentUserId = savedUserId
        database = nil
        super.tearDown()
    }

    // MARK: - SDK object fakes

    /// SceytChat model classes mark `init` unavailable — the SDK only creates them from
    /// its internal bridge. Their storage is plain ObjC ivars, so tests allocate through
    /// the runtime and fill the readonly properties via KVC. The sessions under test only
    /// READ these objects.
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

    private func makeReaction(id: UInt64 = 777, key: String? = nil, userId: String? = nil) -> Reaction {
        makeSDKObject(Reaction.self, properties: [
            "id": NSNumber(value: id),
            "messageId": NSNumber(value: messageId),
            "key": key ?? reactionKey,
            "score": NSNumber(value: UInt16(1)),
            "createdAt": Date(),
            "user": makeUser(id: userId ?? me),
        ])
    }

    // MARK: - Helpers

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
            // The current user must be in the store for addPendingReaction to attach them.
            _ = UserDTO.fetchOrCreate(id: self.me, context: ctx)
        }, completion: { _ in seeded.fulfill() })
        wait(for: [seeded], timeout: 5)
    }

    private func write(_ perform: @escaping (NSManagedObjectContext) -> Void) {
        let done = expectation(description: "write done")
        database.write({ ctx in perform(ctx) }, completion: { error in
            XCTAssertNil(error)
            done.fulfill()
        })
        wait(for: [done], timeout: 5)
    }

    private func addPendingReaction(key: String? = nil) {
        write { ctx in
            XCTAssertNotNil(ctx.addPendingReaction(messageId: self.messageId,
                                                   key: key ?? self.reactionKey,
                                                   score: 1,
                                                   reason: nil,
                                                   enforceUnique: false))
        }
    }

    /// The rows the reactions screen's pending observer sees: `message.id == X AND pending`.
    private func pendingKeys() -> [String] {
        var keys: [String] = []
        let read = expectation(description: "pending read")
        database.write({ ctx in
            let request = ReactionDTO.fetchRequest()
            request.predicate = NSPredicate(format: "message.id == %lld AND pending == true", self.messageId)
            request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionDTO.key, ascending: false)
            keys = ReactionDTO.fetch(request: request, context: ctx).map { $0.key }
        }, completion: { _ in read.fulfill() })
        wait(for: [read], timeout: 5)
        return keys
    }

    private func persistedTotals() -> [ChatMessage.ReactionTotal] {
        var totals: [ChatMessage.ReactionTotal] = []
        let read = expectation(description: "totals read")
        database.write({ ctx in
            let request = ReactionTotalDTO.fetchRequest()
            request.predicate = NSPredicate(format: "message.id == %lld", self.messageId)
            request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionTotalDTO.key, ascending: false)
            totals = ReactionTotalDTO.fetch(request: request, context: ctx).map { $0.convert() }
        }, completion: { _ in read.fulfill() })
        wait(for: [read], timeout: 5)
        return totals
    }

    /// What the header renders: the merge of the two observers the screen runs.
    private func renderedChips() -> [(key: String, value: Int64)] {
        ReactionScoreViewModel.merge(totals: ReactionScoreViewModel.uniqueTotals(persistedTotals()),
                                     pendingKeys: pendingKeys())
    }

    // MARK: - Header chips

    /// THE reported case: the user reacts while the server hasn't confirmed yet, so the
    /// message has a pending reaction and no total at all. The screen must show the
    /// reaction with count 1, not "All 0" with no chip.
    func testPendingOnlyReaction_isCountedInHeaderChips() {
        addPendingReaction()

        XCTAssertTrue(persistedTotals().isEmpty,
                      "Precondition: a pending reaction must not write a total row")

        let chips = renderedChips()
        XCTAssertEqual(chips.map { $0.key }, [reactionKey],
                       "A pending-only reaction must still get its own header chip and page")
        XCTAssertEqual(chips.first?.value, 1,
                       "The pending reaction must be counted — this is the reported count of 0")
    }

    /// The user reacts with a key someone else already reacted with: the confirmed total
    /// counts the other user, the pending row counts the current user, so the chip must
    /// read 2 — and the key must not be listed twice.
    func testPendingReactionOnExistingKey_addsToTheConfirmedCount() {
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction(id: 1, userId: "someone-else"))) }
        addPendingReaction()

        let chips = renderedChips()
        XCTAssertEqual(chips.count, 1, "One reaction key must produce exactly one chip")
        XCTAssertEqual(chips.first?.value, 2,
                       "The chip must count the confirmed reaction plus the pending one")
    }

    /// Chip order must be stable while a reaction is pending: `merge` sorts by key the
    /// same way the totals observer fetches, so a pending key keeps its position once the
    /// server total replaces it. The emitted key order drives the page order, so a
    /// reordering here would swap pages under the user.
    func testPendingAndConfirmedKeys_areOrderedLikeTheTotalsObserver() {
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction(id: 1, key: self.otherKey, userId: "someone-else"))) }
        addPendingReaction()

        let pendingOrder = renderedChips().map { $0.key }

        // Confirm the pending reaction — the key set is unchanged, so the order must be too.
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction())) }

        XCTAssertEqual(renderedChips().map { $0.key }, pendingOrder,
                       "Confirming a pending reaction must not reorder the chips")
        XCTAssertEqual(pendingOrder.sorted(by: >), pendingOrder,
                       "Chips must be sorted by key descending, like the totals observer")
    }

    // MARK: - Pending rows must survive the screen's first server load

    /// The keys of the rows `deleteNotExistReactions` would purge for a given server list.
    ///
    /// `deleteNotExistReactions` itself can't run in this harness (like `deleteChannel(id:)`
    /// in PendingMessageDeleteTests): its batch delete merges into
    /// `SceytChatUIKit.shared.database`, whose persistent store coordinator differs from the
    /// test container's. The selection is exercised through the predicate it builds.
    private func keysPurgedByServerList(_ reactions: [Reaction]) -> [String] {
        var keys: [String] = []
        let read = expectation(description: "purge selection read")
        database.write({ ctx in
            let request = ReactionDTO.fetchRequest()
            request.predicate = ReactionDTO.notExistPredicate(messageId: self.messageId,
                                                              existingIds: reactions.map { $0.id })
            keys = ReactionDTO.fetch(request: request, context: ctx).map { $0.key }
        }, completion: { _ in read.fulfill() })
        wait(for: [read], timeout: 5)
        return keys
    }

    /// Opening the screen loads the "All" page, whose provider cleans local reactions the
    /// server didn't return (`cleanLocalReactionAfterFirstLoad`). A pending reaction is by
    /// definition not in the server's list, so this must not select it for deletion — that
    /// wiped the user's in-flight reaction the moment they opened the screen.
    func testPendingReaction_survivesTheAllPagesFirstServerLoad() {
        let othersReaction = makeReaction(id: 1, key: otherKey, userId: "someone-else")
        write { XCTAssertNotNil($0.add(reaction: othersReaction)) }
        addPendingReaction()

        // The "All" page's first load: the server returns everything except the pending row.
        XCTAssertFalse(keysPurgedByServerList([othersReaction]).contains(reactionKey),
                       "The server's reaction list must not delete the local pending reaction")
    }

    /// Confirmed reactions the server no longer reports still have to be deleted — the
    /// pending carve-out must not disable the cleanup itself.
    func testConfirmedReactionMissingFromServerList_isStillDeleted() {
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction(id: 1, key: self.otherKey, userId: "someone-else"))) }
        addPendingReaction()

        // Server reports neither the stored 👍 nor (as always) the pending reaction.
        let purged = keysPurgedByServerList([makeReaction(id: 2, key: "😀", userId: "someone-else")])

        XCTAssertEqual(purged, [otherKey],
                       "A confirmed reaction the server dropped must still be cleaned up")
    }

    // MARK: - Confirming a pending reaction

    /// The socket `didAdd` event for the user's own pending reaction: the row becomes the
    /// confirmed reaction and the total counts it once. If the row stayed pending, the
    /// merge above would count the same reaction twice (chip reading 2 for one tap).
    func testServerConfirmsPendingReaction_countedOnceNotTwice() {
        addPendingReaction()
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction())) }

        XCTAssertTrue(pendingKeys().isEmpty,
                      "The confirmed reaction's row must no longer be pending")
        let chips = renderedChips()
        XCTAssertEqual(chips.count, 1)
        XCTAssertEqual(chips.first?.value, 1,
                       "One tap must be counted once after the server confirms it")
    }

    /// The same confirmation with no stored user on the pending row (addPendingReaction can
    /// only attach a user already in the store): the reaction must reuse that row rather
    /// than leave it behind as a second, pending copy of itself.
    func testServerConfirmsPendingReactionWithNoStoredUser_countedOnceNotTwice() {
        // Drop the current user so addPendingReaction leaves `user` nil.
        write { ctx in
            if let user = UserDTO.fetch(id: self.me, context: ctx) {
                ctx.delete(user)
            }
        }
        addPendingReaction()
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction())) }

        XCTAssertTrue(pendingKeys().isEmpty,
                      "A user-less pending row must also be confirmed, not left pending")
        XCTAssertEqual(renderedChips().first?.value, 1,
                       "One tap must be counted once even when the pending row had no user")
    }

    /// Another user's reaction with the same key must not swallow the current user's
    /// pending row — both people reacted, so the count is 2 until the server confirms.
    func testOtherUsersReactionWithSameKey_doesNotConfirmMyPendingReaction() {
        addPendingReaction()
        write { XCTAssertNotNil($0.add(reaction: self.makeReaction(id: 9, userId: "someone-else"))) }

        XCTAssertEqual(pendingKeys(), [reactionKey],
                       "Someone else reacting must leave my pending reaction pending")
        XCTAssertEqual(renderedChips().first?.value, 2,
                       "Two people reacted — the chip must count both")
    }
}
