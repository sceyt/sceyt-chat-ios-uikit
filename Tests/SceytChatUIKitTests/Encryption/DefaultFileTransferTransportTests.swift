//
//  DefaultFileTransferTransportTests.swift
//  SceytChatUIKitTests
//
//  `DefaultFileTransferTransport`, the Chat SDK's own transfers: plain and encrypted uploads
//  (the SDK client's two upload calls are replaced in-process, nothing reaches a server),
//  downloads served by a URL protocol stub, publishing and decryption into the destination,
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

/// Replaces `ChatClient.upload(fileUrl:…)` and `ChatClient.uploadEncrypted(_:…)` with handlers the
/// test drives, and `UploadOperation.cancel` with a counter.
private enum FakeClient {
    typealias Progress = (Double) -> Void
    typealias PlainCompletion = (URL?, SceytError?) -> Void
    typealias EncryptedCompletion = (URL?, FileEncryptionInfo?, SceytError?) -> Void

    struct PlainCall {
        let file: URL
        let progress: Progress
        let completion: PlainCompletion
    }

    struct EncryptedCall {
        let upload: PreparedUpload
        let progress: Progress
        let completion: EncryptedCompletion
    }

    private static let lock = NSLock()
    private static var _plain = [PlainCall]()
    private static var _encrypted = [EncryptedCall]()
    private static var _cancels = 0
    private static var originals = [(Method, IMP)]()
    /// Called on every plain upload, e.g. to answer at once.
    static var onPlain: (PlainCall) -> Void = { _ in }
    static var onEncrypted: (EncryptedCall) -> Void = { _ in }

    static var plain: [PlainCall] { lock.lock(); defer { lock.unlock() }; return _plain }
    static var encrypted: [EncryptedCall] { lock.lock(); defer { lock.unlock() }; return _encrypted }
    static var cancels: Int { lock.lock(); defer { lock.unlock() }; return _cancels }
    /// The operation `uploadEncrypted` returns; kept alive here.
    static let operation: UploadOperation = class_createInstance(UploadOperation.self, 0) as! UploadOperation

    static func install() {
        lock.lock()
        _plain = []
        _encrypted = []
        _cancels = 0
        lock.unlock()
        onPlain = { _ in }
        onEncrypted = { _ in }

        let plain: @convention(block) (AnyObject, NSURL, @escaping Progress, @escaping PlainCompletion) -> Void = { _, file, progress, completion in
            let call = PlainCall(file: file as URL, progress: progress, completion: completion)
            lock.lock(); _plain.append(call); lock.unlock()
            onPlain(call)
        }
        let encrypted: @convention(block) (AnyObject, PreparedUpload, @escaping Progress, @escaping EncryptedCompletion) -> UploadOperation = { _, upload, progress, completion in
            let call = EncryptedCall(upload: upload, progress: progress, completion: completion)
            lock.lock(); _encrypted.append(call); lock.unlock()
            onEncrypted(call)
            return operation
        }
        let cancel: @convention(block) (AnyObject) -> Void = { _ in
            lock.lock(); _cancels += 1; lock.unlock()
        }
        replace(ChatClient.self, "uploadFile:progressHandler:completion:", with: plain)
        replace(ChatClient.self, "uploadEncrypted:progressHandler:completion:", with: encrypted)
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

/// A `FileEncryption` whose sessions the SDK client did not make.
private final class ForeignEncryption: FileEncryption {
    var prepareError: Error?
    private(set) var session: ForeignSession?

    func prepareEncryption(file: URL) async throws -> FileEncryptionSession {
        if let prepareError { throw prepareError }
        let session = ForeignSession()
        self.session = session
        return session
    }

    func restoreEncryption(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession {
        throw AttachmentEncryptionError.invalidCheckpoint
    }

    func prepareDecryption(encryptedFile: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64) async throws -> FileDecryptionSession {
        throw AttachmentEncryptionError.invalidEncryptionInfo
    }
}

/// The SDK's own encryption, whose `prepareEncryption` can be held until the test lets it finish.
private final class GatedEncryption: FileEncryption {
    private let inner = ChatSDKFileEncryption()
    private let lock = NSLock()
    private var holding: Bool
    private var gate: CheckedContinuation<Void, Never>?
    private var _entered = false
    private var _session: ChatSDKEncryptionSession?

    init(holding: Bool = false) {
        self.holding = holding
    }

    var prepareEntered: Bool { lock.lock(); defer { lock.unlock() }; return _entered }
    /// 1 once the session it made is closed (a closed SDK session refuses reads), else 0.
    var released: Int {
        guard let session else { return 0 }
        return (try? session.read(offset: 0, length: 1)) == nil ? 1 : 0
    }
    var session: ChatSDKEncryptionSession? { lock.lock(); defer { lock.unlock() }; return _session }

    func letPrepareFinish() {
        lock.lock()
        holding = false
        let gate = gate
        self.gate = nil
        lock.unlock()
        gate?.resume()
    }

    func prepareEncryption(file: URL) async throws -> FileEncryptionSession {
        let session = try await inner.prepareEncryption(file: file)
        lock.lock(); _session = session as? ChatSDKEncryptionSession; lock.unlock()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            _entered = true
            if holding {
                gate = continuation
                lock.unlock()
            } else {
                lock.unlock()
                continuation.resume()
            }
        }
        return session
    }

    func restoreEncryption(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession {
        try await inner.restoreEncryption(file: file, checkpoint: checkpoint)
    }

    func prepareDecryption(encryptedFile: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64) async throws -> FileDecryptionSession {
        try await inner.prepareDecryption(encryptedFile: encryptedFile, encryptionInfo: encryptionInfo, plaintextSize: plaintextSize)
    }
}

private final class ForeignSession: FileEncryptionSession {
    let sourceId = "foreign"
    let plaintextSize: Int64 = 1
    let ciphertextSize: Int64 = 1
    let encryptionInfo = EncryptedFileInfo(algorithm: "foreign", attachmentId: "f", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")
    private(set) var closed = false
    func read(offset: Int64, length: Int) throws -> Data { Data(count: length) }
    func checkpoint() -> EncryptedFileCheckpoint { EncryptedFileCheckpoint(encryptionInfo: encryptionInfo, plaintextSize: 1, data: "foreign") }
    func close() { closed = true }
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

// MARK: - DefaultFileTransferTransport

final class DefaultFileTransferTransportTests: XCTestCase {

    private var transport: DefaultFileTransferTransport!
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        FakeClient.install()
        URLProtocol.registerClass(StubServer.self)
        StubServer.reset()
        transport = DefaultFileTransferTransport(encryption: ChatSDKFileEncryption())
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

    private func uploadRequest(_ type: FileUploadType = .plain, operationId: String = "upload-1", file: URL? = nil) throws -> FileUploadRequest {
        FileUploadRequest(operationId: operationId, sourceFile: try file ?? self.file(), fileName: "a.bin", mimeType: nil, type: type)
    }

    /// Starts `upload` in a task; returns its outcome, its progress and the task.
    @discardableResult
    private func startUpload(_ request: FileUploadRequest, on transport: DefaultFileTransferTransport? = nil) -> (Outcome<FileTransferResult<FileUploadResult>>, ProgressLog, Task<Void, Never>) {
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
        if case .success(let uploaded) = outcome.value { XCTAssertNil(uploaded.encryptionInfo) }
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

    // MARK: - Encrypted upload

    func testEncryptedUploadSendsTheSDKSessionAndReturnsItsEncryption() throws {
        let source = try file(size: 3000)
        var ciphertext: Data?
        FakeClient.onEncrypted = { call in
            ciphertext = try? call.upload.readCiphertextRange(offset: 0, length: UInt(call.upload.ciphertextSize))
            call.progress(0.5)
            call.completion(URL(string: "https://cdn.example/enc"), nil, nil)
        }

        let (outcome, progress, _) = startUpload(try uploadRequest(.encrypted, file: source))
        waitUntil { outcome.value != nil }

        guard case .success(let uploaded) = outcome.value, let info = uploaded.encryptionInfo else {
            return XCTFail("expected an encrypted success, got \(String(describing: outcome.value))")
        }
        XCTAssertEqual(uploaded.url, "https://cdn.example/enc")
        XCTAssertEqual(progress.values, [0.5])
        XCTAssertNotNil(ciphertext, "the session is open while the SDK sends it")

        // What was sent decrypts with what was returned.
        let object = directory.appendingPathComponent("object")
        try XCTUnwrap(ciphertext).write(to: object)
        let output = directory.appendingPathComponent("output")
        let done = Outcome<Error?>()
        Task {
            do {
                try await ChatSDKFileEncryption().decrypt(file: object, to: output, encryptionInfo: info, plaintextSize: nil)
                done.set(nil)
            } catch { done.set(error) }
        }
        waitUntil { done.value != nil }
        XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: source))

        // The session is released after the completion.
        XCTAssertThrowsError(try FakeClient.encrypted.first?.upload.readCiphertextRange(offset: 0, length: 1))
    }

    func testEncryptedUploadFailures() throws {
        let sdkError = SceytError(domain: "sceyt", code: 9, userInfo: nil)
        for (url, error) in [(nil, sdkError), (nil, nil)] as [(URL?, SceytError?)] {
            FakeClient.onEncrypted = { $0.completion(url, nil, error) }
            let (outcome, _, _) = startUpload(try uploadRequest(.encrypted))
            waitUntil { outcome.value != nil }
            let failure = self.error(outcome.value)
            if let error {
                XCTAssertEqual((failure as NSError?)?.code, error.code)
            } else {
                guard case .invalidRequest = failure as? FileTransferError else { return XCTFail("\(String(describing: failure))") }
            }
        }
    }

    func testCancelStopsTheSDKOperationOfAnEncryptedUpload() throws {
        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted))
        waitUntil { FakeClient.encrypted.count == 1 }

        transport.cancel(operationId: "upload-1")
        waitUntil { outcome.value != nil }

        guard case .cancelled = error(outcome.value) as? FileTransferError else { return XCTFail("\(String(describing: outcome.value))") }
        XCTAssertEqual(FakeClient.cancels, 1)
    }

    /// Ended before the session was prepared: the SDK is never asked to send it, and the
    /// session is released.
    func testAnEncryptedUploadCancelledBeforeTheSDKStartsSendsNothing() throws {
        let gated = GatedEncryption()
        let transport = DefaultFileTransferTransport(encryption: gated)
        let request = try uploadRequest(.encrypted)
        let outcome = Outcome<FileTransferResult<FileUploadResult>>()
        Task {
            withUnsafeCurrentTask { $0?.cancel() }
            outcome.set(await transport.upload(request) { _ in })
        }

        waitUntil { outcome.value != nil }
        XCTAssertTrue(interruption(outcome.value) is CancellationError)
        waitUntil { gated.released == 1 }
        settle()
        XCTAssertTrue(FakeClient.encrypted.isEmpty, "never sent")
        XCTAssertEqual(FakeClient.cancels, 0, "nothing to stop")
        XCTAssertEqual(gated.released, 1)
        try assertReleased(gated)
    }

    /// Finding #8: a cancel while the session is being prepared. Nothing is sent once
    /// preparation ends, and the session is released.
    func testACancelDuringPrepareStartsNoSDKUploadAndReleasesTheSession() throws {
        let gated = GatedEncryption(holding: true)
        let transport = DefaultFileTransferTransport(encryption: gated)
        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { gated.prepareEntered }

        transport.cancel(operationId: "upload-1")
        waitUntil { outcome.value != nil }
        guard case .cancelled = error(outcome.value) as? FileTransferError else { return XCTFail("\(String(describing: outcome.value))") }

        gated.letPrepareFinish()
        waitUntil { gated.released == 1 }
        settle()
        XCTAssertTrue(FakeClient.encrypted.isEmpty, "uploadEncrypted never starts for an invocation that already ended")
        XCTAssertEqual(gated.released, 1, "released exactly once")
        try assertReleased(gated)
    }

    func testACancelMidUploadReleasesTheSessionOnce() throws {
        let gated = GatedEncryption()
        let transport = DefaultFileTransferTransport(encryption: gated)
        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { FakeClient.encrypted.count == 1 }
        XCTAssertEqual(gated.released, 0, "open while the SDK sends it")

        transport.cancel(operationId: "upload-1")
        waitUntil { outcome.value != nil }

        XCTAssertEqual(FakeClient.cancels, 1)
        XCTAssertEqual(gated.released, 1, "released on cancel: the SDK may never call back")
        try assertReleased(gated)
        // A late completion does not release it again.
        FakeClient.encrypted.first?.completion(URL(string: "https://cdn.example/late"), nil, nil)
        settle()
        XCTAssertEqual(gated.released, 1)
    }

    func testAnInterruptionMidUploadReleasesTheSession() throws {
        let gated = GatedEncryption()
        let transport = DefaultFileTransferTransport(encryption: gated)
        let (outcome, _, task) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { FakeClient.encrypted.count == 1 }

        task.cancel()
        waitUntil { outcome.value != nil }

        XCTAssertTrue(interruption(outcome.value) is CancellationError)
        XCTAssertEqual(FakeClient.cancels, 1)
        XCTAssertEqual(gated.released, 1)
        try assertReleased(gated)
    }

    /// A pause is not an ending: the session stays open (the SDK keeps sending), and the held
    /// result is delivered on resume. It is released by the completion, once.
    func testAPausedEncryptedUploadKeepsItsSessionAndResumes() throws {
        let gated = GatedEncryption()
        let transport = DefaultFileTransferTransport(encryption: gated)
        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { FakeClient.encrypted.count == 1 }

        XCTAssertTrue(transport.pause(operationId: "upload-1"))
        settle()
        XCTAssertEqual(gated.released, 0, "a pause releases nothing")
        XCTAssertNoThrow(try FakeClient.encrypted.first?.upload.readCiphertextRange(offset: 0, length: 1))

        FakeClient.encrypted.first?.completion(URL(string: "https://cdn.example/paused"), nil, nil)
        settle()
        XCTAssertNil(outcome.value, "held while paused")
        XCTAssertEqual(gated.released, 1, "the SDK is done with it")
        XCTAssertTrue(transport.resume(operationId: "upload-1"))
        waitUntil { outcome.value != nil }
        XCTAssertEqual(reference(outcome.value), "https://cdn.example/paused")
        XCTAssertEqual(gated.released, 1)
    }

    private func assertReleased(_ gated: GatedEncryption, file: StaticString = #filePath, line: UInt = #line) throws {
        let session = try XCTUnwrap(gated.session, file: file, line: line)
        XCTAssertThrowsError(try session.read(offset: 0, length: 1), "closed", file: file, line: line)
    }

    func testAPrepareFailureFailsTheEncryptedUpload() throws {
        let foreign = ForeignEncryption()
        foreign.prepareError = CocoaError(.fileNoSuchFile)
        let transport = DefaultFileTransferTransport(encryption: foreign)

        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { outcome.value != nil }

        XCTAssertEqual(error(outcome.value) as? CocoaError, CocoaError(.fileNoSuchFile))
        XCTAssertTrue(FakeClient.encrypted.isEmpty)
    }

    func testASessionTheSDKDidNotMakeIsNeverSent() throws {
        let foreign = ForeignEncryption()
        let transport = DefaultFileTransferTransport(encryption: foreign)

        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { outcome.value != nil }

        guard case .encryptionUnsupportedBySession = error(outcome.value) as? AttachmentEncryptionError else {
            return XCTFail("\(String(describing: outcome.value))")
        }
        XCTAssertTrue(FakeClient.encrypted.isEmpty, "uploadEncrypted raises for a foreign session")
        XCTAssertEqual(foreign.session?.closed, true)
    }

    func testASessionOfAnotherProviderIsNeverSent() throws {
        let transport = DefaultFileTransferTransport(encryption: ChatSDKFileEncryption(provider: { OtherProvider() }))
        let (outcome, _, _) = startUpload(try uploadRequest(.encrypted), on: transport)
        waitUntil { outcome.value != nil }

        guard case .encryptionUnsupportedBySession = error(outcome.value) as? AttachmentEncryptionError else {
            return XCTFail("\(String(describing: outcome.value))")
        }
        XCTAssertTrue(FakeClient.encrypted.isEmpty)
    }

    func testDefaultEncryptionIsTheComponent() {
        XCTAssertTrue(DefaultFileTransferTransport().encryption === Components.fileEncryption)
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

    /// The transport moves bytes only (doc §4): an encrypted object is written as stored, for
    /// UIKit to verify and decrypt.
    func testAnEncryptedObjectIsDownloadedAsStored() async throws {
        let object = directory.appendingPathComponent("object")
        _ = try await ChatSDKFileEncryption().encrypt(file: try file(size: 70_000), to: object)
        StubServer.serve("/enc", body: try Data(contentsOf: object))
        let destination = destination("enc.bin.sceyt.enc.part")

        let result = await transport.download(
            FileDownloadRequest(operationId: "d", url: StubServer.url("/enc"), destinationFile: destination)
        ) { _ in }

        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: object))
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

        try DefaultFileTransferTransport.publish(staging, to: FileDownloadRequest(operationId: "d", url: "u", destinationFile: destination))

        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
    }

    func testPublishFailsWhenTheDestinationFolderCannotBeMade() throws {
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let staging = try file()
        do {
            try DefaultFileTransferTransport.publish(
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

/// Another provider than the SDK's: its sessions cannot go through `uploadEncrypted`.
private final class OtherProvider: NSObject, FileEncryptionProvider {
    let real = StreamingAeadFileEncryptionProvider()

    func prepareUpload(fileURL: URL, uniqueId: String) throws -> PreparedUpload {
        try real.prepareUpload(fileURL: fileURL, uniqueId: uniqueId)
    }

    func restoreUpload(fileURL: URL, checkpoint: FileEncryptionCheckpoint) throws -> PreparedUpload {
        try real.restoreUpload(fileURL: fileURL, checkpoint: checkpoint)
    }

    func openDownload(source: CiphertextRangeSource, encryptionInfo: FileEncryptionInfo) throws -> PlaintextReader {
        try real.openDownload(source: source, encryptionInfo: encryptionInfo)
    }
}

// MARK: - Coverage: the download's own failure paths

extension DefaultFileTransferTransportTests {

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
            try DefaultFileTransferTransport.publish(missing, to: FileDownloadRequest(operationId: "d", url: "u", destinationFile: destination()))
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

    private final class NullTransport: FileTransferTransport {
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
        XCTAssertTrue(SCTSession().transport is DefaultFileTransferTransport)
        let transport = NullTransport()
        XCTAssertTrue(SCTSession(transport: transport).transport === transport)
        XCTAssertTrue(SCTSession.default.supportsAttachmentEncryption)
    }

    func testTheDefaultSessionStoresInItsFileStorage() throws {
        let session = SCTSession(transport: NullTransport())
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
        let session = SCTSession(transport: NullTransport())
        XCTAssertNil(session.downloadDestination(for: makeAttachment(url: nil)))
        let destination = try XCTUnwrap(session.downloadDestination(for: makeAttachment(name: "b.pdf", url: "https://cdn.example/TID-9/b.pdf")))
        XCTAssertTrue(destination.path.contains("TID-9"))
        XCTAssertEqual(destination.lastPathComponent, "b.pdf")
    }

    func testTheDefaultSessionHasNoThumbnailWithoutAFile() {
        XCTAssertNil(SCTSession(transport: NullTransport()).thumbnailFile(for: makeAttachment(), preferred: CGSize(width: 20, height: 20)))
    }

    // MARK: SCTDataSession defaults

    func testADataSessionDoesNotEncryptUnlessItSaysSo() {
        XCTAssertFalse(MinimalSession().supportsAttachmentEncryption)
    }

    func testATransportThatCannotPauseSaysSo() {
        let transport = NullTransport()
        XCTAssertFalse(transport.pause(operationId: "any"), "UIKit then stops the attempt and starts another")
        XCTAssertFalse(transport.resume(operationId: "any"))
    }

    func testPosterUploadThroughTheSDK() {
        for session: SCTDataSession in [MinimalSession(), SCTSession(transport: NullTransport())] {
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
        for session: SCTDataSession in [MinimalSession(), SCTSession(transport: NullTransport())] {
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
        let session = SCTSession(transport: NullTransport())
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
        let session = SCTSession(transport: NullTransport())
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
        let session = SCTSession(transport: NullTransport(), fileStorage: storage)

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
        XCTAssertNil(SCTSession(transport: NullTransport()).thumbnailFile(for: makeAttachment(url: "https://cdn.example/TID-\(UUID().uuidString)/a.pdf"), preferred: CGSize(width: 10, height: 10)))
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
        savedResumeDirectory = DefaultFileTransferTransport.resumeDirectory
        DefaultFileTransferTransport.resumeDirectory = directory.appendingPathComponent("resume-data", isDirectory: true)
        try FileManager.default.createDirectory(at: DefaultFileTransferTransport.resumeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        DefaultFileTransferTransport.resumeDirectory = savedResumeDirectory
        try? FileManager.default.removeItem(at: directory)
    }

    func testStaleResumeDataIsPurgedAndRecentKept() throws {
        let stale = DefaultFileTransferTransport.resumeDataFile(operationId: "old")
        let recent = DefaultFileTransferTransport.resumeDataFile(operationId: "new")
        try Data("a".utf8).write(to: stale)
        try Data("b".utf8).write(to: recent)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-DefaultFileTransferTransport.staleResumeAge - 60)], ofItemAtPath: stale.path)
        DefaultFileTransferTransport.purgeStaleResumeData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }

    func testResumeDataIsKeptOutOfTheAttachmentFolder() {
        let file = DefaultFileTransferTransport.resumeDataFile(operationId: "download-tid1")
        XCTAssertEqual(file.deletingLastPathComponent(), DefaultFileTransferTransport.resumeDirectory)
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
        let transport = DefaultFileTransferTransport(encryption: ChatSDKFileEncryption())
        let destination = directory.appendingPathComponent("files/a.bin")
        let resumeFile = DefaultFileTransferTransport.resumeDataFile(operationId: "d")
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
        let transport = DefaultFileTransferTransport(encryption: ChatSDKFileEncryption())
        let destination = directory.appendingPathComponent("files/a.bin")
        transport.startDownload = { _, _, completion in
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: [NSURLSessionDownloadTaskResumeData: Data("partial".utf8)])))
            return nil
        }
        let result = await transport.download(FileDownloadRequest(operationId: "d", url: "https://files.example/a.bin", destinationFile: destination)) { _ in }
        guard case .interrupted = result else { return XCTFail("a lost network is an interruption, got \(result)") }
        XCTAssertEqual(try Data(contentsOf: DefaultFileTransferTransport.resumeDataFile(operationId: "d")), Data("partial".utf8))
    }

    /// Resume data the server no longer accepts (expired url, changed object): fetched again
    /// from the start, with the request as it is now.
    func testRefusedResumeDataFallsBackToAFreshDownload() async throws {
        let transport = DefaultFileTransferTransport(encryption: ChatSDKFileEncryption())
        let destination = directory.appendingPathComponent("files/a.bin")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: DefaultFileTransferTransport.resumeDataFile(operationId: "d"))
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: DefaultFileTransferTransport.resumeDataFile(operationId: "d").path))
    }

    /// A completed download keeps no resume data, even one a stop saved just before.
    func testACompletedDownloadLeavesNoResumeData() async throws {
        let transport = DefaultFileTransferTransport(encryption: ChatSDKFileEncryption())
        let destination = directory.appendingPathComponent("files/a.bin")
        let body = directory.appendingPathComponent("body")
        try Data("whole".utf8).write(to: body)
        transport.startDownload = { _, _, completion in
            completion(.success(body))
            return nil
        }
        _ = await transport.download(FileDownloadRequest(operationId: "d", url: "https://files.example/a.bin", destinationFile: destination)) { _ in }
        XCTAssertFalse(FileManager.default.fileExists(atPath: DefaultFileTransferTransport.resumeDataFile(operationId: "d").path))
    }

    func testOnlyAConnectionLossCountsAsNetworkLoss() {
        XCTAssertTrue(DefaultFileTransferTransport.isNetworkLoss(URLError(.networkConnectionLost)))
        XCTAssertTrue(DefaultFileTransferTransport.isNetworkLoss(URLError(.timedOut)))
        XCTAssertFalse(DefaultFileTransferTransport.isNetworkLoss(URLError(.badServerResponse)))
        XCTAssertFalse(DefaultFileTransferTransport.isNetworkLoss(URLError(.cancelled)))
        XCTAssertFalse(DefaultFileTransferTransport.isNetworkLoss(CocoaError(.fileWriteOutOfSpace)))
    }
}
