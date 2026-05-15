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
    @ObservedObject var voiceController: HostVoiceSessionController

    var body: some View {
        // Placeholder during scaffolding — real sections land in Tasks 3, 4, 5, 7.
        Text("Inspector tab")
            .foregroundStyle(.secondary)
    }
}
