/// Fires when ``FeedScreenModel`` detects the legacy "jukebox changed"
/// condition — a paginated feed's hash mismatched mid-scroll under
/// ``FeedChangeDetector/Policy/surfaceChange`` (LEGACY.md "Change
/// detection"). Purely a signal: the app turns it into the toast and
/// pop/reload legacy performed (`kJukeboxUpdatedText` +
/// `notificationJukeboxChange`), since navigation and toast presentation
/// aren't FeedUI's concern.
public struct JukeboxChangedEvent: Sendable, Equatable {
	/// Increments on every occurrence, so two detections in a row are still
	/// distinct values for a SwiftUI `onChange(of:)` to react to.
	public let id: Int
}
