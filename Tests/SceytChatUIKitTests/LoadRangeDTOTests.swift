//
//  LoadRangeDTOTests.swift
//  
//
//  Created by Андрей Букша on 11.03.2024.
//

import XCTest
import SceytChat
@testable import SceytChatUIKit

final class LoadRangeDTOTests: XCTestCase {

    private let testChannelId: ChannelId = 0
    var loadRangeProvider: LoadRangeProvider!
    lazy var messagesObserver = {
        MessagesObserverMock(
            channelId: testChannelId,
            loadRangeProvider: loadRangeProvider,
            itemCreator: { return $0.convert() }
        )
    }()
    var messages = [MessageDTO]()

    override func setUpWithError() throws {
        Config.storageDirectory = nil
        loadRangeProvider = LoadRangeProvider()
        messagesObserver.onLoaded = { [weak self] dtos in
            self?.messages = dtos
        }
    }

    override func tearDownWithError() throws {
        messagesObserver.stopObserver()
        loadRangeProvider = nil
        Config.database.deleteAll()
        messages.removeAll()
    }

    func testStoreRange() throws {
        let provider = ChannelMessageProvider(channelId: testChannelId)

        let chunk1 = [
            1, 
            2,
            3
        ].map { makeMessage(id: $0) }
        
        let chunk2 = [
            4,
            5,
            6
        ].map { makeMessage(id: $0) }

        let chunk3 = [
            10,
            11,
            12
        ].map { makeMessage(id: $0) }

        let exp = XCTestExpectation(description: "Store")

        provider.store(messages: chunk1, triggerMessage: 4) { [weak self] error in
            guard let self else { return }
            if let error {
                XCTFail(error.localizedDescription)
            } else {
                provider.store(messages: chunk2, triggerMessage: 7) { error in
                    if let error {
                        XCTFail(error.localizedDescription)
                    } else {
                        provider.store(messages: chunk3, triggerMessage: 9) { error in
                            if let error {
                                XCTFail(error.localizedDescription)
                            } else {
                                self.loadRangeProvider.fetchLoadRanges(channelId: self.testChannelId) { ranges in
                                    XCTAssertEqual(ranges.count, 2)
                                    XCTAssertEqual(ranges.first?.startMessageId, 1)
                                    XCTAssertEqual(ranges.first?.endMessageId, 7)
                                    XCTAssertEqual(ranges.last?.startMessageId, 9)
                                    XCTAssertEqual(ranges.last?.endMessageId, 12)
                                    exp.fulfill()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        wait(for: [exp], timeout: 3)
    }

    func testStartObserver() {
        let exp = XCTestExpectation(description: "Test start observer")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            self.messagesObserver.startObserver(initialMessageId: 10, fetchLimit: 5) { [weak self] in
                XCTAssertEqual(self?.messages.count, 5)
                XCTAssertEqual(self?.messages.first?.id, 6)
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 5)
    }

    func testLoadPrev() {
        let exp = XCTestExpectation(description: "Test load prev")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            self.messagesObserver.startObserver(initialMessageId: 10, fetchLimit: 3) {
                self.messagesObserver.loadPrev(before: 5) {
                    XCTAssertEqual(self.messages.count, 3)
                    XCTAssertEqual(self.messages.first?.id, 3)
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp], timeout: 5)
    }

    func testLoadPrevEmptyCase() {
        let exp = XCTestExpectation(description: "Test load prev")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            self.messagesObserver.startObserver(initialMessageId: 10, fetchLimit: 3) {
                self.messagesObserver.loadPrev(before: 20) {
                    XCTAssertEqual(self.messages.count, 3)
                    XCTAssertEqual(self.messages.last?.id, 10)
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp], timeout: 5)
    }

    func testLoadNext() {
        let exp = XCTestExpectation(description: "Test load next")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            self.messagesObserver.startObserver(initialMessageId: 3, fetchLimit: 3) {
                self.messagesObserver.loadNext(after: 7) {
                    XCTAssertEqual(self.messages.count, 3)
                    XCTAssertEqual(self.messages.last?.id, 10)
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp], timeout: 5)
    }

    func testLoadNextEmptyCase() {
        let exp = XCTestExpectation(description: "Test load next")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            self.messagesObserver.startObserver(initialMessageId: 10, fetchLimit: 3) {
                self.messagesObserver.loadNext(after: 10) {
                    XCTAssertEqual(self.messages.count, 0)
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp], timeout: 5)
    }

    func testLoadNear() {
        let exp = XCTestExpectation(description: "Test load near")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            self.messagesObserver.startObserver(initialMessageId: 10, fetchLimit: 4) {
                self.messagesObserver.loadNear(at: 4) { _ in
                    XCTAssertEqual(self.messages.count, 4)
                    XCTAssertEqual(self.messages.first?.id, 3)
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp], timeout: 5)
    }

    func testLoadNearEmptyCase() {
        let exp = XCTestExpectation(description: "Test load near")

        prepareData { [weak self] in
            guard let self else {
                XCTFail("self deinited")
                return
            }
            
            self.messagesObserver.startObserver(initialMessageId: 10, fetchLimit: 4) {
                self.messagesObserver.loadNear(at: 15) { _ in
                    XCTAssertEqual(self.messages.count, 4)
                    XCTAssertEqual(self.messages.first?.id, 7)
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp], timeout: 5)
    }

}

private extension LoadRangeDTOTests {
    func makeMessage(id: UInt64) -> Message {
        let builder = Message.Builder()
            .id(MessageId(id))
            .tid(Int(id))
        return builder.build()
    }

    func prepareData(completion: @escaping () -> Void) {
        let provider = ChannelMessageProvider(channelId: self.testChannelId)
        let testData = Array(0...10).map { self.makeMessage(id: $0) }

        provider.store(messages: testData) { error in
            if let error {
                XCTFail(error.localizedDescription)
            } else {
                completion()
            }
        }
    }
}
