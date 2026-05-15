import SwiftUI
import TrueCaddieDomain

struct CaddieTabView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContext: RoundContext
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    @ObservedObject var voiceController: HostVoiceSessionController
    /// Imperative jump from "Edit…" tap chip into the Inspector tab.
    let onRequestInspector: () -> Void

    var body: some View {
        // Placeholder during scaffolding — real content lands in Tasks 2–6.
        Text("Caddie tab")
            .foregroundStyle(.secondary)
    }
}
