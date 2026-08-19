import Foundation
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// ``FileManagerSkinStoring`` — the production ``SkinStoring``: persists a
/// downloaded skin (manifest fields + asset bytes) under a scratch
/// directory standing in for Application Support (swift-testing's
/// determinism rule: isolate a real adapter with a temp directory, never
/// touch the real one from a unit test), so relaunches can
/// ``SkinStoring/loadSnapshot(venueId:)`` without re-downloading
/// (PLAN.md S7.2).
@MainActor
struct FileManagerSkinStoringTests {
	private func makeStore() -> (store: FileManagerSkinStoring, directory: URL) {
		let directory = FileManager.default.temporaryDirectory
			.appending(path: "FileManagerSkinStoringTests-\(UUID().uuidString)")
		return (FileManagerSkinStoring(rootDirectory: directory), directory)
	}

	@Test func `has no snapshot for a venue that was never saved`() {
		let (store, directory) = makeStore()
		defer { try? FileManager.default.removeItem(at: directory) }

		#expect(store.loadSnapshot(venueId: "v1") == nil)
	}

	@Test func `round-trips a saved manifest and its asset bytes`() throws {
		let (store, directory) = makeStore()
		defer { try? FileManager.default.removeItem(at: directory) }

		let manifest = try SkinManifestFixture.make(
			properties: [1020: "https://example.com/attract.html", 1021: "120", 1004: "20", 1151: "#FFFCC129"],
			images: [1001: "https://cdn.example.com/r-01001.png"],
		)

		let saved = try store.save(venueId: "v1", manifest: manifest, assetData: [1001: Data([0xAB, 0xCD])])
		let loaded = try #require(store.loadSnapshot(venueId: "v1"))

		#expect(loaded.venueId == "v1")
		#expect(loaded.attractURL == URL(string: "https://example.com/attract.html"))
		#expect(loaded.attractTimeoutSeconds == 120)
		#expect(loaded.idleTimeoutSeconds == 20)
		#expect(loaded.colors[.nowPlayingTint] == "#FFFCC129")
		#expect(try Data(contentsOf: #require(loaded.imageFileURLs[1001])) == Data([0xAB, 0xCD]))
		#expect(loaded == saved)
	}

	@Test func `keeps different venues' snapshots independent`() throws {
		let (store, directory) = makeStore()
		defer { try? FileManager.default.removeItem(at: directory) }

		_ = try store.save(venueId: "v1", manifest: SkinManifestFixture.make(), assetData: [:])

		#expect(store.loadSnapshot(venueId: "v2") == nil)
	}

	@Test func `treats a snapshot as missing once one of its asset files is gone`() throws {
		let (store, directory) = makeStore()
		defer { try? FileManager.default.removeItem(at: directory) }

		let manifest = try SkinManifestFixture.make(images: [1001: "https://cdn.example.com/r-01001.png"])
		let saved = try store.save(venueId: "v1", manifest: manifest, assetData: [1001: Data([0x01])])
		try FileManager.default.removeItem(at: #require(saved.imageFileURLs[1001]))

		#expect(store.loadSnapshot(venueId: "v1") == nil)
	}

	@Test func `clear wipes every persisted venue`() throws {
		let (store, directory) = makeStore()
		defer { try? FileManager.default.removeItem(at: directory) }

		_ = try store.save(venueId: "v1", manifest: SkinManifestFixture.make(), assetData: [:])
		_ = try store.save(venueId: "v2", manifest: SkinManifestFixture.make(), assetData: [:])

		store.clear()

		#expect(store.loadSnapshot(venueId: "v1") == nil)
		#expect(store.loadSnapshot(venueId: "v2") == nil)
	}
}
