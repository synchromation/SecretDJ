/// Persists the counter's value between launches.
///
/// Abstracting storage behind this protocol keeps `CounterModel` free of
/// persistence details and lets tests and previews substitute an in-memory store.
protocol CounterStoring {
    func savedCount() -> Int
    func save(_ count: Int)
}
