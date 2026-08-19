import Testing

@testable import SecretDJKiosk

/// ``SkinCacheClearing`` — the ``KioskCacheClearing`` conformance the staff
/// reset registers for the skin system (``KioskCacheClearing``'s own doc
/// comment: "S7.2's skin system will add one for its downloaded venue skin
/// assets").
@MainActor
struct SkinCacheClearingTests {
	@Test func `clears the underlying skin store`() {
		let storing = InMemorySkinStoring()
		_ = try? storing.save(venueId: "v1", manifest: SkinManifestFixture.make(), assetData: [:])
		let clearing = SkinCacheClearing(storing: storing)

		clearing.clear()

		#expect(storing.loadSnapshot(venueId: "v1") == nil)
	}
}
