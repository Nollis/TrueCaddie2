import SwiftUI

struct InspectorVoiceDiagnosticsSection: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    @ObservedObject private var debugLog = AppDebugLogStore.shared

    var body: some View {
        Section("Voice diagnostics") {
            LabeledContent("Connection", value: connectionLabel)
            LabeledContent("Debug log", value: "\(debugLog.entryCount) events")

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

            DisclosureGroup("Recent debug events") {
                if debugLog.entries.isEmpty {
                    Text("No debug events yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(debugLog.entries.suffix(30)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(logHeader(for: entry))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(logBody(for: entry))
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Button("Copy diagnostics") {
                UIPasteboard.general.string = diagnosticsDump
            }
            .disabled(voiceController.state.transcriptEntries.isEmpty && debugLog.entries.isEmpty)

            Button("Clear debug log", role: .destructive) {
                debugLog.clear()
            }
            .disabled(debugLog.entries.isEmpty)
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

    private var diagnosticsDump: String {
        let transcriptSection = transcriptDump.isEmpty ? "No transcript" : transcriptDump
        let logSection = debugLog.exportText()
        return """
        Transcript
        \(transcriptSection)

        Debug log
        \(logSection.isEmpty ? "No debug events" : logSection)
        """
    }

    private func logHeader(for entry: AppDebugLogEntry) -> String {
        "\(entry.timestamp.formatted(date: .omitted, time: .standard)) · \(entry.category.rawValue)"
    }

    private func logBody(for entry: AppDebugLogEntry) -> String {
        let metadata = entry.metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return metadata.isEmpty ? entry.message : "\(entry.message) \(metadata)"
    }
}
