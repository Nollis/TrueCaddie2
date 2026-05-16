import SwiftUI
import TrueCaddieDomain

struct InspectorTabView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContext: RoundContext
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    @Binding var editingScoreHoleNumber: Int?
    @Binding var editingScoreStrokes: Int
    @Binding var selectedPlanMode: HostRoundPreviewModel.RoundPlanMode
    @Binding var selectedScenarioId: String
    @Binding var pendingHoleOutStrokes: Int?
    let scenarioOptions: [HoleInspectorModel.ShotStateScenario]
    @ObservedObject var voiceController: HostVoiceSessionController
    let onResetRound: () -> Void
    let onStartHole: () -> Void
    let onAdvanceHole: () -> Void
    let onConfirmHoleOut: () -> Void
    let onCancelHoleOut: () -> Void
    let onResetHole: () -> Void
    let onBeginShotResultCapture: (ShotStateContext) -> Void

    var body: some View {
        NavigationStack {
            Form {
                InspectorRoundSection(
                    bundle: bundle,
                    roundState: $roundState,
                    editingScoreHoleNumber: $editingScoreHoleNumber,
                    editingScoreStrokes: $editingScoreStrokes,
                    currentHoleNumber: selectedHoleNumber,
                    onResetRound: onResetRound
                )

                InspectorShotContextSection(
                    bundle: bundle,
                    selectedHoleNumber: $selectedHoleNumber,
                    roundOverrides: $roundOverrides,
                    roundState: $roundState,
                    pendingHoleOutStrokes: $pendingHoleOutStrokes,
                    onStartHole: onStartHole,
                    onAdvanceHole: onAdvanceHole,
                    onConfirmHoleOut: onConfirmHoleOut,
                    onCancelHoleOut: onCancelHoleOut,
                    onResetHole: onResetHole,
                    onBeginShotResultCapture: onBeginShotResultCapture
                )

                InspectorStrategySection(
                    bundle: bundle,
                    roundOverrides: $roundOverrides,
                    selectedPlanMode: $selectedPlanMode,
                    selectedScenarioId: $selectedScenarioId,
                    scenarioOptions: scenarioOptions,
                    usesLiveState: roundState.holeState(for: selectedHoleNumber)?.status == .inProgress,
                    isHoleFinished: roundState.holeState(for: selectedHoleNumber)?.status == .finished
                )

                InspectorVoiceDiagnosticsSection(voiceController: voiceController)

                InspectorDeveloperSection(voiceController: voiceController)
            }
            .navigationTitle("Inspector")
        }
    }
}
