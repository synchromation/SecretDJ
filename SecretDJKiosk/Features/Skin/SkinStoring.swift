import Foundation
import SecretDJAPI

/// The local persistence ``SkinModel`` needs — files plus a manifest
/// snapshot, so a relaunch can skip the network entirely once a venue's
/// skin has downloaded once (ios-architecture: a protocol seam per real
/// dependency). Production is ``FileManagerSkinStoring`` (Application
/// Support); tests and previews use ``InMemorySkinStoring``.
protocol SkinStoring: Sendable {
	/// A previously persisted skin for `venueId`, when this store holds one
	/// and every asset file it references is still present on disk — `nil`
	/// otherwise. A partial wipe, a venue this store has never seen, and
	/// nothing persisted yet all look identical from here: no snapshot, so
	/// ``SkinModel`` always falls back to a fresh download rather than
	/// exposing a broken local file URL.
	func loadSnapshot(venueId: String) -> SkinSnapshot?

	/// Persists `manifest`'s fields for `venueId` plus every downloaded
	/// image's raw bytes (keyed by the server's numeric id — typed roles
	/// and ``SecretDJAPI/SkinManifest/unknownImages`` alike), returning the
	/// resulting ``SkinSnapshot`` with its resolved local file URLs.
	func save(venueId: String, manifest: SkinManifest, assetData: [Int: Data]) throws -> SkinSnapshot

	/// Wipes every persisted skin, for every venue. The staff reset's
	/// ``KioskCacheClearing`` conformance (``SkinCacheClearing``) calls this
	/// so a relaunch is forced back to a fresh download — mirrors legacy's
	/// `?RESTART?` handler, which "deletes all skin assets"
	/// (LEGACY.md "Venue login and the skin system").
	func clear()
}
