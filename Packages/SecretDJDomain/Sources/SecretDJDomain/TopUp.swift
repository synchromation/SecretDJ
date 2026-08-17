/// Which store fulfilled a top-up purchase (`VendorId`).
public enum Vendor: Int, Sendable, Hashable, Codable {
	case unknown = 0
	case googlePlayStore = 1
	case appleAppStore = 2
}

/// A purchasable credit bundle — the `topUp` template.
public struct TopUp: Sendable, Hashable, Decodable {
	public let sku: String
	public let vendor: Vendor
	public let name: String
	public let productDescription: String
	/// The server's raw price string, before any StoreKit override.
	public let price: String
	public let displayPrice: String
	public let currencyCode: String
	public let url: String?
	public let numCredits: Int
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]

	public init(
		sku: String,
		vendor: Vendor,
		name: String,
		productDescription: String,
		price: String,
		displayPrice: String,
		currencyCode: String,
		url: String?,
		numCredits: Int,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
	) {
		self.sku = sku
		self.vendor = vendor
		self.name = name
		self.productDescription = productDescription
		self.price = price
		self.displayPrice = displayPrice
		self.currencyCode = currencyCode
		self.url = url
		self.numCredits = numCredits
		self.text = text
		self.sortIndex = sortIndex
		self.action = action
		self.actions = actions
	}

	private enum CodingKeys: String, CodingKey {
		case text = "Text"
		case sortIndex = "Index"
		case data = "Data"
	}

	private enum DataKeys: String, CodingKey {
		case sku = "SKU"
		case vendor = "VendorId"
		case name = "Name"
		case productDescription = "Description"
		case price = "Price"
		case displayPrice = "DisplayPrice"
		case currencyCode = "CurrencyCode"
		case url = "Url"
		case numCredits = "NumCredits"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		let sku = try data.decodeIfPresent(String.self, forKey: .sku) ?? ""
		guard !sku.isEmpty else {
			throw DecodingError.dataCorruptedError(
				forKey: .sku,
				in: data,
				debugDescription: "TopUp requires a non-empty SKU",
			)
		}
		self.sku = sku
		// Unlike legacy (`TopUp.swift:35`, which casts the raw Int straight to
		// `Vendor` and always fails, reading every purchase as `.unknown`),
		// this decodes the raw int and maps it properly.
		vendor = try Vendor(rawValue: data.decodeIfPresent(Int.self, forKey: .vendor) ?? 0) ?? .unknown
		name = try data.decodeIfPresent(String.self, forKey: .name) ?? ""
		productDescription = try data.decodeIfPresent(String.self, forKey: .productDescription) ?? ""
		price = try data.decodeIfPresent(String.self, forKey: .price) ?? ""
		displayPrice = try data.decodeIfPresent(String.self, forKey: .displayPrice) ?? ""
		currencyCode = try data.decodeIfPresent(String.self, forKey: .currencyCode) ?? ""
		url = try data.decodeIfPresent(String.self, forKey: .url)?.nonEmptyOrNil
		numCredits = try data.decodeIfPresent(Int.self, forKey: .numCredits) ?? 0
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
	}
}
