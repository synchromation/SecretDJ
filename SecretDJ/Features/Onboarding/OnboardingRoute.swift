/// How the signed-up account arrived, which determines what's left to
/// collect before onboarding is done (LEGACY.md "Login, sign-up,
/// onboarding": native → gender → photo → details; Facebook → username →
/// photo; Apple → username → gender → photo). Username is each route's own
/// sign-in screen's job (S4.3 for Apple, S4.4 for Facebook), never this
/// model's — ``OnboardingRoute`` only ever sees what's left once that
/// screen, and `createuser`/`signin`, have already run.
enum OnboardingRoute: Equatable {
	/// Native sign-up. S4.2's ``SignUpModel`` already folds the legacy
	/// gender screen into its own details form and sends `gender` with
	/// `createuser`, so the only step left here is the photo.
	case native
	/// Sign-in with Apple. The native details form was never shown, so
	/// gender still needs collecting before the photo. Constructed by
	/// `RootView` once `AppleSignInModel` and the shared
	/// `SocialUsernameModel` step have both run.
	case apple
	/// Sign-in with Facebook, which never collects gender at all — only the
	/// photo is left. Constructed by `RootView` once `FacebookSignInModel`
	/// and the shared `SocialUsernameModel` step have both run.
	case facebook

	/// The steps this route still needs, in display order.
	var steps: [OnboardingStep] {
		switch self {
		case .native:
			[.photo]

		case .apple:
			[.genderSelection, .photo]

		case .facebook:
			[.photo]
		}
	}
}
