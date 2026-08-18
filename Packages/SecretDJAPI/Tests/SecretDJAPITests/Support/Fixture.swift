import Foundation

/// Loads a JSON fixture file bundled under `Resources/`, copied verbatim
/// from `secret-dj-ios-old/SecretDJTests` (each call site's doc comment
/// says which legacy file and why) rather than referenced across repos.
enum Fixture {
	static func data(_ name: String) -> Data {
		guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources"),
		      let data = try? Data(contentsOf: url) else
		{
			preconditionFailure("Missing test fixture: \(name).json")
		}
		return data
	}
}
