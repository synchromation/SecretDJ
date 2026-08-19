import Foundation
import SecretDJAPI

/// Builds a ``SkinManifest`` from plain `[id: value]` maps, going through
/// its real `Decodable` initializer (`SecretDJAPI/APIClient+Skin.swift`) so
/// every Skin-feature test exercises the same wire shape
/// `Packages/SecretDJAPI/Tests/SecretDJAPITests/Resources/SkinResources.json`
/// does, without each test file re-deriving JSON by hand.
enum SkinManifestFixture {
	static func make(
		properties: [Int: String] = [:],
		images: [Int: String] = [:],
	) throws -> SkinManifest {
		let propertiesJSON = properties
			.map { "{\"Id\": \($0.key), \"Text\": \"\(escape($0.value))\"}" }
			.joined(separator: ",")
		let imagesJSON = images
			.map { "{\"Id\": \($0.key), \"Image\": {\"Uri\": \"\(escape($0.value))\"}}" }
			.joined(separator: ",")
		let json = "{\"Response\": {\"Images\": [\(imagesJSON)], \"Properties\": [\(propertiesJSON)]}}"

		return try JSONDecoder().decode(SkinManifest.self, from: Data(json.utf8))
	}

	private static func escape(_ value: String) -> String {
		value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
	}
}
