//
//  MessageSearchStore.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SQLite3

/// SQLite FTS5 sidecar that holds a tokenized index of message bodies. The index
/// is the source of truth for "find messages by text"; `MessageDTO` remains the
/// source of truth for everything else and is loaded by id once FTS returns hits.
///
/// All public methods are thread-safe — internal access is serialized through a
/// dedicated dispatch queue, so callers can dispatch from any thread.
public final class MessageSearchStore {

    /// Bump when the schema or tokenizer changes. The next launch will detect a
    /// version mismatch and trigger a full rebuild from `MessageDTO`.
    public static let schemaVersion: Int = 1

    public struct Row {
        public let messageId: Int64
        public let channelId: Int64
        public let channelType: String
        public let userId: String
        public let createdAt: Double
        public let body: String

        public init(
            messageId: Int64,
            channelId: Int64,
            channelType: String,
            userId: String,
            createdAt: Double,
            body: String
        ) {
            self.messageId = messageId
            self.channelId = channelId
            self.channelType = channelType
            self.userId = userId
            self.createdAt = createdAt
            self.body = body
        }
    }

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self
    )

    /// Path passed directly to `sqlite3_open_v2`. `":memory:"` opens a fresh
    /// transient database; any other value is treated as a filesystem path.
    private let path: String
    private let queue = DispatchQueue(label: "com.sceyt.uikit.message-search-store")
    private var db: OpaquePointer?
    private var isOpen = false

    public init(url: URL) {
        self.path = url.path
    }

    public init(path: String) {
        self.path = path
    }

    /// Convenience for tests / callers without a backing file.
    public static func inMemory() -> MessageSearchStore {
        MessageSearchStore(path: ":memory:")
    }

    deinit {
        if let db = db {
            sqlite3_close_v2(db)
        }
    }

    // MARK: - Lifecycle

    /// Opens the sidecar database, creating tables if needed.
    public func open() {
        queue.sync { _open() }
    }

    public func close() {
        queue.sync {
            if let db = db {
                sqlite3_close_v2(db)
            }
            db = nil
            isOpen = false
        }
    }

    /// Removes every indexed row. Used on logout and after a tokenizer change.
    public func clear() {
        queue.sync {
            guard isOpen else { return }
            _ = exec("DELETE FROM messages_fts;")
        }
    }

    // MARK: - Indexing

    /// Inserts or replaces the given rows in a single transaction. FTS5 has no
    /// `ON CONFLICT`, so we delete-then-insert per row to keep `messageId` unique.
    public func index(rows: [Row]) {
        guard !rows.isEmpty else { return }
        queue.sync {
            guard isOpen else { return }
            _ = exec("BEGIN IMMEDIATE TRANSACTION;")
            let deleteSQL = "DELETE FROM messages_fts WHERE messageId = ?;"
            let insertSQL = """
            INSERT INTO messages_fts (messageId, channelId, channelType, userId, createdAt, body)
            VALUES (?, ?, ?, ?, ?, ?);
            """
            var deleteStmt: OpaquePointer?
            var insertStmt: OpaquePointer?
            defer {
                sqlite3_finalize(deleteStmt)
                sqlite3_finalize(insertStmt)
            }
            guard
                sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK,
                sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK
            else {
                logError("prepare insert/delete")
                _ = exec("ROLLBACK;")
                return
            }
            for row in rows {
                sqlite3_reset(deleteStmt)
                sqlite3_bind_int64(deleteStmt, 1, row.messageId)
                _ = sqlite3_step(deleteStmt)

                sqlite3_reset(insertStmt)
                sqlite3_bind_int64(insertStmt, 1, row.messageId)
                sqlite3_bind_int64(insertStmt, 2, row.channelId)
                sqlite3_bind_text(insertStmt, 3, row.channelType, -1, Self.SQLITE_TRANSIENT)
                sqlite3_bind_text(insertStmt, 4, row.userId, -1, Self.SQLITE_TRANSIENT)
                sqlite3_bind_double(insertStmt, 5, row.createdAt)
                sqlite3_bind_text(insertStmt, 6, row.body, -1, Self.SQLITE_TRANSIENT)
                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    logError("insert row \(row.messageId)")
                }
            }
            _ = exec("COMMIT;")
        }
    }

    /// Inserts rows without the per-row delete that `index(rows:)` does for
    /// upsert semantics. Use only when the caller can guarantee `messageId`s
    /// are not already present — e.g. initial seeding or one-shot migration
    /// from `MessageDTO`. Calling this with duplicates yields duplicate rows
    /// in the FTS index.
    ///
    /// `messageId` is an `UNINDEXED` column, so the upsert variant scans the
    /// whole FTS table per row, which becomes quadratic when bulk-loading.
    /// This method skips that scan entirely.
    public func bulkInsert(rows: [Row]) {
        guard !rows.isEmpty else { return }
        queue.sync {
            guard isOpen else { return }
            _ = exec("BEGIN IMMEDIATE TRANSACTION;")
            let insertSQL = """
            INSERT INTO messages_fts (messageId, channelId, channelType, userId, createdAt, body)
            VALUES (?, ?, ?, ?, ?, ?);
            """
            var insertStmt: OpaquePointer?
            defer { sqlite3_finalize(insertStmt) }
            guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else {
                logError("prepare bulkInsert")
                _ = exec("ROLLBACK;")
                return
            }
            for row in rows {
                sqlite3_reset(insertStmt)
                sqlite3_bind_int64(insertStmt, 1, row.messageId)
                sqlite3_bind_int64(insertStmt, 2, row.channelId)
                sqlite3_bind_text(insertStmt, 3, row.channelType, -1, Self.SQLITE_TRANSIENT)
                sqlite3_bind_text(insertStmt, 4, row.userId, -1, Self.SQLITE_TRANSIENT)
                sqlite3_bind_double(insertStmt, 5, row.createdAt)
                sqlite3_bind_text(insertStmt, 6, row.body, -1, Self.SQLITE_TRANSIENT)
                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    logError("bulkInsert row \(row.messageId)")
                }
            }
            _ = exec("COMMIT;")
        }
    }

    public func delete(messageIds: [Int64]) {
        guard !messageIds.isEmpty else { return }
        queue.sync {
            guard isOpen else { return }
            _ = exec("BEGIN IMMEDIATE TRANSACTION;")
            let sql = "DELETE FROM messages_fts WHERE messageId = ?;"
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logError("prepare delete")
                _ = exec("ROLLBACK;")
                return
            }
            for id in messageIds {
                sqlite3_reset(stmt)
                sqlite3_bind_int64(stmt, 1, id)
                _ = sqlite3_step(stmt)
            }
            _ = exec("COMMIT;")
        }
    }

    // MARK: - Search

    /// Returns matching `messageId`s ordered by `createdAt` DESC.
    /// `query` is split on whitespace; each token becomes a quoted prefix
    /// (`"token"*`) and the tokens are AND-ed together.
    public func search(
        query: String,
        channelTypes: [String]? = nil,
        userId: String? = nil,
        channelIds: [Int64]? = nil,
        offset: Int = 0,
        limit: Int = 20
    ) -> [Int64] {
        let tokens = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map(Self.escapeFTSToken)
        guard !tokens.isEmpty else { return [] }
        let matchExpr = tokens.joined(separator: " ")

        var sql = "SELECT messageId FROM messages_fts WHERE messages_fts MATCH ?"
        if let channelTypes, !channelTypes.isEmpty {
            sql += " AND channelType IN (\(placeholders(channelTypes.count)))"
        }
        if userId != nil {
            sql += " AND userId = ?"
        }
        if let channelIds, !channelIds.isEmpty {
            sql += " AND channelId IN (\(placeholders(channelIds.count)))"
        }
        sql += " ORDER BY createdAt DESC LIMIT ? OFFSET ?;"

        var result: [Int64] = []
        queue.sync {
            guard isOpen else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logError("prepare search")
                return
            }
            var idx: Int32 = 1
            sqlite3_bind_text(stmt, idx, matchExpr, -1, Self.SQLITE_TRANSIENT)
            idx += 1
            if let channelTypes {
                for t in channelTypes {
                    sqlite3_bind_text(stmt, idx, t, -1, Self.SQLITE_TRANSIENT)
                    idx += 1
                }
            }
            if let userId {
                sqlite3_bind_text(stmt, idx, userId, -1, Self.SQLITE_TRANSIENT)
                idx += 1
            }
            if let channelIds {
                for id in channelIds {
                    sqlite3_bind_int64(stmt, idx, id)
                    idx += 1
                }
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))
            idx += 1
            sqlite3_bind_int(stmt, idx, Int32(offset))

            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(sqlite3_column_int64(stmt, 0))
            }
        }
        return result
    }

    /// Returns the number of indexed rows. Useful in tests and for diagnostics.
    public func count() -> Int {
        var count = 0
        queue.sync {
            guard isOpen else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM messages_fts;", -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int64(stmt, 0))
            }
        }
        return count
    }

    // MARK: - Filter helpers

    /// A message is indexable only when it's not soft-deleted, not transient,
    /// and has a non-empty body. Mirrors the predicate used by the legacy search.
    public static func shouldIndex(state: Int16, transient: Bool, body: String) -> Bool {
        return state != 2 /* MessageState.deleted */ && !transient && !body.isEmpty
    }

    // MARK: - Internals

    private func _open() {
        guard !isOpen else { return }
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            logError("open at \(path)")
            db = nil
            return
        }
        _ = exec("PRAGMA journal_mode = WAL;")
        _ = exec("PRAGMA synchronous = NORMAL;")
        _ = exec("PRAGMA temp_store = MEMORY;")

        let create = """
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
            messageId UNINDEXED,
            channelId UNINDEXED,
            channelType UNINDEXED,
            userId UNINDEXED,
            createdAt UNINDEXED,
            body,
            tokenize = 'unicode61 remove_diacritics 2'
        );
        """
        guard exec(create) else {
            sqlite3_close_v2(db)
            db = nil
            return
        }
        isOpen = true
    }

    /// Wraps a token in double quotes (escaping any `"`) and appends `*` so the
    /// FTS5 parser treats it as a prefix-of-word match — same UX as the legacy
    /// `\bword.*` regex but index-driven.
    private static func escapeFTSToken(_ token: String) -> String {
        let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\"*"
    }

    private func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ",")
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        var errPtr: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errPtr)
        if result != SQLITE_OK {
            let message = errPtr.map { String(cString: $0) } ?? "<no error message>"
            logger.error("[MessageSearchStore] exec failed: \(sql) — \(message)")
            sqlite3_free(errPtr)
            return false
        }
        return true
    }

    private func logError(_ context: String) {
        let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "<no message>"
        logger.error("[MessageSearchStore] \(context) failed: \(message)")
    }
}
