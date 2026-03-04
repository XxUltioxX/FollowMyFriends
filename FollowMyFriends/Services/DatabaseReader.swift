import Foundation
import SQLite3

struct FriendRecord: Sendable {
    var handleIdentifier: String         // phone number or email
    var handleServerIdentifier: String   // server-side UUID (base64)
    var locationBlob: Data?
}

/// Decrypts the FindMy LocalStorage.db (+ WAL), then queries it via SQLite3.
struct DatabaseReader: Sendable {

    static let dbPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Group Containers/"
            + "group.com.apple.findmy.findmylocateagent/"
            + "Library/Application Support/LocalStorage.db"
    }()

    static var walPath: String { dbPath + "-wal" }

    // MARK: - Public

    /// Full pipeline: load key → verify → decrypt + merge WAL → query.
    static func readFriends(keyPath: String, customDBPath: String = "") throws -> [FriendRecord] {
        let key = try FindMyDecryptor.loadKey(from: keyPath)

        let resolvedPath = customDBPath.isEmpty ? dbPath : customDBPath
        let dbURL  = URL(fileURLWithPath: resolvedPath)
        let walURL = URL(fileURLWithPath: resolvedPath + "-wal")

        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw NSError(
                domain: "DatabaseReader",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "FindMy database not found at \(resolvedPath). " +
                    "Grant Full Disk Access in System Settings → Privacy & Security."]
            )
        }

        // Quick key verification before doing the expensive full merge
        guard try FindMyDecryptor.verifyKey(key, dbPath: dbURL) else {
            throw FindMyDecryptor.Error.keyVerificationFailed
        }

        let mergeResult = try WALMerger.merge(dbPath: dbURL, walPath: walURL, key: key)
        let pages = mergeResult.pages
        var diagnostics = mergeResult.diagnostics

        let tmpURL = try WALMerger.writeMerged(pages: pages)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Write a debug copy to Desktop so it can be inspected with sqlite3 CLI
        let debugURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/fmf_debug.db")
        try? FileManager.default.removeItem(at: debugURL)
        try? FileManager.default.copyItem(at: tmpURL, to: debugURL)

        // Log header bytes to verify the WAL-mode patch
        if let rawCheck = try? Data(contentsOf: tmpURL), rawCheck.count > 23 {
            let b16_23 = rawCheck[16..<24].map { String(format: "%02x", $0) }.joined(separator: " ")
            diagnostics += " | merged=\(rawCheck.count)B hdr[\(b16_23)]"
        } else {
            diagnostics += " | merged=0B (EMPTY!)"
        }

        // Always surface WAL merger diagnostics to the caller for logging
        let result = try query(dbURL: tmpURL, diagnostics: diagnostics)
        // Attach diagnostics as a thrown-away side channel via NotificationCenter so
        // AppState can log them without changing the return type.
        NotificationCenter.default.post(
            name: .init("DatabaseReaderDiagnostics"),
            object: nil,
            userInfo: ["diag": diagnostics]
        )
        return result
    }

    // MARK: - Private

    private static func query(dbURL: URL, diagnostics: String) throws -> [FriendRecord] {
        var db: OpaquePointer?

        // Match Python's sqlite3.connect() default: READWRITE | CREATE
        let openFlags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let rc = sqlite3_open_v2(dbURL.path, &db, openFlags, nil)

        let openDetails: String
        if let db {
            let extCode = sqlite3_extended_errcode(db)
            let msg = String(cString: sqlite3_errmsg(db))
            openDetails = "rc=\(rc) extCode=\(extCode) msg=\(msg)"
        } else {
            openDetails = "rc=\(rc) db=nil"
        }

        guard rc == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: Int(rc),
                          userInfo: [NSLocalizedDescriptionKey:
                            "Cannot open DB [\(openDetails)] | \(diagnostics)"])
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT
                f.handleIdentifier,
                f.handleServerIdentifier,
                sl.value
            FROM friends f
            LEFT JOIN secureLocations sl
                   ON sl.serverUserID = f.handleServerIdentifier
            ORDER BY f.handleIdentifier
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let extCode = db.map { sqlite3_extended_errcode($0) } ?? -1
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw NSError(domain: "SQLite", code: -1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Prepare failed rc=\(extCode): \(msg) | path=\(dbURL.path) | \(diagnostics)"])
        }
        defer { sqlite3_finalize(stmt) }

        var records: [FriendRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let handleId = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
            let serverId = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""

            var blob: Data?
            if sqlite3_column_type(stmt, 2) != SQLITE_NULL {
                let ptr = sqlite3_column_blob(stmt, 2)
                let len = Int(sqlite3_column_bytes(stmt, 2))
                if let ptr, len > 0 {
                    blob = Data(bytes: ptr, count: len)
                }
            }

            records.append(FriendRecord(
                handleIdentifier:       handleId,
                handleServerIdentifier: serverId,
                locationBlob:           blob
            ))
        }
        return records
    }
}
