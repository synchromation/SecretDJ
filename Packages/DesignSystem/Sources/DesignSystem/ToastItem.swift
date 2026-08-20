import Foundation

/// One piece of server-driven toast copy queued for display by ``ToastQueue``.
public struct ToastItem: Identifiable, Equatable, Sendable {
	public let id: UUID
	/// The message text, exactly as delivered by the server — already
	/// localized for the device's language, never a `LocalizedStringKey`.
	/// Still populated for a rich toast (``richContent``'s doc comment): it's
	/// what ``ToastPresenterModifier`` posts as the VoiceOver announcement,
	/// and what shows if a caller ever renders this item plainly.
	public let message: String
	/// How long this toast stays current before auto-dismissing.
	public let duration: Duration
	/// Non-nil for a server-driven "rich" (award-style) toast — LEGACY.md's
	/// rich-toast contract (`secretdjv3/RichToastView.swift`). ``ToastView``
	/// renders ``RichToastContent``'s artwork/VIP layout instead of the
	/// plain capsule when this is set.
	public let richContent: RichToastContent?

	public init(
		id: UUID = UUID(),
		message: String,
		duration: Duration = .seconds(3),
		richContent: RichToastContent? = nil,
	) {
		self.id = id
		self.message = message
		self.duration = duration
		self.richContent = richContent
	}
}
