import SwiftUI

/// App settings sheet.  Accessible from both the Welcome screen and the
/// Caddie tab toolbar so developers can toggle the Inspector tab at any point
/// during a round without having to abandon it.
struct SettingsView: View {

    @AppStorage("truecaddie.developerToolsEnabled") private var developerToolsEnabled = false
    @ObservedObject private var debugLog = AppDebugLogStore.shared
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

                Section {
                    LabeledContent("Events", value: "\(debugLog.entryCount)")

                    Button("Copy Debug Log") {
                        UIPasteboard.general.string = debugLog.exportText()
                    }
                    .disabled(debugLog.entries.isEmpty)

                    Button("Clear Debug Log", role: .destructive) {
                        debugLog.clear()
                    }
                    .disabled(debugLog.entries.isEmpty)
                } header: {
                    Text("Debug Log")
                } footer: {
                    Text("Stores recent round, location, and voice events on-device so you can copy them after an on-course test.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
