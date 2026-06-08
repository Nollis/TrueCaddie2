import SwiftUI
import TrueCaddieDomain

struct CaddieTapRow: View {
    let holeNumber: Int
    let par: Int
    let currentScore: Int
    let currentShotNumber: Int
    let currentRemainingDistanceM: Double
    let currentLie: ShotLie
    let isHoleFinished: Bool
    var showEditButton: Bool = false
    let onRequestEditor: () -> Void
    let onStartHole: () -> Void
    let onReportResult: (ShotLie) -> Void
    let onCompleteHole: (Int) -> Void

    @State private var showHoleSheet = false
    @State private var draftScore = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hole details")
                        .font(.headline.weight(.semibold))
                    Text("Track the hole, update the result, and finish cleanly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    showHoleSheet = true
                } label: {
                    Label("Open", systemImage: "slider.horizontal.3")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("Open hole details")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryPill(title: "Score", value: currentScore == 0 ? "-" : "\(currentScore)")
                summaryPill(title: "Shots", value: "\(max(currentShotNumber - 1, 0))")
                summaryPill(title: "Lie", value: lieLabel)
                summaryPill(title: "Left", value: "\(Int(currentRemainingDistanceM.rounded())) m")
            }

            if isHoleFinished {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Hole complete. You can still adjust the score from Hole details.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if showEditButton {
                Button("Open Inspector") { onRequestEditor() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .sheet(isPresented: $showHoleSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        headerSection
                        scoreSection
                        resultSection
                        completeSection
                    }
                    .padding(20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Hole \(holeNumber)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showHoleSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .onAppear {
                draftScore = max(currentScore, 1)
            }
        }
        .onChange(of: currentScore) { _, newScore in
            draftScore = max(newScore, 1)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                statBadge("Par \(par)")
                statBadge(currentRemainingDistanceM > 0 ? "\(Int(currentRemainingDistanceM.rounded())) m left" : "Ready")
                statBadge(lieLabel)
            }

            Text(isHoleFinished ? "Hole complete" : "Keep the round state simple and current.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hole score")
                .font(.headline.weight(.semibold))

            HStack(spacing: 18) {
                scoreButton(systemImage: "minus") {
                    draftScore = max(1, draftScore - 1)
                }

                VStack(spacing: 2) {
                    Text("\(draftScore)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("strokes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                scoreButton(systemImage: "plus") {
                    draftScore += 1
                }
            }

            Text("Current shot \(currentShotNumber)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After the shot")
                .font(.headline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                resultButton(title: "Fairway", systemImage: "checkmark.circle", lie: .fairway)
                resultButton(title: "Rough", systemImage: "leaf", lie: .rough)
                resultButton(title: "Bunker", systemImage: "triangle", lie: .bunker)
                resultButton(title: "Recovery", systemImage: "arrow.triangle.branch", lie: .recovery)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var completeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish the hole")
                .font(.headline.weight(.semibold))

            Button {
                onStartHole()
                onCompleteHole(draftScore)
                showHoleSheet = false
            } label: {
                Text(isHoleFinished ? "Update Hole Score" : "Complete Hole")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }

    private func statBadge(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.72))
            )
    }

    private func scoreButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func resultButton(title: String, systemImage: String, lie: ShotLie) -> some View {
        Button {
            onStartHole()
            onReportResult(lie)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }

    private var lieLabel: String {
        currentLie.rawValue.capitalized
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
    }
}
