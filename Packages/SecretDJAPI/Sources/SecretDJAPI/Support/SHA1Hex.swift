import CryptoKit
import Foundation

/// Lowercase hex SHA-1, matching the legacy client's formatting
/// (`secretdjv3/String+Crypto.swift`, `secretdjv3/SongSigGenerator.swift`).
///
/// SHA-1 is used throughout this file's callers for wire compatibility with
/// the existing backend (D7), not as a security choice; CryptoKit's
/// ``Insecure/SHA1`` names it accordingly.
func sha1Hex(_ input: String) -> String {
	Insecure.SHA1.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
}
