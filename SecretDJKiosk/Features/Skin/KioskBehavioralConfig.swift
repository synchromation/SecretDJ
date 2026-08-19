import Foundation
import SecretDJAPI

/// The kiosk timing/URL behavior a venue skin drives — S7.3's attract/idle
/// system consumes this exactly (PLAN.md S7.2's doc comment: "feeding
/// S7.3"). Falls back to legacy's own defaults
/// (`secretdjv3/KioskAppConfig.swift`'s `defaultAttractTimeout`/
/// `defaultIdleTimeout`, both 10 seconds) when the venue skin doesn't set a
/// value — a venue that has never configured custom timing still behaves
/// sanely, matching legacy's own fallback exactly.
struct KioskBehavioralConfig: Equatable {
	/// The default both timeouts fall back to when the manifest omits them
	/// (`secretdjv3/KioskAppConfig.swift`).
	static let legacyDefaultTimeoutSeconds = 10

	/// The attract-mode web page (``SecretDJAPI/SkinManifest/attractURL``).
	/// `nil` when the venue hasn't configured one — legacy has no fallback
	/// URL for this field, so S7.3 simply offers no attract screen in that
	/// case, rather than guessing a destination.
	let attractURL: URL?
	/// Seconds of inactivity before the attract screen shows.
	let attractTimeoutSeconds: Int
	/// Seconds of inactivity before returning to the jukebox wall.
	let idleTimeoutSeconds: Int

	init(manifest: SkinManifest) {
		attractURL = manifest.attractURL
		attractTimeoutSeconds = manifest.attractTimeoutSeconds ?? Self.legacyDefaultTimeoutSeconds
		idleTimeoutSeconds = manifest.idleTimeoutSeconds ?? Self.legacyDefaultTimeoutSeconds
	}

	/// Derives the same config from a previously persisted skin, on a
	/// relaunch that skipped the network entirely
	/// (``SkinStoring/loadSnapshot(venueId:)``).
	init(snapshot: SkinSnapshot) {
		attractURL = snapshot.attractURL
		attractTimeoutSeconds = snapshot.attractTimeoutSeconds ?? Self.legacyDefaultTimeoutSeconds
		idleTimeoutSeconds = snapshot.idleTimeoutSeconds ?? Self.legacyDefaultTimeoutSeconds
	}
}
