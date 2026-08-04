/// Persists the counter's value between launches.
///
/// Abstracting storage behind this protocol keeps ``CounterModel`` free of
/// persistence details and lets tests and previews substitute an in-memory store.
protocol CounterStoring {
	/// The last count saved, or zero when nothing has ever been saved.
	func savedCount() -> Int

	/// Replaces the saved count; saving the same value repeatedly is harmless.
	func save(_ count: Int)
}
