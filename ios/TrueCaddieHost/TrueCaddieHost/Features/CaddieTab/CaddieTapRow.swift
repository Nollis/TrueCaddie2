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

    @State private var draftScore = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            scoreSection
            resultSection
            completeSection

            if showEditButton {
                Button("Open Inspector") { onRequestEditor() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .secondarySystemBackground),
                            Color.green.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .onChange(of: currentScore) { _, newScore in
            draftScore = max(newScore, 1)
        }
        .onAppear {
            draftScore = max(currentScore, 1)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Play Hole \(holeNumber)")
                        .font(.title3.weight(.bold))
                    Text(isHoleFinished ? "Hole complete. You can still adjust the score here." : "Log the result and finish the hole without leaving the caddie screen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isHoleFinished {
                    statusChip("Complete", tint: .green)
                } else {
                    statusChip("In play", tint: .blue)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryPill(title: "Par", value: "\(par)")
                summaryPill(title: "Left", value: leftLabel)
                summaryPill(title: "Lie", value: lieLabel)
                summaryPill(title: "Shots", value: "\(max(currentShotNumber - 1, 0))")
            }
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Score")
                        .font(.headline.weight(.semibold))
                    Text("Adjust total strokes for this hole.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 16) {
                scoreButton(systemImage: "minus") {
                    draftScore = max(1, draftScore - 1)
                }

                VStack(spacing: 2) {
                    Text("\(draftScore)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("strokes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                scoreButton(systemImage: "plus") {
                    draftScore += 1
                }
            }

            HStack(spacing: 10) {
                statBadge("Current shot \(currentShotNumber)")
                if currentScore > 0 {
                    statBadge("Recorded \(currentScore)")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("After the shot")
                    .font(.headline.weight(.semibold))
                Text("Tap the most useful outcome so the caddie stays grounded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Finish the hole")
                    .font(.headline.weight(.semibold))
                Text("When the hole is over, save the score and move on to the next one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                onStartHole()
                onCompleteHole(draftScore)
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

    private func statusChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
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

    private var leftLabel: String {
        "\(Int(currentRemainingDistanceM.rounded())) m"
    }

    private var lieLabel: String {
        currentLie.rawValue.capitalized
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
    }
}
