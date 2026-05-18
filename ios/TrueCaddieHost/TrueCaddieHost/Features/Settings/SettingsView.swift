import SwiftUI

/// App settings sheet.  Accessible from both the Welcome screen and the
/// Caddie tab toolbar so developers can toggle the Inspector tab at any point
/// during a round without having to abandon it.
struct SettingsView: View {

    @AppStorage("truecaddie.developerToolsEnabled") private var developerToolsEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Developer Tools", isOn: $developerToolsEnabled)
                } footer: {
                    Text("Enables the Inspector tab and debug controls. For development use only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
