import Foundation

/// Nonsecret settings only. Credentials and per-request content consent are separate.
public struct ProviderProfile: Codable, Equatable, Sendable, Identifiable {
    public enum Locality: String, Codable, CaseIterable, Sendable { case local, remote }
    public var id: String
    public var endpoint: String
    public var model: String
    public var locality: Locality

    public init(id: String, endpoint: String, model: String, locality: Locality) {
        self.id = id; self.endpoint = endpoint; self.model = model; self.locality = locality
    }

    /// Strict endpoint subset shared with the Rust provider boundary. No URL secrets.
    public func validate() throws {
        guard Self.identifier(id), Self.identifier(model), endpoint.utf8.count <= 2048,
              endpoint.utf8.allSatisfy({ $0 > 32 && $0 < 127 }), !endpoint.contains("%"),
              let parts = URLComponents(string: endpoint), let host = parts.host,
              parts.user == nil, parts.password == nil, parts.query == nil,
              parts.fragment == nil, !parts.path.isEmpty,
              parts.path.utf8.allSatisfy({ Self.pathByte($0) }),
              parts.port.map({ (1...65535).contains($0) }) ?? true,
              !host.isEmpty, host.utf8.allSatisfy({ Self.hostByte($0) })
        else { throw ProviderSettingsError.invalid }
        let loopback = host == "127.0.0.1" || host == "[::1]" || host == "::1"
        guard (locality == .local && loopback && parts.scheme == "http")
                || (locality == .remote && !loopback && parts.scheme == "https")
        else { throw ProviderSettingsError.invalid }
        if !loopback {
            let host = host.lowercased()
            let labels = host.split(separator: ".", omittingEmptySubsequences: false)
            guard host.utf8.count <= 253, host != "localhost", !host.hasSuffix(".localhost"),
                  !host.hasPrefix("127."), host != "0.0.0.0", host != "255.255.255.255",
                  labels.allSatisfy({ label in
                      !label.isEmpty && label.utf8.count <= 63
                          && label.utf8.first!.isASCIIAlphaNumeric && label.utf8.last!.isASCIIAlphaNumeric
                  })
            else { throw ProviderSettingsError.invalid }
        }
    }

    private static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
            && value.utf8.allSatisfy { $0 > 32 && $0 < 127 }
    }
    private static func pathByte(_ b: UInt8) -> Bool {
        b.isASCIIAlphaNumeric || [47, 45, 46, 95, 126].contains(b)
    }
    private static func hostByte(_ b: UInt8) -> Bool {
        b.isASCIIAlphaNumeric || [45, 46, 58, 91, 93].contains(b)
    }
}

private extension UInt8 {
    var isASCIIAlphaNumeric: Bool {
        (65...90).contains(self) || (97...122).contains(self) || (48...57).contains(self)
    }
}

public enum ProviderSettingsError: Error { case invalid, disabled, missingProfile }

/// Host-owned encoding only; no implicit disk/global/environment access.
/// Loading settings never constitutes consent to upload any particular request.
public struct ProviderSettings: Codable, Equatable, Sendable {
    public var profiles: [ProviderProfile] = []
    public var selectedProfileID: String?
    public var enabled = false

    public init() {}

    public func selectedProfile() throws -> ProviderProfile {
        guard enabled else { throw ProviderSettingsError.disabled }
        guard profiles.count <= 16, Set(profiles.map(\.id)).count == profiles.count,
              let profile = profiles.first(where: { $0.id == selectedProfileID })
        else { throw ProviderSettingsError.missingProfile }
        try profile.validate()
        return profile
    }

    /// Replacement invalidates enablement; host must ask for opt-in again.
    public mutating func configure(_ profile: ProviderProfile) throws {
        try profile.validate()
        guard profiles.count < 16 || profiles.contains(where: { $0.id == profile.id })
        else { throw ProviderSettingsError.invalid }
        profiles.removeAll { $0.id == profile.id }
        profiles.append(profile)
        selectedProfileID = profile.id
        enabled = false
    }
}
