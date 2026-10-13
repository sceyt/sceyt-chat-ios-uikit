//
//  SessionDownloadStatusTests.swift
//  SceytChatUIKitTests
//
//  Created by Vahagn Manasyan on 05.10.26.
//
//  `Session.download` handed back a 404's body as the downloaded file. `SCTSession` then stored
//  that error page as the attachment, and the reconcile read the file on disk as a finished
//  download, so it was never fetched again.
//

@testable import SceytChatUIKit
import XCTest

final class SessionDownloadStatusTests: XCTestCase {

    /// Answers requests to `stub.example` with `statusCode` and an S3-style error body.
    private final class StubProtocol: URLProtocol {
        nonisolated(unsafe) static var statusCode = 200

        override class func canInit(with request: URLRequest) -> Bool {
            request.url?.host == "stub.example"
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: Self.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
            else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("<Error><Code>NoSuchKey</Code></Error>".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubProtocol.self)
        StubProtocol.statusCode = 200
        super.tearDown()
    }

    private func download() throws -> Result<URL, Error> {
        let done = expectation(description: "download finished")
        var result: Result<URL, Error>?
        Session.download(url: try XCTUnwrap(URL(string: "https://stub.example/files/IMG_1590.jpg")), completion: {
            result = $0
            done.fulfill()
        })
        wait(for: [done], timeout: 5)
        return try XCTUnwrap(result)
    }

    func testErrorStatusIsAFailureNotAFile() throws {
        StubProtocol.statusCode = 404

        guard case .failure = try download() else {
            return XCTFail("a 404 body must not be handed back as the downloaded file")
        }
    }

    /// Guard: a 2xx still delivers the file.
    func testSuccessStatusStillDeliversTheFile() throws {
        StubProtocol.statusCode = 200

        guard case .success = try download() else {
            return XCTFail("a 200 must still deliver the file")
        }
    }
}
