/// The identity, forced venue, and rotated token a successful kiosk
/// `signin` call returns — the kiosk-local counterpart to the consumer
/// app's `AuthenticatedSession`, with the one extra field the venue-account
/// business rule needs: LEGACY.md "Venue login and the skin system" —
/// "kiosk credentials are venue accounts, and the backend pins them to one
/// venue via `Venues.Force`."
struct KioskAuthenticatedSession: Equatable {
	let personId: String
	let screenName: String
	let forcedVenueId: String
	/// The server's freshly issued token, when the response carried one
	/// (``SecretDJAPI/APIResponse/rotatedToken``).
	let rotatedToken: String?
}
