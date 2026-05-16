import SwiftUI

struct InspectorVoiceDiagnosticsSection: View {
    @ObservedObject var voiceController: HostVoiceSessionController

    var body: some View {
        Section("Voice diagnostics") {
            LabeledContent("Connection", value: connectionLabel)

            if let session = voiceController.state.activeSession {
                LabeledContent("Session") {
                    Text(String(session.id.prefix(8)))
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let failure = lastFailureMessage {
                LabeledContent("Last error") {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            DisclosureGroup("Transcript history") {
                if voiceController.state.transcriptEntries.isEmpty {
                    Text("No transcript yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(voiceController.state.transcriptEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.speakerLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(entry.text)
                                .font(.footnote)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Button("Copy session") {
                UIPasteboard.general.string = transcriptDump
            }
            .disabled(voiceController.state.transcriptEntries.isEmpty)
        }
    }

    private var connectionLabel: String {
        switch voiceController.state.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected(let descriptor): return "Connected · \(descriptor.model)"
        case .failed(let message): return "Failed: \(message)"
        }
    }

    private var lastFailureMessage: String? {
        if case .failed(let message) = voiceController.state.connectionState { return message }
        return nil
    }

    private var transcriptDump: String {
        voiceController.state.transcriptEntries
            .map { "\($0.speakerLabel): \($0.text)" }
            .joined(separator: "\n")
    }
}
