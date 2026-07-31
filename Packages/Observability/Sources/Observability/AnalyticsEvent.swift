/// A typed analytics event.
///
/// Features declare their events as small conforming enums (one per feature)
/// so the complete set of events the app can ever send is enumerable in code,
/// reviewable for privacy, and exhaustively testable — never ad-hoc strings
/// at call sites.
public protocol AnalyticsEvent: Sendable {
	/// The event name as it appears in the analytics platform.
	var name: String { get }

	/// Extra dimensions for the event; keep values non-identifying — no
	/// user IDs, no free-form user content.
	var parameters: [String: String] { get }
}

extension AnalyticsEvent {
	public var parameters: [String: String] {
		[:]
	}
}
