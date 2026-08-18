import Foundation

/// The day-of-year salted signed-song-id `watchonyoutube`'s `item`
/// parameter requires (LEGACY.md "Backend API and Spotify integration" →
/// endpoint catalog: "signed song id `<songId>_<sha1(songId +
/// (dayOfYear-1) + salt)>`"; ported from `secretdjv3/SongSigGenerator.swift`).
///
/// Like ``AppleSignInAuthDigest``, the day number is computed in
/// `calendar`'s time zone, not UTC, and `date`/`calendar` are injected so
/// the signature is reproducible under test (LEGACY.md's day-of-year
/// digests note; D7 ports this fragility rather than fixing it).
public enum SongSignature {
	/// The salt baked into the wire contract (`secretdjv3/SongSigGenerator.swift:13`).
	static let salt = "9cx63a21cqdc782ed6b05ww124447f8e15c8"

	/// `"<songId>_<sha1(songId + (dayOfYear - 1) + salt)>"`.
	public static func signedSongId(songId: String, date: Date, calendar: Calendar) -> String {
		let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
		let input = "\(songId)\(dayOfYear - 1)\(salt)"
		return "\(songId)_\(sha1Hex(input))"
	}
}
