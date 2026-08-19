/// The Facebook Login flow ``FacebookSignInModel`` needs, thinned to a
/// protocol seam so tests never touch the Facebook SDK (ios-architecture: a
/// protocol seam per real dependency). The real adapter
/// (``LoginManagerFacebookAuthorizing``) wraps `LoginManager` and a Graph
/// `me` request directly.
protocol FacebookAuthorizing: Sendable {
	/// Presents the Facebook login flow, then fetches the signed-in
	/// person's profile fields, and awaits the combined result.
	func requestSignIn() async throws(FacebookAuthorizationError) -> FacebookAuthorizationResult
}
