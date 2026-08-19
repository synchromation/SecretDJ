import SwiftUI

/// A vertical A–Z fast-scroll rail for jumping a long alphabetized list to a
/// letter — the SwiftUI replacement for the legacy `BDKCollectionIndexView`
/// (LEGACY.md "UI layer..." → "Misc"; "Gaps and cross-checks" →
/// "the rewrite needs a SwiftUI replacement for this behavior"). Generic
/// over whatever letters the caller groups its list by, so both the phone's
/// short index and any other bucketing scheme reuse the same view.
///
/// One combined interactive element rather than per-letter buttons: sighted
/// users drag anywhere in the strip to scrub through letters (a continuous
/// gesture, like the legacy control), while VoiceOver users step through
/// letters with the standard adjustable swipe-up/down gesture
/// (``accessibilityAdjustableAction(_:)``) — the accessibility skill's
/// "richer semantics over more elements" rule: an index this dense could
/// never offer discrete 44pt-tall letter targets, so it's one adjustable
/// element instead, matching `CounterView`'s count display.
public struct SectionIndexStrip: View {
	public let letters: [String]
	public let onSelect: (String) -> Void

	@State private var selectedIndex = 0

	/// The accessibility skill's minimum comfortable tap target — applied to
	/// the strip's width, since its height is whatever the caller's layout
	/// grants it and the strip is one combined element rather than
	/// per-letter targets.
	private static let minimumTapTarget: CGFloat = 44

	public init(letters: [String], onSelect: @escaping (String) -> Void) {
		self.letters = letters
		self.onSelect = onSelect
	}

	public var body: some View {
		GeometryReader { geometry in
			VStack(spacing: 0) {
				ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
					Text(verbatim: letter)
						.font(Theme.TextStyle.caption.font.weight(.semibold))
						.foregroundStyle(
							index == selectedIndex
								? Theme.ColorRole.accent.color
								: Theme.ColorRole.secondaryText.color,
						)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
			.contentShape(Rectangle())
			.gesture(
				DragGesture(minimumDistance: 0)
					.onChanged { value in
						select(at: Self.index(
							forDragY: value.location.y,
							height: geometry.size.height,
							letterCount: letters.count,
						))
					},
			)
		}
		.frame(minWidth: Self.minimumTapTarget)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(
			"Alphabet index",
			comment: "Accessibility label of the A–Z fast-scroll rail on an alphabetized list.",
		))
		.accessibilityValue(Text(verbatim: letters.indices.contains(selectedIndex) ? letters[selectedIndex] : ""))
		.accessibilityAdjustableAction { direction in
			select(at: Self.adjustedIndex(from: selectedIndex, direction: direction, letterCount: letters.count))
		}
	}

	private func select(at index: Int?) {
		guard let index, letters.indices.contains(index) else { return }
		selectedIndex = index
		onSelect(letters[index])
	}

	/// Maps a drag's y-offset within the strip to a letter index, clamped to
	/// the available letters. `nil` with no letters or no measured height —
	/// nothing to select. Pure and `static` so it's directly testable
	/// without a hosted view (tdd skill: view bodies aren't TDD'd, but this
	/// geometry math is logic).
	nonisolated static func index(forDragY y: CGFloat, height: CGFloat, letterCount: Int) -> Int? {
		guard letterCount > 0, height > 0 else { return nil }
		let row = Int((y / height) * CGFloat(letterCount))
		return min(max(row, 0), letterCount - 1)
	}

	/// The next index for one VoiceOver adjustable-action step, clamped to
	/// the available letters — stepping past either end holds at that end
	/// rather than wrapping.
	nonisolated static func adjustedIndex(
		from index: Int,
		direction: AccessibilityAdjustmentDirection,
		letterCount: Int,
	) -> Int {
		guard letterCount > 0 else { return 0 }
		switch direction {
		case .increment:
			return min(index + 1, letterCount - 1)
		case .decrement:
			return max(index - 1, 0)
		@unknown default:
			return index
		}
	}
}

// MARK: - Previews

#Preview("Section index strip") {
	SectionIndexStrip(letters: (65 ... 90).map { String(UnicodeScalar($0)) }, onSelect: { _ in })
		.frame(height: 400)
		.padding()
}

#Preview("Short letter set") {
	SectionIndexStrip(letters: ["A", "B", "C", "#"], onSelect: { _ in })
		.frame(height: 200)
		.padding()
}

#Preview("Dark mode") {
	SectionIndexStrip(letters: (65 ... 90).map { String(UnicodeScalar($0)) }, onSelect: { _ in })
		.frame(height: 400)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	SectionIndexStrip(letters: (65 ... 90).map { String(UnicodeScalar($0)) }, onSelect: { _ in })
		.frame(height: 400)
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
