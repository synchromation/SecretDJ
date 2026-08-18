import SwiftUI

/// A person row: circular avatar-or-icon, screen name/subtitle, and an
/// optional trailing accessory — ``MediaRowCell`` configured for the one
/// visual difference a person row has (a circular avatar instead of a
/// rounded-rectangle thumbnail).
public struct PersonRowCell: View {
	let avatarURL: URL?
	let name: String
	let subtitle: String?
	let accessory: MediaRowCell.Accessory?

	public init(
		avatarURL: URL? = nil,
		name: String,
		subtitle: String? = nil,
		accessory: MediaRowCell.Accessory? = nil,
	) {
		self.avatarURL = avatarURL
		self.name = name
		self.subtitle = subtitle
		self.accessory = accessory
	}

	public var body: some View {
		MediaRowCell(
			artworkURL: avatarURL,
			placeholderIcon: .profile,
			title: name,
			subtitle: subtitle,
			accessory: accessory,
			artworkShape: .circle,
		)
	}
}

// MARK: - Previews

#Preview("Person row") {
	PersonRowCell(name: "Nick Banks", subtitle: "12 places visited", accessory: .chevron)
		.padding()
}

#Preview("Liked") {
	PersonRowCell(name: "Nick Banks", accessory: .like(isLiked: true, summary: "You buzzed this person"))
		.padding()
}

#Preview("Dark mode") {
	PersonRowCell(name: "Nick Banks", subtitle: "12 places visited", accessory: .chevron)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	PersonRowCell(name: "Nicholas Bartholomew Banks III", subtitle: "12 places visited", accessory: .chevron)
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
