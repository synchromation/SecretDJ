/// The signed-in user's identity, as far as the session needs it.
///
/// Deliberately smaller than `SecretDJDomain.Person`: `Person` decodes from
/// a feed item's `Text`/`Index`/`Data`/`Action` envelope and carries
/// feed-cell concerns (`likeInfo`, `text`, `sortIndex`, `action`,
/// `actions`) that have no meaning for "who is signed in", and has no
/// `Encodable` counterpart to round-trip through session persistence.
/// `SessionUser` carries only the identity fields and is `Codable` end to
/// end.
public struct SessionUser: Sendable, Hashable, Codable {
	public let personId: String
	public let screenName: String

	public init(personId: String, screenName: String) {
		self.personId = personId
		self.screenName = screenName
	}
}
