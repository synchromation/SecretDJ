import CryptoKit
import Foundation

/// A sensitive value made safe to place in any observability event.
///
/// Printing (or interpolating) a `Redacted` never reveals the value — only
/// three debugging hints: the first character, the length, and a short
/// stable digest, e.g. `⟨email: j…16 #4f9a⟩`. The digest lets logs answer
/// "was this the same account both times?" while identifying no one.
///
/// Redact at the emission call site, so every destination — console,
/// crash reporter, anything future — receives only the redacted form. When
/// unsure whether a value is sensitive, wrap it: sensitivity is the default
/// assumption, never the exception. The original value is not retained.
public struct Redacted: CustomStringConvertible, Equatable, Sendable {
	public let description: String

	/// - Parameters:
	///   - value: The sensitive value; only its redacted hint is kept.
	///   - label: What kind of thing the value is ("email", "postcode") —
	///     the hint a reader needs to know what was redacted.
	public init(_ value: String, label: String = "value") {
		description = Self.hint(for: value, label: label)
	}

	private static func hint(for value: String, label: String) -> String {
		guard let first = value.first else {
			return "⟨\(label): empty⟩"
		}

		return "⟨\(label): \(first)…\(value.count) #\(digest(of: value))⟩"
	}

	private static func digest(of value: String) -> String {
		SHA256.hash(data: Data(value.utf8))
			.prefix(2)
			.map { String(format: "%02x", $0) }
			.joined()
	}
}
