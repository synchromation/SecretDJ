import Foundation
import SecretDJAPI

/// A ``SkinStoring`` fake for tests and previews — keeps everything in a
/// plain dictionary, never touches disk (mirrors ``InMemoryCounterStore``'s
/// shape from the ios-architecture golden example). File URLs are
/// synthesized (never actually written), so a test that wants
/// ``SkinStoring/loadSnapshot(venueId:)`` to see a missing file after
/// ``save(venueId:manifest:assetData:)`` should reach for
/// ``FileManagerSkinStoring`` in a scratch directory instead — this fake
/// always "has" whatever it was told to save.
final class InMemorySkinStoring: SkinStoring {
	private var snapshots: [String: SkinSnapshot] = [:]

	init() {}

	func loadSnapshot(venueId: String) -> SkinSnapshot? {
		snapshots[venueId]
	}

	func save(venueId: String, manifest: SkinManifest, assetData: [Int: Data]) throws -> SkinSnapshot {
		let snapshot = SkinSnapshot(
			venueId: venueId,
			attractURL: manifest.attractURL,
			attractTimeoutSeconds: manifest.attractTimeoutSeconds,
			idleTimeoutSeconds: manifest.idleTimeoutSeconds,
			headerHeight: manifest.headerHeight,
			toastBackgroundColor: manifest.toast?.backgroundColor,
			toastTextColor: manifest.toast?.textColor,
			toastBorderColor: manifest.toast?.borderColor,
			toastBorderWidth: manifest.toast?.borderWidth,
			colors: manifest.colors,
			imageFileURLs: Dictionary(uniqueKeysWithValues: assetData.keys.map { id in
				(id, URL(fileURLWithPath: "/dev/null/skin-asset-\(id)"))
			}),
		)
		snapshots[venueId] = snapshot
		return snapshot
	}

	func clear() {
		snapshots.removeAll()
	}
}
