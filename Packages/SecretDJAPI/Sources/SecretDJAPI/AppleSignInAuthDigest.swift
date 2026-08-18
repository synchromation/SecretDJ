import Foundation

/// The day-of-year salted digest `applesignin`'s `auth` parameter requires
/// (LEGACY.md "Backend API and Spotify integration" → "Day-of-year auth
/// digests"; ported from `secretdjv3/LoginAPIAccess.swift:313-321`).
///
/// The day number is computed in `calendar`'s time zone, not UTC — matching
/// the legacy client's `DateFormatter` "DDD" pattern, which resolves in the
/// formatter's (device-current) time zone rather than UTC. LEGACY.md flags
/// this as a known-fragile, timezone-sensitive contract; per D7 this rewrite
/// ports the behavior as-is rather than fixing it unilaterally. `date` and
/// `calendar` are injected so the digest is reproducible under test.
public enum AppleSignInAuthDigest {
	/// The salt baked into the wire contract (`secretdjv3/LoginAPIAccess.swift:42`).
	static let salt = "a199eb60aad211ea"

	public static func compute(appleUserId: String, date: Date, calendar: Calendar) -> String {
		let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
		let input = "\(appleUserId)\(dayOfYear - 1)\(salt)"
		return sha1Hex(input)
	}
}
