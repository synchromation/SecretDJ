import Observability

/// Analytics events the Skin feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions are breadcrumbs instead.
enum SkinEvent: String, AnalyticsEvent {
	/// A venue's skin finished downloading and applying for the first time
	/// on this device (mirrors legacy's own `ReportableEvent.getSkinAssets`
	/// — `secretdjv3/SkinAPIAccess.swift`). Not sent on a cache hit: that
	/// path does nothing business-meaningful, it's a relaunch skipping work
	/// already done.
	case skinDownloaded

	var name: String {
		rawValue
	}
}
