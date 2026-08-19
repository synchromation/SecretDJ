import Observability

/// Analytics events ``CheckInModel`` can send.
///
/// One enum per feature keeps its complete analytics surface reviewable in
/// a single place (observability skill). Only the business moment
/// (`Checkin`, `secretdjv3/Reporting.swift`'s `ReportableEvent`) becomes an
/// analytics event; the attempt itself is a breadcrumb instead (mirrors
/// ``TopUpsEvent``'s doc comment).
enum CheckInEvent: String, AnalyticsEvent {
	case checkedIn
	case checkInFailed

	var name: String {
		rawValue
	}
}
