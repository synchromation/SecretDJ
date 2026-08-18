import Foundation

/// Loads a JSON fixture file bundled under `Resources/`, copied verbatim
/// from `secret-dj-ios-old/SecretDJTests` (each call site's doc comment
/// says which legacy file and why) rather than referenced across repos.
enum Fixture {
	static func data(_ name: String) -> Data {
		load(name, subdirectory: "Resources")
	}

	/// Loads a JSON fixture captured against the live production backend
	/// under `Resources/Live/` (PLAN.md's R2: the approved live-capture
	/// pass), pretty-printed as received with only session tokens, auth
	/// material, and email addresses redacted to a same-shape dummy — each
	/// call site's doc comment says which endpoint and what, if anything,
	/// it redacted.
	static func liveData(_ name: String) -> Data {
		load(name, subdirectory: "Resources/Live")
	}

	private static func load(_ name: String, subdirectory: String) -> Data {
		guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: subdirectory),
		      let data = try? Data(contentsOf: url) else
		{
			preconditionFailure("Missing test fixture: \(subdirectory)/\(name).json")
		}
		return data
	}
}
