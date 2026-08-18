import SecretDJDomain

/// Typed access to ``FeedDisplayModel/hiddenSections`` by their template —
/// LEGACY.md's hidden-section catalog ("Domain model and persistence"):
/// each hidden template carries exactly one payload shape.
extension FeedDisplayModel {
	/// The authoritative venue payload from a `hiddenVenueDetails` section
	/// (drives the venue screen's header), when the feed carried one.
	public var venueDetails: Venue? {
		hiddenPayloads(template: .hiddenVenueDetails) { if case .venue(let venue) = $0 { venue } else { nil } }.first
	}

	/// The signed-in user's full profile from a `hiddenUserDetails` section.
	public var userDetails: Person? {
		hiddenPayloads(template: .hiddenUserDetails) { if case .person(let person) = $0 { person } else { nil } }
			.first
	}

	/// Another user's profile from a `hiddenProfile` section (the profile
	/// tab reached by tapping someone else).
	public var profile: Person? {
		hiddenPayloads(template: .hiddenProfile) { if case .person(let person) = $0 { person } else { nil } }.first
	}

	/// The venue's jukebox menu from a `hiddenJukeboxList` section.
	public var jukeboxList: [Jukebox] {
		hiddenPayloads(template: .hiddenJukeboxList) { if case .jukebox(let jukebox) = $0 { jukebox } else { nil } }
	}

	/// The rotating "now playing" ticker content from a
	/// `hiddenExtraContentSong` section.
	public var extraContentSongs: [Song] {
		hiddenPayloads(template: .hiddenExtraContentSong) { if case .song(let song) = $0 { song } else { nil } }
	}

	private func hiddenPayloads<Payload>(template: Template, extract: (Item) -> Payload?) -> [Payload] {
		hiddenSections
			.filter { $0.template == template }
			.flatMap { $0.items.compactMap(extract) }
	}
}
