import Foundation

/// Stores the counter's value in `UserDefaults`.
struct UserDefaultsCounterStore: CounterStoring {
    private static let countKey = "counter.count"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savedCount() -> Int {
        defaults.integer(forKey: Self.countKey)
    }

    func save(_ count: Int) {
        defaults.set(count, forKey: Self.countKey)
    }
}
