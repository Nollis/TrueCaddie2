import SwiftUI
import TrueCaddieDomain

struct CaddieTabView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContext: RoundContext
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    let preview: HostRoundPreviewModel.HolePreview?
    @ObservedObject var voiceController: HostVoiceSessionController
    let onRequestInspector: () -> Void

    private var currentPar: Int {
        bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })?.par ?? 0
    }

    private var currentLie: ShotLie {
        roundState.holeState(for: selectedHoleNumber)?.shotStateContext?.lie ?? .tee
    }

    private var currentRemainingDistanceM: Double {
        roundState.holeState(for: selectedHoleNumber)?.shotStateContext?.remainingDistanceM ?? 0
    }

    private var currentRoundScoreVsPar: Int {
        roundState.holeStates.filter { $0.status == .finished }.reduce(0) { total, holeState in
            let par = bundle.holes.first(where: { $0.holeNumber == holeState.holeNumber })?.par ?? 0
            return total + ((holeState.strokesTaken ?? 0) - par)
        }
    }

    private var emptyStateText: String {
        if voiceController.needsMicrophonePermission {
            return "Enable microphone access to start the caddie."
        }
        if !voiceController.isConnected {
            return "Tap Connect to start the caddie."
        }
        return "Hole \(selectedHoleNumber) ready · Tap Start Listening"
    }

    var body: some View {
        VStack(spacing: 0) {
            CaddieStatusPill(
                holeNumber: selectedHoleNumber,
                par: currentPar,
                remainingDistanceM: currentRemainingDistanceM,
                lie: currentLie,
                roundScoreVsPar: currentRoundScoreVsPar,
                onTap: onRequestInspector
            )

            ScrollView {
                VStack(spacing: 16) {
                    CaddieRecommendationHero(
                        packet: preview?.packet,
                        emptyStateText: emptyStateText
                    )
                    .padding(.horizontal, 16)

                    CaddieVoiceCluster(voiceController: voiceController)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 0)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            CaddieTapRow(
                voiceController: voiceController,
                currentRemainingDistanceM: currentRemainingDistanceM,
                onRequestEditor: onRequestInspector
            )
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }
}
