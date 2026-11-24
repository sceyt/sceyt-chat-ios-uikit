//
//  LazyMessagesObserverListRuleTests.swift
//  SceytChatUIKitTests
//
//  The message list observer against real `MessageDTO` rows and the production list
//  predicate. A shown row that breaks a list rule (a delete for me hides it with
//  `unlisted`) must leave the list on refresh; undoing the hide must bring it back; a row
//  that only fell outside the loaded window must stay; and one refresh that both removes a
//  row and moves another must produce change paths that replay to the final list.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class LazyMessagesObserverListRuleTests: XCTestCase {

    private typealias Paths = LazyDatabaseObserver<MessageDTO, ChatMessage>.ChangeItemPaths

    private let channelId: ChannelId = 1
    private var database: MockDatabase!
    private var context: NSManagedObjectContext!
    private var observer: LazyMessagesObserver!
    /// One day, so every row lands in a single section and paths are plain row indexes.
    private let base = Date().addingTimeInterval(-3_600)

    override func setUp() {
        super.setUp()
        database = MockDatabase()
        context = database.container.newBackgroundContext()
        // Configured like the production observable context.
        context.automaticallyMergesChangesFromParent = true
        context.retainsRegisteredObjects = true
        write { ctx in
            for id in 1...4 {
                let dto = MessageDTO.fetchOrCreate(id: MessageId(id), tid: Int64(id), channelId: Int64(self.channelId), context: ctx)
                dto.channelId = Int64(self.channelId)
                dto.body = "m\(id)"
                dto.incoming = true
                dto.createdAt = self.base.addingTimeInterval(Double(id)).bridgeDate
                dto.user = UserDTO.fetchOrCreate(id: "peer", context: ctx)
            }
        }
        observer = LazyMessagesObserver(
            context: context,
            sortDescriptors: [
                .init(keyPath: \MessageDTO.createdAt, ascending: true),
                .init(keyPath: \MessageDTO.id, ascending: true)
            ],
            sectionNameKeyPath: #keyPath(MessageDTO.daySectionIdentifier),
            fetchPredicate: LazyMessagesObserver.listPredicate(channelId: channelId),
            itemCreator: { $0.convert() }
        )
        let started = expectation(description: "initial start")
        observer.startObserver(completion: { started.fulfill() })
        wait(for: [started], timeout: defaultWaitTimeout)
        XCTAssertEqual(shownIds(), [1, 2, 3, 4])
    }

    override func tearDown() {
        observer?.stopObserver()
        observer = nil
        context = nil
        database = nil
        super.tearDown()
    }

    func test_unlistedRow_leavesTheList() {
        change { self.message(2, in: $0).unlisted = true }

        XCTAssertEqual(shownIds(), [1, 3, 4], "A row hidden by a delete for me must leave the list at once")
    }

    func test_undoingTheHide_bringsTheRowBack() {
        change { self.message(2, in: $0).unlisted = true }
        change { self.message(2, in: $0).unlisted = false }

        // The row comes back through the observer's follow-up insert pass, published as a
        // second event after the refresh itself.
        waitUntil { self.shownIds() == [1, 2, 3, 4] }
        XCTAssertEqual(shownIds(), [1, 2, 3, 4], "A refused delete restores the row in its place")
    }

    func test_hiddenReplyParentStub_leavesTheList() {
        // A history clear keeps a row that replies still point at, hidden with `replied`.
        change { self.message(3, in: $0).replied = true }

        XCTAssertEqual(shownIds(), [1, 2, 4])
    }

    func test_rowOutsideTheLoadedWindow_isKept() {
        observer.update(predicate: observer.defaultFetchPredicate.and(predicate: .init(format: "id <= 2")))

        change { self.message(4, in: $0).body = "edited" }

        XCTAssertEqual(shownIds(), [1, 2, 3, 4],
                       "Falling outside the window is not leaving the list; the row must stay")
    }

    func test_removalAndMoveInOneRefresh_pathsReplayToTheFinalList() {
        let before = shownIds()
        var paths: Paths?

        change(onEvent: { paths = $0 }) { ctx in
            self.message(2, in: ctx).unlisted = true
            // Re-sorts row 4 to the top in the same save.
            self.message(4, in: ctx).createdAt = self.base.bridgeDate
        }

        XCTAssertEqual(shownIds(), [4, 1, 3])
        let replayed = replay(paths?.changeItems ?? [], onto: before)
        XCTAssertEqual(replayed, shownIds(),
                       "Change paths are applied in order; replaying them must give the list on screen")
    }

    func test_removalBeforeAMovedRow_destinationPathsAddressTheFinalList() {
        var paths: Paths?

        change(onEvent: { paths = $0 }) { ctx in
            // Row 1 re-sorts to the end while row 3, between its old and new place, is hidden.
            self.message(1, in: ctx).createdAt = self.base.addingTimeInterval(10).bridgeDate
            self.message(3, in: ctx).unlisted = true
        }

        let final = shownIds()
        XCTAssertEqual(final, [2, 4, 1])
        // `ChannelViewModel.onWillChangeEvent` looks each reload's destination up in the
        // final list to regroup bubbles. Recorded before the removal, row 1's destination
        // was one past the end of the final list.
        for item in paths?.changeItems ?? [] {
            guard case let .move(_, to, message) = item else { continue }
            XCTAssertLessThan(to.item, final.count, "Move destination is outside the final list")
            XCTAssertEqual(final[safe: to.item], message.id, "Move destination must address the moved row in the final list")
        }
    }

    // MARK: - Helpers

    private func message(_ id: MessageId, in ctx: NSManagedObjectContext) -> MessageDTO {
        MessageDTO.fetch(id: id, context: ctx)!
    }

    private func write(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let writer = database.container.newBackgroundContext()
        writer.performAndWait {
            block(writer)
            try! writer.save()
        }
    }

    /// Writes from another context and waits for the observer to publish the change.
    private func change(
        onEvent: ((Paths) -> Void)? = nil,
        _ block: @escaping (NSManagedObjectContext) -> Void
    ) {
        let changed = expectation(description: "change event")
        changed.assertForOverFulfill = false
        var delivered = false
        observer.onDidChange = { isInitial, paths, _ in
            guard !isInitial, !delivered else { return }
            delivered = true
            onEvent?(paths)
            changed.fulfill()
        }
        write(block)
        wait(for: [changed], timeout: defaultWaitTimeout)
    }

    private func waitUntil(timeout: TimeInterval = defaultWaitTimeout, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        drainMainQueueAfterDeadline(until: condition)
    }

    private func shownIds() -> [MessageId] {
        var ids = [MessageId]()
        observer.forEach { _, item in
            ids.append(item.id)
            return false
        }
        return ids
    }

    /// Applies change items one after another, each against the list the previous one left —
    /// the contract the observer records them in. Single-section lists only.
    private func replay(_ items: [LazyDatabaseObserver<MessageDTO, ChatMessage>.ChangeItem], onto list: [MessageId]) -> [MessageId] {
        var list = list
        for item in items {
            switch item {
            case let .insert(indexPath, message):
                list.insert(message.id, at: indexPath.item)
            case let .delete(indexPath):
                list.remove(at: indexPath.item)
            case let .move(from, to, message):
                list.remove(at: from.item)
                list.insert(message.id, at: to.item)
            case .update:
                break
            }
        }
        return list
    }
}
