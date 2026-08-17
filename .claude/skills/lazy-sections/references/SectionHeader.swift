import SwiftUI

struct SectionHeader: View {
	let title: String
	let kind: SectionKind

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			// title is demo fixture text; a real section's title arrives
			// from the backend already localized (localization skill's
			// server-text rule), so Text(verbatim:) here only keeps this
			// fixture out of the live String Catalog.
			Text(verbatim: title)
				.font(.title3.weight(.bold))
				.lineLimit(1)
			Spacer(minLength: 8)
			// Demo-only badge naming the concrete lazy container; carries no
			// information a VoiceOver user needs (items stay navigable
			// regardless of container), so it's hidden from the
			// accessibility tree.
			Text(verbatim: kind.badgeLabel)
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.secondary)
				.padding(.horizontal, 8)
				.padding(.vertical, 3)
				.background(Color.primary.opacity(0.06), in: Capsule())
				.accessibilityHidden(true)
		}
		.padding(.horizontal, 16)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
	}
}

// MARK: - Previews

#Preview("Section header") {
	SectionHeader(title: "Fresh Picks", kind: .list)
}

#Preview("Accessibility text") {
	SectionHeader(title: "Fresh Picks", kind: .list)
		.environment(\.dynamicTypeSize, .accessibility5)
}
