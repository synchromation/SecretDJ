import Observability
import SwiftUI

/// Displays the current count with controls to change it.
struct CounterView: View {
	let model: CounterModel

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	@ScaledMetric(relativeTo: .largeTitle)
	private var countFontSize = 64

	var body: some View {
		VStack(spacing: 32) {
			countDisplay
			controls
		}
		.padding()
		.tracksScreen("Counter")
	}

	/// VoiceOver treats the count as one adjustable element: swipe up or
	/// down to change it without hunting for the buttons.
	private var countDisplay: some View {
		Text(model.count, format: .number)
			.font(.system(size: countFontSize, weight: .bold, design: .rounded))
			.contentTransition(.numericText())
			.animation(.snappy, value: model.count)
			.accessibilityLabel("Current count")
			.accessibilityValue("\(model.count)")
			.accessibilityAdjustableAction { direction in
				switch direction {
				case .increment:
					model.increment()
				case .decrement:
					model.decrement()
				@unknown default:
					break
				}
			}
	}

	/// At accessibility text sizes the change buttons stack vertically and
	/// show their titles; otherwise they sit side by side as icons.
	private var controls: some View {
		VStack(spacing: 16) {
			Group {
				if dynamicTypeSize.isAccessibilitySize {
					VStack(spacing: 16) {
						changeButtons
					}
					.labelStyle(.titleAndIcon)
				} else {
					HStack(spacing: 16) {
						changeButtons
					}
					.labelStyle(.iconOnly)
				}
			}
			.buttonStyle(.borderedProminent)

			Button("Reset") {
				model.reset()
			}
			.buttonStyle(.bordered)
		}
	}

	@ViewBuilder
	private var changeButtons: some View {
		Button("Decrement", systemImage: "minus") {
			model.decrement()
		}

		Button("Increment", systemImage: "plus") {
			model.increment()
		}
	}
}

#Preview("Fresh install") {
	CounterView(model: CounterModel(store: InMemoryCounterStore()))
}

#Preview("Existing count") {
	CounterView(model: CounterModel(store: InMemoryCounterStore(count: 41)))
}

#Preview("Negative count") {
	CounterView(model: CounterModel(store: InMemoryCounterStore(count: -7)))
}

#Preview("Accessibility text size") {
	CounterView(model: CounterModel(store: InMemoryCounterStore(count: 8)))
		.environment(\.dynamicTypeSize, .accessibility5)
}
