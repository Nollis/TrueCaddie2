import SwiftUI
import TrueCaddieDomain

struct CaddieVoiceCluster: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    @ObservedObject var locationModel: LiveCourseLocationModel
    @State private var listeningPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(voicePromptTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(voicePromptSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                primaryButton
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )

            HStack(spacing: 10) {
                markBallButton

                if voiceController.canInterrupt {
                    compactActionButton("Interrupt", systemImage: "waveform.slash") {
                        voiceController.interrupt()
                    }
                }

                if voiceController.isSpeaking {
                    compactActionButton("Done", systemImage: "checkmark.circle") {
                        voiceController.finishPlayback()
                    }
                }

                Spacer(minLength: 0)
                statusChip
            }
        }
    }

    @ViewBuilder
    private var markBallButton: some View {
        compactActionButton(markBallButtonLabel, systemImage: "location.fill") {
            _ = voiceController.markBallPosition()
        }
        .disabled(!isCaptureReady)
        .accessibilityLabel("Mark ball position from GPS")
    }

    private var markBallButtonLabel: String {
        guard let fix = locationModel.lastFix else { return "GPS warming up" }
        if fix.horizontalAccuracyM > GolfGeometry.Constants.minimumAcceptableAccuracyM {
            return "GPS warming up"
        }
        return "I'm at my ball"
    }

    private var isCaptureReady: Bool {
        guard let fix = locationModel.lastFix else { return false }
        return fix.horizontalAccuracyM <= GolfGeometry.Constants.minimumAcceptableAccuracyM
    }

    @ViewBuilder
    private var primaryButton: some View {
        if voiceController.needsMicrophonePermission {
            Button {
                voiceController.requestMicrophoneAccess()
            } label: {
                Label("Allow Microphone", systemImage: "mic.fill")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel("Enable microphone access")
        } else if voiceController.isListening {
            Button {
                voiceController.stopListening()
            } label: {
                Label("Done Speaking", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!voiceController.canStopListening)
            .accessibilityLabel("Stop listening, double-tap to stop")
        } else {
            Button {
                voiceController.beginListening()
            } label: {
                Label("Talk to Caddie", systemImage: "mic.fill")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!voiceController.canStartListening && !voiceController.canConnect)
            .accessibilityLabel("Talk to caddie")
        }
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .opacity(voiceController.isListening ? (listeningPulse ? 1.0 : 0.35) : 1.0)
                .animation(
                    voiceController.isListening
                        ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                        : .default,
                    value: listeningPulse
                )
                .onChange(of: voiceController.isListening) { _, listening in
                    listeningPulse = listening
                }
            Text(stateLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityLabel("Voice session: \(stateLabel)")
    }

    private func compactActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    private var dotColor: Color {
        switch voiceController.state.connectionState {
        case .disconnected: return .gray
        case .connecting: return .gray
        case .connected:
            if voiceController.isListening { return .red }
            if voiceController.state.playbackState == .speaking { return .blue }
            return .gray
        case .failed: return .orange
        }
    }

    private var stateLabel: String {
        switch voiceController.state.connectionState {
        case .disconnected: return "Ready"
        case .connecting: return "Getting ready"
        case .connected:
            if voiceController.isListening { return "Listening" }
            if voiceController.state.playbackState == .speaking { return "Speaking" }
            return "Ready"
        case .failed: return "Failed"
        }
    }

    private var voicePromptTitle: String {
        if voiceController.needsMicrophonePermission {
            return "Set up voice"
        }
        if voiceController.isListening {
            return "Listening now"
        }
        if voiceController.isSpeaking {
            return "Caddie is speaking"
        }
        return "Ask for the next shot"
    }

    private var voicePromptSubtitle: String {
        if voiceController.needsMicrophonePermission {
            return "Enable the mic once and the caddie will be ready whenever you need it."
        }
        if voiceController.isListening {
            return "Speak naturally, then tap Done Speaking when you've finished."
        }
        if voiceController.isSpeaking {
            return "Let the guidance finish, or interrupt if you want to jump in."
        }
        return "Ask what the play is, or mark your ball position for grounded guidance."
    }
}
