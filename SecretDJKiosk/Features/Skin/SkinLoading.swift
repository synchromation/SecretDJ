import SecretDJAPI

/// The one skin-manifest fetch ``SkinModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface
/// (ios-architecture: a protocol seam per real dependency) — no parameters,
/// since (like ``AtmosphereChanging``'s own production implementation) the
/// production ``SkinLoading`` reads the signed-in session fresh on every
/// call rather than capturing ids once at construction time.
protocol SkinLoading: Sendable {
	func fetchManifest() async throws(SkinLoadingError) -> SkinManifest
}

/// Every way ``SkinLoading/fetchManifest()`` can fail. Deliberately coarser
/// than ``SecretDJAPI/APIError``: legacy's own skin-download-failed surface
/// (`KioskLoginFlowController.skinResourcesLoadingComplete`) shows one fixed
/// retry-only alert regardless of *why* the download failed, so
/// ``SkinModel`` never needs to branch on the server's message the way
/// sign-in's error surface does — this only exists to give
/// ``KioskSkinTests``/``SkinModelTests`` something typed to assert on and
/// ``ObservabilityPipeline/report(_:category:)`` something to log.
enum SkinLoadingError: Error, Equatable {
	/// No session is signed in — ``SkinModel`` should never be constructed
	/// in this state (skin loading only starts post-login), so this is a
	/// defensive case, not an expected path.
	case notSignedIn
	/// The request never reached a response (offline, timeout, transport
	/// failure).
	case connection
	/// The server rejected the request; `message` is its copy, when
	/// present.
	case server(message: String?)
}

extension SkinLoadingError {
	init(_ apiError: APIError) {
		switch apiError {
		case .server(let message):
			self = .server(message: message)
		case .missingCredential,
		     .requestGeneration,
		     .transport,
		     .decoding:
			self = .connection
		}
	}
}
