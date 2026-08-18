import SwiftUI

/// A purchasable credit bundle row: title/subtitle leading, price trailing,
/// with a chevron affordance — the `topUp` template's cell.
public struct TopUpRowCell: View {
	let title: String
	let subtitle: String?
	let priceText: String

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	@ScaledMetric(relativeTo: .subheadline)
	private var rowHeight: CGFloat = 64

	public init(title: String, subtitle: String? = nil, priceText: String) {
		self.title = title
		self.subtitle = subtitle
		self.priceText = priceText
	}

	public var body: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(alignment: .leading, spacing: Spacing.small) {
					textStack(lineLimit: nil)
					HStack {
						priceLabel
						Spacer(minLength: 0)
						chevron
					}
				}
				.padding(Spacing.medium)
			} else {
				HStack(spacing: Spacing.medium) {
					textStack(lineLimit: 1)
					Spacer(minLength: 0)
					priceLabel
					chevron
				}
				.padding(.horizontal, Spacing.medium)
				.frame(height: rowHeight)
			}
		}
		.background(Theme.ColorRole.cellSurface.color, in: RoundedRectangle(cornerRadius: 14))
		.accessibilityElement(children: .combine)
	}

	private func textStack(lineLimit: Int?) -> some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			Text(verbatim: title)
				.font(Theme.TextStyle.cellTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.lineLimit(lineLimit)

			if let subtitle {
				Text(verbatim: subtitle)
					.font(Theme.TextStyle.cellSubtitle.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(lineLimit)
			}
		}
	}

	private var priceLabel: some View {
		Text(verbatim: priceText)
			.font(Theme.TextStyle.cellTitle.font)
			.foregroundStyle(Theme.ColorRole.accent.color)
	}

	private var chevron: some View {
		Theme.Icon.disclosure.image
			.font(.caption.weight(.semibold))
			.foregroundStyle(Theme.ColorRole.secondaryText.color)
			.accessibilityHidden(true)
	}
}

// MARK: - Previews

#Preview("Top-up row") {
	TopUpRowCell(title: "20 credits", subtitle: "Best value", priceText: "£1.99")
		.padding()
}

#Preview("No subtitle") {
	TopUpRowCell(title: "5 credits", priceText: "£0.99")
		.padding()
}

#Preview("Dark mode") {
	TopUpRowCell(title: "20 credits", subtitle: "Best value", priceText: "£1.99")
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	TopUpRowCell(title: "20 credits", subtitle: "Best value — most popular with regulars", priceText: "£1.99")
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
