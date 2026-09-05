import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = KeychainService.loadAPIKey() ?? ""
    @State private var savedConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Your key is stored securely in the iOS Keychain and is only used to call the Claude API directly from this device.")
                }

                if savedConfirmation {
                    Text("Saved")
                        .foregroundStyle(.green)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        KeychainService.save(apiKey: apiKey)
                        savedConfirmation = true
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
