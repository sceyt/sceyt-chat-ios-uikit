//
//  TransferStoreTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class TransferStoreTests: XCTestCase {

    private let message = ChatMessage(id: 7, channelId: 100, attachments: [], user: ChatUser(id: "u1"))

    func testAReadThatFoundTheMessageOrNotIsTakenAsIs() {
        XCTAssertTrue(DatabaseTransferStore.exists(.success(true), message: message))
        XCTAssertFalse(DatabaseTransferStore.exists(.success(false), message: message))
    }

    /// E3: a failed read says nothing about the message. Taken as deleted, the finished
    /// upload's message would never be sent.
    func testAFailedReadKeepsTheMessage() {
        let failure = NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreOperationError)
        XCTAssertTrue(DatabaseTransferStore.exists(.failure(failure), message: message))
    }
}
