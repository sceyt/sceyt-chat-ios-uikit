//
//  TransferFailureStatusTests.swift
//  SceytChatUIKitTests
//
//  What a failed download turns into, and what a poster download answered with an HTTP error
//  leaves behind.
//

import XCTest
@testable import SceytChatUIKit

final class TransferFailureStatusTests: XCTestCase {

    // MARK: - Download status after a failure

    func testAConnectivityFailureIsPendingSoTheNextBindRetriesIt() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut] {
            XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: URLError(code)), .pending, "\(code)")
        }
    }

    func testAConnectivityFailureWrappedByATransportIsPending() {
        let wrapped = NSError(domain: "transport", code: 1, userInfo: [NSUnderlyingErrorKey: URLError(.notConnectedToInternet)])
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: wrapped), .pending)
    }

    func testAnInterruptionIsPending() {
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: URLError(.cancelled), interrupted: true), .pending)
    }

    func testAUserCancelIsPausedNotFailed() {
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: URLError(.cancelled)), .pauseDownloading)
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: NSError(domain: "x", code: 1), userCancelled: true), .pauseDownloading)
    }

    func testARefusalFails() {
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: NSError(domain: "http", code: 404)), .failedDownloading)
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: AttachmentTransferError.missingURL), .failedDownloading)
        XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: nil), .failedDownloading)
    }

    // MARK: - Failure categories

    func testFailureCategories() {
        XCTAssertEqual(TransferFailureCategory.of(nil), .none)
        XCTAssertEqual(TransferFailureCategory.of(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(TransferFailureCategory.of(CancellationError()), .cancelled)
        XCTAssertEqual(TransferFailureCategory.of(URLError(.notConnectedToInternet)), .connectivity)
        XCTAssertEqual(TransferFailureCategory.of(URLError(.badServerResponse)), .refusal)
        XCTAssertEqual(TransferFailureCategory.of(AttachmentEncryptionError.encryptionBypassed), .integrity)
        XCTAssertEqual(TransferFailureCategory.of(TransportDataSessionError.missingSourceFile), .storage)
        XCTAssertEqual(TransferFailureCategory.of(CocoaError(.fileWriteOutOfSpace)), .storage)
        XCTAssertEqual(TransferFailureCategory.of(AttachmentTransferError.missingURL), .refusal)
        XCTAssertEqual(TransferFailureCategory.of(NSError(domain: "x", code: 1)), .unknown)
    }

    // MARK: - Decryption files left behind

    func testOnlyOldDecryptionFilesOfTheDestinationAreRemoved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("photo.jpg")
        func make(_ name: String, age: TimeInterval) throws -> URL {
            let file = folder.appendingPathComponent(name)
            try Data("x".utf8).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: file.path)
            return file
        }
        let old = try make(".\(UUID().uuidString)-photo.jpg", age: 3600)
        let young = try make(".\(UUID().uuidString)-photo.jpg", age: 5)
        let otherFile = try make(".\(UUID().uuidString)-other.jpg", age: 3600)
        let unrelated = try make(".hidden-photo.jpg", age: 3600)

        TransferDirectories.removeStaleDecryptionFiles(for: destination, tag: "test")

        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path), "left behind by a crash")
        XCTAssertTrue(FileManager.default.fileExists(atPath: young.path), "may belong to a publish still running")
        XCTAssertTrue(FileManager.default.fileExists(atPath: otherFile.path), "another destination's")
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path), "not a decryption file")
    }

    // MARK: - Poster download

    func testAPosterAnsweredWithAnHTTPErrorFailsAndCachesNothing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let body = directory.appendingPathComponent("body")
        try Data("<Error>AccessDenied</Error>".utf8).write(to: body)

        let posters = directory.appendingPathComponent("posters", isDirectory: true)
        try FileManager.default.createDirectory(at: posters, withIntermediateDirectories: true)
        var transfer = DefaultThumbnailTransfer()
        transfer.posterDirectory = { posters }
        transfer.startDownload = { url, completion in
            completion(body, HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil), nil)
        }

        let done = expectation(description: "poster")
        var result: Result<URL, Error>?
        transfer.download(origin: "https://cdn.example/poster.jpg") {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        guard case .failure = result else { return XCTFail("an error body is not a poster: \(String(describing: result))") }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: posters.path).isEmpty, "nothing cached as the poster")
    }
}
