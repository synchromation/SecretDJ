import CryptoKit
import Foundation

/// Computes the `sig` query parameter the auth scheme requires on every
/// signed request (LEGACY.md "Backend API and Spotify integration" → "Auth
/// scheme: rotating token + HMAC signature").
public protocol RequestSigning: Sendable {
	func signature(token: String, passwordHash: String) -> String
}

/// `base64(HMAC-SHA1(base64Decode(token), key: passwordHash))` — ported
/// from `secretdjv3/SignatureProvider.swift` + `secretdjv3/Hmac.swift`.
///
/// SHA-1 here is a wire-compatibility requirement (D7), not a security
/// choice: the production backend verifies this exact HMAC-SHA1 scheme, and
/// changing it is a coordinated server-side change, not a client one.
public struct HMACSHA1RequestSigner: RequestSigning {
	public init() {}

	public func signature(token: String, passwordHash: String) -> String {
		guard let decodedToken = Data(base64Encoded: token) else {
			return ""
		}
		let key = SymmetricKey(data: Data(passwordHash.utf8))
		let mac = HMAC<Insecure.SHA1>.authenticationCode(for: decodedToken, using: key)
		return Data(mac).base64EncodedString()
	}
}
