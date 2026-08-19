import Foundation
import Observability
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// ``SkinModel`` — the post-login download/persist/gate orchestrator
/// PLAN.md S7.2 describes: fetch the manifest, download its image assets
/// (bounded concurrency, fractional progress), persist so a relaunch skips
/// the network, and block on any failure with a retry-only path (no skip —
/// LEGACY.md "Venue login and the skin system": "the kiosk cannot proceed
/// unskinned").
@MainActor
struct SkinModelTests {
	private final class SpySkinStoring: SkinStoring {
		private let wrapped: InMemorySkinStoring
		private(set) var saveInvocations: [(venueId: String, assetData: [Int: Data])] = []

		init(wrapped: InMemorySkinStoring = InMemorySkinStoring()) {
			self.wrapped = wrapped
		}

		func loadSnapshot(venueId: String) -> SkinSnapshot? {
			wrapped.loadSnapshot(venueId: venueId)
		}

		func save(venueId: String, manifest: SkinManifest, assetData: [Int: Data]) throws -> SkinSnapshot {
			saveInvocations.append((venueId, assetData))
			return try wrapped.save(venueId: venueId, manifest: manifest, assetData: assetData)
		}

		func clear() {
			wrapped.clear()
		}
	}

	private func makeModel(
		venueId: String = "v1",
		loading: InMemorySkinLoading,
		downloading: InMemorySkinAssetDownloading = InMemorySkinAssetDownloading(),
		storing: some SkinStoring = InMemorySkinStoring(),
		observability: ObservabilityPipeline = .disabled,
	) -> SkinModel {
		SkinModel(
			venueId: venueId,
			loading: loading,
			assetDownloading: downloading,
			storing: storing,
			observability: observability,
		)
	}

	struct `Cache hit` {
		@Test func `skips the network entirely when a snapshot is already persisted for the venue`() async throws {
			let storing = InMemorySkinStoring()
			let manifest = try SkinManifestFixture.make(properties: [1004: "20"])
			_ = try storing.save(venueId: "v1", manifest: manifest, assetData: [:])
			let loading = InMemorySkinLoading(result: .failure(.connection))

			let model = SkinModelTests().makeModel(loading: loading, storing: storing)
			await model.start()

			#expect(loading.fetchCount == 0)
			guard case .ready(_, let config) = model.phase else {
				Issue.record("expected ready, got \(model.phase)")
				return
			}
			#expect(config.idleTimeoutSeconds == 20)
		}
	}

	struct `Fresh download` {
		@Test func `downloads every referenced image, typed roles and unknown ids alike`() async throws {
			let manifest = try SkinManifestFixture.make(
				images: [1001: "https://cdn.example.com/01001.png", 9999: "https://cdn.example.com/09999.png"],
			)
			let loading = InMemorySkinLoading(result: .success(manifest))
			let downloading = InMemorySkinAssetDownloading()
			let model = SkinModelTests().makeModel(loading: loading, downloading: downloading)

			let task = Task { await model.start() }
			try await SkinModelTests.waitUntil { await downloading.requestedURLs.count == 2 }
			try await downloading.complete(
				url: #require(URL(string: "https://cdn.example.com/01001.png")),
				with: Data([0x01]),
			)
			try await downloading.complete(
				url: #require(URL(string: "https://cdn.example.com/09999.png")),
				with: Data([0x02]),
			)
			await task.value

			guard case .ready(let skin, _) = model.phase else {
				Issue.record("expected ready, got \(model.phase)")
				return
			}
			#expect(skin.headerBackgroundImageURL != nil)
		}

		@Test func `reports progress as a fraction of assets completed`() async throws {
			let manifest = try SkinManifestFixture.make(
				images: [1001: "https://cdn.example.com/a.png", 1002: "https://cdn.example.com/b.png"],
			)
			let loading = InMemorySkinLoading(result: .success(manifest))
			let downloading = InMemorySkinAssetDownloading()
			let model = SkinModelTests().makeModel(loading: loading, downloading: downloading)

			let task = Task { await model.start() }
			try await SkinModelTests.waitUntil { await downloading.requestedURLs.count == 2 }
			try await downloading.complete(
				url: #require(URL(string: "https://cdn.example.com/a.png")),
				with: Data([0x01]),
			)
			try await SkinModelTests.waitUntil { @MainActor in
				if case .loading(let progress) = model.phase { progress > 0 } else { false }
			}

			guard case .loading(let progress) = model.phase else {
				Issue.record("expected loading, got \(model.phase)")
				return
			}
			#expect(progress == 0.5)

			try await downloading.complete(
				url: #require(URL(string: "https://cdn.example.com/b.png")),
				with: Data([0x02]),
			)
			await task.value
			#expect(model.phase.isReady)
		}

		@Test func `persists the downloaded manifest and assets`() async throws {
			let manifest = try SkinManifestFixture.make(images: [1001: "https://cdn.example.com/a.png"])
			let loading = InMemorySkinLoading(result: .success(manifest))
			let downloading = InMemorySkinAssetDownloading()
			let storing = SpySkinStoring()
			let model = SkinModelTests().makeModel(loading: loading, downloading: downloading, storing: storing)

			let task = Task { await model.start() }
			try await SkinModelTests.waitUntil { await downloading.requestedURLs.count == 1 }
			try await downloading.complete(
				url: #require(URL(string: "https://cdn.example.com/a.png")),
				with: Data([0xFF]),
			)
			await task.value

			#expect(storing.saveInvocations.count == 1)
			#expect(storing.saveInvocations.first?.venueId == "v1")
			#expect(storing.saveInvocations.first?.assetData[1001] == Data([0xFF]))
		}

		@Test func `a manifest with no images at all goes straight to ready`() async throws {
			let manifest = try SkinManifestFixture.make()
			let loading = InMemorySkinLoading(result: .success(manifest))
			let model = SkinModelTests().makeModel(loading: loading)

			await model.start()

			#expect(model.phase.isReady)
		}
	}

	struct `Failure blocks entry` {
		@Test func `a manifest fetch failure moves to failed without persisting anything`() async {
			let loading = InMemorySkinLoading(result: .failure(.connection))
			let storing = SpySkinStoring()
			let model = SkinModelTests().makeModel(loading: loading, storing: storing)

			await model.start()

			#expect(model.phase == .failed)
			#expect(storing.saveInvocations.isEmpty)
		}

		@Test func `any single asset download failure fails the whole skin, not just that asset`() async throws {
			let manifest = try SkinManifestFixture.make(
				images: [1001: "https://cdn.example.com/a.png", 1002: "https://cdn.example.com/b.png"],
			)
			let loading = InMemorySkinLoading(result: .success(manifest))
			let downloading = InMemorySkinAssetDownloading()
			let storing = SpySkinStoring()
			let model = SkinModelTests().makeModel(loading: loading, downloading: downloading, storing: storing)

			let task = Task { await model.start() }
			try await SkinModelTests.waitUntil { await downloading.requestedURLs.count == 2 }
			try await downloading.complete(
				url: #require(URL(string: "https://cdn.example.com/a.png")),
				with: Data([0x01]),
			)
			try await downloading.fail(url: #require(URL(string: "https://cdn.example.com/b.png")), with: StubError())
			await task.value

			#expect(model.phase == .failed)
			#expect(storing.saveInvocations.isEmpty)
		}

		@Test func `retry re-fetches the manifest from scratch and can succeed`() async throws {
			let manifest = try SkinManifestFixture.make()
			let loading = InMemorySkinLoading(result: .failure(.connection))
			let model = SkinModelTests().makeModel(loading: loading)

			await model.start()
			#expect(model.phase == .failed)

			loading.result = .success(manifest)
			await model.retry()

			#expect(loading.fetchCount == 2)
			#expect(model.phase.isReady)
		}
	}

	struct Instrumentation {
		@Test func `reports the failure`() async {
			let recorder = RecordingDestination()
			let loading = InMemorySkinLoading(result: .failure(.connection))
			let model = SkinModelTests().makeModel(
				loading: loading,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.start()

			let diagnostics = recorder.events.compactMap { event -> Diagnostic? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic
			}
			#expect(diagnostics.contains { $0.level == .error })
		}

		@Test func `tracks a successful fresh download as analytics`() async throws {
			let recorder = RecordingDestination()
			let manifest = try SkinManifestFixture.make()
			let loading = InMemorySkinLoading(result: .success(manifest))
			let model = SkinModelTests().makeModel(
				loading: loading,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.start()

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "skinDownloaded", parameters: [:])))
		}
	}

	private struct StubError: Error {}

	/// Polls `condition` on a short interval until it's true or a generous
	/// timeout elapses — the choreography primitive these tests need to
	/// observe ``SkinModel``'s state *mid-flight* (e.g. progress after one
	/// of several concurrent downloads completes), which plain `await`
	/// can't do since `start()` only returns once the whole operation
	/// finishes.
	static func waitUntil(
		timeout: Duration = .seconds(2),
		_ condition: () async -> Bool,
	) async throws {
		let deadline = ContinuousClock.now + timeout
		while ContinuousClock.now < deadline {
			if await condition() { return }
			await Task.yield()
		}
		Issue.record("condition never became true within \(timeout)")
	}
}

extension SkinModel.Phase {
	var isReady: Bool {
		if case .ready = self { return true }
		return false
	}
}
