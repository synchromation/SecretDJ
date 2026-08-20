import Observability
import Observation
import SecretDJDomain
import SharedFeatures

/// Resolves a single-song artist's own song before the kiosk's TuneIn screen
/// can show it — the kiosk's own copy of the consumer's
/// `TuneInArtistResolvingModel` (`SecretDJ/Features/TuneIn/TuneInArtistResolvingModel.swift`),
/// duplicated per this codebase's own convention rather than shared
/// (``KioskAtmosphereChanging``'s doc comment): every S6/S7 screen's own
/// small adapter/resolving model lives in its app target. Reuses the same
/// ``SharedFeatures/MusicSearching`` seam the kiosk's own search screens
/// already share, rather than opening a dedicated one.
@MainActor
@Observable
final class KioskTuneInArtistResolvingModel {
	enum Phase: Equatable {
		case loading
		case resolved(Song)
		/// The artist search came back with no song — mirrors the
		/// consumer's own `Phase/empty` doc comment: legacy disables the
		/// jukebox button rather than erroring, and this rewrite shows the
		/// same empty state as a failed lookup either way.
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
			observability.report(error, category: "KioskTuneIn")
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
