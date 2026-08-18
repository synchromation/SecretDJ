/// One screen in the post-signup onboarding sequence (LEGACY.md "Login,
/// sign-up, onboarding") — which steps apply, and in what order, is
/// ``OnboardingRoute/steps``'s responsibility.
enum OnboardingStep: Equatable {
	case genderSelection
	case photo
}
