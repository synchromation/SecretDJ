import SecretDJAPI

extension SessionStore {
	/// Signs the session in from a successful kiosk `signin` call, storing
	/// the forced venue the server pinned this account to
	/// (``KioskAuthenticatedSession/forcedVenueId``; LEGACY.md "Venue login
	/// and the skin system" — `Venues.Force`).
	///
	/// The venue's *name* isn't in `signin`'s response — legacy never had
	/// one at login either, only ever building `Venue(venueId:)` with no
	/// name (`secretdjv3/LoginAPIAccess.swift`'s `serverLoginDetails`).
	/// Resolving the real name means a `venuedetails` feed fetch, which is
	/// S7.4's kiosk-feeds work, not this shell's — so the venue id stands in
	/// for the name until then; ``KioskHomeView`` documents the same seam on
	/// the display side.
	///
	/// - Returns: `false`, leaving the session untouched, when the response
	///   carried no token to sign future requests with (mirrors the
	///   consumer's own `SessionStore.signIn(from:passwordHash:)`).
	@discardableResult
	func signIn(from session: KioskAuthenticatedSession, passwordHash: String) -> Bool {
		guard let token = session.rotatedToken else {
			return false
		}

		signIn(
			user: SessionUser(personId: session.personId, screenName: session.screenName),
			venue: SessionVenue(venueId: session.forcedVenueId, name: session.forcedVenueId),
			credential: APICredential(token: token, passwordHash: passwordHash),
		)
		return true
	}
}
