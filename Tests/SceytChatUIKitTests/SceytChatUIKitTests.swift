//
//  AudioSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

@testable import SceytChatUIKit
import XCTest

class SceytChatUIKitTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testNumberFormatter() throws {
        let numberFormatter = MessageViewsCountFormatter()
        XCTAssert(numberFormatter.short(1_111_000_000_000) == "1.11t")
        XCTAssert(numberFormatter.short(1_110_000_000_000) == "1.11t")
        XCTAssert(numberFormatter.short(1_100_000_000_000) == "1.1t")
        XCTAssert(numberFormatter.short(1_011_000_000_000) == "1.01t")
        XCTAssert(numberFormatter.short(1_010_000_000_000) == "1.01t")
        XCTAssert(numberFormatter.short(1_000_000_000_000) == "1t")
        XCTAssert(numberFormatter.short(1_111_000_000) == "1.11b")
        XCTAssert(numberFormatter.short(1_110_000_000) == "1.11b")
        XCTAssert(numberFormatter.short(1_100_000_000) == "1.1b")
        XCTAssert(numberFormatter.short(1_010_000_000) == "1.01b")
        XCTAssert(numberFormatter.short(1_000_000_000) == "1b")
        XCTAssert(numberFormatter.short(1_111_000) == "1.11m")
        XCTAssert(numberFormatter.short(1_110_000) == "1.11m")
        XCTAssert(numberFormatter.short(1_100_000) == "1.1m")
        XCTAssert(numberFormatter.short(1_010_000) == "1.01m")
        XCTAssert(numberFormatter.short(1_000_000) == "1m")
        XCTAssert(numberFormatter.short(1_111) == "1.11k")
        XCTAssert(numberFormatter.short(1_110) == "1.11k")
        XCTAssert(numberFormatter.short(1_100) == "1.1k")
        XCTAssert(numberFormatter.short(1_010) == "1.01k")
        XCTAssert(numberFormatter.short(1_000) == "1k")
        XCTAssert(numberFormatter.short(999) == "999")
        XCTAssert(numberFormatter.short(100) == "100")
        XCTAssert(numberFormatter.short(10) == "10")
        XCTAssert(numberFormatter.short(1) == "1")
        XCTAssert(numberFormatter.short(0) == "0")
    }
}
