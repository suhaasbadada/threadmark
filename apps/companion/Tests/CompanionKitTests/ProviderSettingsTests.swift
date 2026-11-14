import Foundation
import Testing
@testable import CompanionKit

struct ProviderSettingsTests {
    @Test func defaultOffAndExplicitConfiguration() throws {
        var settings = ProviderSettings()
        #expect(throws: ProviderSettingsError.self) { try settings.selectedProfile() }
        let profile = ProviderProfile(id: "synthetic", endpoint: "http://127.0.0.1:8080/v1/chat/completions", model: "fixture-model", locality: .local)
        try settings.configure(profile)
        #expect(throws: ProviderSettingsError.self) { try settings.selectedProfile() }
        settings.enabled = true
        #expect(try settings.selectedProfile() == profile)
        let decoded = try JSONDecoder().decode(ProviderSettings.self, from: JSONEncoder().encode(settings))
        #expect(try decoded.selectedProfile() == profile)
        try settings.configure(profile)
        #expect(!settings.enabled)
    }

    @Test func secretsAndAmbiguousEndpointsReject() {
        for endpoint in ["http://example.com/v1", "https://user:password@example.com/v1", "https://example.com/v1?key=synthetic", "https://example.com/v1#fragment", "http://localhost/v1", "http://127.0.0.1/v1%0d", "file:///local"] {
            for locality in ProviderProfile.Locality.allCases {
                #expect(throws: ProviderSettingsError.self) { try ProviderProfile(id: "fixture", endpoint: endpoint, model: "fixture-model", locality: locality).validate() }
            }
        }
        #expect(throws: Never.self) { try ProviderProfile(id: "remote", endpoint: "https://provider.invalid/v1/chat/completions", model: "fixture-model", locality: .remote).validate() }
        for endpoint in ["https://./v1", "https://-bad.invalid/v1", "https://bad..invalid/v1", "https://localhost/v1", "https://127.0.0.2/v1", "https://0.0.0.0/v1"] {
            #expect(throws: ProviderSettingsError.self) { try ProviderProfile(id: "remote", endpoint: endpoint, model: "model", locality: .remote).validate() }
        }
    }

    @Test func missingAndDuplicateProfilesFailClosed() throws {
        var settings = ProviderSettings()
        settings.enabled = true
        #expect(throws: ProviderSettingsError.self) { try settings.selectedProfile() }
        let profile = ProviderProfile(id: "fixture", endpoint: "http://127.0.0.1:8080/v1", model: "model", locality: .local)
        settings.profiles = [profile, profile]; settings.selectedProfileID = profile.id
        #expect(throws: ProviderSettingsError.self) { try settings.selectedProfile() }
    }
}
