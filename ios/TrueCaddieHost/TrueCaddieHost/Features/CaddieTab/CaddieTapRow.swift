import SwiftUI
import TrueCaddieDomain

struct CaddieTapRow: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    let currentRemainingDistanceM: Double
    /// When `true` an **Edit…** button appears that opens the Inspector tab.
    /// Set to `false` for normal players (inspector hidden).
    var showEditButton: Bool = false
    let onRequestEditor: () -> Void

    private var isEnabled: Bool { voiceController.isConnected }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                resultChip(.fairway, label: "Fairway")
                resultChip(.rough, label: "Rough")
                resultChip(.bunker, label: "Bunker")
                holeOutChip
                if showEditButton {
                    Button("Edit…") { onRequestEditor() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func resultChip(_ lie: ShotLie, label: String) -> some View {
        Button(label) {
            _ = voiceController.submitVoiceToolInvocation(
                VoiceToolInvocation(
                    actionName: .reportResult,
                    arguments: .init(lie: lie, remainingDistanceM: currentRemainingDistanceM)
                )
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isEnabled)
        .accessibilityLabel("Report \(label) result")
    }

    private var holeOutChip: some View {
        Button("Holed Out") {
            _ = voiceController.submitVoiceToolInvocation(
                VoiceToolInvocation(
                    actionName: .holeOut,
                    arguments: .init()
                )
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isEnabled)
        .accessibilityLabel("Report holed out")
    }
}
