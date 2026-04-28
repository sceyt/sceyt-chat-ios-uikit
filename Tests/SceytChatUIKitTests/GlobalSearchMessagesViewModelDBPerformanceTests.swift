//
//  GlobalSearchMessagesViewModelDBPerformanceTests.swift
//  SceytChatUIKitTests
//
//  Benchmarks the DB-backed GlobalSearchMessagesViewModel under small (1K),
//  medium (10K), large (50K+), xlarge (500K), and xxlarge (1M) message datasets
//  using an in-memory CoreData store. Captures search duration (ms), memory
//  delta (MB), and result count.
//

@testable import SceytChatUIKit
import XCTest
import Combine
import CoreData
import SceytChat
import Darwin

// MARK: - Benchmark Result

private struct BenchmarkResult {
    let testName: String
    let datasetSize: Int
    let matchType: String
    let searchQuery: String
    let durationMs: Double
    let resultCount: Int
    let memoryDeltaMB: Double
}

// MARK: - Performance Test Suite

final class GlobalSearchMessagesViewModelDBPerformanceTests: XCTestCase {

    // MARK: - State

    private var mockDB: MockDatabase!
    private var viewModel: DBTestableGlobalSearchMessagesViewModel!
    private var cancellables: Set<AnyCancellable> = []

    private var directType: String { SceytChatUIKit.shared.config.channelTypesConfig.direct }
    private var groupType: String { SceytChatUIKit.shared.config.channelTypesConfig.group }
    private var broadcastType: String { SceytChatUIKit.shared.config.channelTypesConfig.broadcast }

    // Accumulates results across all tests; printed once in tearDownClass.
    private static var results: [BenchmarkResult] = []

    // MARK: - XCTestCase lifecycle

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        viewModel = DBTestableGlobalSearchMessagesViewModel(mockDB: mockDB)
    }

    override func tearDown() {
        cancellables = []
        viewModel = nil
        mockDB = nil
        super.tearDown()
    }

    override class func tearDown() {
        printSummary()
        results = []
        super.tearDown()
    }

    // MARK: - Memory helper

    private func residentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kern: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kern == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
    }

    // MARK: - Seed helpers

    private func seedChannel(id: ChannelId, type: String, ctx: NSManagedObjectContext) {
        let (ch, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
        ch.type = type
        // Distinct sortingKey per channel to avoid the model's uniqueness
        // constraint trump-merging seeded channels into each other.
        ch.createdAt = Date(timeIntervalSinceReferenceDate: TimeInterval(id)).bridgeDate
    }

    /// Bulk-inserts `count` messages into FTS, and a bounded subset into Core
    /// Data. Per-row Core Data inserts dominate seed time at large scales (the
    /// uniqueness constraint on MessageDTO forces a conflict-resolution pass
    /// per save), so we cap the number of MessageDTO rows that actually get
    /// written via `coreDataLimit`. The FTS sidecar — which is what the
    /// benchmark is actually exercising — is always populated in full so
    /// search timing reflects the real index size.
    ///
    /// The viewModel's search resolves the top-N matching messageIds back to
    /// `MessageDTO` objects to construct ChatMessages. Provided every match
    /// that *can* land in the top page is present in Core Data, the assertions
    /// `resultCount > 0` and the duration-cap still hold.
    ///
    /// `coreDataLimit` is the maximum number of MessageDTOs to insert. We
    /// preferentially seed the latest matching messages (highest `createdAt`),
    /// which are exactly the ones FTS returns first under `ORDER BY createdAt
    /// DESC`. Passing `Int.max` (default for small datasets) seeds everything.
    /// `ctx` is unused but kept for source compatibility with prior call sites.
    private func seedMessages(
        count: Int,
        startId: Int64,
        channelId: ChannelId,
        channelType: String,
        targetWord: String,
        matchRate: Double = 0.10,
        userId: String = "bench_user",
        batchSize: Int = 25_000,
        coreDataLimit: Int = .max,
        ctx: NSManagedObjectContext
    ) {
        mockDB.setFTSSyncEnabled(false)
        defer { mockDB.setFTSSyncEnabled(true) }

        let matchCount = Int(Double(count) * matchRate)
        let baseDate = Date()
        let baseTimestamp = baseDate.timeIntervalSince1970
        let chId = Int64(channelId)

        let noiseBodies: [String] = [
            "Good morning everyone",
            "Let me check on that and get back to you",
            "Thanks for the update, appreciate it",
            "I will review this and respond shortly",
            "Sounds great, let us proceed with the plan",
            "Please share the document when ready",
            "Looking forward to our next sync",
            "The report has been submitted for review",
            "Could you clarify the requirements",
            "See you at the standup tomorrow morning",
            "The deployment is scheduled for tonight",
            "All tests are passing on the feature branch",
            "The client approved the proposal",
            "Need to reschedule the call for next week",
            "Design review is set for Friday afternoon"
        ]

        @inline(__always) func bodyFor(_ i: Int) -> String {
            i < matchCount
                ? "\(targetWord) in message number \(i)"
                : noiseBodies[i % noiseBodies.count] + " (\(i))"
        }

        // Pre-compute which message indices we'll actually insert into Core
        // Data. The viewModel's search returns the top-`limit` matches by
        // createdAt DESC; matching messages all have lower `i` than noise
        // (i ∈ [0, matchCount)), but they get sorted by their distinct
        // `createdAt = baseTimestamp + i`, so the LATEST matching ones live at
        // i = matchCount - 1 down to matchCount - limit. We pick the latest
        // `coreDataLimit` matching indices so any top-page result the FTS
        // returns has a backing MessageDTO to resolve into a ChatMessage.
        var coreDataIndices: [Int] = []
        if coreDataLimit > 0 {
            let upper = matchCount  // exclusive
            let lower = max(0, upper - coreDataLimit)
            if lower < upper {
                coreDataIndices.append(contentsOf: lower..<upper)
            }
            // If the caller asked for more than we have matches, top up with
            // the latest noise messages so at least `coreDataLimit` rows are
            // present overall (preserves the original test feel for medium
            // datasets where `matchCount < coreDataLimit`).
            if coreDataIndices.count < coreDataLimit {
                let need = coreDataLimit - coreDataIndices.count
                let noiseUpper = count
                let noiseLower = max(matchCount, noiseUpper - need)
                if noiseLower < noiseUpper {
                    coreDataIndices.append(contentsOf: noiseLower..<noiseUpper)
                }
            }
        }

        // Phase 1: Insert the bounded set of MessageDTOs in a single Core Data
        // save. Decoupling this from FTS batch flushing avoids the previous
        // pattern of save+reset+refetch-user per FTS batch (which on xlarge
        // forced a tiny FTS commit cadence to align with Core Data).
        let phase1Start = CFAbsoluteTimeGetCurrent()
        if !coreDataIndices.isEmpty {
            let bgCtx = mockDB.container.newBackgroundContext()
            bgCtx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            bgCtx.undoManager = nil
            bgCtx.performAndWait {
                let user = UserDTO.fetchOrCreate(id: userId, context: bgCtx)
                for i in coreDataIndices {
                    let messageId = startId + Int64(i)
                    let msg = MessageDTO.insertNewObject(into: bgCtx)
                    msg.id = messageId
                    msg.tid = messageId
                    msg.channelId = chId
                    msg.state = 0
                    msg.transient = false
                    msg.user = user
                    msg.createdAt = baseDate.addingTimeInterval(Double(i)).bridgeDate
                    msg.body = bodyFor(i)
                }
                try? bgCtx.save()
            }
        }
        let phase1Ms = (CFAbsoluteTimeGetCurrent() - phase1Start) * 1_000
        print(String(format: "[SEED] Phase 1 (CoreData %d rows): %.1f ms",
                     coreDataIndices.count, phase1Ms))

        // Phase 2: Bulk-index FTS in large batches. `batchSize` now controls
        // FTS commit size only, so callers on xlarge/xxlarge can crank it up
        // without paying any Core Data cost.
        let phase2Start = CFAbsoluteTimeGetCurrent()
        var batchRows: [MessageSearchStore.Row] = []
        batchRows.reserveCapacity(min(count, batchSize))
        var indexedSoFar = 0
        for i in 0..<count {
            let messageId = startId + Int64(i)
            batchRows.append(MessageSearchStore.Row(
                messageId: messageId,
                channelId: chId,
                channelType: channelType,
                userId: userId,
                createdAt: baseTimestamp + Double(i),
                body: bodyFor(i)
            ))
            if batchRows.count >= batchSize {
                let batchStart = CFAbsoluteTimeGetCurrent()
                mockDB.messageSearchStore.bulkInsert(rows: batchRows)
                indexedSoFar += batchRows.count
                let batchMs = (CFAbsoluteTimeGetCurrent() - batchStart) * 1_000
                print(String(format: "[SEED] FTS batch flushed %d (running: %d/%d) in %.1f ms",
                             batchRows.count, indexedSoFar, count, batchMs))
                batchRows.removeAll(keepingCapacity: true)
            }
        }
        if !batchRows.isEmpty {
            let batchStart = CFAbsoluteTimeGetCurrent()
            mockDB.messageSearchStore.bulkInsert(rows: batchRows)
            indexedSoFar += batchRows.count
            let batchMs = (CFAbsoluteTimeGetCurrent() - batchStart) * 1_000
            print(String(format: "[SEED] FTS batch flushed %d (running: %d/%d) in %.1f ms",
                         batchRows.count, indexedSoFar, count, batchMs))
        }
        let phase2Ms = (CFAbsoluteTimeGetCurrent() - phase2Start) * 1_000
        print(String(format: "[SEED] Phase 2 (FTS %d rows): %.1f ms total", count, phase2Ms))
    }

    // MARK: - Benchmark runner

    /// Executes a single benchmark: measures wall-clock time and resident-memory
    /// delta for one `search(query:)` call, waits for the `.reload` event, then
    /// stores and returns a `BenchmarkResult`.
    @discardableResult
    private func runBenchmark(
        testName: String,
        query: String,
        matchType: String,
        datasetSize: Int,
        timeout: TimeInterval = 30
    ) -> BenchmarkResult {
        // Snapshot memory before the search.
        let memBefore = residentMemoryMB()
        let start = CFAbsoluteTimeGetCurrent()

        // Set up a one-shot Combine subscription that resolves the expectation.
        var localCancellables = Set<AnyCancellable>()
        let exp = expectation(description: "reload – \(testName)")
        viewModel.$event
            .compactMap { $0 }
            .first { if case .reload = $0 { return true }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &localCancellables)

        viewModel.search(query: query)
        wait(for: [exp], timeout: timeout)

        let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1_000
        let memDelta = residentMemoryMB() - memBefore
        let resultCount = viewModel.messages.count

        let r = BenchmarkResult(
            testName: testName,
            datasetSize: datasetSize,
            matchType: matchType,
            searchQuery: query,
            durationMs: durationMs,
            resultCount: resultCount,
            memoryDeltaMB: memDelta
        )
        Self.results.append(r)

        let paddedName  = testName.padding(toLength: 42, withPad: " ", startingAt: 0)
        let paddedMatch = matchType.padding(toLength: 7,  withPad: " ", startingAt: 0)
        print(String(format:
            "[PERF] %@ | size: %6d | %@ match | %6.1f ms | %4d results | Δmem %+.2f MB",
            paddedName, datasetSize, paddedMatch, durationMs, resultCount, memDelta))

        return r
    }

    // MARK: - Summary printer (called once after all tests in the class)

    private static func printSummary() {
        guard !results.isEmpty else { return }
        let sep = String(repeating: "─", count: 92)
        print("\n" + sep)
        print("  GLOBAL SEARCH DB PERFORMANCE SUMMARY")
        print(sep)
        print("  " + "Test".padding(toLength: 42, withPad: " ", startingAt: 0)
            + "    Size   Time(ms)  Results   ΔMem(MB)")
        print(sep)
        for r in results {
            let name = r.testName.padding(toLength: 42, withPad: " ", startingAt: 0)
            print(String(format: "  %@ %7d %10.1f %8d %10.2f",
                         name, r.datasetSize, r.durationMs, r.resultCount, r.memoryDeltaMB))
        }
        print(sep)

        // Result-count vs execution-time breakdown per match type.
        for matchType in ["exact", "partial"] {
            let filtered = results
                .filter { $0.matchType == matchType }
                .sorted { $0.datasetSize < $1.datasetSize }
            guard !filtered.isEmpty else { continue }
            print("\n  \(matchType.capitalized) match — scalability:")
            for r in filtered {
                print(String(format: "    %6d msgs → %4d results in %7.1f ms",
                             r.datasetSize, r.resultCount, r.durationMs))
            }
        }
        print(sep + "\n")
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Small dataset — 1 000 messages
    // MARK: ─────────────────────────────────────────────────────────────────

    /// Exact-word search on 1 K messages in a direct channel.
    /// Expects non-zero results and sub-2-second wall-clock time.
    func testPerf_small_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 1_001, type: directType, ctx: ctx)
        seedMessages(count: 1_000, startId: 1_000_000, channelId: 1_001,
                     channelType: directType,
                     targetWord: "invoice", matchRate: 0.10, ctx: ctx)

        let r = runBenchmark(
            testName: "small_exactMatch",
            query: "invoice",
            matchType: "exact",
            datasetSize: 1_000
        )

        XCTAssertGreaterThan(r.resultCount, 0, "Expected matches for 'invoice'")
        XCTAssertLessThan(r.durationMs, 2_000, "1K exact search should complete in < 2 s")
    }

    /// Partial-word search ("meet" matches "meeting") on 1 K messages.
    func testPerf_small_partialMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 1_002, type: directType, ctx: ctx)
        seedMessages(count: 1_000, startId: 1_100_000, channelId: 1_002,
                     channelType: directType,
                     targetWord: "meeting", matchRate: 0.15, ctx: ctx)

        let r = runBenchmark(
            testName: "small_partialMatch",
            query: "meet",
            matchType: "partial",
            datasetSize: 1_000
        )

        XCTAssertGreaterThan(r.resultCount, 0, "Expected partial matches for 'meet'")
        XCTAssertLessThan(r.durationMs, 2_000, "1K partial search should complete in < 2 s")
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Medium dataset — 10 000 messages
    // MARK: ─────────────────────────────────────────────────────────────────

    /// Exact-word search on 10 K messages in a group channel.
    func testPerf_medium_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 2_001, type: groupType, ctx: ctx)
        seedMessages(count: 10_000, startId: 2_000_000, channelId: 2_001,
                     channelType: groupType,
                     targetWord: "invoice", matchRate: 0.10, ctx: ctx)

        let r = runBenchmark(
            testName: "medium_exactMatch",
            query: "invoice",
            matchType: "exact",
            datasetSize: 10_000,
            timeout: 30
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 5_000, "10K exact search should complete in < 5 s")
    }

    /// Partial-word search on 10 K messages spread across a group channel.
    func testPerf_medium_partialMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 2_002, type: groupType, ctx: ctx)
        seedMessages(count: 10_000, startId: 2_200_000, channelId: 2_002,
                     channelType: groupType,
                     targetWord: "meeting", matchRate: 0.15, ctx: ctx)

        let r = runBenchmark(
            testName: "medium_partialMatch",
            query: "meet",
            matchType: "partial",
            datasetSize: 10_000,
            timeout: 30
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 5_000, "10K partial search should complete in < 5 s")
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Large dataset — 50 000 messages
    // MARK: ─────────────────────────────────────────────────────────────────

    /// Exact-word search on 50 K messages — primary scalability stress test.
    func testPerf_large_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 3_001, type: directType, ctx: ctx)
        seedMessages(count: 50_000, startId: 5_000_000, channelId: 3_001,
                     channelType: directType,
                     targetWord: "invoice", matchRate: 0.10,
                     coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "large_exactMatch",
            query: "invoice",
            matchType: "exact",
            datasetSize: 50_000,
            timeout: 60
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 15_000, "50K exact search should complete in < 15 s")
    }

    /// Partial-word search on 50 K messages — higher fanout than exact match.
    func testPerf_large_partialMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 3_002, type: directType, ctx: ctx)
        seedMessages(count: 50_000, startId: 5_500_000, channelId: 3_002,
                     channelType: directType,
                     targetWord: "meeting", matchRate: 0.15,
                     coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "large_partialMatch",
            query: "meet",
            matchType: "partial",
            datasetSize: 50_000,
            timeout: 60
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 15_000, "50K partial search should complete in < 15 s")
    }

    /// No-match scan on 50 K messages — measures worst-case full-table regex
    /// evaluation with zero qualifying results.
    func testPerf_large_noMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 3_003, type: directType, ctx: ctx)
        seedMessages(count: 50_000, startId: 6_000_000, channelId: 3_003,
                     channelType: directType,
                     targetWord: "placeholder", matchRate: 0.0,
                     coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "large_noMatch",
            query: "zzz_no_match_xqz",
            matchType: "exact",
            datasetSize: 50_000,
            timeout: 60
        )

        XCTAssertEqual(r.resultCount, 0, "No-match query must return zero results")
        XCTAssertLessThan(r.durationMs, 15_000, "No-match scan on 50K should complete in < 15 s")
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: XLarge dataset — 500 000 messages
    // MARK: ─────────────────────────────────────────────────────────────────

    /// Exact-word search on 500 K messages — extreme scalability stress test.
    /// Uses a larger batch size (2 000) to reduce the number of CoreData saves
    /// during seeding and keep total test time reasonable.
    func testPerf_xlarge_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 4_001, type: directType, ctx: ctx)
        seedMessages(count: 500_000, startId: 10_000_000, channelId: 4_001,
                     channelType: directType,
                     targetWord: "invoice", matchRate: 0.10,
                     batchSize: 50_000, coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "xlarge_exactMatch",
            query: "invoice",
            matchType: "exact",
            datasetSize: 500_000,
            timeout: 300
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 60_000, "500K exact search should complete in < 60 s")
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: XXLarge dataset — 1 000 000 messages
    // MARK: ─────────────────────────────────────────────────────────────────

    /// Exact-word search on 1 M messages — ultimate scalability stress test.
    /// Uses a batch size of 5 000 to minimize CoreData save overhead during seeding.
    func testPerf_xxlarge_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 5_001, type: directType, ctx: ctx)
        seedMessages(count: 1_000_000, startId: 20_000_000, channelId: 5_001,
                     channelType: directType,
                     targetWord: "invoice", matchRate: 0.10,
                     batchSize: 100_000, coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "xxlarge_exactMatch",
            query: "invoice",
            matchType: "exact",
            datasetSize: 1_000_000,
            timeout: 600
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 120_000, "1M exact search should complete in < 120 s")
    }

    /// Partial-word search on 1 M messages — tests regex evaluation at scale.
    func testPerf_xxlarge_partialMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 5_002, type: directType, ctx: ctx)
        seedMessages(count: 1_000_000, startId: 21_000_000, channelId: 5_002,
                     channelType: directType,
                     targetWord: "meeting", matchRate: 0.15,
                     batchSize: 100_000, coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "xxlarge_partialMatch",
            query: "meet",
            matchType: "partial",
            datasetSize: 1_000_000,
            timeout: 600
        )

        XCTAssertGreaterThan(r.resultCount, 0)
        XCTAssertLessThan(r.durationMs, 120_000, "1M partial search should complete in < 120 s")
    }

    /// No-match scan on 1 M messages — worst-case full-table scan with zero results.
    func testPerf_xxlarge_noMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 5_003, type: directType, ctx: ctx)
        seedMessages(count: 1_000_000, startId: 22_000_000, channelId: 5_003,
                     channelType: directType,
                     targetWord: "placeholder", matchRate: 0.0,
                     batchSize: 100_000, coreDataLimit: 1_000, ctx: ctx)

        let r = runBenchmark(
            testName: "xxlarge_noMatch",
            query: "zzz_no_match_xqz",
            matchType: "exact",
            datasetSize: 1_000_000,
            timeout: 600
        )

        XCTAssertEqual(r.resultCount, 0, "No-match query must return zero results")
        XCTAssertLessThan(r.durationMs, 120_000, "No-match scan on 1M should complete in < 120 s")
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: XCTest native measure blocks (feeds Xcode baseline tracking)
    // MARK: ─────────────────────────────────────────────────────────────────

    /// Native XCTest performance measure for a 1 K dataset. Establishes an
    /// Xcode baseline so regressions are flagged automatically in CI.
    func testMeasure_small_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 7_001, type: directType, ctx: ctx)
        seedMessages(count: 1_000, startId: 7_000_000, channelId: 7_001,
                     channelType: directType,
                     targetWord: "alpha", matchRate: 0.10, ctx: ctx)

        measure {
            var localCancellables = Set<AnyCancellable>()
            let exp = expectation(description: "measure reload 1K")
            viewModel.$event
                .compactMap { $0 }
                .first { if case .reload = $0 { return true }; return false }
                .sink { _ in exp.fulfill() }
                .store(in: &localCancellables)
            viewModel.search(query: "alpha")
            wait(for: [exp], timeout: 10)
        }
    }

    /// Native XCTest performance measure for a 10 K dataset.
    func testMeasure_medium_exactMatch() {
        let ctx = mockDB.container.viewContext
        seedChannel(id: 7_002, type: directType, ctx: ctx)
        seedMessages(count: 10_000, startId: 8_000_000, channelId: 7_002,
                     channelType: directType,
                     targetWord: "alpha", matchRate: 0.10, ctx: ctx)

        measure {
            var localCancellables = Set<AnyCancellable>()
            let exp = expectation(description: "measure reload 10K")
            viewModel.$event
                .compactMap { $0 }
                .first { if case .reload = $0 { return true }; return false }
                .sink { _ in exp.fulfill() }
                .store(in: &localCancellables)
            viewModel.search(query: "alpha")
            wait(for: [exp], timeout: 30)
        }
    }
}
