import Foundation
import SecretDJDomain

/// Routes a feed tap or server-driven action to its typed
/// ``FeedActionOutcome``, reproducing `secretdjv3/FeedActionProvider.swift`
/// and `ActionBarButtonProvider.swift`'s dispatch rules. Pure and
/// side-effect-free: navigation and network execution stay with the caller
/// (PLAN.md S3.3) via an ``InstalledApps`` seam for the one runtime query
/// this routing needs.
public struct FeedActionRouter: Sendable {
	private let installedApps: any InstalledApps

	public init(installedApps: any InstalledApps) {
		self.installedApps = installedApps
	}

	/// Routes a tap on a feed cell. An item carrying its own recognized
	/// ``Action`` dispatches through that action
	/// (`FeedActionProvider.actionFor(item:...)`'s gate); otherwise falls
	/// back to the per-payload default (song → TuneIn, venue → venue feed,
	/// artist branching on song count, promotion's deep-link rules, ...).
	/// Returns `nil` when nothing in this build knows how to handle the tap
	/// — dropped, consistent with the engine's unknown-kind rule.
	public func outcome(forTap item: FeedDisplayItem) -> FeedActionOutcome? {
		// A jukebox row's `.jukeboxGotoItem` action names the tapped row
		// itself (`actionGotoJukebox(jukebox:)`), not something resolvable
		// from the bare action below — resolved here, ahead of the generic
		// gate.
		if case .jukebox(let jukebox) = item.item, let action = jukebox.action, action.kind == .jukeboxGotoItem {
			return .showJukebox(jukeboxId: jukebox.jukeboxId)
		}

		if let action = item.item.action, action.kind.isRecognized {
			return outcome(for: action)
		}

		return defaultOutcome(for: item.item)
	}

	/// Routes a nav-bar action button tap
	/// (`secretdjv3/ActionBarButtonProvider.swift`). The button's icon
	/// (`Action/button` — insert-coin, hail-taxi, search) only decides which
	/// glyph renders; behavior follows the same `Action/kind` mapping an
	/// item-level action uses.
	public func outcome(forBarButton action: Action) -> FeedActionOutcome? {
		outcome(for: action)
	}

	/// The `ActionKind` → ``FeedActionOutcome`` mapping shared by item taps
	/// and bar buttons (`secretdjv3/FeedActionProvider.swift`'s
	/// `actionFor(action:...)`).
	private func outcome(for action: Action) -> FeedActionOutcome? {
		switch action.kind {
		case .showTopup:
			.showTopUps(context: .insertCoin)

		case .launchUberApp,
		     .launchUberSignup:
			action.url.flatMap { URL(string: $0) }.map { .hailRide(url: $0) }

		case .launchSearch:
			.launchSearch

		case .jukeboxChangeAtmosphere:
			action.itemId.map { .changeAtmosphere(itemId: $0) }

		case .jukeboxSkipSong:
			action.itemId.map { .machineControl(action: .skip, itemId: $0) }

		case .jukeboxBlacklistSong:
			action.itemId.map { .machineControl(action: .neverPlay, itemId: $0) }

		case .jukeboxRequestSong:
			action.itemId.map { .requestSong(itemId: $0) }

		case .gotoURL:
			action.url.flatMap { URL(string: $0) }.map { .openURL(.inApp($0)) }

		case .jukeboxGotoItem,
		     .unsupported:
			// jukeboxGotoItem needs the tapped item's own identity, resolved
			// in outcome(forTap:) before reaching here; as a bare action it
			// carries nothing this mapping can resolve to a screen.
			nil
		}
	}

	private func defaultOutcome(for item: Item) -> FeedActionOutcome? {
		switch item {
		case .song(let song):
			outcome(forSong: song)

		case .venue(let venue):
			.showVenue(venueId: venue.venueId)

		case .person(let person):
			.showPerson(personId: person.personId)

		case .artist(let artist):
			outcome(forArtist: artist)

		case .jukebox:
			// Every jukebox row carries its own `.jukeboxGotoItem` action
			// (handled above) — this default is unreachable in practice.
			nil

		case .topUp:
			// Tapping a top-up bundle starts a StoreKit purchase
			// (`TopUpManager.handleTopup`), a side effect outside this
			// navigation vocabulary — out of scope for S3.3.
			nil

		case .promotion(let promotion):
			outcome(forPromotion: promotion)

		case .control:
			// A mood tile with no action can't do anything.
			nil

		case .unsupported:
			nil
		}
	}

	private func outcome(forSong song: Song) -> FeedActionOutcome? {
		song.isIntermission ? nil : .showSong(.song(songId: song.songId))
	}

	private func outcome(forArtist artist: Artist) -> FeedActionOutcome {
		artist.numSongs == 1
			? .showSong(.artist(name: artist.name))
			: .showSongsForArtist(artist: artist.name)
	}

	/// `secretdjv3/FeedActionProvider.swift`'s `handle(promotion:venue:)`:
	/// social profile URLs convert to a native deep link when the app is
	/// installed; a URL-less promotion pings the engagement endpoint
	/// (LEGACY.md "Actions"); everything else opens as a URL, external or
	/// in-app per `externalBrowser`. Facebook conversion is out of S3.3's
	/// scope (PLAN.md) — a Facebook profile URL falls through to the
	/// external/in-app branch instead of a native deep link.
	private func outcome(forPromotion promotion: Promotion) -> FeedActionOutcome? {
		guard let urlString = promotion.url, let url = URL(string: urlString) else {
			return .engagePromotion(promotionId: promotion.promotionId)
		}

		if let identifier = socialIdentifier(in: url, host: "instagram.com"), installedApps.isInstalled(.instagram) {
			return .openSocialApp(platform: .instagram, identifier: identifier, webFallbackURL: url)
		}

		if let identifier = socialIdentifier(in: url, host: "twitter.com"), installedApps.isInstalled(.twitter) {
			return .openSocialApp(platform: .twitter, identifier: identifier, webFallbackURL: url)
		}

		return .openURL(promotion.externalBrowser ? .external(url) : .inApp(url))
	}

	private func socialIdentifier(in url: URL, host: String) -> String? {
		guard url.absoluteString.contains(host), !url.lastPathComponent.isEmpty else {
			return nil
		}
		return url.lastPathComponent
	}
}

extension ActionKind {
	fileprivate var isRecognized: Bool {
		if case .unsupported = self {
			return false
		}
		return true
	}
}
