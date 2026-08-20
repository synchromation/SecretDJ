import Foundation

/// The primitive rendering data for a server-driven "rich" (award-style)
/// toast — DesignSystem's own vocabulary for the domain-layer reward payload
/// (`SecretDJDomain.RichToastData`; `secretdjv3/RichToastView.swift`'s
/// `populateViews(_:)`/`setupVip(_:)`). The only place that domain concept
/// crosses into DesignSystem's primitive vocabulary, mirroring
/// `FeedUI/FeedCellProps`' own doc comment on why DesignSystem never sees a
/// Domain type directly (PLAN.md S3.2).
public struct RichToastContent: Equatable, Sendable {
	public let title: String
	public let headline: String
	public let bodyText: String
	public let vip: Vip?

	public init(title: String, headline: String, bodyText: String, vip: Vip?) {
		self.title = title
		self.headline = headline
		self.bodyText = bodyText
		self.vip = vip
	}

	/// The rewarded person's row — an avatar, two lines of copy, and a "view
	/// profile" tap target.
	public struct Vip: Equatable, Sendable {
		public let name: String
		public let subtitle: String?
		public let avatarURL: URL?
		/// Opaque identifier the presenting layer resolves to a navigation
		/// action when this row is tapped (the VIP's own person id) — kept a
		/// primitive `String` rather than a closure, so ``ToastItem`` stays a
		/// plain `Equatable`/`Sendable` value ``ToastQueue`` can hold and
		/// compare without capturing any app-specific behavior (the
		/// lazy-sections no-closures-in-queue-item discipline). The
		/// presenting layer maps this id to a real action —
		/// `ToastPresenterModifier`'s own `onRichToastTapped` doc comment.
		public let tapActionID: String

		public init(name: String, subtitle: String?, avatarURL: URL?, tapActionID: String) {
			self.name = name
			self.subtitle = subtitle
			self.avatarURL = avatarURL
			self.tapActionID = tapActionID
		}
	}
}
