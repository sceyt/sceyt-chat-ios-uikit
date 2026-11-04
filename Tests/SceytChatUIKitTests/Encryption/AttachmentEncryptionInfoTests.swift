//
//  AttachmentEncryptionInfoTests.swift
//  SceytChatUIKitTests
//
//  The `enc` object: its JSON (every required field missing or of the wrong type, unknown
//  versions, renditions), how it is read from and written into attachment metadata, the
//  size arithmetic that replaces a stored size (`plaintextSize(ciphertextSize:)`) and the
//  encryption policy of `InlineAttachmentKeyProvider`.
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

final class AttachmentEncryptionInfoTests: XCTestCase {

    private let algorithm = StreamingAeadFileEncryptionProvider.format
    private let attachmentId = "t7qA7hJJlA8x9sgMjck7Qg"
    private let key = "Rx3aNGnrgKqgOFEAC_3pg44jSri5YmYPP0U374KYztU"

    // Layout constants of the format, spelled out independently of the production code.
    private let segment: UInt64 = 64 * 1024
    private let tag: UInt64 = 16
    private let header: UInt64 = 40
    private let commitment: UInt64 = 32
    /// The plaintext the first segment holds; the header shares it.
    private var firstSegmentPlaintext: UInt64 { segment - tag - header }
    private var segmentPlaintext: UInt64 { segment - tag }

    // MARK: Fixtures

    private var validObject: [String: Any] {
        ["v": 1, "alg": algorithm, "attachmentId": attachmentId, "key": key]
    }

    private func decode(_ object: [String: Any]) throws -> AttachmentEncryption {
        try JSONDecoder().decode(AttachmentEncryption.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func metadata(enc: Any, extra: [String: Any] = ["tmb": "x"]) throws -> String {
        var object = extra
        object["enc"] = enc
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func object(_ metadata: String?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(metadata).utf8)) as? [String: Any])
    }

    private func makeAttachment(type: String = "file", metadata: String? = nil) -> ChatMessage.Attachment {
        .init(id: 0, tid: 1, messageId: 1, userId: "user", url: nil, filePath: nil, type: type, name: "a", metadata: metadata, uploadedFileSize: 0, createdAt: Date())
    }

    // MARK: - Decoding

    func testDecodesAMinimalEncWithoutRenditions() throws {
        let enc = try decode(validObject)
        XCTAssertEqual(enc.algorithm, algorithm)
        XCTAssertEqual(enc.attachmentId, attachmentId)
        XCTAssertEqual(enc.key, key)
        XCTAssertEqual(enc.renditions, [])
        XCTAssertNil(enc.thumbnail)
    }

    func testEveryRequiredFieldMissingIsRejected() {
        for field in ["v", "alg", "attachmentId", "key"] {
            var object = validObject
            object[field] = nil
            XCTAssertThrowsError(try decode(object), "missing \(field)") { error in
                guard case DecodingError.keyNotFound(let key, _) = error else {
                    return XCTFail("missing \(field): expected keyNotFound, got \(error)")
                }
                XCTAssertEqual(key.stringValue, field)
            }
        }
    }

    func testEveryFieldOfTheWrongTypeIsRejected() {
        let wrong: [String: Any] = ["v": "1", "alg": 7, "attachmentId": ["x"], "key": NSNull()]
        for (field, value) in wrong {
            var object = validObject
            object[field] = value
            XCTAssertThrowsError(try decode(object), "\(field) = \(value)")
        }
    }

    func testAKeyThatIsNot32BytesOfBase64URLIsRejectedBeforeAnythingIsFetched() {
        for bad in ["", "short", String(key.dropLast()), key + "AA", key.replacingOccurrences(of: "_", with: "/"), key + "="] {
            var object = validObject
            object["key"] = bad
            XCTAssertThrowsError(try decode(object), "key \(bad)")
        }
    }

    func testAnAttachmentIdThatIsNotBase64URLIsRejected() {
        for bad in ["", "has space", "a+b/c==", "a.b"] {
            var object = validObject
            object["attachmentId"] = bad
            XCTAssertThrowsError(try decode(object), "attachmentId \(bad)")
        }
    }

    func testARenditionWithABadKeyRejectsTheWholeEnc() {
        var object = validObject
        object["renditions"] = [["role": "thumbnail", "attachmentId": attachmentId, "key": "nope"]]
        XCTAssertThrowsError(try decode(object))
    }

    func testBase64URLDecodedCount() {
        XCTAssertEqual(AttachmentEncryption.base64URLDecodedCount(key), 32)
        XCTAssertEqual(AttachmentEncryption.base64URLDecodedCount(attachmentId), 16)
        XCTAssertNil(AttachmentEncryption.base64URLDecodedCount("A"), "one character can't encode a byte")
        XCTAssertTrue(AttachmentEncryption.isBase64URLAlphabet("a-_Z9"))
    }

    func testAnUnknownVersionIsRejected() {
        for version in [0, 2, -1] {
            var object = validObject
            object["v"] = version
            XCTAssertThrowsError(try decode(object), "v \(version)") { error in
                guard case DecodingError.dataCorrupted(let context) = error else {
                    return XCTFail("v \(version): expected dataCorrupted, got \(error)")
                }
                XCTAssertTrue(context.debugDescription.contains("\(version)"))
            }
        }
    }

    func testAMalformedRenditionRejectsTheWholeEnc() {
        for rendition in [["attachmentId": "a", "key": "k"], ["role": "thumbnail", "key": "k"], ["role": "thumbnail", "attachmentId": "a"]] {
            var object = validObject
            object["renditions"] = [rendition]
            XCTAssertThrowsError(try decode(object), "\(rendition)")
        }
        var notAnArray = validObject
        notAnArray["renditions"] = "thumbnail"
        XCTAssertThrowsError(try decode(notAnArray))
    }

    func testNullRenditionsDecodeAsNone() throws {
        var object = validObject
        object["renditions"] = NSNull()
        XCTAssertEqual(try decode(object).renditions, [])
    }

    func testUnknownKeysAreIgnored() throws {
        var object = validObject
        object["future"] = ["x": 1]
        XCTAssertEqual(try decode(object).attachmentId, attachmentId)
    }

    // MARK: - Encoding

    func testEncodingWritesTheVersionAndOmitsEmptyRenditions() throws {
        let enc = AttachmentEncryption(algorithm: algorithm, attachmentId: attachmentId, key: key)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(enc)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["v", "alg", "attachmentId", "key"])
        XCTAssertEqual(object["v"] as? Int, AttachmentEncryption.version)
    }

    func testEncodingRoundTripsRenditions() throws {
        let thumbnail = AttachmentEncryption.Rendition(role: AttachmentEncryption.Rendition.thumbnailRole, attachmentId: "p", key: "YGzDgK1imJtelRMNIoRMDMFn3l2SITyRHaqTrSwGYx4")
        let other = AttachmentEncryption.Rendition(role: "preview", attachmentId: "q", key: "fc3Ym1caWRIAWJRXZAj3kM088pUm0Etu7i2i70hQsDk")
        let enc = AttachmentEncryption(algorithm: algorithm, attachmentId: attachmentId, key: key, renditions: [other, thumbnail])
        let data = try JSONEncoder().encode(enc)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual((object["renditions"] as? [[String: Any]])?.count, 2)

        let decoded = try JSONDecoder().decode(AttachmentEncryption.self, from: data)
        XCTAssertEqual(decoded, enc)
        XCTAssertEqual(decoded.thumbnail, thumbnail, "the thumbnail is found by role, not position")
    }

    // MARK: - Derived infos

    func testInfosOfTheFileAndOfARendition() {
        let file = EncryptedFileInfo(algorithm: algorithm, attachmentId: attachmentId, key: key)
        let poster = EncryptedFileInfo(algorithm: "ignored", attachmentId: "p", key: "pk")
        let rendition = AttachmentEncryption.Rendition(role: AttachmentEncryption.Rendition.thumbnailRole, info: poster)
        XCTAssertEqual(rendition.attachmentId, "p")
        XCTAssertEqual(rendition.key, "pk")

        let enc = AttachmentEncryption(info: file, renditions: [rendition])
        XCTAssertEqual(enc.fileInfo, file)
        XCTAssertEqual(
            enc.info(of: rendition),
            EncryptedFileInfo(algorithm: algorithm, attachmentId: "p", key: "pk"),
            "a rendition is decrypted with the root algorithm and its own id and key"
        )
    }

    func testSDKInfoForAStoredObject() throws {
        let enc = AttachmentEncryption(algorithm: algorithm, attachmentId: attachmentId, key: key)
        let info = try enc.fileEncryptionInfo(ciphertextSize: AttachmentEncryption.ciphertextSize(plaintextSize: 1234))
        XCTAssertEqual(info.format, algorithm)
        XCTAssertEqual(info.data.uniqueId, attachmentId)
        XCTAssertEqual(info.data.key, key)
        XCTAssertEqual(info.data.plainSize, 1234)

        XCTAssertThrowsError(try enc.fileEncryptionInfo(ciphertextSize: 87)) { error in
            guard case .invalidCiphertextSize(87) = error as? AttachmentEncryptionError else {
                return XCTFail("expected invalidCiphertextSize(87), got \(error)")
            }
        }
    }

    func testNewAttachmentIdsAreRandomUnpaddedBase64URL() {
        let ids = (0..<200).map { _ in AttachmentEncryption.newAttachmentId() }
        XCTAssertEqual(Set(ids).count, ids.count)
        let alphabet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        for id in ids {
            XCTAssertEqual(id.count, 22, id)
            XCTAssertTrue(id.unicodeScalars.allSatisfy(alphabet.contains), id)
        }
    }

    // MARK: - Sizes

    func testCiphertextSizeAtTheSegmentBoundaries() {
        let overhead = commitment + header
        XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: 0), overhead + tag, "an empty file is one empty segment")
        XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: 1), overhead + 1 + tag)
        XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: firstSegmentPlaintext), commitment + segment, "a full first segment")
        XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: firstSegmentPlaintext + 1), commitment + segment + 1 + tag, "one byte over opens a second segment")
        let twoFull = firstSegmentPlaintext + segmentPlaintext
        XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: twoFull), commitment + 2 * segment)
        XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: twoFull + 1), commitment + 2 * segment + 1 + tag)
    }

    func testPlaintextSizeInvertsCiphertextSizeAtEveryBoundary() {
        let boundaries: [UInt64] = [
            0, 1, 2,
            firstSegmentPlaintext - 1, firstSegmentPlaintext, firstSegmentPlaintext + 1,
            firstSegmentPlaintext + segmentPlaintext - 1, firstSegmentPlaintext + segmentPlaintext, firstSegmentPlaintext + segmentPlaintext + 1,
            firstSegmentPlaintext + 10 * segmentPlaintext, 1 << 20, 50 << 20, UInt64(UInt32.max)
        ]
        for size in boundaries {
            let stored = AttachmentEncryption.ciphertextSize(plaintextSize: size)
            XCTAssertEqual(AttachmentEncryption.plaintextSize(ciphertextSize: stored), size, "plaintext \(size)")
        }
    }

    func testSizesNoFileEncryptsToHaveNoPlaintextSize() {
        let minimum = commitment + header + tag
        for size in [0, 1, minimum - 1] {
            XCTAssertNil(AttachmentEncryption.plaintextSize(ciphertextSize: size), "below the minimum: \(size)")
        }
        XCTAssertEqual(AttachmentEncryption.plaintextSize(ciphertextSize: minimum), 0, "the minimum is the empty file")
        // A second segment that has started but cannot even hold its tag.
        for extra in 1...tag {
            XCTAssertNil(AttachmentEncryption.plaintextSize(ciphertextSize: commitment + segment + extra), "\(extra) byte(s) of a second segment")
        }
        XCTAssertEqual(AttachmentEncryption.plaintextSize(ciphertextSize: commitment + segment + tag + 1), firstSegmentPlaintext + 1)
    }

    // MARK: - Metadata

    func testEncryptionIsReadOnlyFromAMetadataObject() throws {
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: nil))
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: ""))
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: "not json"))
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: #"[{"enc":{}}]"#))
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: #"{"tmb":"x"}"#))
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: try metadata(enc: "a string")), "enc must be an object")
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: try metadata(enc: ["v": 1])), "an incomplete enc")
        XCTAssertEqual(ChatMessage.Attachment.encryption(inMetadata: try metadata(enc: validObject))?.key, key)
    }

    func testAnyEncMakesTheAttachmentEncryptedEvenWhenUnreadable() throws {
        XCTAssertFalse(makeAttachment().isEncrypted)
        XCTAssertFalse(makeAttachment(metadata: "garbage").isEncrypted)
        XCTAssertFalse(makeAttachment(metadata: #"{"tmb":"x"}"#).isEncrypted)
        for enc: Any in ["a string", 1, ["v": 9], validObject] {
            let attachment = makeAttachment(metadata: try metadata(enc: enc))
            XCTAssertTrue(attachment.isEncrypted, "\(enc)")
        }
        XCTAssertNil(makeAttachment(metadata: try metadata(enc: ["v": 9])).encryption)
        XCTAssertNotNil(makeAttachment(metadata: try metadata(enc: validObject)).encryption)
    }

    /// E7: metadata that is not JSON but names `enc` (a truncated write, a bad merge) fails
    /// closed: encrypted and unreadable, never saved as plaintext.
    func testUnparsableMetadataNamingEncIsEncryptedAndUnreadable() {
        let truncated = makeAttachment(metadata: #"{"enc":{"alg":"x","key":"#)
        XCTAssertTrue(truncated.isEncrypted)
        XCTAssertNil(truncated.encryption)
        XCTAssertFalse(makeAttachment(metadata: #"{"tmb":"x""#).isEncrypted, "no enc named: still plain")
    }

    func testSettingEncryptionKeepsTheOtherKeysAndReplacesAnOldEnc() throws {
        let enc = AttachmentEncryption(algorithm: algorithm, attachmentId: attachmentId, key: key)
        let old = try metadata(enc: ["v": 1, "alg": "old", "attachmentId": "old", "key": "old"], extra: ["szw": 3, "tmb": "t"])

        let written = try ChatMessage.Attachment.metadata(old, settingEncryption: enc)

        let object = try object(written)
        XCTAssertEqual(object["szw"] as? Int, 3)
        XCTAssertEqual(object["tmb"] as? String, "t")
        XCTAssertEqual(ChatMessage.Attachment.encryption(inMetadata: written), enc)
    }

    func testSettingEncryptionOnNoMetadataMakesAnObject() throws {
        let enc = AttachmentEncryption(algorithm: algorithm, attachmentId: attachmentId, key: key)
        for metadata in [nil, ""] as [String?] {
            let written = try ChatMessage.Attachment.metadata(metadata, settingEncryption: enc)
            XCTAssertEqual(Set(try object(written).keys), ["enc"])
            XCTAssertEqual(ChatMessage.Attachment.encryption(inMetadata: written), enc)
        }
    }

    func testSettingEncryptionOnMetadataThatIsNotAnObjectThrows() {
        let enc = AttachmentEncryption(algorithm: algorithm, attachmentId: attachmentId, key: key)
        for metadata in ["not json", "[1,2]", "\"string\"", "42"] {
            XCTAssertThrowsError(try ChatMessage.Attachment.metadata(metadata, settingEncryption: enc), metadata) { error in
                guard case .metadataNotAnObject = error as? AttachmentEncryptionError else {
                    return XCTFail("\(metadata): expected metadataNotAnObject, got \(error)")
                }
            }
        }
    }

    func testPreservingEncryption() throws {
        let enc = try metadata(enc: validObject, extra: ["szw": 1])
        let rebuilt = #"{"szw":2,"tmb":"y"}"#

        // Nothing to carry over.
        XCTAssertEqual(ChatMessage.Attachment.metadata(rebuilt, preservingEncryptionFrom: nil), rebuilt)
        XCTAssertEqual(ChatMessage.Attachment.metadata(rebuilt, preservingEncryptionFrom: "not json"), rebuilt)
        XCTAssertNil(ChatMessage.Attachment.metadata(nil, preservingEncryptionFrom: #"{"tmb":"x"}"#))

        // Carried into the rebuilt metadata, which keeps its own keys.
        let merged = try object(ChatMessage.Attachment.metadata(rebuilt, preservingEncryptionFrom: enc))
        XCTAssertEqual(merged["szw"] as? Int, 2)
        XCTAssertEqual(merged["tmb"] as? String, "y")
        XCTAssertNotNil(merged["enc"])

        // Into no metadata, or metadata that isn't an object: enc alone.
        XCTAssertEqual(Set(try object(ChatMessage.Attachment.metadata(nil, preservingEncryptionFrom: enc)).keys), ["enc"])
        XCTAssertEqual(Set(try object(ChatMessage.Attachment.metadata("garbage", preservingEncryptionFrom: enc)).keys), ["enc"])

        // A new metadata with its own enc keeps it.
        let newer = try metadata(enc: ["v": 1, "alg": algorithm, "attachmentId": "newer", "key": "k2"])
        XCTAssertEqual(ChatMessage.Attachment.metadata(newer, preservingEncryptionFrom: enc), newer)

        // An unreadable enc is carried as is: it must never disappear.
        let unreadable = try metadata(enc: "opaque")
        let carried = ChatMessage.Attachment.metadata(rebuilt, preservingEncryptionFrom: unreadable)
        XCTAssertEqual(try object(carried)["enc"] as? String, "opaque")
    }

    // MARK: - Key provider

    func testInlineKeyProviderPolicy() {
        let message = ChatMessage(id: 1, channelId: 1, attachments: [], user: ChatUser(id: "u"))
        XCTAssertEqual(InlineAttachmentKeyProvider().requirement(for: makeAttachment(), in: message), .none, "ships with encryption off")

        var asked = [String]()
        let required = InlineAttachmentKeyProvider { attachment, _ in
            asked.append(attachment.type)
            return .required
        }
        XCTAssertEqual(required.requirement(for: makeAttachment(type: "image"), in: message), .required)
        XCTAssertEqual(required.requirement(for: makeAttachment(type: "link"), in: message), .none, "a link has no file to encrypt")
        XCTAssertEqual(asked, ["image"], "the policy is not even asked about a link")
    }
}

// MARK: - Coverage: the random source and the metadata writer's seams

extension AttachmentEncryptionInfoTests {

    func testANewAttachmentIdStillComesWhenTheRandomSourceFails() {
        let id = AttachmentEncryption.newAttachmentId(randomBytes: { _ in errSecAllocate })

        XCTAssertFalse(id.isEmpty, "the SDK makes one")
    }

    func testEncThatCannotBeWrittenAsUTF8Throws() {
        let noText = MetadataJSON(serialize: MetadataJSON.live.serialize, string: { _ in nil })

        XCTAssertThrowsError(try ChatMessage.Attachment.metadata(nil, settingEncryption: AttachmentEncryption(algorithm: "a", attachmentId: "b", key: "c"), json: noText)) {
            guard case .metadataNotAnObject = $0 as? AttachmentEncryptionError else { return XCTFail("\($0)") }
        }
    }

    func testEncThatCannotBeCarriedOverLeavesTheNewMetadata() throws {
        let old = try ChatMessage.Attachment.metadata(nil, settingEncryption: AttachmentEncryption(algorithm: "a", attachmentId: "b", key: "c"))
        let failing = MetadataJSON(serialize: { _ in throw CocoaError(.coderInvalidValue) }, string: MetadataJSON.live.string)

        XCTAssertEqual(ChatMessage.Attachment.metadata(#"{"tmb":"x"}"#, preservingEncryptionFrom: old, json: failing), #"{"tmb":"x"}"#)
    }
}
