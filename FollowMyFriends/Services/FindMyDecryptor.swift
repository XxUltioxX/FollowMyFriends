import Foundation
import CommonCrypto

/// Implements Apple's proprietary FindMy AES-256 CBC-keystream codec.
///
/// Each 4096-byte SQLite page is encrypted as:
///   IV        = LE-uint32(pageNumber) ++ encPage[4084..<4096]   (16 bytes)
///   keystream = AES-256-CBC-Encrypt(key, IV, zeroes_4096)
///   plaintext = encPage[0..<4084] XOR keystream[0..<4084]
///               ++ encPage[4084..<4096]   (tail kept verbatim)
///
/// Page 1 special case: bytes 16–23 are stored unencrypted (SQLite header
/// constants).  The XOR step corrupts them, so they must be restored from
/// the raw encrypted page after decryption.
struct FindMyDecryptor: Sendable {
    static let pageSize     = 4096
    static let reservedOff  = 4084   // last 12 bytes are plaintext tail
    static let sqliteMagic  = Data([
        0x53,0x51,0x4c,0x69,0x74,0x65,0x20,0x66,
        0x6f,0x72,0x6d,0x61,0x74,0x20,0x33,0x00
    ])

    enum Error: Swift.Error, LocalizedError {
        case keyWrongLength(Int)
        case pageWrongSize(Int)
        case aesEncryptionFailed(CCCryptorStatus)
        case keyVerificationFailed
        case fileReadError(String)

        var errorDescription: String? {
            switch self {
            case .keyWrongLength(let n):
                return "Key must be 32 bytes; got \(n)"
            case .pageWrongSize(let n):
                return "Page must be \(pageSize) bytes; got \(n)"
            case .aesEncryptionFailed(let s):
                return "AES encryption failed with status \(s)"
            case .keyVerificationFailed:
                return "Key verification failed — decrypted page 1 does not start with the SQLite magic header"
            case .fileReadError(let msg):
                return "File read error: \(msg)"
            }
        }
    }

    // MARK: - Core Decryption

    /// Decrypt one 4096-byte page.
    static func decryptPage(_ encPage: Data, pageNumber: Int, key: Data) throws -> Data {
        guard key.count == 32 else { throw Error.keyWrongLength(key.count) }
        guard encPage.count == pageSize else { throw Error.pageWrongSize(encPage.count) }

        // Build 16-byte IV: 4-byte LE page number ++ 12-byte reserved tail
        var iv = Data(count: 16)
        let pageNumLE = UInt32(pageNumber).littleEndian
        withUnsafeBytes(of: pageNumLE) { bytes in
            iv.replaceSubrange(0..<4, with: bytes)
        }
        iv.replaceSubrange(4..<16, with: encPage[reservedOff..<pageSize])

        // Generate keystream via AES-256-CBC encrypt of 4096 zero bytes
        let zeros = Data(count: pageSize)
        var keystreamBuffer = Data(count: pageSize + kCCBlockSizeAES128)
        var keystreamLen = 0
        // Capture buffer count before the mutating borrow to avoid
        // Swift 6 overlapping-access errors.
        let keystreamCapacity = keystreamBuffer.count

        let status: CCCryptorStatus = key.withUnsafeBytes { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                zeros.withUnsafeBytes { inputPtr in
                    keystreamBuffer.withUnsafeMutableBytes { outputPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress!, key.count,
                            ivPtr.baseAddress!,
                            inputPtr.baseAddress!, zeros.count,
                            outputPtr.baseAddress!, keystreamCapacity,
                            &keystreamLen
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw Error.aesEncryptionFailed(status) }

        // XOR first 4084 bytes with keystream
        var plaintext = Data(count: reservedOff)
        encPage.withUnsafeBytes { enc in
            keystreamBuffer.withUnsafeBytes { ks in
                let encBytes = enc.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let ksBytes  = ks.baseAddress!.assumingMemoryBound(to: UInt8.self)
                plaintext.withUnsafeMutableBytes { plain in
                    let plainBytes = plain.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    for i in 0..<reservedOff {
                        plainBytes[i] = encBytes[i] ^ ksBytes[i]
                    }
                }
            }
        }

        // Page 1: restore bytes 16–23 (stored unencrypted in the raw page)
        if pageNumber == 1 {
            plaintext.replaceSubrange(16..<24, with: encPage[16..<24])
        }

        // Append plaintext tail verbatim
        plaintext.append(contentsOf: encPage[reservedOff..<pageSize])
        return plaintext
    }

    // MARK: - Key Utilities

    /// Load raw 32-byte key from a file path.
    static func loadKey(from path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        let key: Data
        do {
            key = try Data(contentsOf: url)
        } catch {
            throw Error.fileReadError(error.localizedDescription)
        }
        guard key.count == 32 else { throw Error.keyWrongLength(key.count) }
        return key
    }

    /// Quick sanity check: decrypt page 1 and verify SQLite magic header.
    static func verifyKey(_ key: Data, dbPath: URL) throws -> Bool {
        // Use Data(contentsOf:) so we see the actual OS error (not just nil from try?)
        let raw: Data
        do {
            raw = try Data(contentsOf: dbPath)
        } catch {
            throw Error.fileReadError("Cannot read \(dbPath.lastPathComponent): \(error)")
        }
        guard raw.count >= pageSize else {
            throw Error.fileReadError("DB too small: \(raw.count) bytes")
        }
        let firstPage = raw.prefix(pageSize)
        let decrypted = try decryptPage(Data(firstPage), pageNumber: 1, key: key)
        return decrypted.prefix(16) == sqliteMagic
    }

    /// Scan common locations for LocalStorage.key and return first match.
    static func autoDetectKeyPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Desktop/FMFv2/LocalStorage.key",
            "\(home)/Documents/LocalStorage.key",
            "\(home)/LocalStorage.key",
            "\(home)/Downloads/LocalStorage.key",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
