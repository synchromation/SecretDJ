import SecretDJAPI
import SecretDJDomain

/// The `extracontent` call ``ExtraContentModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface
/// (ios-architecture: a protocol seam per real dependency).
protocol ExtraContentLoading: Sendable {
	/// Fetches `screen`'s rotating content — `venueId` only when the
	/// hosting screen has one (the venue screen; `nil` on Places Nearby,
	/// mirroring `secretdjv3/FeedAPIAccess.swift`'s `extraContent`).
	/// Returns the first section's items, or an empty array when the
	/// response carries none — matches
	/// `FeedViewController.show(extraContent:)`'s own `section(for: 0)`
	/// read. Errors propagate to the caller, which — per legacy — never
	/// surfaces one to the UI; it only logs.
	func loadExtraContent(venueId: String?, screen: ExtraContentScreen) async throws -> [Item]
}
