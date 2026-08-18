/// The identity, plus venue-forcing/created-account signal, common to every
/// successful auth response (`signin`, `createuser`, `applesignin`) — ported
/// from `secretdjv3/LoginAPIAccess.swift`'s `LoginDetails` (LEGACY.md
/// "Consumer app: features and flows" → "Login, sign-up, onboarding").
public struct LoginDetails: Sendable, Hashable {
	public let personId: String
	public let screenName: String
	/// `true` for a brand-new account. `signin`/`createuser` never carry
	/// this on the wire — the caller already knows which endpoint it
	/// called — so it's a literal per call site; `applesignin` reads it
	/// from the server's `Created` field.
	public let created: Bool
	/// The venue the server force-joins the user to (`signin`'s optional
	/// `Venues.Force`), when present.
	public let forcedVenueId: String?
	/// The server-issued credential to sign future requests with — present
	/// only for `applesignin`, which skips native password entry and gets
	/// its credential back from the server instead (`Param`; LEGACY.md's
	/// auth-scheme section: "For Facebook/Apple sign-in the server
	/// *returns* the credential"). `nil` for `signin`/`createuser`, whose
	/// credential is the caller's own SHA-1 password hash.
	public let issuedCredential: String?

	public init(
		personId: String,
		screenName: String,
		created: Bool,
		forcedVenueId: String?,
		issuedCredential: String?,
	) {
		self.personId = personId
		self.screenName = screenName
		self.created = created
		self.forcedVenueId = forcedVenueId
		self.issuedCredential = issuedCredential
	}
}
