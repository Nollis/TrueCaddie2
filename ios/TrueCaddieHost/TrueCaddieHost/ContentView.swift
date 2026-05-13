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
    @State private var selectedHoleNumber = 0
    @State private var selectedScenarioId = ""

    private var scenarioOptions: [HoleInspectorModel.ShotStateScenario] {
        HostRoundPreviewModel.scenarios(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: roundContext,
            holeNumber: selectedHoleNumber
        )
    }

    private var preview: HostRoundPreviewModel.HolePreview? {
        HostRoundPreviewModel.preview(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: roundContext,
            holeNumber: selectedHoleNumber,
            selectedScenarioId: selectedScenarioId
        )
    }

    var body: some View {
        List {
            if let preview {
                Section("Round") {
                    Picker("Hole", selection: $selectedHoleNumber) {
                        ForEach(bundle.holes) { hole in
                            Text("Hole \(hole.holeNumber)").tag(hole.holeNumber)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Scenario", selection: $selectedScenarioId) {
                        ForEach(scenarioOptions) { scenario in
                            Text(scenario.name).tag(scenario.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

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
        .onAppear {
            syncSelection()
        }
        .onChange(of: selectedHoleNumber) {
            syncScenarioSelection()
        }
    }

    private func metric(_ number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }

    private func syncSelection() {
        if selectedHoleNumber == 0 {
            selectedHoleNumber = bundle.holes.first?.holeNumber ?? 0
        }

        syncScenarioSelection()
    }

    private func syncScenarioSelection() {
        if scenarioOptions.contains(where: { $0.id == selectedScenarioId }) {
            return
        }

        selectedScenarioId = scenarioOptions.first?.id ?? ""
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
        guard let firstHoleNumber = bundle.holes.first?.holeNumber else {
            return nil
        }

        return preview(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: roundContext,
            holeNumber: firstHoleNumber,
            selectedScenarioId: ""
        )
    }

    static func scenarios(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        holeNumber: Int
    ) -> [HoleInspectorModel.ShotStateScenario] {
        guard let hole = hole(bundle: bundle, holeNumber: holeNumber) else {
            return []
        }

        return HoleInspectorModel.makeShotStateScenarios(
            for: hole,
            courseId: bundle.courseId,
            playerContext: playerContext,
            roundContext: roundContext
        )
    }

    static func preview(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        holeNumber: Int,
        selectedScenarioId: String
    ) -> HolePreview? {
        guard let hole = hole(bundle: bundle, holeNumber: holeNumber) else {
            return nil
        }

        let scenarios = scenarios(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: roundContext,
            holeNumber: holeNumber
        )
        let scenario = scenarios.first(where: { $0.id == selectedScenarioId }) ?? scenarios.first
        guard let scenario,
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

    private static func hole(bundle: CourseBundle, holeNumber: Int) -> CourseHole? {
        bundle.holes.first(where: { $0.holeNumber == holeNumber })
    }
}
