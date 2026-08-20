import DesignSystem
import SwiftUI

/// The kiosk's permanent now-playing header (PLAN.md S7.4): artwork, title,
/// and artist at kiosk scale, cross-fading between songs — legacy's own
/// `KioskNowPlayingViewController` header, minus the full-bleed-vs-blurred
/// artwork distinction (``SharedFeatures/TuneInScreen``'s own doc comment
/// already trims that same legacy effect for S6.3b; no other screen in this
/// rewrite carries it forward either). Intermission suppresses artwork
/// entirely and centers its two-line message instead.
struct KioskNowPlayingHeaderView: View {
	let display: KioskNowPlayingDisplay

	@Environment(\.kioskSkin) private var kioskSkin

	var body: some View {
		ZStack {
			background

			content
				.padding(.horizontal, Spacing.large)
		}
		.frame(maxWidth: .infinity)
		.frame(height: CGFloat(kioskSkin.headerHeight ?? Self.defaultHeight))
		.clipped()
		.accessibilityElement(children: .combine)
	}

	/// `220` when the skin didn't configure a `headerHeight` text property
	/// (LEGACY.md's `headerHeight`/1003 id) — generous enough at iPad scale
	/// for a title/artist pair plus artwork without crowding.
	private static let defaultHeight: Int = 220

	@ViewBuilder
	private var background: some View {
		if let imageURL = kioskSkin.headerBackgroundImageURL {
			AsyncImage(url: imageURL) { phase in
				if case .success(let image) = phase {
					image.resizable().scaledToFill()
				} else {
					tintedBackground
				}
			}
		} else {
			tintedBackground
		}
	}

	/// The skin's own tint (or ``Theme``'s accent fallback) washed over the
	/// secondary background — used whenever the skin configured no header
	/// image, and while one is still downloading/failed to load.
	private var tintedBackground: some View {
		Theme.ColorRole.secondaryBackground.color
			.overlay(kioskSkin.headerTint.color.opacity(0.15))
	}

	@ViewBuilder
	private var content: some View {
		switch display {
		case .idle:
			idleContent

		case .nowPlaying(let title, let artist, let artworkURL):
			nowPlayingContent(title: title, artist: artist, artworkURL: artworkURL)

		case .intermission(let title, let subtitle):
			intermissionContent(title: title, subtitle: subtitle)
		}
	}

	private var idleContent: some View {
		Text(
			"Nothing playing yet",
			comment: "Shown in the kiosk's now-playing header before this venue's first song of the session.",
		)
		.font(Theme.TextStyle.sectionHeader.font)
		.foregroundStyle(Theme.ColorRole.secondaryText.color)
	}

	private func nowPlayingContent(title: String, artist: String, artworkURL: URL?) -> some View {
		HStack(spacing: Spacing.large) {
			RemoteArtworkView(url: artworkURL, placeholderIcon: .nowPlaying, size: Self.artworkSize)

			VStack(alignment: .leading, spacing: Spacing.extraSmall) {
				Text(verbatim: title)
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)
					.lineLimit(2)

				Text(verbatim: artist)
					.font(Theme.TextStyle.sectionHeader.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(1)
			}

			Spacer(minLength: 0)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.id(title + artist)
		.transition(.opacity)
	}

	/// Fixed rather than derived from `headerHeight`, so a very tall/short
	/// skinned header never produces comically over/undersized artwork.
	private static let artworkSize: CGFloat = 160

	private func intermissionContent(title: String, subtitle: String) -> some View {
		VStack(spacing: Spacing.small) {
			Text(verbatim: title)
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.multilineTextAlignment(.center)

			if !subtitle.isEmpty {
				Text(verbatim: subtitle)
					.font(Theme.TextStyle.sectionHeader.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.multilineTextAlignment(.center)
			}
		}
		.frame(maxWidth: .infinity)
		.id(title + subtitle)
		.transition(.opacity)
	}
}

// MARK: - Previews

#Preview("Now playing") {
	KioskNowPlayingHeaderView(display: .nowPlaying(title: "Yellow", artist: "Coldplay", artworkURL: nil))
}

#Preview("Intermission") {
	KioskNowPlayingHeaderView(display: .intermission(
		title: "Back in ten minutes",
		subtitle: "Grab another drink at the bar!",
	))
}

#Preview("Idle") {
	KioskNowPlayingHeaderView(display: .idle)
}

#Preview("Skinned") {
	KioskNowPlayingHeaderView(display: .nowPlaying(title: "Yellow", artist: "Coldplay", artworkURL: nil))
		.environment(\.kioskSkin, KioskSkin(
			toast: ResolvedToastAppearance(
				background: .themeFallback(.toastSurface),
				text: .themeFallback(.toastText),
				border: nil,
				borderWidth: nil,
			),
			headerTint: .skin(Theme.RGBAComponents(red: 0.8, green: 0.1, blue: 0.4)),
			headerBackgroundImageURL: nil,
			headerHeight: 260,
		))
}

#Preview("Accessibility text size") {
	KioskNowPlayingHeaderView(display: .nowPlaying(title: "Yellow", artist: "Coldplay", artworkURL: nil))
		.environment(\.dynamicTypeSize, .accessibility5)
}
