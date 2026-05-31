import SwiftUI
import TrueCaddieDomain

struct CaddieVoiceCluster: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    @ObservedObject var locationModel: LiveCourseLocationModel
    @State private var listeningPulse = false

    var body: some View {
        VStack(spacing: 12) {
            primaryButton

            HStack(spacing: 12) {
                if voiceController.canInterrupt {
                    Button("Interrupt") { voiceController.interrupt() }
                        .buttonStyle(.bordered)
                        .font(.callout)
                }
                if voiceController.isSpeaking {
                    Button("Finish") { voiceController.finishPlayback() }
                        .buttonStyle(.bordered)
                        .font(.callout)
                }
                markBallButton
                Spacer(minLength: 0)
                statusChip
            }
        }
    }

    @ViewBuilder
    private var markBallButton: some View {
        Button(markBallButtonLabel) {
            _ = voiceController.markBallPosition()
        }
        .buttonStyle(.bordered)
        .font(.callout)
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
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel("Enable microphone access")
        } else if voiceController.isListening {
            Button {
                voiceController.stopListening()
            } label: {
                Label("Done Speaking", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityLabel("Voice session: \(stateLabel)")
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
}
