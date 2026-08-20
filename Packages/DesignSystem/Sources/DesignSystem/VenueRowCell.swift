import SwiftUI

/// A venue row: artwork-or-icon, name/address, and up to two trailing status
/// badges (jukebox availability, check-in state) shown together rather than
/// through a single ``MediaRowCell/Accessory``, since a venue can carry both
/// at once.
public struct VenueRowCell: View {
	let artworkURL: URL?
	let name: String
	let address: String?
	let hasJukebox: Bool
	let isCheckedIn: Bool

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	@ScaledMetric(relativeTo: .subheadline)
	private var artworkSize: CGFloat = 44
	@ScaledMetric(relativeTo: .subheadline)
	private var rowHeight: CGFloat = 64

	public init(
		artworkURL: URL? = nil,
		name: String,
		address: String? = nil,
		hasJukebox: Bool = false,
		isCheckedIn: Bool = false,
	) {
		self.artworkURL = artworkURL
		self.name = name
		self.address = address
		self.hasJukebox = hasJukebox
		self.isCheckedIn = isCheckedIn
	}

	public var body: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(alignment: .leading, spacing: Spacing.small) {
					HStack {
						artwork
						Spacer(minLength: 0)
						badges
					}
					textStack(lineLimit: nil)
				}
				.padding(Spacing.medium)
			} else {
				HStack(spacing: Spacing.medium) {
					artwork
					textStack(lineLimit: 1)
					Spacer(minLength: 0)
					badges
				}
				.padding(.horizontal, Spacing.medium)
				// `minHeight`, not a fixed `height` — see `TopUpRowCell`'s own
				// comment (PLAN.md S8.2): a hard-fixed frame around
				// `lineLimit(1)` text is a Dynamic Type clipping risk.
				.frame(minHeight: rowHeight)
			}
		}
		.background(Theme.ColorRole.cellSurface.color, in: RoundedRectangle(cornerRadius: 14))
		.accessibilityElement(children: .combine)
	}

	private var artwork: some View {
		RemoteArtworkView(url: artworkURL, placeholderIcon: .venue, size: artworkSize)
	}

	private func textStack(lineLimit: Int?) -> some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			Text(verbatim: name)
				.font(Theme.TextStyle.cellTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.lineLimit(lineLimit)

			if let address {
				Text(verbatim: address)
					.font(Theme.TextStyle.cellSubtitle.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(lineLimit)
			}
		}
	}

	/// isCheckedIn/hasJukebox are the only signal for these badges: color
	/// alone never carries the state (accessibility skill), so each badge's
	/// presence — not its tint — is what communicates it, and both fold into
	/// the row's combined accessibility element via their default symbol
	/// labels rather than staying hidden, since (unlike a chevron) their
	/// presence is real information a sighted user also only gets from the icon.
	private var badges: some View {
		HStack(spacing: Spacing.extraSmall) {
			if hasJukebox {
				Theme.Icon.jukebox.image
					.font(.caption)
					.foregroundStyle(Theme.ColorRole.accent.color)
			}
			if isCheckedIn {
				Theme.Icon.checkIn.image
					.font(.caption)
					.foregroundStyle(Theme.ColorRole.success.color)
			}
		}
	}
}

// MARK: - Previews

#Preview("Venue row") {
	VenueRowCell(name: "The Fox", address: "123 High Street, Chiswick", hasJukebox: true)
		.padding()
}

#Preview("Checked in") {
	VenueRowCell(name: "The Fox", address: "123 High Street, Chiswick", hasJukebox: true, isCheckedIn: true)
		.padding()
}

#Preview("Dark mode") {
	VenueRowCell(name: "The Fox", address: "123 High Street, Chiswick", hasJukebox: true, isCheckedIn: true)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	VenueRowCell(
		name: "The Fox and Hounds Chiswick",
		address: "123 High Street, Chiswick, London",
		hasJukebox: true,
		isCheckedIn: true,
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
