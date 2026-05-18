import SwiftUI
import TrueCaddieDomain

struct InspectorStrategySection: View {
    let bundle: CourseBundle
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var selectedPlanMode: HostRoundPreviewModel.RoundPlanMode
    @Binding var selectedScenarioId: String
    let scenarioOptions: [HoleInspectorModel.ShotStateScenario]
    let usesLiveState: Bool
    let isHoleFinished: Bool
    @ObservedObject var windModel: LiveWindModel

    var body: some View {
        Section("Strategy & overlays") {
            Picker("Plan", selection: $selectedPlanMode) {
                ForEach(HostRoundPreviewModel.RoundPlanMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Strategy", selection: $roundOverrides.strategyPreference) {
                ForEach(HoleInspectorModel.strategyOptions, id: \.rawValue) { strategy in
                    Text(strategy.rawValue.capitalized).tag(strategy)
                }
            }
            .pickerStyle(.segmented)

            liveWindRow

            if isHoleFinished {
                LabeledContent("Scenario", value: "Hole finished")
            } else if usesLiveState {
                LabeledContent("Scenario", value: "Live hole state")
            } else if !scenarioOptions.isEmpty {
                Picker("Scenario", selection: $selectedScenarioId) {
                    ForEach(scenarioOptions) { scenario in
                        Text(scenario.name).tag(scenario.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var liveWindRow: some View {
        if let wind = windModel.windContext {
            LabeledContent("Live wind", value: "\(Int(wind.speedMps.rounded())) m/s \(wind.relativeDirection.rawValue)")
        } else if let error = windModel.lastFetchError {
            LabeledContent("Live wind", value: "unavailable — \(describe(error))")
                .foregroundStyle(.secondary)
        } else {
            LabeledContent("Live wind", value: "warming up")
                .foregroundStyle(.secondary)
        }
    }

    private func describe(_ error: WindProvidingError) -> String {
        switch error {
        case .notAuthorized: return "not authorized"
        case .network(let message): return message
        case .unknown(let message): return message
        }
    }
}
