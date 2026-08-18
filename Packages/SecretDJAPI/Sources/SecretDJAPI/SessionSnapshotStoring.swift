/// Persists the signed-in user and current venue between launches.
///
/// Abstracting storage behind this protocol keeps ``SessionStore`` free of
/// persistence details and lets tests substitute an in-memory store.
@MainActor
public protocol SessionSnapshotStoring {
	/// The last snapshot saved, or `nil` when nothing has been saved (or it
	/// was cleared).
	func savedSnapshot() -> SessionSnapshot?

	/// Replaces the saved snapshot; pass `nil` to wipe it (sign-out).
	func save(_ snapshot: SessionSnapshot?)
}
