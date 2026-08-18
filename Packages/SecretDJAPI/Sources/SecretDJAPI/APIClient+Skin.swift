import Foundation

/// `skinresources` — the venue-branded chrome/behavior manifest (LEGACY.md
/// "Backend API and Spotify integration" → endpoint catalog; "Kiosk app" →
/// "Venue login and the skin system"), typed over ``APIClient``. Ported
/// from `secretdjv3/SkinAPIAccess.swift`. Doesn't appear in the legacy
/// sig-exclusion list, so this requires an ``APICredential``.
extension APIClient {
	/// `skinresources` — ported from `secretdjv3/SkinAPIAccess.swift`'s
	/// `skinAssets`. Downloading the referenced image assets is a caller
	/// concern (S7.2) — this only fetches and decodes the manifest.
	public func skinResources(
		userId: String,
		venueId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SkinManifest> {
		try await execute(
			endpoint: "skinresources",
			parameters: ["user": userId, "venue": venueId],
			signed: true,
			credential: credential,
			decodingPayloadAs: SkinManifest.self,
		)
	}
}

/// A single skinnable chrome color, named by role rather than the legacy
/// client's magic numeric id (D10; `secretdjv3/SkinManager.swift`'s
/// `SkinColor` enum). Values are the server's raw `#AARRGGBB` hex strings —
/// parsing into a platform color type is a caller concern (DesignSystem
/// reconciles these with app theming per S7.2), so this package stays
/// platform-agnostic.
public enum SkinColorRole: Int, Sendable, Hashable, CaseIterable {
	case standardButtonDefault = 1051
	case standardButtonHighlight = 1053
	case artistCellText = 1341
	case artistCellBackground = 1346
	case jukeboxCellText = 1122
	case nowPlayingTint = 1151
	case songCellText = 1102
	case tuneInText = 1250
	case sectionHeaderText = 1141
	case keyboardKey = 1380
	case keyboardKeyHighlight = 1385
}

/// A single skinnable chrome image, named by role
/// (`secretdjv3/SkinManager.swift`'s `SkinAsset` enum). The value is the
/// asset's remote URL — downloading and caching it locally (legacy's
/// `Documents/skin_assets`, LEGACY.md's tech debt note #4 on magic numeric
/// filenames) is a caller concern this package doesn't take on.
public enum SkinAssetRole: Int, Sendable, Hashable, CaseIterable {
	case nowPlayingBackground = 1001
	case loadingIndicator = 1002
	case standardButtonDefault = 1050
	case standardButtonHighlight = 1052
	case searchButtonDefault = 1160
	case searchButtonHighlight = 1161
	case allJukeboxesButtonDefault = 1173
	case allJukeboxesButtonHighlight = 1174
	case jukeboxCellPlaceholder = 1121
	case jukeboxCellTitleBackground = 1120
	case nowPlayingEmptyImage = 1030
	case nowPlayingNoImage = 1101
	case songTitleBackground = 1100
	case tuneInBackground = 1200
	case tuneInPreviewStart = 1210
	case tuneInPreviewStartHighlight = 1211
	case tuneInPreviewStop = 1220
	case tuneInPreviewStopHighlight = 1221
	case requestSong = 1201
	case requestSongHighlight = 1202
	case sectionHeader = 1140
	case close = 1240
	case closeHighlight = 1241
	case artistSearchButton = 1320
	case artistSearchButtonHighlight = 1321
	case songSearchButton = 1330
	case songSearchButtonHighlight = 1331
	case keyboardKey = 1381
	case keyboardKeyHighlight = 1382
	case wideKey = 1383
	case wideKeyHighlight = 1384
	case clearButton = 1347
	case clearButtonHighlight = 1348
	case searchBackground = 1340
}

/// The rich-toast chrome a skin can override
/// (`secretdjv3/SimpleToastView.swift`'s `initializeKioskAttributes`;
/// LEGACY.md's "Kiosk app" note on toast background/text/border colors +
/// width, ids 1010-1013). `nil` when the manifest carries none of the four
/// fields; present fields are `nil` individually when the server omits just
/// that one.
public struct ToastAppearance: Sendable, Hashable {
	public let backgroundColor: String?
	public let textColor: String?
	public let borderColor: String?
	public let borderWidth: Int?
}

/// The `skinresources` manifest — replaces the legacy client's
/// numeric-id-addressed asset/property files
/// (`secretdjv3/SkinManager.swift`, LEGACY.md "Kiosk app" tech debt #4)
/// with a typed contract (D10): known roles decode into named fields;
/// every server entry this build doesn't map to a role — search
/// placeholders today, anything the server adds tomorrow — survives in
/// ``unknownProperties``/``unknownImages``, keyed by the server's numeric
/// id, rather than being silently dropped.
///
/// This is the contract S7.2 (kiosk skin system) consumes.
public struct SkinManifest: Sendable, Hashable, Decodable {
	/// The attract-mode web page (`secretdjv3/SkinManager.swift`'s
	/// `SkinText.attractURL`, id 1020) — S7.3's screensaver source.
	public let attractURL: URL?
	/// Seconds of inactivity before the attract screen shows
	/// (`SkinText.attractTimeoutSeconds`, id 1021).
	public let attractTimeoutSeconds: Int?
	/// Seconds of inactivity before returning to the jukebox wall
	/// (`SkinText.idleTimeoutSeconds`, id 1004).
	public let idleTimeoutSeconds: Int?
	/// The now-playing header's skinnable height, in points
	/// (`SkinText.headerHeight`, id 1003).
	public let headerHeight: Int?
	public let toast: ToastAppearance?
	/// Named chrome colors, keyed by role.
	public let colors: [SkinColorRole: String]
	/// Named chrome images, keyed by role.
	public let images: [SkinAssetRole: URL]
	/// Server text properties this build doesn't map to a typed role —
	/// e.g. the legacy `SkinText.songSearchPlaceholder`/
	/// `artistSearchPlaceholder` ids — keyed by the server's numeric id.
	public let unknownProperties: [Int: String]
	/// Server image assets this build doesn't map to a typed
	/// ``SkinAssetRole``, keyed by the server's numeric id.
	public let unknownImages: [Int: URL]

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}

	private enum ResponseKeys: String, CodingKey {
		case images = "Images"
		case properties = "Properties"
	}

	private struct ImageEntryWire: Decodable {
		let id: Int
		let uri: String?

		private enum CodingKeys: String, CodingKey {
			case id = "Id"
			case image = "Image"
		}

		private enum ImageKeys: String, CodingKey {
			case uri = "Uri"
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decode(Int.self, forKey: .id)
			let imageContainer = try container.nestedContainer(keyedBy: ImageKeys.self, forKey: .image)
			uri = try imageContainer.decodeIfPresent(String.self, forKey: .uri)
		}
	}

	private struct PropertyEntryWire: Decodable {
		let id: Int
		let text: String

		private enum CodingKeys: String, CodingKey {
			case id = "Id"
			case text = "Text"
		}
	}

	/// The behavioral text ids this build reads into named fields (not
	/// colors, not toast chrome).
	private enum BehaviorID: Int, CaseIterable {
		case attractURL = 1020
		case attractTimeoutSeconds = 1021
		case idleTimeoutSeconds = 1004
		case headerHeight = 1003
	}

	private enum ToastID: Int, CaseIterable {
		case backgroundColor = 1010
		case textColor = 1011
		case borderColor = 1012
		case borderWidth = 1013
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let responseContainer = try container.nestedContainer(keyedBy: ResponseKeys.self, forKey: .response)
		let imageEntries = try responseContainer.decodeIfPresent([ImageEntryWire].self, forKey: .images) ?? []
		let propertyEntries = try responseContainer.decodeIfPresent([PropertyEntryWire].self, forKey: .properties) ?? []

		var rawProperties = Dictionary(uniqueKeysWithValues: propertyEntries.map { ($0.id, $0.text) })
		var rawImages = Dictionary(uniqueKeysWithValues: imageEntries.compactMap { entry -> (Int, URL)? in
			guard let uri = entry.uri, let url = URL(string: uri) else { return nil }
			return (entry.id, url)
		})

		attractURL = rawProperties[BehaviorID.attractURL.rawValue].flatMap(URL.init(string:))
		attractTimeoutSeconds = rawProperties[BehaviorID.attractTimeoutSeconds.rawValue].flatMap(Int.init)
		idleTimeoutSeconds = rawProperties[BehaviorID.idleTimeoutSeconds.rawValue].flatMap(Int.init)
		headerHeight = rawProperties[BehaviorID.headerHeight.rawValue].flatMap(Int.init)

		let hasToastEntry = ToastID.allCases.contains { rawProperties[$0.rawValue] != nil }
		toast = hasToastEntry ? ToastAppearance(
			backgroundColor: rawProperties[ToastID.backgroundColor.rawValue],
			textColor: rawProperties[ToastID.textColor.rawValue],
			borderColor: rawProperties[ToastID.borderColor.rawValue],
			borderWidth: rawProperties[ToastID.borderWidth.rawValue].flatMap(Int.init),
		) : nil

		var colors: [SkinColorRole: String] = [:]
		for role in SkinColorRole.allCases {
			if let value = rawProperties[role.rawValue] {
				colors[role] = value
			}
		}
		self.colors = colors

		var images: [SkinAssetRole: URL] = [:]
		for role in SkinAssetRole.allCases {
			if let value = rawImages[role.rawValue] {
				images[role] = value
			}
		}
		self.images = images

		for id in BehaviorID.allCases.map(\.rawValue) {
			rawProperties.removeValue(forKey: id)
		}
		for id in ToastID.allCases.map(\.rawValue) {
			rawProperties.removeValue(forKey: id)
		}
		for id in SkinColorRole.allCases.map(\.rawValue) {
			rawProperties.removeValue(forKey: id)
		}
		unknownProperties = rawProperties

		for id in SkinAssetRole.allCases.map(\.rawValue) {
			rawImages.removeValue(forKey: id)
		}
		unknownImages = rawImages
	}
}
