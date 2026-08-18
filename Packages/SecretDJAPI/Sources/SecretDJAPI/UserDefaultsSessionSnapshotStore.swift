import Foundation

/// Stores the session snapshot as Codable JSON in `UserDefaults`.
@MainActor
public struct UserDefaultsSessionSnapshotStore: SessionSnapshotStoring {
	private static let snapshotKey = "session.snapshot"

	private let defaults: UserDefaults

	public init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	public func savedSnapshot() -> SessionSnapshot? {
		guard let data = defaults.data(forKey: Self.snapshotKey) else {
			return nil
		}
		return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
	}

	public func save(_ snapshot: SessionSnapshot?) {
		guard let snapshot else {
			defaults.removeObject(forKey: Self.snapshotKey)
			return
		}

		guard let data = try? JSONEncoder().encode(snapshot) else {
			return
		}
		defaults.set(data, forKey: Self.snapshotKey)
	}
}
