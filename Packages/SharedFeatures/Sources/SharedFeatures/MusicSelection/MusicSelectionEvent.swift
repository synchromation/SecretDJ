import Observability

/// Analytics events the music-selection feature can send — one enum per
/// feature keeps its complete analytics surface reviewable in a single
/// place (observability skill).
public enum MusicSelectionEvent: String, AnalyticsEvent {
	/// A mood/atmosphere tile change completed successfully.
	case atmosphereChanged
	/// A mood/atmosphere tile change failed.
	case atmosphereChangeFailed

	public var name: String {
		rawValue
	}
}
