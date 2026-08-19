import Observability

/// Analytics events the TopUps feature can send.
///
/// One enum per feature keeps the feature's complete analytics surface
/// reviewable in a single place. Only business-meaningful moments become
/// analytics events — routine interactions (voucher redemption, restore)
/// are breadcrumbs instead (PLAN.md S6.7 SCOPE: "purchase initiated/
/// completed analytics — business moments; failures reported; voucher
/// redemption breadcrumbed").
enum TopUpsEvent: String, AnalyticsEvent {
	case purchaseInitiated
	case purchaseCompleted
	case purchaseFailed

	var name: String {
		rawValue
	}
}
