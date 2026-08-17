/// The outcome of requesting a song, classified from the `requestsong`
/// response's `ReturnCode` (LEGACY.md business rule 5; `WSRX_ERROR_REQUEST_NO_CREDITS`).
public enum SongRequestResult: Sendable, Hashable {
	/// `ReturnCode == 0`: the song was queued. `message`/`url` are the
	/// server's copy for the confirmation toast.
	case success(message: String?, url: String?)
	/// `ReturnCode == -8`: out of credits. `hasProfilePicture` (from the
	/// response's `ImageSize > 0`) decides whether the client offers the
	/// pic-for-credits upsell or goes straight to the top-up screen.
	case outOfCredits(hasProfilePicture: Bool)
	/// Any other non-zero `ReturnCode`: a server-worded failure.
	case failure(message: String)

	/// `WSRX_ERROR_REQUEST_NO_CREDITS` — the server's out-of-credits code.
	public static let outOfCreditsReturnCode = -8

	/// Classifies a `requestsong` response into its typed outcome.
	/// - Parameter imageSize: the response's `ImageSize`; only consulted
	///   when `returnCode` is ``outOfCreditsReturnCode``.
	public init(returnCode: Int, message: String?, url: String?, imageSize: Int) {
		switch returnCode {
		case 0:
			self = .success(message: message, url: url)
		case Self.outOfCreditsReturnCode:
			self = .outOfCredits(hasProfilePicture: imageSize > 0)
		default:
			self = .failure(message: message ?? "")
		}
	}
}
