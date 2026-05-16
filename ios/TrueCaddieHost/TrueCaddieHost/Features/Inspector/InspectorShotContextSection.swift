import SwiftUI
import TrueCaddieDomain

struct InspectorShotContextSection: View {
    let bundle: CourseBundle
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    @Binding var pendingHoleOutStrokes: Int?
    let onStartHole: () -> Void
    let onAdvanceHole: () -> Void
    let onConfirmHoleOut: () -> Void
    let onCancelHoleOut: () -> Void
    let onResetHole: () -> Void
    let onBeginShotResultCapture: (ShotStateContext) -> Void

    private var selectedHole: CourseHole? {
        bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })
    }

    private var selectedHoleState: HoleRoundState? {
        roundState.holeState(for: selectedHoleNumber)
    }

    private var teeOptions: [Tee] {
        selectedHole?.tees ?? []
    }

    private var usesLiveState: Bool {
        selectedHoleState?.status == .inProgress
    }

    private var isHoleFinished: Bool {
        selectedHoleState?.status == .finished
    }

    private var liveDistanceRange: ClosedRange<Double> {
        let maxTeeLength = selectedHole?.tees.map(\.teeLengthM).max() ?? 250
        return 0...max(150, maxTeeLength)
    }

    var body: some View {
        Section("Shot context") {
            Picker("Current Hole", selection: $selectedHoleNumber) {
                ForEach(bundle.holes, id: \.holeNumber) { hole in
                    Text("Hole \(hole.holeNumber)").tag(hole.holeNumber)
                }
            }
            .pickerStyle(.menu)

            if !teeOptions.isEmpty {
                Picker("Tee", selection: $roundOverrides.teeSetId) {
                    ForEach(teeOptions) { tee in
                        Text(tee.name).tag(tee.teeSetId)
                    }
                }
                .pickerStyle(.menu)
            }
        }

        Section("Hole state") {
            if usesLiveState, let holeState = selectedHoleState, let ctx = holeState.shotStateContext {
                HStack {
                    Button("Advance shot") { onAdvanceHole() }
                    Spacer()
                    Button("Record result") { onBeginShotResultCapture(ctx) }
                        .tint(.blue)
                    Spacer()
                    Button("Hole out") {
                        pendingHoleOutStrokes = ctx.shotNumber
                    }
                    .tint(.green)
                }

                if let pending = pendingHoleOutStrokes {
                    Stepper(
                        "Finish in \(pending) strokes",
                        value: Binding(
                            get: { pendingHoleOutStrokes ?? 1 },
                            set: { pendingHoleOutStrokes = $0 }
                        ),
                        in: 1...15
                    )

                    HStack {
                        Button("Confirm score") { onConfirmHoleOut() }
                            .tint(.green)
                        Spacer()
                        Button("Cancel") { onCancelHoleOut() }
                    }
                }

                Stepper(
                    "Shot \(ctx.shotNumber)",
                    value: Binding(
                        get: { ctx.shotNumber },
                        set: { updateShotNumber($0, ctx: ctx) }
                    ),
                    in: 1...10
                )

                Picker(
                    "Lie",
                    selection: Binding(
                        get: { ctx.lie },
                        set: { updateLie($0, ctx: ctx) }
                    )
                ) {
                    ForEach(HostRoundPreviewModel.lieOptions, id: \.rawValue) { lie in
                        Text(lie.rawValue.capitalized).tag(lie)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Remaining", value: "\(metric(ctx.remainingDistanceM)) m")

                Slider(
                    value: Binding(
                        get: { ctx.remainingDistanceM },
                        set: { updateRemainingDistance($0, ctx: ctx) }
                    ),
                    in: liveDistanceRange,
                    step: 1
                )
            } else if isHoleFinished {
                LabeledContent("Status", value: "Finished")
                LabeledContent(
                    "Score",
                    value: "\(selectedHoleState?.strokesTaken ?? 0)"
                )
                Button("Reset hole") { onResetHole() }
            } else {
                Button("Start hole") { onStartHole() }
            }
        }
    }

    private func updateShotNumber(_ shotNumber: Int, ctx: ShotStateContext) {
        roundState = roundState.updateShotState(
            ShotStateContext(shotNumber: shotNumber, remainingDistanceM: ctx.remainingDistanceM, lie: ctx.lie),
            for: selectedHoleNumber
        )
    }

    private func updateLie(_ lie: ShotLie, ctx: ShotStateContext) {
        roundState = roundState.updateShotState(
            ShotStateContext(shotNumber: ctx.shotNumber, remainingDistanceM: ctx.remainingDistanceM, lie: lie),
            for: selectedHoleNumber
        )
    }

    private func updateRemainingDistance(_ distance: Double, ctx: ShotStateContext) {
        roundState = roundState.updateShotState(
            ShotStateContext(shotNumber: ctx.shotNumber, remainingDistanceM: distance, lie: ctx.lie),
            for: selectedHoleNumber
        )
    }

    private func metric(_ number: Double) -> String {
        if number.rounded() == number { return String(Int(number)) }
        return String(format: "%.1f", number)
    }
}
