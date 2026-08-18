extension String {
	/// `nil` when this decoded string is empty — the legacy server uses `""`
	/// as its sentinel for "this optional field has no value" (previews,
	/// affiliate URLs, promotion URLs, ...).
	var nonEmptyOrNil: String? {
		isEmpty ? nil : self
	}
}

extension KeyedDecodingContainer {
	/// Decodes `key` as an `Int`, tolerating the wire's occasional string
	/// encoding of what is semantically a numeric id — e.g. `Action.ItemId`
	/// arrives as a JSON string song id (`"152380"`) for request-song
	/// actions, but a plain JSON number (`679`) for mood/control actions.
	func decodeIntOrStringIfPresent(forKey key: Key) throws -> Int? {
		if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
			return intValue
		}
		return try decodeIfPresent(String.self, forKey: key).flatMap(Int.init)
	}

	/// Decodes `key` as a `Bool`, tolerating the wire's genuinely
	/// inconsistent encoding of this flag as a JSON bool, number, or numeric
	/// string — e.g. `Venue.MachineControl` arrives as `false`, `0`, or
	/// `"63"` depending on the payload. Any non-zero number or numeric
	/// string is truthy, mirroring the legacy `> 0` convention.
	func decodeBoolOrIntOrStringIfPresent(forKey key: Key) throws -> Bool? {
		if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
			return boolValue
		}
		if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
			return intValue > 0
		}
		guard let stringValue = try decodeIfPresent(String.self, forKey: key) else {
			return nil
		}
		return (Int(stringValue) ?? 0) > 0
	}
}
