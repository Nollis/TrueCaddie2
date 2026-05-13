//
//  ContentView.swift
//  TrueCaddieHost
//
//  Created by user273008 on 5/12/26.
//

import SwiftUI
import TrueCaddieDomain

struct ContentView: View {
    private let bundleResult = Result {
        try HostCourseBundleStore.loadKungsbackaNya()
    }
    private let playerContext = PlayerContext.pilotSample
    private let roundContext = RoundContext.pilotSample

    var body: some View {
        switch bundleResult {
        case .success(let bundle):
            TabView {
                NavigationStack {
                    RoundPreviewView(
                        bundle: bundle,
                        playerContext: playerContext,
                        roundContext: roundContext
                    )
                }
                .tabItem {
                    Label("Caddie", systemImage: "figure.golf")
                }

                BundleInspectorView(
                    bundle: bundle,
                    playerContext: playerContext,
                    roundContext: roundContext
                )
                .tabItem {
                    Label("Inspector", systemImage: "list.bullet.rectangle")
                }
            }
        case .failure(let error):
            ContentUnavailableView(
                "Course Bundle Missing",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }
}

#Preview {
    ContentView()
}

private struct RoundPreviewView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let roundContext: RoundContext

    private var preview: HostRoundPreviewModel.HolePreview? {
        HostRoundPreviewModel.firstHolePreview(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: roundContext
        )
    }

    var body: some View {
        List {
            if let preview {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today’s caddie line")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Hole \(preview.holeNumber) • Par \(preview.par)")
                            .font(.headline)

                        Text(preview.packet.headline)
                            .font(.title3.weight(.semibold))

                        Text(preview.packet.primaryReason)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Current Shot") {
                    LabeledContent("Scenario", value: preview.scenarioName)
                    LabeledContent("Lie", value: preview.packet.lie.rawValue.capitalized)
                    LabeledContent("Remaining", value: "\(metric(preview.packet.remainingDistanceM)) m")
                    if let strategyPreference = preview.packet.strategyPreference {
                        LabeledContent("Plan", value: strategyPreference.capitalized)
                    }
                }

                Section("Recommendation") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(preview.voicePreview)
                            .font(.body)

                        HStack(spacing: 12) {
                            Text("Club \(preview.packet.recommendedClub ?? "n/a")")
                            Text("Risk \(preview.packet.riskLevel.capitalized)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "Preview Unavailable",
                        systemImage: "flag.slash",
                        description: Text("Could not build a next-shot preview from the current sample bundle.")
                    )
                }
            }
        }
        .navigationTitle("TrueCaddie")
    }

    private func metric(_ number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}

enum HostRoundPreviewModel {
    struct HolePreview: Equatable {
        let holeNumber: Int
        let par: Int
        let scenarioName: String
        let packet: NextShotRecommendationPacket
        let voicePreview: String
    }

    static func firstHolePreview(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext
    ) -> HolePreview? {
        guard let hole = bundle.holes.first else {
            return nil
        }

        let scenarios = HoleInspectorModel.makeShotStateScenarios(
            for: hole,
            courseId: bundle.courseId,
            playerContext: playerContext,
            roundContext: roundContext
        )
        guard let scenario = scenarios.first,
              let packet = HoleInspectorModel.nextShotRecommendation(
                for: hole,
                courseId: bundle.courseId,
                playerContext: playerContext,
                roundContext: roundContext,
                selectedScenarioId: scenario.id
              ) else {
            return nil
        }

        return HolePreview(
            holeNumber: hole.holeNumber,
            par: hole.par,
            scenarioName: scenario.name,
            packet: packet,
            voicePreview: HoleInspectorModel.voicePreviewText(for: packet)
        )
    }
}
