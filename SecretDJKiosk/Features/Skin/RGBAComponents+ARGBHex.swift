import DesignSystem

extension Theme.RGBAComponents {
	/// Parses a venue skin's raw color string — `"#AARRGGBB"`, alpha
	/// **first** (``SecretDJAPI/SkinColorRole``'s doc comment: "the server's
	/// raw `#AARRGGBB` hex strings"). Deliberately not
	/// ``Theme/RGBAComponents/init(hex:)``: that initializer parses the
	/// six-digit `"#RRGGBB"` wire format the domain's mood-tile colors use,
	/// a different server contract with no alpha channel — this is the
	/// skin manifest's own eight-digit format. `nil` for anything that
	/// isn't exactly eight hex digits, so a malformed skin color falls back
	/// to the caller's own default (``KioskSkin/resolve(manifest:imageFileURLs:)``)
	/// instead of silently rendering black.
	init?(argbHex: String) {
		var hex = argbHex
		if hex.hasPrefix("#") {
			hex.removeFirst()
		}

		guard hex.count == 8, let value = UInt32(hex, radix: 16) else {
			return nil
		}

		let alpha = Double((value >> 24) & 0xFF) / 255
		let red = Double((value >> 16) & 0xFF) / 255
		let green = Double((value >> 8) & 0xFF) / 255
		let blue = Double(value & 0xFF) / 255
		self.init(red: red, green: green, blue: blue, alpha: alpha)
	}
}
