import Observability

/// Analytics events ``AddProfilePictureForCreditsModel`` can send — the
/// consumer-owned half of LEGACY.md business rule 5's out-of-credits funnel
/// (the request/moderation half's events are ``SharedFeatures/TuneInEvent``,
/// package-owned since that model lives in SharedFeatures; this funnel step
/// is consumer-only, reusing S4.5's avatar upload).
enum TuneInFunnelUploadEvent: String, AnalyticsEvent {
	case succeeded
	case failed

	var name: String {
		rawValue
	}
}
