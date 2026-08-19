import Observability

/// Analytics events the Account feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions (signing out, opening the
/// deletion screen) are breadcrumbs instead.
enum AccountEvent: String, AnalyticsEvent {
	/// `requestdeleteaccount` succeeded — the account is now REQUESTED for
	/// deletion server-side.
	case accountDeletionRequested
	/// `requestdeleteaccount` failed; the account is unaffected.
	case accountDeletionRequestFailed

	var name: String {
		rawValue
	}
}
