import Observability

/// Analytics events the Login feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions are breadcrumbs instead.
enum LoginEvent: String, AnalyticsEvent {
	/// A brand-new account was created via the native sign-up form.
	case accountCreated

	/// A brand-new account was created via Sign in with Apple.
	case appleAccountCreated

	var name: String {
		rawValue
	}
}
