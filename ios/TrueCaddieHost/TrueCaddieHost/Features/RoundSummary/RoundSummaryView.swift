import SwiftUI
import TrueCaddieDomain

/// Presented as a full-screen sheet when the player completes the final hole.
/// Shows the full scorecard and offers a single **New Round** exit so the app
/// never silently returns to a completed round.
struct RoundSummaryView: View {

    let bundle: CourseBundle
    let roundState: RoundState
    /// Called when the player taps **New Round**.  The caller is responsible
    /// for deleting saved progress and returning to the Welcome screen.
    let onNewRound: () -> Void

    private var summary: HostRoundProgressModel.RoundSummary {
        HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: roundState,
            currentHoleNumber: bundle.holes.last?.holeNumber ?? 0
        )
    }

    private var scorecardEntries: [HostRoundProgressModel.ScorecardEntry] {
        HostRoundProgressModel.scorecardEntries(
            bundle: bundle,
            roundState: roundState,
            currentHoleNumber: bundle.holes.last?.holeNumber ?? 0
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    completionBadge
                    totalsCard
                    scorecardSection
                }
                .padding(20)
            }
            .navigationTitle("Round Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    newRoundButton
                }
            }
        }
        // The round is over — the only valid exit is New Round.
        // The onDismiss handler in CaddieHostTabContainer re-shows this sheet
        // if it is somehow dismissed by other means.
        .interactiveDismissDisabled(true)
    }

    // MARK: - Subviews

    private var completionBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("\(bundle.holes.count) holes completed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var totalsCard: some View {
        VStack(spacing: 6) {
            Text(summary.totalsHeader)
                .font(.title.weight(.bold))
            Text(summary.progressLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scorecard")
                .font(.headline)

            VStack(spacing: 0) {
                scorecardHeader
                Divider()
                ForEach(scorecardEntries) { entry in
                    scorecardRow(entry)
                    Divider()
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var scorecardHeader: some View {
        HStack {
            Text("Hole")
                .frame(width: 44, alignment: .leading)
            Text("Par")
                .frame(width: 36, alignment: .center)
            Spacer()
            Text("Score")
                .frame(width: 44, alignment: .center)
            Text("+/-")
                .frame(width: 44, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func scorecardRow(_ entry: HostRoundProgressModel.ScorecardEntry) -> some View {
        HStack {
            Text("\(entry.holeNumber)")
                .frame(width: 44, alignment: .leading)
                .fontWeight(.medium)
            Text("\(entry.par)")
                .frame(width: 36, alignment: .center)
                .foregroundStyle(.secondary)
            Spacer()
            Text(entry.strokesLabel)
                .frame(width: 44, alignment: .center)
                .fontWeight(.semibold)
            Text(entry.relativeToParLabel)
                .frame(width: 44, alignment: .trailing)
                .foregroundStyle(relativeToParColor(entry.relativeToParLabel))
                .font(.caption.weight(.semibold))
        }
        .font(.body)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var newRoundButton: some View {
        Button {
            HostRoundProgressStore.delete(courseId: bundle.courseId)
            onNewRound()
        } label: {
            Label("New Round", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func relativeToParColor(_ label: String) -> Color {
        if label.hasPrefix("-") { return .green }
        if label == "E"         { return .primary }
        return .red
    }
}

#Preview {
    if let bundle = try? HostCourseBundleStore.loadKungsbackaNya() {
        RoundSummaryView(
            bundle: bundle,
            roundState: RoundState(courseId: bundle.courseId, holeStates: []),
            onNewRound: {}
        )
    }
}
