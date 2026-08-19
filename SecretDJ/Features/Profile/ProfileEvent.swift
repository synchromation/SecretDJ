import Observability

/// Analytics events the Profile feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions are breadcrumbs instead.
enum ProfileEvent: String, AnalyticsEvent {
	case avatarChanged
	case avatarChangeFailed

	var name: String {
		rawValue
	}
}
