//
//  AtomicLostUpdateTests.swift
//  SceytChatUIKitTests
//
//  `@Atomic` only makes a single get or a single set atomic.
//  `holder.value[k] = v` through the wrapper is three steps:
//    1. get   – lock, copy the whole value, unlock
//    2. change the copy (no lock held)
//    3. set   – lock, write the whole copy back, unlock
//  A write by another thread between 1 and 3 is silently overwritten by step 3.
//
//  These tests assert what a thread-safe property MUST do, so they FAIL while
//  the bug exists and pass once `Atomic` is fixed.
//
//  The deterministic tests pause thread T1 inside step 2 (via a hook in the
//  stored value's mutating setter), let T2 write, then resume T1. A correct
//  implementation either makes T2 wait, or ends in a state some serial order of
//  T1 and T2 would produce. The `_throughMutate_` tests do the same writes via
//  `mutate` (one locked block) and pass today.
//

import XCTest
@testable import SceytChatUIKit

final class AtomicLostUpdateTests: XCTestCase {

    // MARK: - Helpers

    /// Pauses the first thread that reaches `hit()`; every later caller passes through.
    final class Gate {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var armed = true

        func hit() {
            lock.lock()
            let shouldPause = armed
            armed = false
            lock.unlock()
            guard shouldPause else { return }
            entered.signal()
            _ = release.wait(timeout: .now() + 10)
        }
    }

    /// A dictionary whose subscript setter calls a hook, so a test can pause a
    /// thread while it is mutating its copy.
    struct HookedDictionary<Key: Hashable, Value> {
        var storage: [Key: Value]
        var gate: Gate?

        subscript(key: Key) -> Value? {
            get { storage[key] }
            set {
                gate?.hit()
                storage[key] = newValue
            }
        }
    }

    /// A set whose `insert` calls a hook.
    struct HookedSet<Element: Hashable> {
        var storage: Set<Element>
        var gate: Gate?

        mutating func insert(_ element: Element) {
            gate?.hit()
            storage.insert(element)
        }

        mutating func remove(_ element: Element) {
            storage.remove(element)
        }
    }

    /// Mirrors how `AttachmentTransfer` declares its state.
    final class Holder<T> {
        @Atomic var value: T

        init(_ value: T) {
            self.value = value
        }

        /// Read-modify-write inside one locked block.
        func mutate(_ changes: (inout T) -> Void) {
            _value.mutate(changes)
        }
    }

    private func runAsync(_ work: @escaping () -> Void) -> DispatchSemaphore {
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            work()
            done.signal()
        }
        return done
    }

    /// Runs `t1` until it pauses mid-write, runs `t2`, then lets `t1` finish.
    /// Returns whether `t2` was able to complete while `t1` was mid-write.
    private func interleave(
        gate: Gate,
        t1: @escaping () -> Void,
        t2: @escaping () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let t1Done = runAsync(t1)
        XCTAssertEqual(gate.entered.wait(timeout: .now() + 5), .success,
                       "T1 never reached its change step", file: file, line: line)
        let t2Done = runAsync(t2)
        let t2RanDuringT1 = t2Done.wait(timeout: .now() + 0.5) == .success
        gate.release.signal()
        XCTAssertEqual(t1Done.wait(timeout: .now() + 5), .success, file: file, line: line)
        if !t2RanDuringT1 {
            XCTAssertEqual(t2Done.wait(timeout: .now() + 5), .success, file: file, line: line)
        }
        return t2RanDuringT1
    }

    // MARK: - taskGroups: a finished task must not come back

    /// Mirrors `AttachmentTransfer.swift:461` racing `didEndTask` (`:948`).
    /// Start: message 42 has one running task "A".
    /// T1 (tasksQueue): taskGroups[42] = (taskGroups[42] ?? []) + ["B"]   // start B
    /// T2 (transfer thread): A ended → taskGroups[42] = nil
    /// Valid results: T1→T2 = nil, T2→T1 = ["B"]. A must never come back.
    func testTaskGroups_finishedTaskIsNotResurrected() {
        let gate = Gate()
        let holder = Holder(HookedDictionary<Int64, [String]>(storage: [42: ["A"]], gate: gate))

        let t2RanDuringT1 = interleave(
            gate: gate,
            t1: { holder.value[42] = (holder.value[42] ?? []) + ["B"] },
            t2: { holder.value[42] = nil }
        )

        XCTAssertFalse(t2RanDuringT1,
                       "T2 wrote while T1 was between its read and its write-back: the lock is not held across the update")
        let result = holder.value.storage[42]
        XCTAssertTrue(result == nil || result == ["B"],
                      "taskGroups[42] is \(String(describing: result)). Finished task A came back, so the next download of A is skipped as 'already running'")
    }

    func testTaskGroups_throughMutate_finishedTaskIsNotResurrected() {
        let gate = Gate()
        let holder = Holder(HookedDictionary<Int64, [String]>(storage: [42: ["A"]], gate: gate))

        let t2RanDuringT1 = interleave(
            gate: gate,
            t1: { holder.mutate { $0[42] = ($0[42] ?? []) + ["B"] } },
            t2: { holder.mutate { $0[42] = nil } }
        )

        XCTAssertFalse(t2RanDuringT1)
        XCTAssertNil(holder.value.storage[42])
    }

    // MARK: - progressCache: a cleared percent must stay cleared

    /// Mirrors `progressCache[X] = progress` (`:758`) racing
    /// `progressCache[Y] = nil` (`:907`) when transfer Y ends.
    func testProgressCache_clearedPercentStaysCleared() {
        let gate = Gate()
        let holder = Holder(HookedDictionary<String, Double>(storage: ["Y": 0.97], gate: gate))

        _ = interleave(
            gate: gate,
            t1: { holder.value["X"] = 0.40 },   // progress chunk for X
            t2: { holder.value["Y"] = nil }     // Y finished
        )

        XCTAssertNil(holder.value.storage["Y"],
                     "Y's percent is \(String(describing: holder.value.storage["Y"])) after Y ended. Its ring would freeze there on the next bind")
        XCTAssertEqual(holder.value.storage["X"], 0.40)
    }

    // MARK: - inFlightVideoThumbOrigins: a finished poster must leave the set

    /// Mirrors `inFlightVideoThumbOrigins.insert(P2)` (`:702`) racing
    /// `.remove(P1)` (`:705`) when P1's download ends. Valid result: {P2}.
    func testInFlightSet_finishedPosterIsRemoved() {
        let gate = Gate()
        let holder = Holder(HookedSet<String>(storage: ["P1"], gate: gate))

        _ = interleave(
            gate: gate,
            t1: { holder.value.insert("P2") },
            t2: { holder.value.remove("P1") }
        )

        XCTAssertEqual(holder.value.storage, ["P2"],
                       "P1 is still 'in flight' after it finished, so `!contains(origin)` skips its poster forever")
    }

    // MARK: - Same race with no hooks: real Dictionary, real threads

    /// 8 threads each insert 2,000 distinct keys. Every write is independent,
    /// so a thread-safe property ends with all 16,000 keys.
    func testConcurrentInserts_throughWrapper_keepEveryWrite() {
        let threads = 8
        let perThread = 2_000
        let holder = Holder([Int: Int]())

        DispatchQueue.concurrentPerform(iterations: threads) { t in
            for i in 0..<perThread {
                let key = t * perThread + i
                holder.value[key] = key
            }
        }

        XCTAssertEqual(holder.value.count, threads * perThread,
                       "Lost \(threads * perThread - holder.value.count) of \(threads * perThread) writes through `holder.value[k] = v`")
    }

    func testConcurrentInserts_throughMutate_keepEveryWrite() {
        let threads = 8
        let perThread = 2_000
        let holder = Holder([Int: Int]())

        DispatchQueue.concurrentPerform(iterations: threads) { t in
            for i in 0..<perThread {
                let key = t * perThread + i
                holder.mutate { $0[key] = key }
            }
        }

        XCTAssertEqual(holder.value.count, threads * perThread)
    }
}
