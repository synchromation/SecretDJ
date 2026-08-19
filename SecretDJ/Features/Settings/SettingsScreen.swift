import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The settings hub (S6.11, LEGACY.md "Tab 3 — Profile" → Settings; the
/// refactor branch's SwiftUI `SettingsScreen` pilot —
/// `secretdjv3/SwiftUI/Settings/SettingsScreen.swift` — is this screen's
/// direct behavioral reference, see each subscreen's own doc comment for
/// exactly what's ported). Reached from the Profile tab's own gear toolbar
/// button, own profile only (``ProfileScreen``'s doc comment) — pushed as
/// ``AppDestination/settings`` rather than presented as a sheet, so its own
/// subscreens push further onto the same navigation stack via
/// `.navigationDestination(isPresented:)`, exactly like `LoginFlow`'s own
/// sign-up push.
///
/// Sign out and delete account both moved here from `ProfileScreen`'s old
/// footer (the `// S6.11:` markers that flagged the move are gone with it).
struct SettingsScreen: View {
	let personId: String
	let credential: APICredential
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let onDeleteAccount: () -> Void
	let observability: ObservabilityPipeline

	@State private var changeDetailsModel: ChangeDetailsModel
	@State private var changePasswordModel: ChangePasswordModel
	@State private var changeGenderModel: ChangeGenderModel
	@State private var autoLockModel = AutoLockPreferenceModel(store: UserDefaultsAutoLockPreferenceStore())
	@State private var showsChangeDetails = false
	@State private var showsChangePassword = false
	@State private var showsChangeGender = false
	@State private var showsTerms = false
	@State private var showsPrivacy = false
	@State private var isConfirmingSignOut = false

	init(
		personId: String,
		credential: APICredential,
		sessionStore: SessionStore,
		settingsService: any SettingsServicing,
		onboardingService: any OnboardingServicing,
		toastQueue: ToastQueue,
		onDeleteAccount: @escaping () -> Void,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.credential = credential
		self.sessionStore = sessionStore
		self.toastQueue = toastQueue
		self.onDeleteAccount = onDeleteAccount
		self.observability = observability
		_changeDetailsModel = State(initialValue: ChangeDetailsModel(
			personId: personId,
			credential: credential,
			settingsService: settingsService,
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			observability: observability,
		))
		_changePasswordModel = State(initialValue: ChangePasswordModel(
			personId: personId,
			credential: credential,
			settingsService: settingsService,
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			observability: observability,
		))
		_changeGenderModel = State(initialValue: ChangeGenderModel(
			personId: personId,
			credential: credential,
			onboardingService: onboardingService,
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			observability: observability,
		))
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: Spacing.large) {
				accountSection
				preferencesSection
				aboutSection
				accountActionsSection
			}
			.padding(Spacing.large)
		}
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text(
			"Settings",
			comment: "Navigation title of the Settings screen, reached from the Profile tab.",
		))
		.tracksScreen("Settings")
		.navigationDestination(isPresented: $showsChangeDetails) {
			ChangeDetailsView(model: changeDetailsModel)
		}
		.navigationDestination(isPresented: $showsChangePassword) {
			ChangePasswordView(model: changePasswordModel)
		}
		.navigationDestination(isPresented: $showsChangeGender) {
			ChangeGenderView(model: changeGenderModel)
		}
		.sheet(isPresented: $showsTerms) {
			LegalWebScreen(url: SettingsLegalLinks.termsOfService).ignoresSafeArea()
		}
		.sheet(isPresented: $showsPrivacy) {
			LegalWebScreen(url: SettingsLegalLinks.privacyPolicy).ignoresSafeArea()
		}
		.confirmationDialog(
			"Sign Out?",
			isPresented: $isConfirmingSignOut,
			titleVisibility: .visible,
		) {
			Button("Sign Out", role: .destructive, action: signOut)
			Button("Cancel", role: .cancel) {}
		}
	}

	private var accountSection: some View {
		VStack(alignment: .leading, spacing: Spacing.small) {
			sectionHeader("Account")
			settingsRow("Change Details") { showsChangeDetails = true }
			settingsRow("Change Password") { showsChangePassword = true }
			settingsRow("Change Gender") { showsChangeGender = true }
		}
	}

	private var preferencesSection: some View {
		VStack(alignment: .leading, spacing: Spacing.small) {
			sectionHeader("Preferences")
			autoLockRow
		}
	}

	private var autoLockRow: some View {
		Toggle(isOn: Binding(get: { autoLockModel.isDisabled }, set: autoLockModel.updateIsDisabled)) {
			VStack(alignment: .leading, spacing: Spacing.extraSmall) {
				Text(
					"Disable Auto-Lock",
					comment: "Title of the Settings toggle that keeps the screen from auto-locking.",
				)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				Text(
					"Keep your screen awake while Secret DJ is open.",
					comment: "Explanatory subtitle under the Settings 'Disable Auto-Lock' toggle.",
				)
				.font(Theme.TextStyle.caption.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
			}
		}
		.padding()
		.frame(minHeight: 44)
		.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
	}

	private var aboutSection: some View {
		VStack(alignment: .leading, spacing: Spacing.small) {
			sectionHeader("About")
			versionRow
			settingsRow("Terms of Service") { showsTerms = true }
			settingsRow("Privacy Policy") { showsPrivacy = true }
		}
	}

	private var versionRow: some View {
		HStack {
			Text("Version", comment: "Label for the app version/build row in Settings' About section.")
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
			Spacer()
			Text(Self.versionText)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
		}
		.padding()
		.frame(minHeight: 44)
		.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
		.accessibilityElement(children: .combine)
	}

	private var accountActionsSection: some View {
		VStack(spacing: Spacing.small) {
			Button("Sign Out") {
				isConfirmingSignOut = true
			}
			.buttonStyle(.secondary)

			Button("Delete Account", action: onDeleteAccount)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.danger.color)
				.frame(minHeight: 44)
		}
	}

	private func sectionHeader(_ title: LocalizedStringResource) -> some View {
		Text(title)
			.font(Theme.TextStyle.sectionHeader.font)
			.foregroundStyle(Theme.ColorRole.primaryText.color)
			.accessibilityAddTraits(.isHeader)
	}

	private func settingsRow(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack {
				Text(title)
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)
				Spacer()
				Theme.Icon.disclosure.image
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.accessibilityHidden(true)
			}
			.padding()
			.frame(minHeight: 44)
			.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
		}
	}

	private func signOut() {
		observability.interaction("signOut")
		sessionStore.signOut()
	}

	/// The app's marketing version and build number, read the same way the
	/// composition root's own `APIClientConfiguration.live` does.
	private static var versionText: String {
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
		return "\(version) (\(build))"
	}
}

#Preview("Fresh") {
	NavigationStack {
		SettingsScreen(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			sessionStore: PreviewSessionStore.signedIn(),
			settingsService: InMemorySettingsService(),
			onboardingService: InMemoryOnboardingService(),
			toastQueue: ToastQueue(),
			onDeleteAccount: {},
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		SettingsScreen(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			sessionStore: PreviewSessionStore.signedIn(),
			settingsService: InMemorySettingsService(),
			onboardingService: InMemoryOnboardingService(),
			toastQueue: ToastQueue(),
			onDeleteAccount: {},
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
