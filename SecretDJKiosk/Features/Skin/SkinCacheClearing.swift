/// Clears every persisted venue skin (files + manifest snapshot) — the
/// ``KioskCacheClearing`` conformance ``KioskCacheClearing``'s own doc
/// comment names in advance: "S7.2's skin system will add one for its
/// downloaded venue skin assets". Registered alongside ``URLCacheClearing``
/// in ``KioskRootView``'s ``StaffResetModel`` construction; mirrors
/// legacy's `?RESTART?` handler, which "deletes all skin assets"
/// (LEGACY.md "Venue login and the skin system").
struct SkinCacheClearing: KioskCacheClearing {
	let storing: any SkinStoring

	func clear() {
		storing.clear()
	}
}
