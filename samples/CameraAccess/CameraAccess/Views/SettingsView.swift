import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = AppConfiguration.shared
    @State private var connectionStatus = "Not tested"

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("Backend URL", text: $configuration.backendURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Test connection") {
                        Task { await testConnection() }
                    }
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Calls") {
                    Toggle("Use demo call mode", isOn: $configuration.useDemoCalls)
                    Text(configuration.useDemoCalls ? "Uses a scripted transcript without placing a real call." : "Uses the backend Twilio flow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func testConnection() async {
        guard let url = configuration.backendURL else {
            connectionStatus = "Invalid URL"
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                connectionStatus = "Reachable (HTTP \(httpResponse.statusCode))"
            }
        } catch {
            connectionStatus = "Unreachable"
        }
    }
}
