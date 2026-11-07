//
//  AttachmentMetadataEntriesTests.swift
//  SceytChatUIKitTests
//
//  The metadata rules of the provider contract: entries merged in (added or overwritten, the
//  rest kept), and keys UIKit does not own kept through every rebuild of the typed metadata.
//

@testable import SceytChatUIKit
import XCTest

final class AttachmentMetadataEntriesTests: XCTestCase {

    private func object(_ metadata: String?) throws -> [String: Any] {
        try XCTUnwrap(ChatMessage.Attachment.metadataObject(metadata))
    }

    func testMergingAddsAndOverwritesAndKeepsTheRest() throws {
        let merged = try ChatMessage.Attachment.metadata(#"{"szw":3,"tmb":"t","sceyt.enc":"OLD"}"#, merging: ["sceyt.enc": "NEW", "sceyt.x": "1"])
        let result = try object(merged)
        XCTAssertEqual(result["szw"] as? Int, 3)
        XCTAssertEqual(result["tmb"] as? String, "t")
        XCTAssertEqual(result["sceyt.enc"] as? String, "NEW")
        XCTAssertEqual(result["sceyt.x"] as? String, "1")
    }

    func testMergingIntoNoMetadataMakesAnObject() throws {
        XCTAssertEqual(try object(try ChatMessage.Attachment.metadata(nil, merging: ["sceyt.enc": "T"]))["sceyt.enc"] as? String, "T")
        XCTAssertEqual(try object(try ChatMessage.Attachment.metadata("", merging: ["sceyt.enc": "T"]))["sceyt.enc"] as? String, "T")
    }

    func testMergingIntoMetadataThatIsNotAnObjectThrows() {
        XCTAssertThrowsError(try ChatMessage.Attachment.metadata("[1,2]", merging: ["sceyt.enc": "T"])) { error in
            guard case .notAnObject = error as? AttachmentMetadataError else { return XCTFail("\(error)") }
        }
    }

    func testARebuildKeepsTheKeysUIKitDoesNotOwn() throws {
        let old = #"{"szw":1,"szh":1,"tmb":"old","sceyt.enc":"TOKEN","server":"s"}"#
        let rebuilt = #"{"szw":40,"szh":30,"tmb":"new"}"#
        let result = try object(ChatMessage.Attachment.metadata(rebuilt, preservingUnownedKeysFrom: old))
        XCTAssertEqual(result["szw"] as? Int, 40, "UIKit's own keys are the rebuild's")
        XCTAssertEqual(result["tmb"] as? String, "new")
        XCTAssertEqual(result["sceyt.enc"] as? String, "TOKEN")
        XCTAssertEqual(result["server"] as? String, "s")
    }

    func testARebuildThatDropsAnOwnedKeyDropsIt() throws {
        let old = #"{"video_thumb":"P","sceyt.enc":"TOKEN"}"#
        let result = try object(ChatMessage.Attachment.metadata(#"{"szw":1}"#, preservingUnownedKeysFrom: old))
        XCTAssertNil(result["video_thumb"], "an owned key is UIKit's to drop")
        XCTAssertEqual(result["sceyt.enc"] as? String, "TOKEN")
    }

    func testARebuildWithNothingToKeepIsUnchanged() {
        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"szw":1}"#, preservingUnownedKeysFrom: #"{"szw":2}"#), #"{"szw":1}"#)
        XCTAssertEqual(ChatMessage.Attachment.metadata(nil, preservingUnownedKeysFrom: nil), nil)
    }

    func testARebuildThatCannotBeWrittenKeepsTheRebuild() {
        let failing = MetadataJSON(serialize: { _ in throw CocoaError(.coderInvalidValue) }, string: { _ in nil })
        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"szw":1}"#, preservingUnownedKeysFrom: #"{"sceyt.enc":"T"}"#, json: failing), #"{"szw":1}"#)
    }

    func testStringEntriesSkipOtherValues() {
        XCTAssertEqual(ChatMessage.Attachment.stringEntries(inMetadata: #"{"szw":3,"tmb":"t","hld":true,"sceyt.enc":"T"}"#), ["tmb": "t", "sceyt.enc": "T"])
        XCTAssertEqual(ChatMessage.Attachment.stringEntries(inMetadata: "not json"), [:])
    }
}
