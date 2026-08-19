import DesignSystem
import SwiftUI

/// The extra-content ticker's chrome (PLAN.md S6.9) — ``entry``'s artwork
/// and up to three text lines over ``DesignSystem/BannerSurface``, bottom-
/// anchored. One combined accessibility element per
/// ``DesignSystem/BannerSurface``'s own contract; this view adds only the
/// `.isButton` trait and the tap gesture, so VoiceOver announces the whole
/// row ("Now playing…, Bobby Womack, Across 110th Street") as a single
/// button.
///
/// Deliberately **not** keyed by `entry.id` (no `.id(entry.id)` on the
/// content passed to `BannerSurface`): every ten-second rotation just
/// updates this same view's text/image in place rather than tearing down
/// and recreating it, so VoiceOver never treats a rotation as new content —
/// no re-announcement, no focus movement, satisfying the accessibility
/// skill's motion rules without any bespoke handling here. The show/hide
/// crossfade (``isVisible``, D9's scroll-direction signal) is
/// `BannerSurface`'s own concern, including its `\.accessibilityReduceMotion`
/// handling — nothing to add for that either.
struct TickerView: View {
	let entry: ExtraContentEntry
	let isVisible: Bool
	let onTap: () -> Void

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	@ScaledMetric(relativeTo: .subheadline)
	private var artworkSize: CGFloat = 44

	var body: some View {
		BannerSurface(isVisible: isVisible, edge: .bottom) {
			Group {
				if dynamicTypeSize.isAccessibilitySize {
					VStack(alignment: .leading, spacing: Spacing.small) {
						artwork
						textStack(lineLimit: nil)
					}
				} else {
					HStack(spacing: Spacing.medium) {
						artwork
						textStack(lineLimit: 1)
						Spacer(minLength: 0)
					}
				}
			}
			.contentShape(Rectangle())
			.onTapGesture(perform: onTap)
			.accessibilityAddTraits(.isButton)
		}
	}

	private var artwork: some View {
		RemoteArtworkView(
			url: entry.imageURL,
			placeholderIcon: entry.placeholderIcon,
			size: artworkSize,
			shape: entry.artworkShape,
		)
	}

	private func textStack(lineLimit: Int?) -> some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			if let caption = entry.caption {
				Text(verbatim: caption)
					.font(Theme.TextStyle.caption.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(lineLimit)
			}

			if let title = entry.title {
				Text(verbatim: title)
					.font(Theme.TextStyle.cellTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)
					.lineLimit(lineLimit)
			}

			if let subtitle = entry.subtitle {
				Text(verbatim: subtitle)
					.font(Theme.TextStyle.cellSubtitle.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(lineLimit)
			}
		}
	}
}

// MARK: - Previews

#Preview("Song, visible") {
	VStack {
		Spacer()
		TickerView(entry: .previewSong, isVisible: true, onTap: {})
	}
}

#Preview("Person, visible") {
	VStack {
		Spacer()
		TickerView(entry: .previewPerson, isVisible: true, onTap: {})
	}
}

#Preview("Hidden") {
	VStack {
		Spacer()
		TickerView(entry: .previewSong, isVisible: false, onTap: {})
	}
}

#Preview("Dark mode") {
	VStack {
		Spacer()
		TickerView(entry: .previewSong, isVisible: true, onTap: {})
	}
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	VStack {
		Spacer()
		TickerView(entry: .previewSong, isVisible: true, onTap: {})
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

extension ExtraContentEntry {
	fileprivate static let previewSong = ExtraContentEntry(
		id: "song-1",
		kind: .song,
		imageURL: nil,
		placeholderIcon: .song,
		artworkShape: .rounded,
		caption: "Now playing…",
		title: "Bobby Womack",
		subtitle: "Across 110th Street",
	)

	fileprivate static let previewPerson = ExtraContentEntry(
		id: "person-1",
		kind: .person,
		imageURL: nil,
		placeholderIcon: .profile,
		artworkShape: .circle,
		caption: "Nick Banks",
		title: "12 places visited",
		subtitle: "134 people like you",
	)
}
