import SwiftUI

@main
struct ExampleApp: App {
	@State private var counterModel = CounterModel(store: UserDefaultsCounterStore())

	var body: some Scene {
		WindowGroup {
			CounterView(model: counterModel)
		}
	}
}
