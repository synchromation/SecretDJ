import Observability

/// Analytics events ``OptimisticLikeModel`` can send — one enum per feature
/// keeps its complete analytics surface reviewable in a single place
/// (observability skill), mirrors ``MusicSelectionEvent``'s doc comment.
/// Package-owned rather than reused from the consumer app's own event
/// vocabulary: ``OptimisticLikeModel`` relocated here from `Support/Like` so
/// TuneIn (S6.3b) and, later, Profile (S6.6) can embed it unmodified, and
/// SharedFeatures never depends on the app target it's used from.
public enum LikeEvent: String, AnalyticsEvent {
	case liked
	case unliked
	case likeFailed

	public var name: String {
		rawValue
	}
}
