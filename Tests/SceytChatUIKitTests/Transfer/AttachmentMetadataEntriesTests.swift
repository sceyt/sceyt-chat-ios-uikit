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
        let old = #"{"pvw":"P","sceyt.enc":"TOKEN"}"#
        let result = try object(ChatMessage.Attachment.metadata(#"{"szw":1}"#, preservingUnownedKeysFrom: old))
        XCTAssertNil(result["pvw"], "an owned key is UIKit's to drop")
        XCTAssertEqual(result["sceyt.enc"] as? String, "TOKEN")
    }

    func testALegacyVideoThumbIsReadAsThePosterAndDroppedOnRebuild() throws {
        typealias Metadata = ChatMessage.Attachment.Metadata<String>
        XCTAssertEqual(try Metadata.decode(#"{"tmb":"","video_thumb":"OLD"}"#).videoThumbnail, "OLD", "older builds wrote the poster under video_thumb")
        XCTAssertEqual(try Metadata.decode(#"{"tmb":"","pvw":"NEW","video_thumb":"OLD"}"#).videoThumbnail, "NEW", "pvw wins")
        let encoded = try XCTUnwrap(Metadata(thumbnail: "", videoThumbnail: "P").build())
        XCTAssertEqual(try object(encoded)["pvw"] as? String, "P")
        XCTAssertNil(try object(encoded)["video_thumb"], "the legacy key is never written")
        let rebuilt = try object(ChatMessage.Attachment.metadata(encoded, preservingUnownedKeysFrom: #"{"video_thumb":"OLD"}"#))
        XCTAssertNil(rebuilt["video_thumb"], "the legacy key is UIKit's to drop")
    }

    func testARebuildWithNothingToKeepIsUnchanged() {
        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"szw":1}"#, preservingUnownedKeysFrom: #"{"szw":2}"#), #"{"szw":1}"#)
        XCTAssertEqual(ChatMessage.Attachment.metadata(nil, preservingUnownedKeysFrom: nil), nil)
    }

    func testARebuildThatCannotBeWrittenKeepsTheRebuild() {
        let failing = MetadataJSON(serialize: { _ in throw CocoaError(.coderInvalidValue) }, string: { _ in nil })
        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"szw":1}"#, preservingUnownedKeysFrom: #"{"sceyt.enc":"T"}"#, json: failing), #"{"szw":1}"#)
    }

    func testRollingBackRestoresOverwrittenKeysRemovesAddedOnesAndKeepsTheRest() throws {
        let previous = #"{"szw":3,"other":"keep"}"#
        let merged = try ChatMessage.Attachment.metadata(previous, merging: ["sceyt.enc": "K1", "other": "NEW"])
        // A write that landed after the merge (a poster) must survive the rollback.
        let later = try ChatMessage.Attachment.metadata(merged, merging: ["pvw": "P"])
        let result = try object(ChatMessage.Attachment.metadata(later, restoringKeys: ["sceyt.enc", "other"], from: previous))
        XCTAssertNil(result["sceyt.enc"], "a key the merge added is removed")
        XCTAssertEqual(result["other"] as? String, "keep", "a key the merge overwrote is restored")
        XCTAssertEqual(result["szw"] as? Int, 3, "a non-string key is kept")
        XCTAssertEqual(result["pvw"] as? String, "P", "a later write is kept")
    }

    func testRollingBackAMergeIntoNoMetadataGivesNoMetadata() throws {
        let merged = try ChatMessage.Attachment.metadata(nil, merging: ["sceyt.enc": "K1"])
        XCTAssertNil(ChatMessage.Attachment.metadata(merged, restoringKeys: ["sceyt.enc"], from: nil))
        XCTAssertEqual(ChatMessage.Attachment.metadata(merged, restoringKeys: ["sceyt.enc"], from: ""), "")
    }

    func testRollingBackNoKeysOrNonObjectMetadataIsUnchanged() {
        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"a":"b"}"#, restoringKeys: [], from: nil), #"{"a":"b"}"#)
        XCTAssertEqual(ChatMessage.Attachment.metadata("[1]", restoringKeys: ["a"], from: nil), "[1]")
    }

    func testARollbackThatCannotBeWrittenRestoresTheEarlierMetadata() {
        let failing = MetadataJSON(serialize: { _ in throw CocoaError(.coderInvalidValue) }, string: { _ in nil })
        let previous = #"{"szw":1}"#
        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"szw":1,"sceyt.enc":"K1"}"#, restoringKeys: ["sceyt.enc"], from: previous, json: failing), previous)
    }

    func testStringEntriesSkipOtherValues() {
        XCTAssertEqual(ChatMessage.Attachment.stringEntries(inMetadata: #"{"szw":3,"tmb":"t","hld":true,"sceyt.enc":"T"}"#), ["tmb": "t", "sceyt.enc": "T"])
        XCTAssertEqual(ChatMessage.Attachment.stringEntries(inMetadata: "not json"), [:])
    }
}
