import Observability

/// Analytics events ``OptimisticLikeModel`` can send.
///
/// One enum keeps the model's complete analytics surface reviewable in a
/// single place, shared by every feature that constructs an
/// ``OptimisticLikeModel`` (S6.2's venue, S6.3's songs, S6.6's people) —
/// mirrors ``AccountEvent``'s doc comment on why only business-meaningful
/// moments (a completed like/unlike) become analytics events, while the
/// toggle gesture itself is a breadcrumb.
enum LikeEvent: String, AnalyticsEvent {
	case liked
	case unliked
	case likeFailed

	var name: String {
		rawValue
	}
}
