import Observability

/// Analytics events ``TuneInScreenModel`` can send — one enum per feature
/// keeps its complete analytics surface reviewable in a single place
/// (observability skill, mirrors ``MusicSelectionEvent``/``LikeEvent``).
/// ``songRequested`` is the one business-moment event PLAN.md S6.3 calls
/// out explicitly; the rest cover the moderation/failure paths the same way
/// ``LikeEvent`` covers its own toggle's failure.
public enum TuneInEvent: String, AnalyticsEvent {
	/// A song was successfully queued on the jukebox (`requestsong`
	/// `ReturnCode == 0`) — the business moment PLAN.md S6.3 calls out.
	case songRequested
	/// A request came back out of credits (`ReturnCode == -8`) — not a
	/// failure in the transport sense, but its own funnel-entry moment.
	case songRequestOutOfCredits
	/// A request failed — a transport error, or a non-zero, non-`-8`
	/// server return code.
	case songRequestFailed
	case songSkipped
	case songSkipFailed
	case songNeverPlayed
	case songNeverPlayFailed

	public var name: String {
		rawValue
	}
}
