import Observability
import Observation
import SecretDJDomain
import SharedFeatures

/// Resolves a single-song artist's own song before TuneIn can show it —
/// mirrors `secretdjv3/TuneInViewController.swift`'s `update(artistName:...)`/
/// `updateForArtist()`, which does the identical `musicsearch` (type
/// `.artists`) round trip when ``FeedUI/FeedActionOutcome/showSong(_:)``
/// carries only a name (no song id known yet, per
/// ``FeedUI/FeedActionOutcome/TuneInTarget``'s doc comment). Reuses the same
/// ``SharedFeatures/MusicSearching`` seam the search screens already share
/// (``SongsForArtistScreen``'s own `MusicSearchingSongsForArtistLoading`),
/// rather than opening a dedicated one.
@MainActor
@Observable
final class TuneInArtistResolvingModel {
	enum Phase: Equatable {
		case loading
		case resolved(Song)
		/// The artist search came back with no song — legacy disables the
		/// jukebox button rather than erroring
		/// (`artistUpdateCompleted`'s `else` branch); this rewrite shows the
		/// same empty state as a failed lookup, since neither leaves
		/// anything to show details for.
		case empty
		case failed
	}

	private(set) var phase: Phase = .loading

	private let artistName: String
	private let musicSearching: any MusicSearching
	private let observability: ObservabilityPipeline

	init(
		artistName: String,
		musicSearching: any MusicSearching,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.artistName = artistName
		self.musicSearching = musicSearching
		self.observability = observability
	}

	func resolve() async {
		do {
			let sectionList = try await musicSearching.songs(forArtist: artistName)
			if let song = Self.firstSong(in: sectionList) {
				phase = .resolved(song)
			} else {
				phase = .empty
			}
		} catch {
			observability.report(error, category: "TuneIn")
			phase = .failed
		}
	}

	private static func firstSong(in sectionList: SectionList) -> Song? {
		for section in sectionList.sections {
			for item in section.items {
				if case .song(let song) = item {
					return song
				}
			}
		}
		return nil
	}
}
