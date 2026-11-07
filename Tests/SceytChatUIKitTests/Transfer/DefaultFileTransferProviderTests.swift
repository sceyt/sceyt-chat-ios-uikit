//
//  DefaultFileTransferProviderTests.swift
//  SceytChatUIKitTests
//
//  `DefaultFileTransferProvider`, the Chat SDK's own transfers: plain uploads (the SDK
//  client's upload call is replaced in-process, nothing reaches a server), downloads served
//  by a URL protocol stub, publishing into the destination,
//  and the one-invocation rules of pause, resume, cancel and task cancellation. Also the
//  `SCTSession` and `SCTDataSession` parts the transport split introduced: the default
//  session's storage and the video-poster transfers.
//

@testable import SceytChatUIKit
import ObjectiveC
import SceytChat
import UIKit
import XCTest

// MARK: - Fakes

/// Replaces `ChatClient.upload(fileUrl:…)` with a handler the test drives, and
/// `UploadOperation.cancel` with a counter.
private enum FakeClient {
    typealias Progress = (Double) -> Void
    typealias PlainCompletion = (URL?, SceytError?) -> Void

    struct PlainCall {
        let file: URL
        let progress: Progress
        let completion: PlainCompletion
    }

    private static let lock = NSLock()
    private static var _plain = [PlainCall]()
    private static var _cancels = 0
    private static var originals = [(Method, IMP)]()
    /// Called on every plain upload, e.g. to answer at once.
    static var onPlain: (PlainCall) -> Void = { _ in }

    static var plain: [PlainCall] { lock.lock(); defer { lock.unlock() }; return _plain }
    static var cancels: Int { lock.lock(); defer { lock.unlock() }; return _cancels }

    static func install() {
        lock.lock()
        _plain = []
        _cancels = 0
        lock.unlock()
        onPlain = { _ in }

        let plain: @convention(block) (AnyObject, NSURL, @escaping Progress, @escaping PlainCompletion) -> Void = { _, file, progress, completion in
            let call = PlainCall(file: file as URL, progress: progress, completion: completion)
            lock.lock(); _plain.append(call); lock.unlock()
            onPlain(call)
        }
        let cancel: @convention(block) (AnyObject) -> Void = { _ in
            lock.lock(); _cancels += 1; lock.unlock()
        }
        replace(ChatClient.self, "uploadFile:progressHandler:completion:", with: plain)
        replace(UploadOperation.self, "cancel", with: cancel)
    }

    static func uninstall() {
        for (method, imp) in originals {
            method_setImplementation(method, imp)
        }
        originals = []
    }

    private static func replace(_ cls: AnyClass, _ selector: String, with block: Any) {
        guard let method = class_getInstanceMethod(cls, NSSelectorFromString(selector)) else {
            return XCTFail("\(cls) has no \(selector)")
        }
        originals.append((method, method_setImplementation(method, imp_implementationWithBlock(block))))
    }
}

/// Serves `https://transport.stub/<path>`: the registered body with its status, nothing at all
/// for `/hold`, and a transport error for `/error`.
private final class StubServer: URLProtocol {
    private static let lock = NSLock()
    private static var bodies = [String: (Int, Data)]()
    private static var _headers = [String: [String: String]]()
    static var delay: TimeInterval = 0

    /// The headers of the last request for each path.
    static func headers(_ path: String) -> [String: String]? {
        lock.lock(); defer { lock.unlock() }
        return _headers[path]
    }

    static func serve(_ path: String, status: Int = 200, body: Data) {
        lock.lock(); bodies[path] = (status, body); lock.unlock()
    }

    static func reset() {
        lock.lock(); bodies = [:]; _headers = [:]; lock.unlock()
        delay = 0
    }

    static func url(_ path: String) -> String { "https://transport.stub\(path)" }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "transport.stub"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.lock(); Self._headers[url.path] = request.allHTTPHeaderFields ?? [:]; Self.lock.unlock()
        switch url.path {
        case "/hold":
            return
        case "/error":
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        default:
            break
        }
        Self.lock.lock()
        let (status, body) = Self.bodies[url.path] ?? (404, Data())
        Self.lock.unlock()
        let respond = { [weak self] in
            guard let self,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": "\(body.count)"])
            else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: body)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if Self.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay, execute: respond)
        } else {
            respond()
        }
    }

    override func stopLoading() {}
}

/// Collects progress from any thread.
private final class ProgressLog {
    private let lock = NSLock()
    private var _values = [Double]()
    var values: [Double] { lock.lock(); defer { lock.unlock() }; return _values }
    func record(_ value: Double) { lock.lock(); _values.append(value); lock.unlock() }
}

/// The outcome of a call made in a `Task`.
private final class Outcome<T> {
    private let lock = NSLock()
    private var _value: T?
    var value: T? { lock.lock(); defer { lock.unlock() }; return _value }
    func set(_ value: T) { lock.lock(); _value = value; lock.unlock() }
}

private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        RunLoop.main.run(until: Date().addingTimeInterval(0.005))
    }
    XCTAssertTrue(condition(), "timed out", file: file, line: line)
}

private func settle(_ seconds: TimeInterval = 0.15) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

// MARK: - DefaultFileTransferProvider

final class DefaultFileTransferProviderTests: XCTestCase {

    private var transport: DefaultFileTransferProvider!
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        FakeClient.install()
        URLProtocol.registerClass(StubServer.self)
        StubServer.reset()
        transport = DefaultFileTransferProvider()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("default-transport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        FakeClient.uninstall()
        URLProtocol.unregisterClass(StubServer.self)
        StubServer.reset()
        try? FileManager.default.removeItem(at: directory)
        transport = nil
        try super.tearDownWithError()
    }

    // MARK: Fixtures

    private func file(size: Int = 100) throws -> URL {
        let url = directory.appendingPathComponent("plain-\(UUID().uuidString).bin")
        try Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 11) }).write(to: url)
        return url
    }

    private func uploadRequest(operationId: String = "upload-1", file: URL? = nil) throws -> FileUploadRequest {
        FileUploadRequest(operationId: operationId, sourceFile: try file ?? self.file(), fileName: "a.bin", mimeType: nil)
    }

    /// Starts `upload` in a task; returns its outcome, its progress and the task.
    @discardableResult
    private func startUpload(_ request: FileUploadRequest, on transport: DefaultFileTransferProvider? = nil) -> (Outcome<FileTransferResult<FileUploadResult>>, ProgressLog, Task<Void, Never>) {
        let outcome = Outcome<FileTransferResult<FileUploadResult>>()
        let progress = ProgressLog()
        let transport = transport ?? self.transport!
        let task = Task {
            outcome.set(await transport.upload(request) { progress.record($0) })
        }
        return (outcome, progress, task)
    }

    @discardableResult
    private func startDownload(_ request: FileDownloadRequest) -> (Outcome<FileTransferResult<URL>>, ProgressLog, Task<Void, Never>) {
        let outcome = Outcome<FileTransferResult<URL>>()
        let progress = ProgressLog()
        let task = Task { [transport] in
            outcome.set(await transport!.download(request) { progress.record($0) })
        }
        return (outcome, progress, task)
    }

    private func destination(_ name: String = "file.bin") -> URL {
        directory.appendingPathComponent("downloads/nested/\(name)")
    }

    private func reference(_ result: FileTransferResult<FileUploadResult>?) -> String? {
        if case .success(let uploaded) = result { return uploaded.url }
        return nil
    }

    private func error<T>(_ result: FileTransferResult<T>?) -> Error? {
        if case .failure(let error) = result { return error }
        return nil
    }

    private func interruption<T>(_ result: FileTransferResult<T>?) -> Error? {
        if case .interrupted(let error) = result { return error }
        return nil
    }

    // MARK: - Plain upload

    func testPlainUploadForwardsProgressAndReturnsTheURL() throws {
        let request = try uploadRequest()
        FakeClient.onPlain = { call in
            call.progress(0.3)
            call.progress(1)
            call.completion(URL(string: "https://cdn.example/a.bin"), nil)
        }

        let (outcome, progress, _) = startUpload(request)
        waitUntil { outcome.value != nil }

        XCTAssertEqual(FakeClient.plain.first?.file, request.sourceFile)
        XCTAssertEqual(reference(outcome.value), "https://cdn.example/a.bin")
        XCTAssertEqual(progress.values, [0.3, 1])
    }

    func testPlainUploadFailures() throws {
        let sdkError = SceytError(domain: "sceyt", code: 7, userInfo: nil)
        for (url, error) in [(nil, sdkError), (URL(string: "https://cdn.example/x"), sdkError), (nil, nil)] as [(URL?, SceytError?)] {
            FakeClient.onPlain = { $0.completion(url, error) }
            let (outcome, _, _) = startUpload(try uploadRequest())
            waitUntil { outcome.value != nil }
            let failure = self.error(outcome.value)
            if let error {
                XCTAssertEqual((failure as NSError?)?.code, error.code)
            } else {
                guard case .invalidRequest = failure as? FileTransferError else { return XCTFail("\(String(describing: failure))") }
            }
        }
    }

    func testAPausedUploadHoldsItsResultAndProgressUntilResumed() throws {
        let (outcome, progress, _) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 1 }
        let call = try XCTUnwrap(FakeClient.plain.first)
        call.progress(0.2)

        XCTAssertTrue(transport.pause(operationId: "upload-1"))
        call.progress(0.5)
        call.completion(URL(string: "https://cdn.example/a"), nil)
        settle()
        XCTAssertNil(outcome.value, "a paused upload is not delivered")
        XCTAssertEqual(progress.values, [0.2], "no progress while paused")

        XCTAssertTrue(transport.resume(operationId: "upload-1"))
        waitUntil { outcome.value != nil }
        XCTAssertEqual(reference(outcome.value), "https://cdn.example/a")
        XCTAssertFalse(transport.pause(operationId: "upload-1"), "the invocation is over")
        XCTAssertFalse(transport.resume(operationId: "upload-1"))
    }

    func testAResumeWithNothingHeldKeepsTheUploadRunning() throws {
        let (outcome, progress, _) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 1 }
        let call = try XCTUnwrap(FakeClient.plain.first)

        XCTAssertTrue(transport.pause(operationId: "upload-1"))
        XCTAssertTrue(transport.resume(operationId: "upload-1"))
        call.progress(0.6)
        call.completion(URL(string: "https://cdn.example/b"), nil)

        waitUntil { outcome.value != nil }
        XCTAssertEqual(progress.values, [0.6])
        XCTAssertEqual(reference(outcome.value), "https://cdn.example/b")
    }

    func testASecondResultWhilePausedEndsTheUpload() throws {
        let (outcome, _, _) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 1 }
        let call = try XCTUnwrap(FakeClient.plain.first)

        XCTAssertTrue(transport.pause(operationId: "upload-1"))
        call.completion(URL(string: "https://cdn.example/first"), nil)
        call.completion(nil, nil)

        waitUntil { outcome.value != nil }
        XCTAssertNotNil(error(outcome.value), "only one result can be held")
    }

    func testCancelEndsAPlainUploadAtOnceAndIgnoresItsLateResult() throws {
        let (outcome, progress, _) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 1 }

        transport.cancel(operationId: "upload-1")
        transport.cancel(operationId: "upload-1")
        transport.cancel(operationId: "unknown")
        waitUntil { outcome.value != nil }

        guard case .cancelled = error(outcome.value) as? FileTransferError else {
            return XCTFail("expected cancelled, got \(String(describing: outcome.value))")
        }
        FakeClient.plain.first?.progress(0.9)
        FakeClient.plain.first?.completion(URL(string: "https://cdn.example/late"), nil)
        XCTAssertTrue(progress.values.isEmpty)
    }

    func testTaskCancellationInterruptsAnUpload() throws {
        let (outcome, _, task) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 1 }

        task.cancel()
        waitUntil { outcome.value != nil }

        XCTAssertTrue(interruption(outcome.value) is CancellationError)
    }

    func testAnUploadOfAnAlreadyCancelledTaskEndsAtOnce() throws {
        let request = try uploadRequest()
        let outcome = Outcome<FileTransferResult<FileUploadResult>>()
        Task { [transport] in
            withUnsafeCurrentTask { $0?.cancel() }
            outcome.set(await transport!.upload(request) { _ in })
        }

        waitUntil { outcome.value != nil }
        XCTAssertTrue(interruption(outcome.value) is CancellationError)
    }

    func testAnInvocationThatEndedCannotBePausedOrResumed() throws {
        let request = try uploadRequest()
        let outcome = Outcome<FileTransferResult<FileUploadResult>>()
        var controls = [Bool]()
        FakeClient.onPlain = { [transport] _ in
            // Still registered, but already over: the task was cancelled before it began.
            controls = [transport!.pause(operationId: "upload-1"), transport!.resume(operationId: "upload-1")]
        }
        Task { [transport] in
            withUnsafeCurrentTask { $0?.cancel() }
            outcome.set(await transport!.upload(request) { _ in })
        }

        waitUntil { outcome.value != nil }
        XCTAssertEqual(controls, [false, false])
    }

    func testControlsOfAnUnknownOperation() {
        XCTAssertFalse(transport.pause(operationId: "nothing"))
        XCTAssertFalse(transport.resume(operationId: "nothing"))
        transport.cancel(operationId: "nothing")
    }

    /// A second invocation of an operation still running is rejected: the two would share
    /// one record, and a cancel could reach only one of them.
    func testARepeatedOperationIdIsRejectedWhileTheFirstRuns() throws {
        let (first, _, _) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 1 }
        let (second, _, _) = startUpload(try uploadRequest())
        waitUntil { second.value != nil }

        guard case .duplicateOperation = error(second.value) as? FileTransferError else {
            return XCTFail("expected duplicateOperation, got \(String(describing: second.value))")
        }
        XCTAssertEqual(FakeClient.plain.count, 1, "nothing was sent for the duplicate")

        transport.cancel(operationId: "upload-1")
        waitUntil { first.value != nil }
        guard case .cancelled = error(first.value) as? FileTransferError else {
            return XCTFail("the cancel reaches the running invocation")
        }

        // Once it ended, the operation can run again.
        let (third, _, _) = startUpload(try uploadRequest())
        waitUntil { FakeClient.plain.count == 2 }
        FakeClient.plain[1].completion(URL(string: "https://cdn.example/3"), nil)
        waitUntil { third.value != nil }
        XCTAssertEqual(reference(third.value), "https://cdn.example/3")
    }

    // MARK: - Download

    func testADownloadOfAnUnusableReferenceFailsAtOnce() async {
        let result = await transport.download(FileDownloadRequest(operationId: "d", url: "", destinationFile: destination())) { _ in }
        guard case .invalidRequest = error(result) as? FileTransferError else { return XCTFail("\(result)") }
    }

    func testPlainDownloadIsPublishedAtTheDestination() throws {
        let body = Data((0..<50_000).map { UInt8(truncatingIfNeeded: $0) })
        StubServer.serve("/plain", body: body)
        let request = FileDownloadRequest(operationId: "download-1", url: StubServer.url("/plain"), destinationFile: destination())

        let (outcome, progress, _) = startDownload(request)
        waitUntil { outcome.value != nil }

        guard case .success(let url) = outcome.value else { return XCTFail("\(String(describing: outcome.value))") }
        XCTAssertEqual(url, request.destinationFile)
        XCTAssertEqual(try Data(contentsOf: url), body)
        XCTAssertTrue(progress.values.allSatisfy { (0...1).contains($0) })
    }

    func testADownloadReplacesAnOlderFile() throws {
        StubServer.serve("/new", body: Data("new".utf8))
        let destination = destination()
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: destination)

        let (outcome, _, _) = startDownload(FileDownloadRequest(operationId: "d", url: StubServer.url("/new"), destinationFile: destination))
        waitUntil { outcome.value != nil }

        XCTAssertEqual(try Data(contentsOf: destination), Data("new".utf8))
    }

    /// A refused request fails; a lost connection interrupts (what arrived can be continued).
    /// Neither leaves a file at the destination.
    func testARefusalFailsAndALostConnectionInterrupts() throws {
        StubServer.serve("/missing", status: 404, body: Data("<Error/>".utf8))
        let missing = destination("missing.bin")
        let (refused, _, _) = startDownload(FileDownloadRequest(operationId: "/missing", url: StubServer.url("/missing"), destinationFile: missing))
        waitUntil { refused.value != nil }
        XCTAssertNotNil(error(refused.value))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))

        let lost = destination("error.bin")
        let (interrupted, _, _) = startDownload(FileDownloadRequest(operationId: "/error", url: StubServer.url("/error"), destinationFile: lost))
        waitUntil { interrupted.value != nil }
        XCTAssertNotNil(interruption(interrupted.value), "not connected: an interruption")
        XCTAssertFalse(FileManager.default.fileExists(atPath: lost.path))
    }


    func testTheRequestHeadersAreSent() async throws {
        StubServer.serve("/headers", body: Data("x".utf8))
        let result = await transport.download(
            FileDownloadRequest(operationId: "d", url: StubServer.url("/headers"), destinationFile: destination(), headers: ["X-Chat-Token": "t", "X-Message-Id": "42"])
        ) { _ in }

        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(StubServer.headers("/headers")?["X-Chat-Token"], "t")
        XCTAssertEqual(StubServer.headers("/headers")?["X-Message-Id"], "42")
    }

    func testPublishReplacesAnOlderFile() throws {
        let staging = try file(size: 500)
        let bytes = try Data(contentsOf: staging)
        let destination = destination()
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: destination)

        try DefaultFileTransferProvider.publish(staging, to: FileDownloadRequest(operationId: "d", url: "u", destinationFile: destination))

        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
    }

    func testPublishFailsWhenTheDestinationFolderCannotBeMade() throws {
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let staging = try file()
        do {
            try DefaultFileTransferProvider.publish(
                staging,
                to: FileDownloadRequest(operationId: "d", url: "u", destinationFile: blocker.appendingPathComponent("x/file"))
            )
            XCTFail("a file is in the way")
        } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path), "the downloaded file is not left behind")
    }

    func testCancelEndsADownloadAtOnce() throws {
        let (outcome, _, _) = startDownload(FileDownloadRequest(operationId: "download-1", url: StubServer.url("/hold"), destinationFile: destination()))
        settle()

        transport.cancel(operationId: "download-1")
        waitUntil { outcome.value != nil }

        guard case .cancelled = error(outcome.value) as? FileTransferError else { return XCTFail("\(String(describing: outcome.value))") }
    }

    func testTaskCancellationInterruptsADownload() throws {
        let (outcome, _, task) = startDownload(FileDownloadRequest(operationId: "download-1", url: StubServer.url("/hold"), destinationFile: destination()))
        settle()

        task.cancel()
        waitUntil { outcome.value != nil }

        XCTAssertTrue(interruption(outcome.value) is CancellationError)
    }

    func testADownloadPausesAndResumesInPlace() throws {
        StubServer.serve("/slow", body: Data("slow".utf8))
        StubServer.delay = 0.3
        let destination = destination()
        let (outcome, _, _) = startDownload(FileDownloadRequest(operationId: "download-1", url: StubServer.url("/slow"), destinationFile: destination))
        settle(0.05)

        XCTAssertTrue(transport.pause(operationId: "download-1"))
        XCTAssertTrue(transport.resume(operationId: "download-1"))
        waitUntil { outcome.value != nil }

        guard case .success = outcome.value else { return XCTFail("\(String(describing: outcome.value))") }
        XCTAssertEqual(try Data(contentsOf: destination), Data("slow".utf8))
    }
}

// MARK: - Coverage: the download's own failure paths

extension DefaultFileTransferProviderTests {

    func testARepeatedDownloadOperationIdIsRejectedWhileTheFirstRuns() throws {
        let request = FileDownloadRequest(operationId: "same", url: StubServer.url("/hold"), destinationFile: destination())
        let (first, _, _) = startDownload(request)
        settle()
        let (second, _, _) = startDownload(request)
        waitUntil { second.value != nil }

        guard case .duplicateOperation = error(second.value) as? FileTransferError else { return XCTFail("\(String(describing: second.value))") }
        transport.cancel(operationId: "same")
        waitUntil { first.value != nil }
    }

    func testADownloadThatCannotLeaveTheSessionsTempLocationFails() throws {
        transport.downloadStagingDirectory = { self.directory.appendingPathComponent("no/such/folder") }
        StubServer.serve("/moved", body: Data("x".utf8))

        let (outcome, _, _) = startDownload(FileDownloadRequest(operationId: "d", url: StubServer.url("/moved"), destinationFile: destination()))
        waitUntil { outcome.value != nil }

        XCTAssertNotNil(error(outcome.value))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination().path))
    }

    func testADownloadWithoutAURLSessionTaskStillCompletes() throws {
        transport.startDownload = { _, _, completion in
            let file = self.directory.appendingPathComponent("task-file-\(UUID().uuidString)")
            try? Data("body".utf8).write(to: file)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { completion(.success(file)) }
            return nil
        }

        let (outcome, _, _) = startDownload(FileDownloadRequest(operationId: "d", url: StubServer.url("/none"), destinationFile: destination()))
        waitUntil { outcome.value != nil }

        XCTAssertEqual(try Data(contentsOf: destination()), Data("body".utf8))
        XCTAssertFalse(transport.pause(operationId: "d"), "nothing to pause once over")
    }

    func testAPlainPublishThatCannotMoveTheFileFails() throws {
        let missing = directory.appendingPathComponent("never-downloaded")
        do {
            try DefaultFileTransferProvider.publish(missing, to: FileDownloadRequest(operationId: "d", url: "u", destinationFile: destination()))
            XCTFail("nothing to publish")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination().path))
        }
    }
}

// MARK: - SCTSession and SCTDataSession

final class SCTSessionTransportTests: XCTestCase {

    /// A data session that keeps every default of `SCTDataSession`.
    private final class MinimalSession: NSObject, SCTDataSession {
        func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {}
        func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {}
        func getFilePath(attachment: ChatMessage.Attachment) -> String? { nil }
        func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? { nil }
    }

    private final class NullTransport: FileTransferProvider {
        func upload(_ request: FileUploadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<FileUploadResult> {
            .failure(FileTransferError.invalidRequest)
        }
        func download(_ request: FileDownloadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<URL> {
            .failure(FileTransferError.invalidRequest)
        }
        func cancel(operationId: String) {}
    }

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        FakeClient.install()
        URLProtocol.registerClass(StubServer.self)
        StubServer.reset()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sct-session-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        FakeClient.uninstall()
        URLProtocol.unregisterClass(StubServer.self)
        StubServer.reset()
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func makeAttachment(name: String? = "a.pdf", url: String? = nil, filePath: String? = nil) -> ChatMessage.Attachment {
        .init(id: 0, tid: 1, messageId: 1, userId: "u", url: url, filePath: filePath, type: "file", name: name, metadata: nil, uploadedFileSize: 0, createdAt: Date())
    }

    private func thumbnailUpload(_ session: SCTDataSession) -> Result<String, Error>? {
        let outcome = Outcome<Result<String, Error>>()
        session.uploadAttachmentThumbnail(for: makeAttachment(), fileUrl: directory.appendingPathComponent("poster.jpg")) { outcome.set($0) }
        waitUntil { outcome.value != nil }
        return outcome.value
    }

    private func posterDownload(_ transfer: DefaultThumbnailTransfer, origin: String) -> Result<URL, Error>? {
        let outcome = Outcome<Result<URL, Error>>()
        transfer.download(origin: origin) { outcome.set($0) }
        waitUntil { outcome.value != nil }
        return outcome.value
    }

    private func thumbnailDownload(_ session: SCTDataSession, origin: String) -> Result<URL, Error>? {
        let outcome = Outcome<Result<URL, Error>>()
        session.downloadAttachmentThumbnail(for: makeAttachment(), origin: origin) { outcome.set($0) }
        waitUntil { outcome.value != nil }
        return outcome.value
    }

    // MARK: SCTSession

    func testTheDefaultSessionUsesTheSDKTransport() {
        XCTAssertTrue(SCTSession().provider is DefaultFileTransferProvider)
        let transport = NullTransport()
        XCTAssertTrue(SCTSession(provider: transport).provider === transport)
    }

    func testTheDefaultSessionStoresInItsFileStorage() throws {
        let session = SCTSession(provider: NullTransport())
        let source = directory.appendingPathComponent("source.bin")
        try Data([1, 2, 3]).write(to: source)
        let transferId = UUID().uuidString

        let stored = session.storeFile(atPath: source.path, transferId: transferId, fileName: "stored.bin")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: stored)), Data([1, 2, 3]))
        XCTAssertTrue(stored.contains(transferId))
        session.updateThumbnailPath(transferId: transferId, filePath: stored)
        XCTAssertEqual(session.getFilePath(attachment: makeAttachment(filePath: stored)), stored)

        session.removeFile(atPath: stored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stored))
    }

    func testTheDefaultSessionDownloadsIntoItsFileStorage() throws {
        let session = SCTSession(provider: NullTransport())
        XCTAssertNil(session.downloadDestination(for: makeAttachment(url: nil)))
        let destination = try XCTUnwrap(session.downloadDestination(for: makeAttachment(name: "b.pdf", url: "https://cdn.example/TID-9/b.pdf")))
        XCTAssertTrue(destination.path.contains("TID-9"))
        XCTAssertEqual(destination.lastPathComponent, "b.pdf")
    }

    func testTheDefaultSessionHasNoThumbnailWithoutAFile() {
        XCTAssertNil(SCTSession(provider: NullTransport()).thumbnailFile(for: makeAttachment(), preferred: CGSize(width: 20, height: 20)))
    }

    // MARK: SCTDataSession defaults


    func testATransportThatCannotPauseSaysSo() {
        let transport = NullTransport()
        XCTAssertFalse(transport.pause(operationId: "any"), "UIKit then stops the attempt and starts another")
        XCTAssertFalse(transport.resume(operationId: "any"))
    }

    func testPosterUploadThroughTheSDK() {
        for session: SCTDataSession in [MinimalSession(), SCTSession(provider: NullTransport())] {
            FakeClient.onPlain = {
                $0.progress(0.5)
                $0.completion(URL(string: "https://cdn.example/poster.jpg"), nil)
            }
            guard case .success(let origin) = thumbnailUpload(session) else { return XCTFail("\(session)") }
            XCTAssertEqual(origin, "https://cdn.example/poster.jpg")

            let sdkError = SceytError(domain: "sceyt", code: 3, userInfo: nil)
            FakeClient.onPlain = { $0.completion(nil, sdkError) }
            guard case .failure(let error) = thumbnailUpload(session) else { return XCTFail("\(session)") }
            XCTAssertEqual((error as NSError).code, 3)

            FakeClient.onPlain = { $0.completion(nil, nil) }
            guard case .failure(SCTDataSessionError.thumbnailUploadFailed) = thumbnailUpload(session) else { return XCTFail("\(session)") }
        }
    }

    func testPosterDownloadOnlyFollowsHTTP() throws {
        StubServer.serve("/poster.jpg", body: Data("jpeg".utf8))
        for session: SCTDataSession in [MinimalSession(), SCTSession(provider: NullTransport())] {
            for origin in ["", "b9d80ec3-e1e9-442f-db3a-df545cad86bb", "file:///etc/hosts", "ftp://cdn.example/a.jpg"] {
                guard case .failure(SCTDataSessionError.unsupportedThumbnailOrigin) = thumbnailDownload(session, origin: origin) else {
                    return XCTFail("\(origin) must not be fetched")
                }
            }
            guard case .success(let local) = thumbnailDownload(session, origin: StubServer.url("/poster.jpg")) else { return XCTFail("\(session)") }
            XCTAssertEqual(try Data(contentsOf: local), Data("jpeg".utf8))
            XCTAssertEqual(local.pathExtension, "jpg")
            try? FileManager.default.removeItem(at: local)

            guard case .failure = thumbnailDownload(session, origin: StubServer.url("/error")) else { return XCTFail("\(session)") }
        }
    }

    // MARK: Coverage: SCTSession lookups and thumbnails

    func testTheDefaultSessionFindsAFileByItsURL() throws {
        let session = SCTSession(provider: NullTransport())
        let transferId = "TID-\(UUID().uuidString)"
        let source = directory.appendingPathComponent("source.bin")
        try Data([1]).write(to: source)
        let stored = session.storeFile(atPath: source.path, transferId: transferId, fileName: "c.pdf")
        defer { session.removeFile(atPath: stored) }

        XCTAssertEqual(session.getFilePath(attachment: makeAttachment(name: "c.pdf", url: "https://cdn.example/\(transferId)/c.pdf")), stored)
        XCTAssertNil(session.getFilePath(attachment: makeAttachment(filePath: directory.appendingPathComponent("gone").path)))
    }

    private func png(_ name: String = "image.png") throws -> URL {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let url = directory.appendingPathComponent(name)
        try XCTUnwrap(image.pngData()).write(to: url)
        return url
    }

    private func attachment(type: String, filePath: String) -> ChatMessage.Attachment {
        .init(id: 0, tid: 1, messageId: 1, userId: "u", url: nil, filePath: filePath, type: type, name: nil, metadata: nil, uploadedFileSize: 0, createdAt: Date())
    }

    func testThumbnailsOfImagesVideosAndFiles() throws {
        FrameProcessor.frame = UIImage(contentsOfFile: try png("frame.png").path)
        let session = SCTSession(provider: NullTransport())
        session.environment.videoProcessor = { FrameProcessor.self }
        let size = CGSize(width: 10, height: 10)
        let image = try png()
        let video = directory.appendingPathComponent("clip.mp4")
        try Data([0]).write(to: video)
        let fileVideo = directory.appendingPathComponent("other.mov")
        try Data([0]).write(to: fileVideo)

        for item in [attachment(type: "image", filePath: image.path),
                     attachment(type: "video", filePath: video.path),
                     attachment(type: "file", filePath: try png("doc.png").path),
                     attachment(type: "file", filePath: fileVideo.path)] {
            let made = try XCTUnwrap(session.thumbnailFile(for: item, preferred: size), item.type)
            XCTAssertTrue(SCTSession.isCompleteImageFile(at: made))
            XCTAssertEqual(session.thumbnailFile(for: item, preferred: size), made, "the cached one")
            // A broken cached thumbnail is evicted and made again.
            try Data("broken".utf8).write(to: URL(fileURLWithPath: made))
            XCTAssertEqual(session.thumbnailFile(for: item, preferred: size), made)
            XCTAssertTrue(SCTSession.isCompleteImageFile(at: made))
            try? FileManager.default.removeItem(atPath: made)
        }
        // A file of another kind has no thumbnail.
        let text = directory.appendingPathComponent("notes.txt")
        try Data("t".utf8).write(to: text)
        XCTAssertNil(session.thumbnailFile(for: attachment(type: "file", filePath: text.path), preferred: size))
        XCTAssertNil(session.thumbnailFile(for: attachment(type: "voice", filePath: text.path), preferred: size))
        // A file the session cannot find: tried from its own path, nothing is made.
        XCTAssertNil(session.thumbnailFile(for: attachment(type: "image", filePath: directory.appendingPathComponent("gone.png").path), preferred: size))
    }

    func testAThumbnailThatCannotBeStoredAtomicallyFallsBack() throws {
        let blocked = directory.appendingPathComponent("blocked")
        try Data("a file, not a folder".utf8).write(to: blocked)
        BlockedStorage.thumbnailRoot = blocked.appendingPathComponent("thumbs")
        let storage = BlockedStorage()
        let session = SCTSession(provider: NullTransport(), fileStorage: storage)

        XCTAssertNil(session.thumbnailFile(for: attachment(type: "image", filePath: try png().path), preferred: CGSize(width: 10, height: 10)),
                     "neither the atomic write nor the fallback can store it")
    }

    // MARK: Coverage: posters and task events

    func testAPosterAnsweredWithAnErrorStatusFails() throws {
        StubServer.serve("/404.jpg", status: 404, body: Data("<Error/>".utf8))
        guard case .failure(SCTDataSessionError.thumbnailDownloadFailed) = thumbnailDownload(MinimalSession(), origin: StubServer.url("/404.jpg")) else {
            return XCTFail("an error body cached as the poster would never be fetched again")
        }
    }

    func testAPosterThatCannotLeaveTheTempLocationFails() throws {
        var transfer = DefaultThumbnailTransfer()
        transfer.posterDirectory = { self.directory.appendingPathComponent("no/such") }
        StubServer.serve("/p.jpg", body: Data("jpeg".utf8))
        guard case .failure = posterDownload(transfer, origin: StubServer.url("/p.jpg")) else { return XCTFail() }
    }

    func testAPosterDownloadWithNeitherAFileNorAnErrorFails() {
        var transfer = DefaultThumbnailTransfer()
        transfer.startDownload = { _, completion in completion(nil, nil, nil) }
        guard case .failure(SCTDataSessionError.thumbnailDownloadFailed) = posterDownload(transfer, origin: "https://cdn.example/p.jpg") else { return XCTFail() }
    }

    func testNoThumbnailForAnAttachmentThatIsNotOnDisk() {
        XCTAssertNil(SCTSession(provider: NullTransport()).thumbnailFile(for: makeAttachment(url: "https://cdn.example/TID-\(UUID().uuidString)/a.pdf"), preferred: CGSize(width: 10, height: 10)))
    }

    func testTaskEventsAfterTheEndOrBeforeTheHooks() throws {
        let attachment = makeAttachment()
        let message = ChatMessage(id: 1, channelId: 1, attachments: [attachment], user: ChatUser(id: "u"))
        let url = try XCTUnwrap(URL(string: "https://cdn.example/x"))
        weak var released: SCTDataSessionTaskInfo?
        do {
            let task = SCTDataSessionTaskInfo(transferType: .upload, message: message, attachment: attachment)
            released = task
            // No hooks yet: logged as lost.
            task.updateProgress(0.5)
            task.success(origin: url)
            XCTAssertEqual(attachment.url, url.absoluteString)
            XCTAssertTrue(task.isTransferFinished, "a success by URL is delivered too")
            // After the end: logged, and a pause or resume is ignored.
            task.failure(error: URLError(.timedOut))
            task.success(origin: "again")
            task.updateProgress(0.9)
            let failed = SCTDataSessionTaskInfo(transferType: .download, message: message, attachment: attachment)
            failed.onEvent = { _ in }
            failed.failure(error: nil)
            failed.updateProgress(0.1)

            let delivered = SCTDataSessionTaskInfo(transferType: .download, message: message, attachment: attachment)
            delivered.success(origin: url)
            attachment.status = .done
            delivered.stop()
            delivered.resume()
            XCTAssertEqual(attachment.status, .done, "nothing to pause or resume once delivered")
        }
        XCTAssertNil(released, "a task is freed once nothing holds it")
    }
}

/// A video processor that returns a fixed frame.
private final class FrameProcessor: VideoProcessor {
    static var frame: UIImage?
    override class func copyFrame(url: URL, at time: TimeInterval = 1) -> UIImage? { frame }
}

/// Storage whose thumbnails go under a path that cannot be a folder.
private final class BlockedStorage: FileStorage {
    static var thumbnailRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    override func thumbnailPath(filePath: String, imageSize: CGSize) -> String {
        Self.thumbnailRoot.appendingPathComponent((filePath as NSString).lastPathComponent).path
    }
}

// MARK: - Resume data (an interrupted download continues instead of starting over)

final class DownloadResumeTests: XCTestCase {
    private var directory: URL!

    private var savedResumeDirectory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("resume-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        savedResumeDirectory = DefaultFileTransferProvider.resumeDirectory
        DefaultFileTransferProvider.resumeDirectory = directory.appendingPathComponent("resume-data", isDirectory: true)
        try FileManager.default.createDirectory(at: DefaultFileTransferProvider.resumeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        DefaultFileTransferProvider.resumeDirectory = savedResumeDirectory
        try? FileManager.default.removeItem(at: directory)
    }

    func testStaleResumeDataIsPurgedAndRecentKept() throws {
        let stale = DefaultFileTransferProvider.resumeDataFile(operationId: "old")
        let recent = DefaultFileTransferProvider.resumeDataFile(operationId: "new")
        try Data("a".utf8).write(to: stale)
        try Data("b".utf8).write(to: recent)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-DefaultFileTransferProvider.staleResumeAge - 60)], ofItemAtPath: stale.path)
        DefaultFileTransferProvider.purgeStaleResumeData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }

    func testResumeDataIsKeptOutOfTheAttachmentFolder() {
        let file = DefaultFileTransferProvider.resumeDataFile(operationId: "download-tid1")
        XCTAssertEqual(file.deletingLastPathComponent(), DefaultFileTransferProvider.resumeDirectory)
        XCTAssertFalse(file.lastPathComponent.contains("download-tid1"), "named by a hash, not the id")
    }

    func testSavedResumeDataIsTakenOnce() {
        let resume = DownloadResume(file: directory.appendingPathComponent("a.resume"), tag: "t")
        XCTAssertNil(resume.take())
        resume.save(Data("r".utf8))
        XCTAssertEqual(resume.take(), Data("r".utf8))
        XCTAssertNil(resume.take(), "used once")
        resume.save(nil)
        resume.save(Data())
        XCTAssertNil(resume.take(), "nothing to keep")
    }

    func testAnAbandonedDownloadKeepsNoResumeData() {
        let file = directory.appendingPathComponent("a.resume")
        let resume = DownloadResume(file: file, tag: "t")
        resume.save(Data("r".utf8))
        resume.abandon()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        resume.save(Data("late".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "a stop that lands after the cancel keeps nothing")
    }

    /// The next attempt continues from the saved resume data, and it is used up.
    func testTheNextAttemptContinuesFromTheSavedResumeData() async throws {
        let transport = DefaultFileTransferProvider()
        let destination = directory.appendingPathComponent("files/a.bin")
        let resumeFile = DefaultFileTransferProvider.resumeDataFile(operationId: "d")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("resume-data".utf8).write(to: resumeFile)
        let body = directory.appendingPathComponent("body")
        try Data("whole file".utf8).write(to: body)
        let used = Locked<Data?>(nil)
        transport.startResumedDownload = { data, _, completion in
            used.wrapped = data
            completion(.success(body))
            return nil
        }
        transport.startDownload = { _, _, _ in
            XCTFail("not started over")
            return nil
        }
        let result = await transport.download(FileDownloadRequest(operationId: "d", url: "https://files.example/a.bin", destinationFile: destination)) { _ in }
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(used.wrapped, Data("resume-data".utf8))
        XCTAssertEqual(try Data(contentsOf: destination), Data("whole file".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resumeFile.path))
    }

    /// A network failure leaves its resume data for the next attempt.
    func testANetworkFailureKeepsItsResumeData() async throws {
        let transport = DefaultFileTransferProvider()
        let destination = directory.appendingPathComponent("files/a.bin")
        transport.startDownload = { _, _, completion in
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: [NSURLSessionDownloadTaskResumeData: Data("partial".utf8)])))
            return nil
        }
        let result = await transport.download(FileDownloadRequest(operationId: "d", url: "https://files.example/a.bin", destinationFile: destination)) { _ in }
        guard case .interrupted = result else { return XCTFail("a lost network is an interruption, got \(result)") }
        XCTAssertEqual(try Data(contentsOf: DefaultFileTransferProvider.resumeDataFile(operationId: "d")), Data("partial".utf8))
    }

    /// Resume data the server no longer accepts (expired url, changed object): fetched again
    /// from the start, with the request as it is now.
    func testRefusedResumeDataFallsBackToAFreshDownload() async throws {
        let transport = DefaultFileTransferProvider()
        let destination = directory.appendingPathComponent("files/a.bin")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: DefaultFileTransferProvider.resumeDataFile(operationId: "d"))
        let body = directory.appendingPathComponent("body")
        try Data("fresh".utf8).write(to: body)
        transport.startResumedDownload = { _, _, completion in
            completion(.failure(URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP 403"])))
            return nil
        }
        let fresh = Locked<[URLRequest]>([])
        transport.startDownload = { request, _, completion in
            fresh.wrapped.append(request)
            completion(.success(body))
            return nil
        }
        let result = await transport.download(FileDownloadRequest(operationId: "d", url: "https://files.example/a.bin", destinationFile: destination, headers: ["X-Token": "new"])) { _ in }
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(fresh.wrapped.first?.value(forHTTPHeaderField: "X-Token"), "new", "the current request, not the saved one")
        XCTAssertEqual(try Data(contentsOf: destination), Data("fresh".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: DefaultFileTransferProvider.resumeDataFile(operationId: "d").path))
    }

    /// A completed download keeps no resume data, even one a stop saved just before.
    func testACompletedDownloadLeavesNoResumeData() async throws {
        let transport = DefaultFileTransferProvider()
        let destination = directory.appendingPathComponent("files/a.bin")
        let body = directory.appendingPathComponent("body")
        try Data("whole".utf8).write(to: body)
        transport.startDownload = { _, _, completion in
            completion(.success(body))
            return nil
        }
        _ = await transport.download(FileDownloadRequest(operationId: "d", url: "https://files.example/a.bin", destinationFile: destination)) { _ in }
        XCTAssertFalse(FileManager.default.fileExists(atPath: DefaultFileTransferProvider.resumeDataFile(operationId: "d").path))
    }

    func testOnlyAConnectionLossCountsAsNetworkLoss() {
        XCTAssertTrue(DefaultFileTransferProvider.isNetworkLoss(URLError(.networkConnectionLost)))
        XCTAssertTrue(DefaultFileTransferProvider.isNetworkLoss(URLError(.timedOut)))
        XCTAssertFalse(DefaultFileTransferProvider.isNetworkLoss(URLError(.badServerResponse)))
        XCTAssertFalse(DefaultFileTransferProvider.isNetworkLoss(URLError(.cancelled)))
        XCTAssertFalse(DefaultFileTransferProvider.isNetworkLoss(CocoaError(.fileWriteOutOfSpace)))
    }
}
