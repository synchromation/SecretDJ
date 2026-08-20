/// The award-style reward payload carried by an action response's `Data`
/// field on `checkin`/`requestsong` — the only two endpoints whose legacy
/// client actually reads it and can show it richly. `like`/`unlike`
/// (`secretdjv3/LikeAPIAccess.swift`) and `machinecontrol`
/// (`secretdjv3/MachineControlAPIAccess.swift`) never read a `Data` key from
/// their own responses at all — only `ReturnCode`/`Text`(/`Url`,
/// `LikeInfo`) — and none of `like`'s call sites (`VenueFeedViewController`,
/// `NowPlayingFeedViewController`, `ProfileFeedViewController`,
/// `TuneInViewController`) ever call `handleRichToast`, only
/// `handleSimpleToast`. ``SecretDJAPI/APIActionResponse`` (shared wire shape
/// for both `checkin` and `machinecontrol`) still decodes this field
/// generically when present, since decoding is harmless and matches the
/// shared shape LEGACY.md documents — nothing in this codebase reads
/// `machinecontrol`'s `data`, mirroring legacy exactly. Ported field-for-field
/// from
/// `secretdjv3/RichToastView.swift`'s `populateViews(_:)`/`setupVip(_:)`
/// (LEGACY.md "Toasts": "server-supplied dictionaries rendered by
/// `RichToastView`, e.g. award-style check-in/request rewards").
///
/// // LIVE-CAPTURE: no fixture in this repo or the legacy checkout's own
/// test bundle carries a `Data` object shaped like this — `RequestSong.json`'s
/// top-level `Vips` array is a different, unread field
/// (`SelectSongAPIAccess.swift`'s `handle(dictionary:)` only ever reads
/// `Response.{Text,Url,Data,ReturnCode}`, never `Vips`). This type's shape is
/// synthesized entirely from `RichToastView.swift`'s dictionary-subscript
/// reads rather than a captured response.
public struct RichToastData: Sendable, Hashable, Decodable {
	public let title: String
	public let headline: String
	public let bodyText: String
	/// The rewarded person, shown with an avatar and a "view profile" tap
	/// target (`viewVipButtonTapped`). `nil` when the toast carries no `Vip`
	/// object at all, or when its nested `Data` is absent/malformed — legacy
	/// still renders a headless VIP row from `Image`/`Text` alone in that
	/// second case (`setupVip(_:)`'s `Data` check is independent of its
	/// `Image`/`Text` reads), but no captured response has ever shown that
	/// combination, so this port collapses it to no VIP row at all rather
	/// than inventing a partial-render case with no evidence behind it.
	public let vip: Person?

	public init(title: String, headline: String, bodyText: String, vip: Person?) {
		self.title = title
		self.headline = headline
		self.bodyText = bodyText
		self.vip = vip
	}

	private enum CodingKeys: String, CodingKey {
		case title = "Title"
		case headline = "Headline"
		case bodyText = "BodyText"
		case vip = "Vip"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
		headline = try container.decodeIfPresent(String.self, forKey: .headline) ?? ""
		bodyText = try container.decodeIfPresent(String.self, forKey: .bodyText) ?? ""
		// Malformed/absent Vip data never fails the whole toast — same
		// tolerant-decode discipline as Person's own Image field.
		vip = try? container.decodeIfPresent(Person.self, forKey: .vip)
	}
}
