import SecretDJDomain

/// A section ``FeedDisplayModel`` dropped because its template didn't map
/// to a ``FeedSectionKind`` (lazy-sections' unknown-kind rule): FeedUI never
/// guesses a layout for an unrecognized template. Carries what a caller
/// needs to log the drop through its own observability pipeline — FeedUI
/// itself does not depend on Observability (the S1.1 boundary note:
/// `Template.unsupported` exists for logging/metrics only).
public struct DroppedSection: Sendable, Hashable {
	public let template: Template
	public let title: String
	public let index: Int
}
