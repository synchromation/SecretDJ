import Foundation

/// One piece of server-driven toast copy queued for display by ``ToastQueue``.
public struct ToastItem: Identifiable, Equatable, Sendable {
	public let id: UUID
	/// The message text, exactly as delivered by the server — already
	/// localized for the device's language, never a `LocalizedStringKey`.
	public let message: String
	/// How long this toast stays current before auto-dismissing.
	public let duration: Duration

	public init(id: UUID = UUID(), message: String, duration: Duration = .seconds(3)) {
		self.id = id
		self.message = message
		self.duration = duration
	}
}
