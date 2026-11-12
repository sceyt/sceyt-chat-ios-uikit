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

    func testAFullDiskFailsAndIsRecognizedThroughWrappers() {
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        let wrapped = NSError(domain: "transport", code: 1, userInfo: [NSUnderlyingErrorKey: posix])
        for error: Error in [CocoaError(.fileWriteOutOfSpace), posix, wrapped, StorageSpace.outOfSpaceError(needed: 2, available: 1)] {
            XCTAssertTrue(StorageSpace.isFull(error), "\(error)")
            XCTAssertEqual(AttachmentTransfer.downloadStatus(afterFailure: error), .failedDownloading, "\(error)")
        }
        XCTAssertFalse(StorageSpace.isFull(nil))
        XCTAssertFalse(StorageSpace.isFull(CocoaError(.fileNoSuchFile)))
        XCTAssertFalse(StorageSpace.isFull(URLError(.notConnectedToInternet)))
    }

    func testOnlyAKnownSizeOverAKnownCapacityCannotFit() {
        XCTAssertTrue(StorageSpace.cannotFit(10, available: 9))
        XCTAssertFalse(StorageSpace.cannotFit(10, available: 10))
        XCTAssertFalse(StorageSpace.cannotFit(10, available: nil))
        XCTAssertFalse(StorageSpace.cannotFit(0, available: 0))
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
        XCTAssertEqual(TransferFailureCategory.of(NSError(domain: "com.sceyt.chat.fileencryption", code: 5)), .integrity)
        XCTAssertEqual(TransferFailureCategory.of(TransportDataSessionError.missingSourceFile), .storage)
        XCTAssertEqual(TransferFailureCategory.of(CocoaError(.fileWriteOutOfSpace)), .storage)
        XCTAssertEqual(TransferFailureCategory.of(AttachmentTransferError.missingURL), .refusal)
        XCTAssertEqual(TransferFailureCategory.of(NSError(domain: "x", code: 1)), .unknown)
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
