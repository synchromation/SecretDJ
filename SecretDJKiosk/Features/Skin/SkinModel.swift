import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives the post-login skin download/persist/gate flow PLAN.md S7.2
/// describes: a returning venue's already-persisted skin
/// (``SkinStoring/loadSnapshot(venueId:)``) is applied with no network call
/// at all; a first-time (or reset) venue fetches the manifest, downloads
/// every referenced image with bounded concurrency and fractional
/// progress, and persists the result so the *next* launch is the cache-hit
/// path. Any failure — manifest fetch, an asset download, or the save
/// itself — moves to ``Phase/failed`` and stays there until ``retry()``:
/// legacy's own skin-download-failed surface is retry-only, with no way to
/// enter the kiosk unskinned (LEGACY.md "Venue login and the skin system"),
/// and this mirrors that exactly.
@Observable
final class SkinModel {
	/// ``SkinModel``'s visible state — ``KioskSkinGateView`` switches on
	/// this directly.
	enum Phase: Equatable {
		case idle
		case loading(progress: Double)
		case ready(skin: KioskSkin, behavioralConfig: KioskBehavioralConfig)
		case failed
	}

	/// At most this many asset downloads run at once
	/// (PLAN.md S7.2: "≤ a few concurrent").
	static let maxConcurrentDownloads = 4

	private(set) var phase = Phase.idle

	private let venueId: String
	private let loading: any SkinLoading
	private let assetDownloading: any SkinAssetDownloading
	private let storing: any SkinStoring
	private let observability: ObservabilityPipeline

	private var isRunning = false

	init(
		venueId: String,
		loading: any SkinLoading,
		assetDownloading: any SkinAssetDownloading,
		storing: any SkinStoring,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.venueId = venueId
		self.loading = loading
		self.assetDownloading = assetDownloading
		self.storing = storing
		self.observability = observability
	}

	/// Starts the flow. Idempotent: a no-op once already ``Phase/ready`` (or
	/// while already running) so a view re-appearing doesn't re-trigger a
	/// download in flight or already finished — call ``retry()`` instead to
	/// force a fresh attempt from ``Phase/failed``.
	func start() async {
		guard !isRunning, phase == .idle else { return }

		if let snapshot = storing.loadSnapshot(venueId: venueId) {
			phase = .ready(
				skin: .resolve(snapshot: snapshot),
				behavioralConfig: KioskBehavioralConfig(snapshot: snapshot),
			)
			observability.log(.info, "Skin loaded from local cache", category: "Skin")
			return
		}

		await download()
	}

	/// Re-attempts the whole flow from scratch (fresh manifest fetch, fresh
	/// downloads) — the retry-only failure surface's action. A no-op while
	/// already running.
	func retry() async {
		guard !isRunning else { return }
		await download()
	}

	private func download() async {
		isRunning = true
		defer { isRunning = false }

		phase = .loading(progress: 0)
		observability.log(.info, "Downloading venue skin", category: "Skin")

		let manifest: SkinManifest
		do {
			manifest = try await loading.fetchManifest()
		} catch {
			observability.report(error, category: "Skin")
			phase = .failed
			return
		}

		var imageRequests = manifest.images.reduce(into: [Int: URL]()) { result, entry in
			result[entry.key.rawValue] = entry.value
		}
		for (id, url) in manifest.unknownImages {
			imageRequests[id] = url
		}

		let assetData: [Int: Data]
		do {
			assetData = try await downloadAll(imageRequests)
		} catch {
			observability.report(error, category: "Skin")
			phase = .failed
			return
		}

		let snapshot: SkinSnapshot
		do {
			snapshot = try storing.save(venueId: venueId, manifest: manifest, assetData: assetData)
		} catch {
			observability.report(error, category: "Skin")
			phase = .failed
			return
		}

		phase = .ready(
			skin: .resolve(manifest: manifest, imageFileURLs: snapshot.imageFileURLs),
			behavioralConfig: KioskBehavioralConfig(manifest: manifest),
		)
		observability.log(.info, "Venue skin ready", category: "Skin")
		observability.track(SkinEvent.skinDownloaded)
	}

	/// Downloads every `(id, url)` request with at most
	/// ``maxConcurrentDownloads`` in flight at once, reporting ``phase``
	/// progress as each one completes. Any single failure cancels the rest
	/// and propagates — S7.2's all-or-nothing rule, matching legacy's own
	/// `downloadsAreComplete`/`downloadGroupComplete(success: false)`
	/// behavior (`secretdjv3/SkinAPIAccess.swift`).
	private func downloadAll(_ requests: [Int: URL]) async throws -> [Int: Data] {
		guard !requests.isEmpty else { return [:] }

		var results: [Int: Data] = [:]
		var completed = 0
		let total = requests.count

		try await withThrowingTaskGroup(of: (Int, Data).self) { group in
			var remaining = requests.makeIterator()

			func addNext() {
				guard let (id, url) = remaining.next() else { return }
				group.addTask { [assetDownloading] in
					try await (id, assetDownloading.data(from: url))
				}
			}

			for _ in 0 ..< min(Self.maxConcurrentDownloads, total) {
				addNext()
			}

			while let (id, data) = try await group.next() {
				results[id] = data
				completed += 1
				phase = .loading(progress: Double(completed) / Double(total))
				addNext()
			}
		}

		return results
	}
}
