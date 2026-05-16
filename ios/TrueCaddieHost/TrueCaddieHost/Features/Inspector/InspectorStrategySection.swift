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

            Toggle("Wind", isOn: $roundOverrides.windEnabled)

            if roundOverrides.windEnabled {
                Picker("Direction", selection: $roundOverrides.windDirection) {
                    ForEach(HoleInspectorModel.windDirectionOptions, id: \.rawValue) { direction in
                        Text(direction.rawValue.capitalized).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Speed", value: "\(Int(roundOverrides.windSpeedMps)) m/s")

                Slider(value: $roundOverrides.windSpeedMps, in: 0...12, step: 1)
            }

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
}
