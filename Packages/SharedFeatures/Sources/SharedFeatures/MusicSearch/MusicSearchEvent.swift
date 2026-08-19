import Observability

/// Analytics events the music-search feature can send — one enum per
/// feature keeps its complete analytics surface reviewable in a single
/// place (observability skill).
public enum MusicSearchEvent: String, AnalyticsEvent {
	/// The user switched between artist and track search.
	case searchModeChanged

	public var name: String {
		rawValue
	}
}
