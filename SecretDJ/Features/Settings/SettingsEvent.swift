import Observability

/// Analytics events the Settings feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions (opening a change-* screen,
/// toggling auto-lock, signing out) are breadcrumbs instead.
enum SettingsEvent: String, AnalyticsEvent {
	case detailsChanged
	case detailsChangeFailed
	case passwordChanged
	case passwordChangeFailed
	case genderChanged
	case genderChangeFailed

	var name: String {
		rawValue
	}
}
