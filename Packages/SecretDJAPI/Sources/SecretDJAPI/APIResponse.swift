/// The outcome of a successful ``APIClient/execute`` call: the decoded
/// payload plus a rotated token, when the server issued one.
public struct APIResponse<Payload: Sendable>: Sendable {
	public let payload: Payload
	/// A new token from this response's envelope — callers persist it
	/// (S1.4) when present; `nil` means the existing token is still valid.
	public let rotatedToken: String?

	public init(payload: Payload, rotatedToken: String?) {
		self.payload = payload
		self.rotatedToken = rotatedToken
	}
}
