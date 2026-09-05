import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = KeychainService.load(.anthropicAPIKey) ?? ""
    @State private var ebayAppID: String = KeychainService.load(.ebayAppID) ?? ""
    @State private var ebayCertID: String = KeychainService.load(.ebayCertID) ?? ""
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
                    Text("Used to identify the item from your photo. Stored in the iOS Keychain.")
                }

                Section {
                    TextField("App ID (Client ID)", text: $ebayAppID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Cert ID (Client Secret)", text: $ebayCertID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("eBay Developer Keys")
                } footer: {
                    Text("Optional but recommended: powers the real average listing price from eBay's Browse API. Get a production keyset at developer.ebay.com. Without these, the app falls back to the AI's own price estimate.")
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
                        KeychainService.save(apiKey, for: .anthropicAPIKey)
                        KeychainService.save(ebayAppID, for: .ebayAppID)
                        KeychainService.save(ebayCertID, for: .ebayCertID)
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
