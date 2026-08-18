/// The current venue's identity, as far as the session needs it.
///
/// Deliberately smaller than `SecretDJDomain.Venue`, for the same reason as
/// ``SessionUser``: `Venue` decodes from a feed item's envelope and carries
/// feed-cell/session-interaction fields (`likeInfo`, `checkedIn`,
/// `hasMachineControl`, `text`, `sortIndex`, `action`, `actions`) that
/// don't belong in a persisted "which venue am I in" record, and has no
/// `Encodable` counterpart.
public struct SessionVenue: Sendable, Hashable, Codable {
	public let venueId: String
	public let name: String

	public init(venueId: String, name: String) {
		self.venueId = venueId
		self.name = name
	}
}
