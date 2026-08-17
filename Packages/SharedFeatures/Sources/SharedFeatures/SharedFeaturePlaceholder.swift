import CoreGraphics
import DesignSystem
import FeedUI
import SecretDJDomain

/// Composes ``SecretDJDomain``, ``FeedUI``, and ``DesignSystem`` into one
/// value, proving this package's dependency graph resolves end to end.
public struct SharedFeaturePlaceholder: Equatable, Sendable {
	/// Whether the feed behind `cached`/`latest` needs to reload.
	public let needsReload: Bool

	/// The spacing this placeholder renders its content with.
	public let contentSpacing: CGFloat

	/// Builds the placeholder from a feed's cached/latest hashes, defaulting
	/// its spacing to the design system's medium token.
	public init(cached: FeedHash, latest: FeedHash, contentSpacing: CGFloat = Spacing.medium) {
		needsReload = FeedRenderState(cached: cached, latest: latest).needsReload
		self.contentSpacing = contentSpacing
	}
}
