import Foundation

/// Merges a SQLite WAL file on top of the main database pages.
///
/// Both the main DB and WAL pages use the same Apple CBC-keystream encryption.
/// The WAL is a sequence of 24-byte frame headers + page data; last frame per
/// page number wins (SQLite WAL semantics).
struct WALMerger: Sendable {
    static let walHeaderSize   = 32
    static let frameHeaderSize = 24
    static let pageSizeOffset  = 8    // bytes 8-11 of WAL header = uint32 BE page size

    // MARK: - Public API

    /// Read and decrypt the main DB, overlay WAL frames, return page dict.
    static func merge(dbPath: URL, walPath: URL, key: Data) throws -> (pages: [Int: Data], diagnostics: String) {
        var pages: [Int: Data] = [:]
        var diag: [String] = []

        // Step 1: decrypt main DB pages
        // Use FileHandle to read byte-by-byte to avoid mmap/coordination issues
        guard let fh = try? FileHandle(forReadingFrom: dbPath) else {
            throw NSError(domain: "WALMerger", code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Cannot open DB with FileHandle: \(dbPath.path)"])
        }
        defer { try? fh.close() }

        let pageSize = FindMyDecryptor.pageSize
        var pageNum = 1
        while true {
            guard let chunk = try? fh.read(upToCount: pageSize), !chunk.isEmpty else { break }
            if chunk.count == pageSize {
                let encPage = Data(chunk)
                pages[pageNum] = try FindMyDecryptor.decryptPage(encPage, pageNumber: pageNum, key: key)
            }
            pageNum += 1
        }
        let dbPageCount = pages.count
        diag.append("DB: \(dbPageCount) pages read from \(dbPath.lastPathComponent)")

        // Step 2: apply WAL frames (last frame per page wins)
        //
        // IMPORTANT: Read the entire WAL into memory FIRST, then parse it.
        // findmylocateagent can checkpoint (truncate/rewrite) the WAL at any moment —
        // if we read frame-by-frame with FileHandle we race with that and stop early,
        // missing the most-recent frames. An upfront Data(contentsOf:) gives us an
        // atomic snapshot of the file (identical to what the Python script does).
        guard FileManager.default.fileExists(atPath: walPath.path) else {
            diag.append("No WAL file")
            return (pages, diag.joined(separator: " | "))
        }

        let walSnapshot: Data
        do {
            walSnapshot = try Data(contentsOf: walPath)
        } catch {
            diag.append("WAL unreadable: \(error.localizedDescription)")
            return (pages, diag.joined(separator: " | "))
        }

        guard walSnapshot.count >= walHeaderSize else {
            diag.append("WAL too small (\(walSnapshot.count) bytes)")
            return (pages, diag.joined(separator: " | "))
        }

        let walPageSize = Int(walSnapshot
            .subdata(in: pageSizeOffset..<(pageSizeOffset + 4))
            .withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        let frameSize = frameHeaderSize + walPageSize
        let totalFrames = (walSnapshot.count - walHeaderSize) / frameSize
        diag.append("WAL pageSize=\(walPageSize) snapshot=\(walSnapshot.count)B frames=\(totalFrames)")

        var walFrames = 0
        for i in 0..<totalFrames {
            let frameOff = walHeaderSize + i * frameSize
            guard frameOff + frameSize <= walSnapshot.count else { break }
            let pgno = Int(walSnapshot
                .subdata(in: frameOff..<(frameOff + 4))
                .withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            let pageStart = frameOff + frameHeaderSize
            let encPage = walSnapshot.subdata(in: pageStart..<(pageStart + walPageSize))
            pages[pgno] = try FindMyDecryptor.decryptPage(encPage, pageNumber: pgno, key: key)
            walFrames += 1
        }
        diag.append("WAL: \(walFrames) frames applied, total pages=\(pages.count)")

        return (pages, diag.joined(separator: " | "))
    }

    /// Write merged page dict to a temp file and return its URL.
    ///
    /// The FindMy DB runs in WAL journal mode (header bytes 18–19 == 2).
    /// When we write a standalone merged file there is no accompanying .wal
    /// or .shm file, so SQLite refuses to prepare any statement.
    /// Patching those two bytes to 1 (rollback journal) lets SQLite open the
    /// file as a plain, self-contained database — exactly what Python's
    /// sqlite3.connect() does by default (it opens read-write, creating the
    /// shm in-place; we avoid that by switching the journal mode instead).
    static func writeMerged(pages: [Int: Data]) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fmf_\(UUID().uuidString).db")

        var merged = Data()
        for key in pages.keys.sorted() {
            merged.append(pages[key]!)
        }

        // SQLite header bytes 18 (write version) and 19 (read version):
        //   2 = WAL mode  →  1 = rollback journal (plain file, no WAL needed)
        if merged.count > 19 {
            merged[18] = 1
            merged[19] = 1
        }

        try merged.write(to: tempURL, options: .atomic)
        return tempURL
    }
}
