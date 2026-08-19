import Foundation
import SecretDJAPI

/// A ``SecretDJAPI/SkinManifest`` fixture for ``KioskSkinGateView``'s
/// previews — built through the real `Decodable` initializer, since
/// `SkinManifest` (deliberately, per its own doc comment: a decode-only
/// wire type) has no public memberwise initializer any other module could
/// call. `try!` is confined to this preview-only fixture, decoding a
/// literal, known-valid string — never production code, and never a test
/// (`SecretDJKioskTests/SkinManifestFixture.swift` is the equivalent for
/// tests, in the tests module where lint rules for this differ).
enum PreviewSkinManifest {
	static let withOneImage: SkinManifest = {
		let json = """
		{"Response": {
			"Images": [{"Id": 1001, "Image": {"Uri": "https://example.com/01001.png"}}],
			"Properties": [{"Id": 1004, "Text": "20"}]
		}}
		"""

		// swiftlint:disable:next force_try
		return try! JSONDecoder().decode(SkinManifest.self, from: Data(json.utf8))
	}()

	/// Pre-seeds `storing` with ``withOneImage`` already "downloaded" for
	/// `venueId`, so a preview's ``SkinModel`` resolves straight to
	/// ``SkinModel/Phase/ready`` via the cache-hit path — the same path a
	/// real relaunch takes.
	static func preSeed(_ storing: InMemorySkinStoring, venueId: String) -> InMemorySkinStoring {
		_ = try? storing.save(venueId: venueId, manifest: withOneImage, assetData: [1001: Data([0x00])])
		return storing
	}
}
