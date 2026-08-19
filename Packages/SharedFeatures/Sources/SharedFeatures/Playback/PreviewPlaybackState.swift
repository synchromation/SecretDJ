/// ``PreviewPlayerModel``'s own state machine — idle, downloading a
/// specific song's clip, or actually playing it. Kept as its own type so
/// ``PreviewPlayerModel/activeSongId``/``PreviewPlayerModel/isPlaying`` can
/// be derived rather than tracked as separate booleans that could
/// disagree.
public enum PreviewPlaybackState: Equatable, Sendable {
	case idle
	case downloading(songId: String)
	case playing(songId: String)
}
