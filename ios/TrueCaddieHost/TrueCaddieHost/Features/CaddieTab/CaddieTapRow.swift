import SwiftUI
import TrueCaddieDomain

struct CaddieTapRow: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    let currentRemainingDistanceM: Double
    /// When `true` an **Edit…** button appears that opens the Inspector tab.
    /// Set to `false` for normal players (inspector hidden).
    var showEditButton: Bool = false
    let onRequestEditor: () -> Void

    private var isEnabled: Bool { !voiceController.needsMicrophonePermission }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("After the shot")
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 0)
                Text("Quick update")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    resultChip(.fairway, label: "Fairway", systemImage: "checkmark.circle")
                    resultChip(.rough, label: "Rough", systemImage: "leaf")
                    resultChip(.bunker, label: "Bunker", systemImage: "triangle")
                    holeOutChip
                    if showEditButton {
                        Button("Edit") { onRequestEditor() }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func resultChip(_ lie: ShotLie, label: String, systemImage: String) -> some View {
        Button {
            _ = voiceController.submitResolvedVoiceToolInvocation(
                VoiceToolInvocation(
                    actionName: .reportResult,
                    arguments: .init(lie: lie, remainingDistanceM: currentRemainingDistanceM)
                )
            )
        } label: {
            Label(label, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!isEnabled)
        .accessibilityLabel("Report \(label) result")
    }

    private var holeOutChip: some View {
        Button("Holed Out") {
            _ = voiceController.submitResolvedVoiceToolInvocation(
                VoiceToolInvocation(
                    actionName: .holeOut,
                    arguments: .init()
                )
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!isEnabled)
        .accessibilityLabel("Report holed out")
    }
}
