/// The `machinecontrol` skip/never-play write ``TuneInScreenModel`` needs
/// (LEGACY.md "Which buttons show is server-decided" and business rule 7) —
/// thinned to this exact surface (ios-architecture: a protocol seam per real
/// dependency) so SharedFeatures never depends on SecretDJAPI (PLAN.md's
/// architecture target). An app implements this over
/// `APIClient.machineControl(action:.skip/.blacklist, ...)`. Named
/// distinctly from `AtmosphereChanging`'s own `machinecontrol` write (the
/// mood/atmosphere action on that same endpoint) since each SharedFeatures
/// seam stays one-per-real-dependency rather than merging every
/// `machinecontrol` action into one protocol.
public protocol MachineControlling: Sendable {
	/// Submits a server-granted moderation action against `songId`, in
	/// `venueId` — mirrors `secretdjv3/TuneInViewController.swift`'s
	/// `skipSong()`/`blacklistSong()`, which pass the song's own id directly
	/// rather than an action's `itemId`.
	func moderate(
		_ action: TuneInModerationAction,
		songId: String,
		venueId: String,
	) async throws(MachineControlError) -> MachineControlResult
}

/// Which server-granted moderation control was tapped — LEGACY.md's
/// "skip"/"never-play" (blacklist) buttons, gated on the song's own
/// `actions` array rather than a fixed per-user permission.
public enum TuneInModerationAction: Sendable, Hashable {
	case skip
	case neverPlay
}

/// The outcome of a successful ``MachineControlling/moderate(_:songId:venueId:)``
/// call.
public struct MachineControlResult: Sendable, Equatable {
	/// The server's own confirmation copy, already localized (D11) — shown
	/// verbatim in a toast when present, never re-worded client-side. `nil`
	/// when the server sent none.
	public let message: String?

	public init(message: String?) {
		self.message = message
	}
}

/// Every way a ``MachineControlling`` call can fail — same shape as
/// ``AtmosphereChangeError``, kept as its own type since each feature's seam
/// is deliberately separate.
public enum MachineControlError: Error, Equatable, Sendable {
	case server(message: String?)
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// ``AtmosphereChangeError/notSignedIn``'s doc comment.
	case notSignedIn
}
