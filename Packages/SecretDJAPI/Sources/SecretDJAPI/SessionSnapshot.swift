/// The unit ``SessionSnapshotStoring`` persists: the signed-in user and the
/// current venue, if any.
public struct SessionSnapshot: Sendable, Hashable, Codable {
	public let user: SessionUser
	public let venue: SessionVenue?

	public init(user: SessionUser, venue: SessionVenue?) {
		self.user = user
		self.venue = venue
	}
}
