import CryptoKit
import Foundation

public enum ImageDigest {
    private static let fileReadChunkSize = 64 * 1024

    public static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return prefixedHex(Array(digest))
    }

    public static func sha256(fileAt url: URL) throws -> String {
        try sha256(
            fileAt: url,
            chunkSize: Self.fileReadChunkSize
        )
    }

    static func sha256(
        fileAt url: URL,
        chunkSize: Int
    ) throws -> String {
        precondition(chunkSize > 0)

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }

        return prefixedHex(Array(hasher.finalize()))
    }

    private static func prefixedHex(_ bytes: [UInt8]) -> String {
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return "sha256:" + hex
    }
}
