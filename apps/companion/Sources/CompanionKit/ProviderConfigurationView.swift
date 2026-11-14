import SwiftUI

// Match the companion's command-line SDK workaround for the same-named macro.
private typealias ProviderViewState<Value> = SwiftUI.State<Value>

/// Optional Connections section. This is not a composer and cannot invoke inference.
/// The host owns persistence; saved settings never grant per-request data consent.
public struct ProviderConfigurationView: View {
    @Binding private var settings: ProviderSettings
    @ProviderViewState<String> private var profileID = ""
    @ProviderViewState<String> private var endpoint = ""
    @ProviderViewState<String> private var model = ""
    @ProviderViewState<ProviderProfile.Locality> private var locality = .local
    @ProviderViewState<String> private var status = "Inference is off by default. No credentials are loaded."

    public init(settings: Binding<ProviderSettings>) { _settings = settings }

    public var body: some View {
        Form {
            Text("Optional inference profiles").font(.headline)
            Text("Local means numeric loopback HTTP on this computer. Remote requires HTTPS and separate consent to send the exact request, selected evidence and attachment metadata. No attachment bytes or whole-project upload.")
            TextField("Profile name", text: $profileID)
            TextField("Exact chat-completions endpoint (no credentials)", text: $endpoint)
            TextField("Model identifier", text: $model)
            Picker("Data destination", selection: $locality) {
                Text("Local — loopback HTTP").tag(ProviderProfile.Locality.local)
                Text("Remote — HTTPS").tag(ProviderProfile.Locality.remote)
            }
            Button("Save profile (leave inference off)") {
                do {
                    try settings.configure(ProviderProfile(id: profileID, endpoint: endpoint, model: model, locality: locality))
                    status = "Profile saved. Inference is off; no request was sent."
                } catch { status = "Invalid profile, model or endpoint. Do not include credentials, query or fragment."
                }
            }
            Picker("Selected profile", selection: $settings.selectedProfileID) {
                Text("None").tag(Optional<String>.none)
                ForEach(settings.profiles) { profile in Text(profile.id).tag(Optional(profile.id)) }
            }
            .onChange(of: settings.selectedProfileID) { _ in settings.enabled = false }
            if let selected = settings.profiles.first(where: { $0.id == settings.selectedProfileID }) {
                Text("Selected: \(selected.id) · \(selected.model) · \(selected.endpoint) · \(selected.locality.rawValue)")
                    .textSelection(.enabled)
                Button("Edit selected profile in form") {
                    profileID = selected.id; endpoint = selected.endpoint; model = selected.model; locality = selected.locality
                }
            }
            Text("Supported transport: numeric-loopback HTTP only. Remote profiles can be saved, but remote inference is not ready. Enabling a profile is not a transport test or request consent.")
            Button(settings.enabled ? "Disable inference" : "Explicitly enable selected profile") {
                if settings.enabled { settings.enabled = false; status = "Inference disabled."; return }
                var candidate = settings
                candidate.enabled = true
                do {
                    _ = try candidate.selectedProfile()
                    settings = candidate
                    status = "Profile enabled, not data consent. Refine still requires exact request/provider/budget approval. Remote TLS and secure secret entry are not connected in this lane."
                } catch { status = "Select a valid profile before enabling inference." }
            }
            Text(status).accessibilityLabel("Provider configuration status: \(status)")
            Text("Credential entry is deferred until an authorized protected-storage integration exists. No environment keys are reused. Configuration alone does not contact the endpoint.")
        }
    }
}
