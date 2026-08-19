/// The `machinecontrol` change-atmosphere write ``MoodTileModel`` needs
/// (LEGACY.md "Change mood (machine control)") — thinned to this exact
/// surface (ios-architecture: a protocol seam per real dependency) so
/// SharedFeatures never depends on SecretDJAPI (PLAN.md's architecture
/// target). An app implements this over `APIClient.machineControl(action:
/// .changeAtmosphere, ...)`.
public protocol AtmosphereChanging: Sendable {
	/// Holds the mood/atmosphere named by `itemId` for `minutes`, in
	/// `venueId`. Mirrors `secretdjv3/MachineControlAPIAccess.swift`'s
	/// `changeMood`.
	func changeAtmosphere(
		itemId: Int,
		venueId: String,
		minutes: Int,
	) async throws(AtmosphereChangeError) -> AtmosphereChangeResult
}

/// The outcome of a successful ``AtmosphereChanging/changeAtmosphere(itemId:venueId:minutes:)``
/// call.
public struct AtmosphereChangeResult: Sendable, Equatable {
	/// The server's own confirmation copy, already localized
	/// (D11) — shown verbatim in a toast when present, never re-worded
	/// client-side. `nil` when the server sent none.
	public let message: String?

	public init(message: String?) {
		self.message = message
	}
}

/// Every way an ``AtmosphereChanging`` call can fail — same shape as
/// `LikeError`/`PromotionEngaging`'s sibling seams, kept as its own type
/// since each feature's seam is deliberately separate.
public enum AtmosphereChangeError: Error, Equatable, Sendable {
	case server(message: String?)
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// `NotSignedInFeedLoadingError`'s doc comment: a mood tile only exists
	/// while signed in, so this defends against a pending call outliving a
	/// sign-out rather than a state the UI needs to distinguish from
	/// ``connection``.
	case notSignedIn
}
