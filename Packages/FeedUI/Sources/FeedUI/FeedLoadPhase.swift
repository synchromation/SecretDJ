/// A feed screen's overall load state, driving which DesignSystem surface
/// ``FeedScreen`` shows.
public enum FeedLoadPhase: Sendable, Equatable {
	/// No content fetched yet — the first load (or a refresh with nothing
	/// currently on screen) is in flight.
	case loading
	/// Content loaded and at least one visible section has items.
	case loaded
	/// Content loaded successfully but every visible section is empty.
	case empty
	/// The load failed before any content was on screen. `offline` is `true`
	/// when the failure was a `URLError` indicating no network connectivity,
	/// distinguishing that case from any other failure.
	case error(offline: Bool)
}
