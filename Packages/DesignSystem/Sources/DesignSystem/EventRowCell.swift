import SwiftUI

/// An activity/check-in/award event row: an icon beside the server's own
/// tagged lines, rendered as-is rather than squeezed into a title/subtitle
/// shape (LEGACY.md: the server pre-formats each cell's lines and the
/// client only splits and displays them — an event's line count varies more
/// than a plain row's, so this cell has no fixed height and no line limit;
/// text wraps freely instead of clipping (accessibility skill)).
public struct EventRowCell: View {
	let icon: Theme.Icon
	let lines: [String]

	@ScaledMetric(relativeTo: .subheadline)
	private var iconBoxSize: CGFloat = 36

	public init(icon: Theme.Icon, lines: [String]) {
		self.icon = icon
		self.lines = lines
	}

	public var body: some View {
		HStack(alignment: .top, spacing: Spacing.medium) {
			icon.image
				.font(.body.weight(.semibold))
				.foregroundStyle(Theme.ColorRole.accentText.color)
				.frame(width: iconBoxSize, height: iconBoxSize)
				.background(Theme.ColorRole.accent.color, in: Circle())
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: Spacing.extraSmall) {
				ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
					Text(verbatim: line)
						.font(index == 0 ? Theme.TextStyle.cellTitle.font : Theme.TextStyle.cellSubtitle.font)
						.foregroundStyle(index == 0 ? Theme.ColorRole.primaryText.color : Theme.ColorRole.secondaryText
							.color)
				}
			}

			Spacer(minLength: 0)
		}
		.padding(Spacing.medium)
		.background(Theme.ColorRole.cellSurface.color, in: RoundedRectangle(cornerRadius: 14))
		.accessibilityElement(children: .combine)
	}
}

// MARK: - Previews

#Preview("Check-in event") {
	EventRowCell(icon: .checkIn, lines: ["You checked in at The Fox", "Chiswick · 2 hours ago"])
		.padding()
}

#Preview("Award event") {
	EventRowCell(icon: .award, lines: ["New badge unlocked: Regular", "5 visits to The Fox", "Keep it up!"])
		.padding()
}

#Preview("Single line") {
	EventRowCell(icon: .checkIn, lines: ["You checked in at The Fox"])
		.padding()
}

#Preview("Dark mode") {
	EventRowCell(icon: .award, lines: ["New badge unlocked: Regular", "5 visits to The Fox"])
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	EventRowCell(
		icon: .award,
		lines: ["New badge unlocked: Regular Visitor", "5 visits to The Fox and Hounds", "Keep up the great work!"],
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
