import SwiftUI

/// Displays the current count with controls to change it.
struct CounterView: View {
    let model: CounterModel

    var body: some View {
        VStack(spacing: 32) {
            countDisplay
            controls
        }
        .padding()
    }

    private var countDisplay: some View {
        Text(model.count, format: .number)
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
            .animation(.snappy, value: model.count)
            .accessibilityLabel("Current count")
            .accessibilityValue("\(model.count)")
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button("Decrement", systemImage: "minus") {
                    model.decrement()
                }

                Button("Increment", systemImage: "plus") {
                    model.increment()
                }
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.iconOnly)

            Button("Reset") {
                model.reset()
            }
            .buttonStyle(.bordered)
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
