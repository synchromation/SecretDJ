/// A scriptable ``PromotionEngaging`` fake for tests and previews — never
/// touches the network. Mirrors ``InMemoryLikeToggling``'s shape.
@MainActor
final class InMemoryPromotionEngaging: PromotionEngaging {
	struct Invocation: Equatable {
		let venueId: String?
		let promotionId: Int
	}

	private(set) var invocations: [Invocation] = []

	func engage(venueId: String?, promotionId: Int) async {
		invocations.append(Invocation(venueId: venueId, promotionId: promotionId))
	}
}
