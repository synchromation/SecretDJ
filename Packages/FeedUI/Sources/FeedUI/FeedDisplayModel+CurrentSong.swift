import SecretDJDomain

extension FeedDisplayModel {
	/// The venue's currently playing song — the first ``SecretDJDomain/Song``
	/// item across ``visibleSections``, in server order. `playhistory`'s own
	/// response lists the venue's current song first and its recent-play
	/// history after (LEGACY.md "Now Playing / play history"), so this is the
	/// one to render in the kiosk's now-playing header (PLAN.md S7.4) — a
	/// consumer screen instead renders the whole list as an ordinary feed
	/// (``NowPlayingScreen``'s own doc comment), so this accessor has no use
	/// there. `nil` for a feed with no song row yet (a freshly checked-in
	/// venue with no play history).
	public var currentSong: Song? {
		for section in visibleSections {
			for item in section.items {
				if case .song(let song) = item.item {
					return song
				}
			}
		}
		return nil
	}
}
