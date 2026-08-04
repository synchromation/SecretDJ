import Observability

/// Analytics events the Counter feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions are breadcrumbs instead.
enum CounterEvent: String, AnalyticsEvent {
	/// The user deliberately started over from zero.
	case counterReset

	var name: String {
		rawValue
	}
}
