import SwiftUI

/// A themed loading indicator with an optional status message. Carries no
/// copy of its own — callers build `message` from their own String Catalog
/// so it stays app-side.
public struct ProgressSurface: View {
	let message: Text?

	public init(message: Text? = nil) {
		self.message = message
	}

	public var body: some View {
		VStack(spacing: Spacing.small) {
			ProgressView()
				.tint(Theme.ColorRole.accent.color)

			if let message {
				message
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.multilineTextAlignment(.center)
			}
		}
		.padding(Spacing.large)
		.accessibilityElement(children: .combine)
	}
}

#Preview("Spinner only") {
	ProgressSurface()
}

#Preview("With message") {
	ProgressSurface(message: Text(verbatim: "Loading the jukebox…"))
}

#Preview("Dark mode") {
	ProgressSurface(message: Text(verbatim: "Loading the jukebox…"))
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	ProgressSurface(message: Text(verbatim: "Loading the jukebox…"))
		.environment(\.dynamicTypeSize, .accessibility5)
}
