import SwiftUI

@main
struct UntitledProjectApp: App {
    @State private var counterModel = CounterModel(store: UserDefaultsCounterStore())

    var body: some Scene {
        WindowGroup {
            CounterView(model: counterModel)
        }
    }
}
