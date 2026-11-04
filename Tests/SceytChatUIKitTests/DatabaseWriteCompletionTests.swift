//
//  DatabaseWriteCompletionTests.swift
//  SceytChatUIKitTests
//
//  `PersistentContainer.write` / `performWriteTask` call their completion exactly once,
//  with the write's outcome, and a failed `write` leaves nothing behind for the next one.
//

import CoreData
import XCTest
@testable import SceytChatUIKit

final class DatabaseWriteCompletionTests: XCTestCase {

    private struct Failure: Error {}

    private var database: PersistentContainer!

    override func setUp() {
        super.setUp()
        database = PersistentContainer(modelName: "SceytChatModel", bundle: .module, storeType: .inMemory)
    }

    override func tearDown() {
        database = nil
        super.tearDown()
    }

    func testAFailedWriteCompletesOnceWithItsError() {
        let completions = completions(of: { completion in
            self.database.write(resultQueue: .global(), { _ in throw Failure() }, completion: completion)
        })
        XCTAssertEqual(completions.count, 1, "one completion, not a success followed by the failure")
        XCTAssertTrue(completions.first.flatMap { $0 } is Failure)
    }

    func testASuccessfulWriteCompletesOnceWithoutAnError() {
        let completions = completions(of: { completion in
            self.database.write(resultQueue: .global(), { _ in }, completion: completion)
        })
        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(completions.first.flatMap { $0 })
    }

    func testAFailedWriteTaskCompletesOnceWithItsError() {
        let completions = completions(of: { completion in
            self.database.performWriteTask(resultQueue: .global(), { _ in throw Failure() }, completion: completion)
        })
        XCTAssertEqual(completions.count, 1)
        XCTAssertTrue(completions.first.flatMap { $0 } is Failure)
    }

    func testAFailedWriteIsRolledBackSoTheNextWriteDoesNotSaveIt() {
        let failed = expectation(description: "failed write")
        database.write(resultQueue: .global(), { context in
            let user = UserDTO(context: context)
            user.id = "left-behind"
            throw Failure()
        }, completion: { _ in failed.fulfill() })
        wait(for: [failed], timeout: 5)

        let next = expectation(description: "next write")
        database.write(resultQueue: .global(), { _ in }, completion: { _ in next.fulfill() })
        wait(for: [next], timeout: 5)

        let request = NSFetchRequest<UserDTO>(entityName: "UserDTO")
        request.predicate = NSPredicate(format: "id == %@", "left-behind")
        let count = (try? database.viewContext.count(for: request)) ?? -1
        XCTAssertEqual(count, 0, "the failed write's object was not saved by the next write")
    }

    /// Every completion `start` produces within a short window after the first.
    private func completions(of start: (@escaping (Error?) -> Void) -> Void) -> [Error?] {
        let lock = NSLock()
        var received = [Error?]()
        let first = expectation(description: "completion")
        first.assertForOverFulfill = false
        start { error in
            lock.lock(); received.append(error); lock.unlock()
            first.fulfill()
        }
        wait(for: [first], timeout: 5)
        // A second, wrong completion is queued right behind the first.
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        lock.lock(); defer { lock.unlock() }
        return received
    }
}
