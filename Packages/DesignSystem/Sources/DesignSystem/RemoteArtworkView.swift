import SwiftUI

/// A themed async image for feed cells. Width and height are always the
/// caller's own already-scaled dimensions (this package's `@ScaledMetric`
/// convention lives at the call site, not here) — the frame never grows to
/// fit the loaded image, so a cell's layout never waits on image decode
/// (lazy-sections' scroll-performance rules).
///
/// No caching layer of its own: the platform's default `URLCache` is enough
/// at this stage. A dedicated image cache (in-memory decoded-image cache,
/// prefetching, ...) is a later optimization only if scroll profiling
/// (PLAN.md S3.5) calls for one.
///
/// Purely decorative — always hidden from accessibility, because every cell
/// that places one also renders the same information as text, and the two
/// combine into one spoken element (lazy-sections' combined-element rule).
public struct RemoteArtworkView: View {
	/// How the artwork's corners resolve.
	public enum Shape: Hashable, Sendable {
		/// A song, venue, or card's rounded rectangle.
		case rounded
		/// A person's circular avatar.
		case circle
	}

	let url: URL?
	let placeholderIcon: Theme.Icon
	/// `nil` fills whatever width its container offers (a promotion banner);
	/// a value fixes it (an avatar, a card's artwork).
	let width: CGFloat?
	let height: CGFloat
	let shape: Shape
	/// The `.rounded` shape's corner radius. `nil` falls back to the
	/// proportional `height * 0.2` this design system uses for its card/tile
	/// artwork (`CardCell`/`TileCell`/`PromotionCell`, none of which this
	/// pass revisits); the flat row family (`MediaRowCell`/`VenueRowCell`/
	/// `PersonRowCell`) instead passes a fixed, Dynamic-Type-scaled 12pt
	/// (S9.6: `StyleKit2023.getCornerRadius(.size3x3)` ==
	/// `MatrixMediumCornerRadius` == `3 * gridUnit` == 12,
	/// `secretdjv3/StyleKit2023.swift:29`, applied to every flat row's
	/// artwork via `BaseCollectionViewCell.awakeFromNib`'s
	/// `isCornerRadiusView` check, `secretdjv3/BaseCollectionViewCell.swift
	/// :80-85` — legacy's corner radius is a fixed point value per template
	/// family, never proportional to the artwork's own pixel size, so the
	/// proportional default was never legacy-matched for that family).
	let cornerRadius: CGFloat?

	public init(
		url: URL?,
		placeholderIcon: Theme.Icon,
		width: CGFloat?,
		height: CGFloat,
		shape: Shape = .rounded,
		cornerRadius: CGFloat? = nil,
	) {
		self.url = url
		self.placeholderIcon = placeholderIcon
		self.width = width
		self.height = height
		self.shape = shape
		self.cornerRadius = cornerRadius
	}

	/// A square artwork view — the common case for row avatars and card/tile
	/// thumbnails.
	public init(
		url: URL?,
		placeholderIcon: Theme.Icon,
		size: CGFloat,
		shape: Shape = .rounded,
		cornerRadius: CGFloat? = nil,
	) {
		self.init(
			url: url,
			placeholderIcon: placeholderIcon,
			width: size,
			height: size,
			shape: shape,
			cornerRadius: cornerRadius,
		)
	}

	public var body: some View {
		AsyncImage(url: url) { phase in
			if case .success(let image) = phase {
				image
					.resizable()
					.scaledToFill()
			} else {
				placeholder
			}
		}
		.frame(width: width, height: height)
		.frame(maxWidth: width == nil ? .infinity : nil)
		.background(Theme.ColorRole.secondaryBackground.color)
		.clipShape(clipShape)
		.accessibilityHidden(true)
	}

	private var placeholder: some View {
		placeholderIcon.image
			.font(.system(size: height * 0.4).weight(.semibold))
			.foregroundStyle(Theme.ColorRole.secondaryText.color)
	}

	private var clipShape: AnyShape {
		switch shape {
		case .rounded: AnyShape(RoundedRectangle(cornerRadius: cornerRadius ?? height * 0.2, style: .continuous))
		case .circle: AnyShape(Circle())
		}
	}
}

// MARK: - Previews

#Preview("Rounded placeholder") {
	RemoteArtworkView(url: nil, placeholderIcon: .song, size: 64)
		.padding()
}

#Preview("Circular placeholder") {
	RemoteArtworkView(url: nil, placeholderIcon: .profile, size: 64, shape: .circle)
		.padding()
}

#Preview("Flexible width placeholder") {
	RemoteArtworkView(url: nil, placeholderIcon: .promotion, width: nil, height: 120)
		.padding()
}

#Preview("Dark mode") {
	RemoteArtworkView(url: nil, placeholderIcon: .song, size: 64)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	RemoteArtworkView(url: nil, placeholderIcon: .song, size: 64)
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
