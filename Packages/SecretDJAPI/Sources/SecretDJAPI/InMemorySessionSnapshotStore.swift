/// Holds the session snapshot in memory only — used by tests and previews.
@MainActor
public final class InMemorySessionSnapshotStore: SessionSnapshotStoring {
	public private(set) var snapshot: SessionSnapshot?
	/// Every value passed to ``save(_:)``, in call order — lets tests assert
	/// that no write happened, not just what the latest write was.
	public private(set) var saveInvocations: [SessionSnapshot?] = []

	public init(snapshot: SessionSnapshot? = nil) {
		self.snapshot = snapshot
	}

	public func savedSnapshot() -> SessionSnapshot? {
		snapshot
	}

	public func save(_ snapshot: SessionSnapshot?) {
		self.snapshot = snapshot
		saveInvocations.append(snapshot)
	}
}
