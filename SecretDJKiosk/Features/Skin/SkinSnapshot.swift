import Foundation
import SecretDJAPI

/// A previously downloaded, fully persisted skin for one venue — what
/// ``SkinStoring/loadSnapshot(venueId:)`` returns when a relaunch can skip
/// the network entirely (PLAN.md S7.2: "persist... so relaunches skip the
/// download"). Carries exactly the ``SecretDJAPI/SkinManifest`` fields
/// ``KioskSkin`` and ``KioskBehavioralConfig`` resolve from — not the
/// manifest itself, which is `Decodable`-only and has no wire format of its
/// own to round-trip through a store — plus local file URLs for every
/// downloaded image, keyed by the server's numeric id so both typed
/// ``SecretDJAPI/SkinAssetRole``s and D10's forward-compatible unknown ids
/// round-trip alike.
///
/// The toast fields are flattened rather than carrying
/// ``SecretDJAPI/ToastAppearance`` itself: that type has no public
/// initializer outside `SecretDJAPI` (by design — it's a decode-only wire
/// type), so a value reconstructed from disk couldn't be built as one.
struct SkinSnapshot: Equatable {
	let venueId: String
	let attractURL: URL?
	let attractTimeoutSeconds: Int?
	let idleTimeoutSeconds: Int?
	let headerHeight: Int?
	let toastBackgroundColor: String?
	let toastTextColor: String?
	let toastBorderColor: String?
	let toastBorderWidth: Int?
	let colors: [SkinColorRole: String]
	/// Local file URLs for every downloaded chrome image, keyed by the
	/// server's numeric id.
	let imageFileURLs: [Int: URL]
}
