/// A place events go: the console, a crash reporter, an analytics platform.
///
/// Destinations receive every event and keep only what concerns them — the
/// routing policy (which levels become vendor breadcrumbs, what gets
/// captured) lives inside each destination, in one switch.
public protocol ObservabilityDestination: Sendable {
	/// Handles one event; must return quickly and never block the caller —
	/// destinations do their own buffering or dispatch if delivery is slow.
	func receive(_ event: ObservabilityEvent)
}
