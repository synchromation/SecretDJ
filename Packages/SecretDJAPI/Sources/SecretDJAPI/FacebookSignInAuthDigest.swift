import Foundation

/// The day-of-year salted digest `facebooksignin`'s `auth` parameter
/// requires — the same day-of-year scheme as ``AppleSignInAuthDigest``, with
/// Facebook's own salt (LEGACY.md "Backend API and Spotify integration" →
/// "Day-of-year auth digests"; ported from
/// `secretdjv3/LoginAPIAccess.swift:41,303-321`). See
/// ``AppleSignInAuthDigest``'s doc comment for the day-of-year/timezone
/// behavior this deliberately ports as-is rather than fixing (D7).
public enum FacebookSignInAuthDigest {
	/// The salt baked into the wire contract (`secretdjv3/LoginAPIAccess.swift:41`).
	static let salt = "a23167ehxwxzf9Fd4"

	public static func compute(facebookUserId: String, date: Date, calendar: Calendar) -> String {
		let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
		let input = "\(facebookUserId)\(dayOfYear - 1)\(salt)"
		return sha1Hex(input)
	}
}
