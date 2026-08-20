import SwiftUI

/// The colors a toast renders with — ``Theme``'s own sanctioned pairing by
/// default, or a venue skin's resolved chrome (the kiosk: PLAN.md S7.5,
/// `KioskSkin/toast`'s own doc comment on why its colors are pre-resolved
/// against contrast rather than trusted blindly).
public struct ToastAppearance: Equatable, Sendable {
	public let background: Color
	public let text: Color
	/// `nil` draws no border — ``ToastView``'s own shape has none by
	/// default, matching legacy's shared `ToastView` (LEGACY.md's kiosk
	/// toast ids 1010-1013 doc comment on `KioskSkin`).
	public let border: Color?
	public let borderWidth: CGFloat?

	public init(background: Color, text: Color, border: Color? = nil, borderWidth: CGFloat? = nil) {
		self.background = background
		self.text = text
		self.border = border
		self.borderWidth = borderWidth
	}

	/// `Theme`'s own already-sanctioned toast pairing — every call site
	/// before this type existed got this implicitly; now it's the explicit
	/// default so an app that never skins its toasts (the consumer) doesn't
	/// have to say so.
	public static let themed = ToastAppearance(
		background: Theme.ColorRole.toastSurface.color,
		text: Theme.ColorRole.toastText.color,
	)
}

/// Renders one ``ToastItem`` on `appearance`'s colors (``Theme``'s own
/// `toastSurface`/`toastText` pairing by default). Used by
/// ``ToastPresenterModifier``; construct directly only for previews or a
/// bespoke presentation.
///
/// A rich ``ToastItem`` (``ToastItem/richContent``) renders the award-style
/// card instead of the plain capsule (`secretdjv3/RichToastView.swift`'s
/// `populateViews(_:)`) — title/icon, headline, an optional VIP row
/// (avatar + two lines + a "view profile" tap target), and body copy. The
/// VIP row's tap fires ``onVipTap`` with its
/// ``RichToastContent/Vip/tapActionID`` — this view never resolves that id
/// to a real action itself (no navigation dependency belongs in
/// DesignSystem); the presenting layer does, mirroring
/// ``ToastPresenterModifier``'s own `onRichToastVipTapped` doc comment.
/// VoiceOver sees the whole card as one element (``ToastItem/message``'s own
/// already-localized copy as its label) with a named custom action for
/// viewing the profile when `vipActionLabel`/``onVipTap`` are both supplied
/// — never a second, separately-focusable button, so the "one element, one
/// clear action" shape holds for VoiceOver exactly as it does for the plain
/// toast's `.combine`d element.
public struct ToastView: View {
	let item: ToastItem
	let appearance: ToastAppearance
	/// The accessible name for the VIP row's custom action (e.g. "View
	/// Profile") — `nil` when the presenting layer never wires rich-toast
	/// taps (every plain-toast caller, and any app that never enqueues a
	/// rich ``ToastItem``, e.g. the kiosk — S8.6's kiosk-exclusion citation
	/// lives on ``SharedFeatures/TuneInScreen``). Left unset, the VIP row
	/// still renders and its visible button still fires ``onVipTap`` for a
	/// sighted tap; only the named VoiceOver action is skipped.
	let vipActionLabel: Text?
	let onVipTap: ((String) -> Void)?

	public init(
		item: ToastItem,
		appearance: ToastAppearance = .themed,
		vipActionLabel: Text? = nil,
		onVipTap: ((String) -> Void)? = nil,
	) {
		self.item = item
		self.appearance = appearance
		self.vipActionLabel = vipActionLabel
		self.onVipTap = onVipTap
	}

	public var body: some View {
		if let richContent = item.richContent {
			richBody(richContent)
		} else {
			plainBody
		}
	}

	private var plainBody: some View {
		Text(item.message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(appearance.text)
			.multilineTextAlignment(.center)
			.padding(.horizontal, Spacing.medium)
			.padding(.vertical, Spacing.small)
			.frame(minHeight: 44)
			.background {
				Capsule().fill(appearance.background)
			}
			.overlay {
				if let border = appearance.border {
					Capsule().strokeBorder(border, lineWidth: appearance.borderWidth ?? 1)
				}
			}
			.contentShape(.capsule)
			.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private func richBody(_ content: RichToastContent) -> some View {
		let card = VStack(alignment: .leading, spacing: Spacing.small) {
			Label {
				Text(content.title)
					.font(Theme.TextStyle.cellSubtitle.font)
			} icon: {
				Theme.Icon.award.image
			}
			.foregroundStyle(Theme.ColorRole.success.color)
			.accessibilityHidden(true)

			Text(content.headline)
				.font(Theme.TextStyle.cellTitle.font)
				.foregroundStyle(appearance.text)
				.accessibilityHidden(true)

			if let vip = content.vip {
				vipRow(vip)
			}

			if !content.bodyText.isEmpty {
				Text(content.bodyText)
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(appearance.text)
					.accessibilityHidden(true)
			}
		}
		.padding(Spacing.medium)
		.frame(minWidth: 44, minHeight: 44, alignment: .leading)
		.background {
			RoundedRectangle(cornerRadius: Spacing.medium, style: .continuous).fill(appearance.background)
		}
		.overlay {
			if let border = appearance.border {
				RoundedRectangle(cornerRadius: Spacing.medium, style: .continuous)
					.strokeBorder(border, lineWidth: appearance.borderWidth ?? 1)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(item.message))

		if let vip = content.vip, let vipActionLabel {
			card.accessibilityAction(named: vipActionLabel) { onVipTap?(vip.tapActionID) }
		} else {
			card
		}
	}

	/// The VIP's own visible tap target — a real, hit-testable `Button` for
	/// sighted/pointer interaction (``onVipTap``'s doc comment on why
	/// VoiceOver reaches the same action a different way instead of
	/// focusing this button directly).
	private func vipRow(_ vip: RichToastContent.Vip) -> some View {
		Button {
			onVipTap?(vip.tapActionID)
		} label: {
			HStack(spacing: Spacing.small) {
				RemoteArtworkView(url: vip.avatarURL, placeholderIcon: .profile, size: 44, shape: .circle)

				VStack(alignment: .leading, spacing: Spacing.extraSmall) {
					Text(vip.name)
						.font(Theme.TextStyle.cellSubtitle.font)
						.foregroundStyle(appearance.text)

					if let subtitle = vip.subtitle {
						Text(subtitle)
							.font(Theme.TextStyle.cellTitle.font)
							.foregroundStyle(appearance.text)
					}
				}

				Spacer(minLength: 0)

				Theme.Icon.disclosure.image
					.foregroundStyle(appearance.text)
			}
			.frame(minHeight: 44)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		// Exposed to VoiceOver as the outer card's own named action instead
		// of a second, separately-focusable element (this type's own doc
		// comment).
		.accessibilityHidden(true)
	}
}

#Preview("Short message") {
	ToastView(item: ToastItem(message: "Saved"))
}

#Preview("Long message") {
	ToastView(item: ToastItem(message: "X people buzzed this song — nice pick!"))
		.padding()
}

#Preview("Dark mode") {
	ToastView(item: ToastItem(message: "Saved"))
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	ToastView(item: ToastItem(message: "Saved to your favourites"))
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Rich toast, with VIP") {
	ToastView(
		item: ToastItem(message: previewRichContent.headline, richContent: previewRichContent),
		vipActionLabel: Text(verbatim: "View Profile"),
	)
	.padding()
}

#Preview("Rich toast, no VIP") {
	ToastView(item: ToastItem(
		message: "You earned a reward",
		richContent: RichToastContent(title: "Reward!", headline: "You earned a reward", bodyText: "", vip: nil),
	))
	.padding()
}

#Preview("Rich toast, dark mode") {
	ToastView(
		item: ToastItem(message: previewRichContent.headline, richContent: previewRichContent),
		vipActionLabel: Text(verbatim: "View Profile"),
	)
	.padding()
	.preferredColorScheme(.dark)
}

#Preview("Rich toast, accessibility text size") {
	ToastView(
		item: ToastItem(message: previewRichContent.headline, richContent: previewRichContent),
		vipActionLabel: Text(verbatim: "View Profile"),
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}

private var previewRichContent: RichToastContent {
	RichToastContent(
		title: "Reward!",
		headline: "You earned DJ status",
		bodyText: "Thanks for checking in tonight.",
		vip: RichToastContent.Vip(
			name: "oliverk",
			subtitle: "is DJ of Bench",
			avatarURL: nil,
			tapActionID: "00000087_feae54c9",
		),
	)
}
