import SwiftUI

/// An interactive like/unlike ("buzz") toggle — the tappable counterpart to
/// ``MediaRowCell/Accessory/like(isLiked:summary:)``'s read-only rendering.
/// Every caller supplies its own accessible name (``accessibilityLabel``,
/// e.g. "Like this venue") since the same control serves venues (S6.2),
/// songs (S6.3), and people (S6.6) — the icon and any visible `summary`
/// alone never carry enough meaning for VoiceOver to announce what's being
/// liked.
public struct LikeButton: View {
	let isLiked: Bool
	/// The server's own pre-rendered, already-localized like-summary copy
	/// (e.g. "12 people buzzed this"), shown next to the icon when present.
	let summary: String?
	let isBusy: Bool
	let accessibilityLabel: Text
	let action: () -> Void

	public init(
		isLiked: Bool,
		summary: String?,
		isBusy: Bool = false,
		accessibilityLabel: Text,
		action: @escaping () -> Void,
	) {
		self.isLiked = isLiked
		self.summary = summary
		self.isBusy = isBusy
		self.accessibilityLabel = accessibilityLabel
		self.action = action
	}

	/// The system minimum for a comfortable tap target
	/// (accessibility skill: "Hit targets at least 44×44 points"). Applied
	/// explicitly because this control's content — an icon alone, with no
	/// `summary` — would otherwise shrink to the bare glyph's bounds.
	private static let minimumTapTarget: CGFloat = 44

	public var body: some View {
		Button(action: action) {
			HStack(spacing: Spacing.small) {
				(isLiked ? Theme.Icon.likeFilled : Theme.Icon.like).image
					.foregroundStyle(isLiked ? Theme.ColorRole.accent.color : Theme.ColorRole.secondaryText.color)
					.accessibilityHidden(true)

				if let summary, !summary.isEmpty {
					Text(verbatim: summary)
						.font(Theme.TextStyle.cellSubtitle.font)
						.foregroundStyle(Theme.ColorRole.secondaryText.color)
				}
			}
			.frame(minWidth: Self.minimumTapTarget, minHeight: Self.minimumTapTarget, alignment: .leading)
			.contentShape(Rectangle())
		}
		.disabled(isBusy)
		.accessibilityLabel(accessibilityLabel)
		.accessibilityValue(accessibilityValue)
		.accessibilityAddTraits(isLiked ? [.isSelected] : [])
	}

	/// The server's summary, verbatim (already localized), when present;
	/// otherwise a client-side fallback naming the boolean state — so
	/// VoiceOver always has something to announce even for a
	/// never-yet-liked item with no server copy at all.
	private var accessibilityValue: Text {
		if let summary, !summary.isEmpty {
			Text(verbatim: summary)
		} else if isLiked {
			Text(
				"Liked",
				comment: "Accessibility value of a like button when the item has no server-provided like summary yet.",
			)
		} else {
			Text(
				"Not liked",
				comment: "Accessibility value of a like button when the item has no server-provided like summary yet.",
			)
		}
	}
}

// MARK: - Previews

#Preview("Not liked") {
	LikeButton(isLiked: false, summary: nil, accessibilityLabel: Text(verbatim: "Like this venue"), action: {})
		.padding()
}

#Preview("Liked, with server summary") {
	LikeButton(
		isLiked: true,
		summary: "12 people buzzed this",
		accessibilityLabel: Text(verbatim: "Like this venue"),
		action: {},
	)
	.padding()
}

#Preview("Busy") {
	LikeButton(
		isLiked: false,
		summary: "12 people buzzed this",
		isBusy: true,
		accessibilityLabel: Text(verbatim: "Like this venue"),
		action: {},
	)
	.padding()
}

#Preview("Dark mode") {
	LikeButton(
		isLiked: true,
		summary: "12 people buzzed this",
		accessibilityLabel: Text(verbatim: "Like this venue"),
		action: {},
	)
	.padding()
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	LikeButton(
		isLiked: true,
		summary: "148 people have buzzed this venue over the last month",
		accessibilityLabel: Text(verbatim: "Like this venue"),
		action: {},
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
