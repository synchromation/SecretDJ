import SwiftUI

extension Theme {
	/// The product's semantic icon vocabulary — every icon role a consumer
	/// reaches for.
	///
	/// Policy (S9.8, overturning S3.2's original "SF Symbols first"):
	/// wherever a legacy Paintcode/Photoshop asset actually rendered on
	/// screen for a role, this package re-cuts that exact artwork into its
	/// own asset catalog (`Resources/Media.xcassets`) and this role shows it
	/// instead of an SF Symbol — a role only stays on its symbol when no
	/// legacy asset served that context. "Verified against legacy usage"
	/// means grepped call sites, not just a same-named asset sitting in the
	/// catalog: several candidate assets (`iconSettingsDefault`,
	/// `iconCameraDefault`, `ButtonVenueCheckInDefault`,
	/// `ButtonVenueNowPlayingDefault`, `ButtonVenueLikeDefault`/`Selected`,
	/// `IconNextArrow`, `iconWarning`) turned out to be orphaned in the
	/// legacy source tree — present in `secretdjv3/SecretDJ.xcassets` but
	/// never wired into any live screen (their real buttons were plain
	/// title-only `GreenButton`/`GreenOutlineButton` controls, or another
	/// asset entirely served the same screen) — so ``checkIn``, ``settings``,
	/// ``changePhoto``, ``disclosure``, and ``warning`` stay on their symbols
	/// despite being named in the porting brief, and ``nowPlaying`` likewise
	/// (no legacy screen rendered any icon for it at all).
	///
	/// A single role can serve more than one legacy-distinct context —
	/// ``venue``'s tab-bar art, its artwork-fallback placeholder, and the
	/// venue map's own pin are three different legacy assets — so this file
	/// exposes one image accessor per *context* (``image``, ``placeholderImage``,
	/// ``tabImage(selected:)``, ``mapPinImage``) rather than a single override
	/// per role; each falls back to the SF Symbol (or, for the placeholder/
	/// map-pin contexts, to ``image``) when that context has no legacy asset.
	public enum Icon: CaseIterable, Hashable, Sendable {
		/// The music/venue/artist search entry point (nav-bar search action,
		/// music search screen).
		case search
		/// The insert-coin nav-bar action and the out-of-credits top-up funnel.
		case topUp
		/// The hail-taxi nav-bar action and Uber deep link.
		case taxi
		/// Venue directions, and the Places Nearby tab's map bar button.
		case map
		/// Checking in at a venue.
		case checkIn
		/// A person, venue, or song not yet liked ("buzzed").
		case like
		/// A person, venue, or song already liked ("buzzed") — the toggled
		/// state of ``like``.
		case likeFilled
		/// A song, artist, or jukebox row's fallback when it has no artwork.
		case song
		/// A promotion card's fallback when it has no artwork.
		case promotion
		/// A mood/atmosphere tile.
		case mood
		/// Starting a song preview.
		case playPreview
		/// Ending an in-progress song preview.
		case stopPreview
		/// The signed-in user's profile, and person cells.
		case profile
		/// The own-profile avatar-change affordance (S6.6).
		case changePhoto
		/// A venue/place, and the Places Nearby tab.
		case venue
		/// The activity feed ("rabbit feed" — LEGACY.md "Tab 2 — Activity
		/// feed") and the Activity tab.
		case activity
		/// A jukebox, and jukebox menu/cells.
		case jukebox
		/// The venue screen's entry point into its now-playing feed.
		case nowPlaying
		/// An award cell.
		case award
		/// The settings entry point.
		case settings
		/// A disclosure/navigation affordance on a row.
		case disclosure
		/// Dismissing a sheet, dialog, or toast.
		case close
		/// A manual refresh control.
		case refresh
		/// A warning or error state.
		case warning
		/// A generic empty-state placeholder.
		case emptyState
		/// The kiosk's idle/attract-mode screensaver entry.
		case kioskAttract
		/// The kiosk's idle-timeout reset back to its home screen.
		case kioskReset
	}
}

extension Theme.Icon {
	/// This role's SF Symbol name — always valid, and used directly by call
	/// sites that need a symbol name string rather than an `Image` (e.g.
	/// `EmptyStateView`, `Button(_:systemImage:)`); also this role's
	/// ``image``/``placeholderImage`` fallback when no legacy asset backs
	/// that context.
	public var systemName: String {
		switch self {
		case .search: "magnifyingglass"
		case .topUp: "creditcard.fill"
		case .taxi: "car.fill"
		case .map: "map.fill"
		case .checkIn: "checkmark.circle.fill"
		case .like: "heart"
		case .likeFilled: "heart.fill"
		case .song: "music.note"
		case .promotion: "megaphone.fill"
		case .mood: "flame.fill"
		case .playPreview: "play.fill"
		case .stopPreview: "stop.fill"
		case .profile: "person.crop.circle.fill"
		case .changePhoto: "camera.circle.fill"
		case .venue: "mappin.circle.fill"
		case .activity: "waveform.path.ecg"
		case .jukebox: "music.note.list"
		case .nowPlaying: "antenna.radiowaves.left.and.right"
		case .award: "trophy.fill"
		case .settings: "gearshape.fill"
		case .disclosure: "chevron.right"
		case .close: "xmark"
		case .refresh: "arrow.clockwise"
		case .warning: "exclamationmark.triangle.fill"
		case .emptyState: "tray"
		case .kioskAttract: "sparkles"
		case .kioskReset: "arrow.counterclockwise"
		}
	}

	/// The legacy imageset backing this role's everyday glyph rendering — a
	/// nav-bar action, an inline status badge, a standalone control icon.
	/// `nil` when legacy showed no icon in that context, so ``image`` falls
	/// back to the SF Symbol.
	///
	/// Tinted (`.alwaysTemplate`) in legacy, reproduced here via each
	/// imageset's own `template-rendering-intent` rather than call-site
	/// code: `search`/`topUp`/`taxi` (`ActionBarButtonItem.swift:26-54`,
	/// tinted `StyleKit2023.TopBarTintColour`) and `map`
	/// (`PlacesNearbyFeedViewController.swift:86-88`, same tint). `like`/
	/// `likeFilled` and `playPreview`/`stopPreview` are original pre-colored
	/// art, unchanged by any rendering mode in legacy.
	///
	/// `like`/`likeFilled` use the same `iconLike`/`iconLikeSelected` pair
	/// everywhere a like control appears (venue, profile, now-playing,
	/// tune-in) — legacy's separate `ButtonVenueLikeDefault`/`Selected` pair
	/// turned out to be unused; every IB-wired like button (`VenueSectionHeaderView.xib:103-108`,
	/// `ProfileSectionHeaderView.xib:118-123`, `NowPlayingSectionHeaderView.xib:92-96`,
	/// `Music_iPhone.storyboard:441-444`) binds `iconLike`/`iconLikeSelected`
	/// instead, so this role needed no per-context split after all.
	private var glyphAssetName: String? {
		switch self {
		case .search: "iconSearchDefault"
		case .topUp: "iconTopupDefault"
		case .taxi: "iconTaxiDefault"
		case .map: "iconMapButton"
		case .like: "iconLike"
		case .likeFilled: "iconLikeSelected"
		case .playPreview: "previewIcon"
		case .stopPreview: "endPreviewIcon"
		default: nil
		}
	}

	/// The legacy imageset backing this role's artwork-fallback rendering —
	/// `RemoteArtworkView`'s own placeholder when a URL has no image yet or
	/// failed to load (`FeedCellConfigurator.swift:204,212`,
	/// `SwiftUI/Feed/FeedViewStateBuilder.swift:232,240`). `nil` when legacy
	/// showed no fallback art for that role, so ``placeholderImage`` falls
	/// back to ``image`` (and from there, the SF Symbol).
	///
	/// `profile` resolves to the *unisex* placeholder
	/// (`placeholderAvatarUnisex`, legacy's `UIImage.fallbackImageForPerson(.unisex)`)
	/// rather than legacy's gendered male/female variants: this rewrite's
	/// `FeedCellProps`/`PersonRowCell`/`ProfileHeaderView` never thread a
	/// person's `Gender` down to a cell (a materially bigger change than an
	/// icon swap), so there is no signal here to pick a gendered asset from.
	/// A second, pixel-different "unisex avatar" asset also exists
	/// (`Icons/Avatar/avatarUnisex`, used only by legacy's `RichToastView.swift:98`
	/// VIP toast) but this package treats every ``profile`` placeholder
	/// context as one role with one asset rather than splitting a
	/// cosmetically-similar circle into a second case.
	private var placeholderAssetName: String? {
		switch self {
		case .song: "placeholderTune"
		case .venue: "placeholderVenue"
		case .profile: "placeholderAvatarUnisex"
		case .jukebox: "placeholderJukeboxBackground"
		default: nil
		}
	}

	/// Legacy's own tab-bar art (`TabBarConfigurationProvider.swift:23-54`):
	/// a distinct Default/Selected pair per tab, `.alwaysTemplate` so it
	/// tints with the tab bar's own accent (reproduced here through each
	/// imageset's `template-rendering-intent` instead of call-site code).
	/// `nil` for every role but the three tabs — a caller falls back to
	/// ``image`` (and from there, the SF Symbol) when this returns `nil`.
	private func tabAssetName(selected: Bool) -> String? {
		switch self {
		case .venue: selected ? "iconTabVenueSelected" : "iconTabVenueDefault"
		case .activity: selected ? "iconTabBuzzSelected" : "iconTabBuzzDefault"
		case .profile: selected ? "iconTabProfileSelected" : "iconTabProfileDefault"
		default: nil
		}
	}

	/// The Places Nearby map's own pre-colored pin art
	/// (`VenueMapViewController.swift:116-120`: plain `UIImage(named:)`, no
	/// rendering mode) — legacy drew a venue's map annotation as a flat pin
	/// image, never a tinted symbol over a colored circle, and used a
	/// visibly different pin for a venue with a jukebox. `nil` for every
	/// role but ``venue``/``jukebox``, the two this package's own venue map
	/// annotates.
	private var mapPinAssetName: String? {
		switch self {
		case .venue: "mapPinVenue"
		case .jukebox: "mapPinVenueJukebox"
		default: nil
		}
	}

	/// This role's action/glyph image — the legacy artwork above when this
	/// context has one, otherwise the SF Symbol. Labelling and decoration
	/// follow the accessibility skill at the call site — this accessor
	/// carries no label of its own.
	public var image: Image {
		if let name = glyphAssetName {
			Image(name, bundle: .module)
		} else {
			Image(systemName: systemName)
		}
	}

	/// This role's artwork-fallback image — `RemoteArtworkView`'s own
	/// placeholder rendering. The legacy placeholder art above when this
	/// role backs one, otherwise the same as ``image``.
	var placeholderImage: Image {
		if let name = placeholderAssetName {
			Image(name, bundle: .module)
		} else {
			image
		}
	}

	/// Whether ``placeholderImage`` is real legacy artwork rather than a
	/// symbol glyph — `RemoteArtworkView`'s own placeholder sizes/scales the
	/// two differently (artwork fills its frame; a symbol is sized off it).
	var hasLegacyPlaceholder: Bool {
		placeholderAssetName != nil
	}

	/// This role's tab-bar image for the given selection state. `nil` for
	/// every role but the three tabs (``venue``, ``activity``, ``profile``)
	/// — a caller falls back to ``image`` when this returns `nil`.
	public func tabImage(selected: Bool) -> Image? {
		tabAssetName(selected: selected).map { Image($0, bundle: .module) }
	}

	/// This role's venue-map annotation pin image. `nil` for every role but
	/// ``venue``/``jukebox``.
	public var mapPinImage: Image? {
		mapPinAssetName.map { Image($0, bundle: .module) }
	}
}

#if DEBUG
	extension Theme.Icon {
		/// Test-only seam onto the private per-context asset-name mapping
		/// (`@testable import`) — the pure, testable part of this file the
		/// tdd/swift-testing skills ask every logic change to carry
		/// coverage for, without making the mapping itself public API.
		enum IconTestSeam {
			static func glyphAssetName(for icon: Theme.Icon) -> String? {
				icon.glyphAssetName
			}

			static func placeholderAssetName(for icon: Theme.Icon) -> String? {
				icon.placeholderAssetName
			}

			static func tabAssetName(for icon: Theme.Icon, selected: Bool) -> String? {
				icon.tabAssetName(selected: selected)
			}

			static func mapPinAssetName(for icon: Theme.Icon) -> String? {
				icon.mapPinAssetName
			}
		}
	}
#endif
