import SecretDJDomain

/// Unifies each payload type's own `Action` field behind one accessor —
/// mirrors `Item+FeedDisplay.swift`'s `stableID`/`displayText` extensions.
extension Item {
	var action: Action? {
		switch self {
		case .song(let song): song.action
		case .venue(let venue): venue.action
		case .person(let person): person.action
		case .artist(let artist): artist.action
		case .jukebox(let jukebox): jukebox.action
		case .topUp(let topUp): topUp.action
		case .promotion(let promotion): promotion.action
		case .control(let control): control.action
		case .unsupported: nil
		}
	}
}
