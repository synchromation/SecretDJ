/// A single server-rendered entry within a ``Section``, dispatched by
/// ``Template`` to its concrete payload (LEGACY.md "Domain model and
/// persistence" — `Section.parseItem`'s dispatch table).
///
/// S1.3: not `Decodable` — picking a case for a raw item requires knowing
/// its governing `Section`'s template, plus the section-level "Templates"/
/// "Items" array shape LEGACY.md documents only in outline. Per the
/// architecture split (PLAN.md "Architecture target"), SecretDJAPI decodes
/// raw feed JSON and constructs these values once it has that context;
/// Domain just defines the vocabulary.
public enum Item: Sendable, Hashable {
	case song(Song)
	case venue(Venue)
	case person(Person)
	case artist(Artist)
	case jukebox(Jukebox)
	case topUp(TopUp)
	case promotion(Promotion)
	case control(Control)
	/// A template this build doesn't map to a payload — carrying the
	/// template for logging/metrics only (the unknown-kind policy).
	case unsupported(Template)
}
