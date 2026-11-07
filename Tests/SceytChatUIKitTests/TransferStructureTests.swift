//
//  TransferStructureTests.swift
//  SceytChatUIKitTests
//
//  The pieces the transfer layer is built from: a session's pluggable file store, the
//  callback bridge posters use, and owned unstructured work.
//

@testable import SceytChatUIKit
import XCTest

final class TransferStructureTests: XCTestCase {

    private final class RecordingStore: AttachmentFileStore, @unchecked Sendable {
        let calls = Locked([String]())

        func store(fileAt path: String, transferId: String, fileName: String?) -> String {
            calls.mutate { $0.append("store \(path) \(transferId) \(fileName ?? "-")") }
            return "/stored/\(transferId)"
        }

        func remove(fileAt path: String) {
            calls.mutate { $0.append("remove \(path)") }
        }

        func updateThumbnailPath(transferId: String, filePath: String) {
            calls.mutate { $0.append("thumbnails \(transferId) \(filePath)") }
        }
    }

    // MARK: File store

    func testASessionStoresThroughItsFileStore() {
        let session = TransportDataSession(provider: DefaultFileTransferProvider())
        let store = RecordingStore()
        session.fileStore = store

        XCTAssertEqual(session.storeFile(atPath: "/staged/a.jpg", transferId: "T1", fileName: "a.jpg"), "/stored/T1")
        session.updateThumbnailPath(transferId: "T1", filePath: "/stored/T1")
        session.removeFile(atPath: "/old/a.jpg")

        XCTAssertEqual(store.calls.wrapped, [
            "store /staged/a.jpg T1 a.jpg",
            "thumbnails T1 /stored/T1",
            "remove /old/a.jpg",
        ])
    }

    func testAnSDKSessionStoresInItsOwnFileStorage() {
        let session = SCTSession()
        XCTAssertTrue(session.fileStore as AnyObject === session.fileStorage)
    }

    // MARK: Callback bridge

    func testTheBridgeReturnsWhatTheCallbackGives() async {
        let value = await VideoPosterTransfer.awaitCallback(cancelled: -1) { done in
            DispatchQueue.global().async { done(7) }
        }
        XCTAssertEqual(value, 7)
    }

    func testTheBridgeTakesACallbackMadeBeforeItWaits() async {
        let value = await VideoPosterTransfer.awaitCallback(cancelled: -1) { done in done(3) }
        XCTAssertEqual(value, 3)
    }

    /// Cancelled, it returns at once with `cancelled`; the callback that comes later is dropped.
    func testACancelledBridgeReturnsAtOnceAndDropsTheLateCallback() async {
        let late = Locked<((Int) -> Void)?>(nil)
        let task = Task {
            await VideoPosterTransfer.awaitCallback(cancelled: -1) { done in late.wrapped = done }
        }
        while late.wrapped == nil { await Task.yield() }
        task.cancel()
        let value = await task.value
        XCTAssertEqual(value, -1)
        late.wrapped?(9)
    }

    // MARK: Owned work

    func testABagWaitsForItsWork() async {
        let bag = TaskBag()
        let done = Locked(0)
        for _ in 0..<3 {
            bag.run {
                try? await Task.sleep(nanoseconds: 20_000_000)
                done.mutate { $0 += 1 }
            }
        }
        await bag.waitAll()
        XCTAssertEqual(done.wrapped, 3)
    }

    func testABagCancelsItsWork() async {
        let bag = TaskBag()
        let cancelled = Locked(false)
        let started = Locked(false)
        bag.run {
            started.wrapped = true
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            cancelled.wrapped = Task.isCancelled
        }
        while !started.wrapped { await Task.yield() }
        bag.cancelAll()
        await bag.waitAll()
        XCTAssertTrue(cancelled.wrapped)
    }
}
