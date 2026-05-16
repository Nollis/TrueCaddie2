import SwiftUI
import TrueCaddieDomain

struct InspectorRoundSection: View {
    let bundle: CourseBundle
    @Binding var roundState: RoundState
    @Binding var editingScoreHoleNumber: Int?
    @Binding var editingScoreStrokes: Int
    let currentHoleNumber: Int
    let onResetRound: () -> Void

    @State private var showResetConfirmation = false

    private var roundSummary: HostRoundProgressModel.RoundSummary {
        HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: roundState,
            currentHoleNumber: currentHoleNumber
        )
    }

    private var scorecardEntries: [HostRoundProgressModel.ScorecardEntry] {
        HostRoundProgressModel.scorecardEntries(
            bundle: bundle,
            roundState: roundState,
            currentHoleNumber: currentHoleNumber
        )
    }

    var body: some View {
        Section("Round Summary") {
            VStack(alignment: .leading, spacing: 6) {
                Text(roundSummary.totalsHeader)
                    .font(.title3.weight(.semibold))
                Text(roundSummary.currentHoleHeader)
                    .foregroundStyle(.secondary)
                Text(roundSummary.progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }

        Section("Round History") {
            if scorecardEntries.isEmpty {
                Text("No holes started yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scorecardEntries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Hole \(entry.holeNumber)")
                                        .fontWeight(.semibold)
                                    Text("Par \(entry.par)")
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.statusLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.strokesLabel)
                                    .fontWeight(.semibold)
                                Text(entry.relativeToParLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if entry.isCurrentHole {
                                    Text("Current")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.blue)
                                }
                            }

                            if entry.isFinished {
                                Button(editingScoreHoleNumber == entry.holeNumber ? "Cancel" : "Edit") {
                                    toggleScoreEdit(for: entry)
                                }
                                .font(.caption)
                            }
                        }

                        if editingScoreHoleNumber == entry.holeNumber {
                            Stepper(
                                "Set score to \(editingScoreStrokes)",
                                value: $editingScoreStrokes,
                                in: 1...15
                            )

                            Button("Save score") {
                                saveEditedScore(for: entry.holeNumber)
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            Button("Reset round", role: .destructive) {
                showResetConfirmation = true
            }
            .confirmationDialog(
                "Reset the current round?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset round", role: .destructive) { onResetRound() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func toggleScoreEdit(for entry: HostRoundProgressModel.ScorecardEntry) {
        if editingScoreHoleNumber == entry.holeNumber {
            editingScoreHoleNumber = nil
            return
        }
        editingScoreHoleNumber = entry.holeNumber
        editingScoreStrokes = entry.rawStrokesTaken ?? 1
    }

    private func saveEditedScore(for holeNumber: Int) {
        roundState = roundState.updateFinishedHoleScore(editingScoreStrokes, for: holeNumber)
        editingScoreHoleNumber = nil
    }
}
