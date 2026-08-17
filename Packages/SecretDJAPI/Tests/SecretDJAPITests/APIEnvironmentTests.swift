import Testing

@testable import SecretDJAPI

struct APIEnvironmentTests {
	@Test func `production targets the live secretdj backend`() {
		#expect(APIEnvironment.production.baseURL.host == "api4.secretdj.com")
	}

	@Test func `staging is a distinct placeholder from production`() {
		#expect(APIEnvironment.staging.baseURL != APIEnvironment.production.baseURL)
	}

	@Test func `every environment resolves to an https base URL`() {
		for environment in [APIEnvironment.production, APIEnvironment.staging] {
			#expect(environment.baseURL.scheme == "https")
		}
	}
}
