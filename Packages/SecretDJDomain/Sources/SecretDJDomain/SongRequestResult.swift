/// The outcome of requesting a song, classified from the `requestsong`
/// response's `ReturnCode` (LEGACY.md business rule 5; `WSRX_ERROR_REQUEST_NO_CREDITS`).
public enum SongRequestResult: Sendable, Hashable {
	/// `ReturnCode == 0`: the song was queued. `message`/`url` are the
	/// server's copy for the confirmation toast; `richToast` is the same
	/// response's optional `Data` award payload (S8.6, LEGACY.md "Toasts") —
	/// present, it renders instead of the plain `message` toast, exactly
	/// like `checkin`'s own rich-toast branch
	/// (`secretdjv3/TuneInViewController.swift`'s `jukeboxButtonTapped`: `if
	/// let richToast { handleRichToast(...) } else { handleSimpleToast(...) }`).
	case success(message: String?, url: String?, richToast: RichToastData?)
	/// `ReturnCode == -8`: out of credits. `hasProfilePicture` (from the
	/// response's `ImageSize > 0`) decides whether the client offers the
	/// pic-for-credits upsell or goes straight to the top-up screen.
	case outOfCredits(hasProfilePicture: Bool)
	/// Any other non-zero `ReturnCode`: a server-worded failure.
	case failure(message: String)

	/// `WSRX_ERROR_REQUEST_NO_CREDITS` — the server's out-of-credits code.
	public static let outOfCreditsReturnCode = -8

	/// Classifies a `requestsong` response into its typed outcome.
	/// - Parameters:
	///   - imageSize: the response's `ImageSize`; only consulted when
	///     `returnCode` is ``outOfCreditsReturnCode``.
	///   - richToast: the response's optional `Data` award payload; only
	///     consulted when `returnCode` is `0`.
	public init(returnCode: Int, message: String?, url: String?, imageSize: Int, richToast: RichToastData? = nil) {
		switch returnCode {
		case 0:
			self = .success(message: message, url: url, richToast: richToast)
		case Self.outOfCreditsReturnCode:
			self = .outOfCredits(hasProfilePicture: imageSize > 0)
		default:
			self = .failure(message: message ?? "")
		}
	}
}
