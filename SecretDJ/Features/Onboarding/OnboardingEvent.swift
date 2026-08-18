import Observability

/// Analytics events the Onboarding feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions are breadcrumbs instead.
enum OnboardingEvent: String, AnalyticsEvent {
	case avatarUploaded
	case avatarUploadFailed

	var name: String {
		rawValue
	}
}
