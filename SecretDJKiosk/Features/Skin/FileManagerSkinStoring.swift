import Foundation
import SecretDJAPI

/// The production ``SkinStoring``: one subdirectory per venue under
/// Application Support (`rootDirectory`'s default), holding a small JSON
/// manifest snapshot plus every downloaded asset's raw bytes as a loose
/// file — the typed-manifest counterpart to legacy's own
/// `Documents/skin_assets` (`secretdjv3/SkinManager.swift`), minus its
/// magic-numeric-filename fragility (LEGACY.md tech debt #4): files here
/// are named by the server's own numeric id directly, no slicing.
///
/// Injected with a scratch `rootDirectory` in tests (swift-testing's
/// determinism rule for a real adapter — never the real Application
/// Support directory from a unit test).
final class FileManagerSkinStoring: SkinStoring {
	private let rootDirectory: URL
	private let fileManager: FileManager

	init(rootDirectory: URL = FileManagerSkinStoring.defaultRootDirectory, fileManager: FileManager = .default) {
		self.rootDirectory = rootDirectory
		self.fileManager = fileManager
	}

	static var defaultRootDirectory: URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
		return base.appending(path: "KioskSkin", directoryHint: .isDirectory)
	}

	func loadSnapshot(venueId: String) -> SkinSnapshot? {
		guard let data = try? Data(contentsOf: manifestFileURL(for: venueId)),
		      let persisted = try? JSONDecoder().decode(PersistedManifest.self, from: data) else
		{
			return nil
		}

		var imageFileURLs: [Int: URL] = [:]
		for id in persisted.imageIds {
			let url = assetFileURL(for: venueId, id: id)
			guard fileManager.fileExists(atPath: url.path) else {
				// A partial or tampered-with store — treat exactly like no
				// snapshot at all, so the caller re-downloads rather than
				// exposing a URL to a file that isn't there.
				return nil
			}
			imageFileURLs[id] = url
		}

		return SkinSnapshot(
			venueId: venueId,
			attractURL: persisted.attractURLString.flatMap(URL.init(string:)),
			attractTimeoutSeconds: persisted.attractTimeoutSeconds,
			idleTimeoutSeconds: persisted.idleTimeoutSeconds,
			headerHeight: persisted.headerHeight,
			toastBackgroundColor: persisted.toastBackgroundColor,
			toastTextColor: persisted.toastTextColor,
			toastBorderColor: persisted.toastBorderColor,
			toastBorderWidth: persisted.toastBorderWidth,
			colors: persisted.colorRoles,
			imageFileURLs: imageFileURLs,
		)
	}

	func save(venueId: String, manifest: SkinManifest, assetData: [Int: Data]) throws -> SkinSnapshot {
		let directory = venueDirectory(for: venueId)
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

		var imageFileURLs: [Int: URL] = [:]
		for (id, data) in assetData {
			let url = assetFileURL(for: venueId, id: id)
			try data.write(to: url, options: .atomic)
			imageFileURLs[id] = url
		}

		let persisted = PersistedManifest(manifest: manifest, imageIds: Array(assetData.keys))
		try JSONEncoder().encode(persisted).write(to: manifestFileURL(for: venueId), options: .atomic)

		return SkinSnapshot(
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
			imageFileURLs: imageFileURLs,
		)
	}

	func clear() {
		try? fileManager.removeItem(at: rootDirectory)
	}

	private func venueDirectory(for venueId: String) -> URL {
		rootDirectory.appending(path: venueId, directoryHint: .isDirectory)
	}

	private func manifestFileURL(for venueId: String) -> URL {
		venueDirectory(for: venueId).appending(path: "manifest.json")
	}

	private func assetFileURL(for venueId: String, id: Int) -> URL {
		venueDirectory(for: venueId).appending(path: "\(id).asset")
	}
}

/// The on-disk shape of a persisted skin's non-binary fields — a private
/// DTO because ``SecretDJAPI/SkinManifest`` is `Decodable`-only (no wire
/// format of its own to encode back out) and ``SecretDJAPI/SkinColorRole``/
/// ``SecretDJAPI/ToastAppearance`` aren't `Codable`, so this flattens
/// everything to primitives and reconstructs typed roles by raw value on
/// the way back in.
private struct PersistedManifest: Codable {
	let attractURLString: String?
	let attractTimeoutSeconds: Int?
	let idleTimeoutSeconds: Int?
	let headerHeight: Int?
	let toastBackgroundColor: String?
	let toastTextColor: String?
	let toastBorderColor: String?
	let toastBorderWidth: Int?
	let colorRoleValues: [Int: String]
	let imageIds: [Int]

	init(manifest: SkinManifest, imageIds: [Int]) {
		attractURLString = manifest.attractURL?.absoluteString
		attractTimeoutSeconds = manifest.attractTimeoutSeconds
		idleTimeoutSeconds = manifest.idleTimeoutSeconds
		headerHeight = manifest.headerHeight
		toastBackgroundColor = manifest.toast?.backgroundColor
		toastTextColor = manifest.toast?.textColor
		toastBorderColor = manifest.toast?.borderColor
		toastBorderWidth = manifest.toast?.borderWidth
		colorRoleValues = Dictionary(uniqueKeysWithValues: manifest.colors.map { ($0.key.rawValue, $0.value) })
		self.imageIds = imageIds
	}

	var colorRoles: [SkinColorRole: String] {
		Dictionary(uniqueKeysWithValues: colorRoleValues.compactMap { rawValue, hex in
			SkinColorRole(rawValue: rawValue).map { ($0, hex) }
		})
	}
}
