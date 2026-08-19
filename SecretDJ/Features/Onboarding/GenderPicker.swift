import DesignSystem
import SecretDJDomain
import SwiftUI

/// The three-way gender picker shared by the Apple route's onboarding
/// gender step (``GenderStepView``) and Settings' change-gender screen
/// (S6.11) — the same three options in the same layout, reused rather than
/// duplicated (`secretdjv3/LoginGenderViewController.swift`'s three
/// buttons).
struct GenderPicker: View {
	/// The currently highlighted option, or `nil` for none.
	let selected: Gender?
	let onSelect: (Gender) -> Void
	/// Disables every option — Settings' screen sets this while a save is in
	/// flight, since it submits immediately on tap rather than waiting for a
	/// separate confirm step.
	var isDisabled = false

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	var body: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(spacing: Spacing.small) {
					optionButtons
				}
			} else {
				HStack(spacing: Spacing.small) {
					optionButtons
				}
			}
		}
	}

	@ViewBuilder
	private var optionButtons: some View {
		option(title: "Female", gender: .female)
		option(title: "Male", gender: .male)
		option(title: "Prefer Not To Say", gender: .unisex)
	}

	private func option(title: LocalizedStringResource, gender: Gender) -> some View {
		let isSelected = selected == gender

		return Button {
			onSelect(gender)
		} label: {
			HStack(spacing: Spacing.extraSmall) {
				Text(title)
				if isSelected {
					Image(systemName: "checkmark.circle.fill")
						.accessibilityHidden(true)
				}
			}
			.frame(maxWidth: .infinity)
			.padding()
			.frame(minHeight: 44)
			.background(
				isSelected ? Theme.ColorRole.accent.color : Theme.ColorRole.cellSurface.color,
				in: .rect(cornerRadius: 12),
			)
			.foregroundStyle(isSelected ? Theme.ColorRole.accentText.color : Theme.ColorRole.primaryText.color)
		}
		.disabled(isDisabled)
		.accessibilityAddTraits(isSelected ? [.isSelected] : [])
	}
}
