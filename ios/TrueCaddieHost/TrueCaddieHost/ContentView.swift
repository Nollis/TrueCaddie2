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
    let baseRoundContext: RoundContext
    @State private var selectedHoleNumber = 0
    @State private var selectedPlanMode: HostRoundPreviewModel.RoundPlanMode = .stockNextShot
    @State private var selectedScenarioId = ""
    @State private var roundOverrides: HoleInspectorModel.RoundOverrideState
    @State private var holeStates: [Int: HostRoundPreviewModel.HoleRoundState] = [:]

    init(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext
    ) {
        self.bundle = bundle
        self.playerContext = playerContext
        self.baseRoundContext = roundContext
        _roundOverrides = State(initialValue: HoleInspectorModel.makeRoundOverrideState(from: roundContext))
    }

    private var selectedHole: CourseHole? {
        bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })
    }

    private var teeOptions: [Tee] {
        selectedHole?.tees ?? []
    }

    private var effectiveRoundContext: RoundContext {
        HoleInspectorModel.makeEffectiveRoundContext(
            from: roundOverrides,
            baseRoundContext: baseRoundContext,
            hole: selectedHole
        )
    }

    private var usesLiveState: Bool {
        holeStates[selectedHoleNumber] != nil
    }

    private var selectedHoleState: HostRoundPreviewModel.HoleRoundState? {
        holeStates[selectedHoleNumber]
    }

    private var liveDistanceRange: ClosedRange<Double> {
        let maxTeeLength = selectedHole?.tees.map(\.teeLengthM).max() ?? 250
        return 0...max(150, maxTeeLength)
    }

    private var scenarioOptions: [HoleInspectorModel.ShotStateScenario] {
        guard !usesLiveState else {
            return []
        }

        HostRoundPreviewModel.scenarios(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: effectiveRoundContext,
            holeNumber: selectedHoleNumber,
            planMode: selectedPlanMode
        )
    }

    private var roundPreviews: [HostRoundPreviewModel.HolePreview] {
        HostRoundPreviewModel.roundPreviews(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: effectiveRoundContext,
            planMode: selectedPlanMode,
            holeStates: holeStates
        )
    }

    private var preview: HostRoundPreviewModel.HolePreview? {
        HostRoundPreviewModel.preview(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: effectiveRoundContext,
            holeNumber: selectedHoleNumber,
            planMode: selectedPlanMode,
            selectedScenarioId: selectedScenarioId,
            holeStates: holeStates
        )
    }

    var body: some View {
        List {
            if let preview {
                Section("Round Plan") {
                    ForEach(roundPreviews, id: \.holeNumber) { holePreview in
                        Button {
                            selectedHoleNumber = holePreview.holeNumber
                            selectedScenarioId = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Hole \(holePreview.holeNumber)")
                                        .fontWeight(.semibold)
                                    Text("Par \(holePreview.par)")
                                        .foregroundStyle(.secondary)
                                    Text(holePreview.scenarioName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if holePreview.holeNumber == selectedHoleNumber {
                                        Text("Current")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.blue)
                                    }
                                }

                                Text(holePreview.packet.headline)
                                    .foregroundStyle(.primary)

                                Text(holePreview.packet.primaryReason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Round") {
                    Picker("View", selection: $selectedPlanMode) {
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

                    Picker("Tee", selection: $roundOverrides.teeSetId) {
                        ForEach(teeOptions) { tee in
                            Text(tee.name).tag(tee.teeSetId)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Wind", isOn: $roundOverrides.windEnabled)

                    if roundOverrides.windEnabled {
                        Picker("Direction", selection: $roundOverrides.windDirection) {
                            ForEach(HoleInspectorModel.windDirectionOptions, id: \.rawValue) { direction in
                                Text(direction.rawValue.capitalized).tag(direction)
                            }
                        }
                        .pickerStyle(.segmented)

                        LabeledContent("Speed", value: "\(metric(roundOverrides.windSpeedMps)) m/s")

                        Slider(
                            value: $roundOverrides.windSpeedMps,
                            in: 0...12,
                            step: 1
                        )
                    }

                    LabeledContent("Hole", value: "\(preview.holeNumber)")
                    LabeledContent("Mode", value: selectedPlanMode.title)

                    if usesLiveState {
                        LabeledContent("Scenario", value: "Live hole state")
                    } else {
                        Picker("Scenario", selection: $selectedScenarioId) {
                            ForEach(scenarioOptions) { scenario in
                                Text(scenario.name).tag(scenario.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Hole State") {
                    Toggle(
                        "Use live hole state",
                        isOn: Binding(
                            get: { usesLiveState },
                            set: setLiveStateEnabled
                        )
                    )

                    if let selectedHoleState {
                        Stepper(
                            "Shot \(selectedHoleState.shotStateContext.shotNumber)",
                            value: Binding(
                                get: { selectedHoleState.shotStateContext.shotNumber },
                                set: updateSelectedHoleShotNumber
                            ),
                            in: 1...10
                        )

                        Picker(
                            "Lie",
                            selection: Binding(
                                get: { selectedHoleState.shotStateContext.lie },
                                set: updateSelectedHoleLie
                            )
                        ) {
                            ForEach(HostRoundPreviewModel.lieOptions, id: \.rawValue) { lie in
                                Text(lie.rawValue.capitalized).tag(lie)
                            }
                        }
                        .pickerStyle(.segmented)

                        LabeledContent(
                            "Remaining",
                            value: "\(metric(selectedHoleState.shotStateContext.remainingDistanceM)) m"
                        )

                        Slider(
                            value: Binding(
                                get: { selectedHoleState.shotStateContext.remainingDistanceM },
                                set: updateSelectedHoleRemainingDistance
                            ),
                            in: liveDistanceRange,
                            step: 1
                        )
                    }
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
                    LabeledContent("Tee", value: effectiveRoundContext.teeSetName)
                    LabeledContent(
                        "Plan",
                        value: (preview.packet.strategyPreference ?? effectiveRoundContext.strategyPreference.rawValue).capitalized
                    )
                    if let wind = effectiveRoundContext.wind {
                        LabeledContent("Wind", value: windLabel(wind))
                    } else {
                        LabeledContent("Wind", value: "Calm")
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
            syncTeeSelection()
            syncScenarioSelection()
        }
        .onChange(of: selectedPlanMode) {
            syncScenarioSelection(forceReset: true)
        }
        .onChange(of: effectiveRoundContext) {
            syncScenarioSelection()
        }
    }

    private func metric(_ number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }

    private func windLabel(_ wind: WindContext) -> String {
        "\(wind.relativeDirection.rawValue.capitalized) • \(metric(wind.speedMps)) m/s"
    }

    private func syncSelection() {
        if selectedHoleNumber == 0 {
            selectedHoleNumber = bundle.holes.first?.holeNumber ?? 0
        }

        syncTeeSelection()
        syncScenarioSelection()
    }

    private func syncTeeSelection() {
        guard !teeOptions.isEmpty else {
            return
        }

        if teeOptions.contains(where: { $0.teeSetId == roundOverrides.teeSetId }) {
            return
        }

        roundOverrides.teeSetId = teeOptions.first(where: { $0.isDefault == true })?.teeSetId
            ?? teeOptions.first?.teeSetId
            ?? roundOverrides.teeSetId
    }

    private func syncScenarioSelection(forceReset: Bool = false) {
        guard !usesLiveState else {
            selectedScenarioId = ""
            return
        }

        if !forceReset, scenarioOptions.contains(where: { $0.id == selectedScenarioId }) {
            return
        }

        selectedScenarioId = scenarioOptions.first?.id ?? ""
    }

    private func setLiveStateEnabled(_ isEnabled: Bool) {
        guard let hole = selectedHole else {
            return
        }

        if isEnabled {
            if holeStates[hole.holeNumber] == nil {
                holeStates[hole.holeNumber] = HostRoundPreviewModel.HoleRoundState(
                    shotStateContext: HostRoundPreviewModel.defaultLiveShotState(
                        for: hole,
                        courseId: bundle.courseId,
                        playerContext: playerContext,
                        roundContext: effectiveRoundContext,
                        planMode: selectedPlanMode
                    )
                )
            }
        } else {
            holeStates.removeValue(forKey: hole.holeNumber)
        }

        syncScenarioSelection(forceReset: true)
    }

    private func updateSelectedHoleShotNumber(_ shotNumber: Int) {
        guard let shotStateContext = selectedHoleState?.shotStateContext else {
            return
        }

        holeStates[selectedHoleNumber] = HostRoundPreviewModel.HoleRoundState(
            shotStateContext: ShotStateContext(
                shotNumber: shotNumber,
                remainingDistanceM: shotStateContext.remainingDistanceM,
                lie: shotStateContext.lie
            )
        )
    }

    private func updateSelectedHoleLie(_ lie: ShotLie) {
        guard let shotStateContext = selectedHoleState?.shotStateContext else {
            return
        }

        holeStates[selectedHoleNumber] = HostRoundPreviewModel.HoleRoundState(
            shotStateContext: ShotStateContext(
                shotNumber: shotStateContext.shotNumber,
                remainingDistanceM: shotStateContext.remainingDistanceM,
                lie: lie
            )
        )
    }

    private func updateSelectedHoleRemainingDistance(_ remainingDistanceM: Double) {
        guard let shotStateContext = selectedHoleState?.shotStateContext else {
            return
        }

        holeStates[selectedHoleNumber] = HostRoundPreviewModel.HoleRoundState(
            shotStateContext: ShotStateContext(
                shotNumber: shotStateContext.shotNumber,
                remainingDistanceM: remainingDistanceM,
                lie: shotStateContext.lie
            )
        )
    }
}

enum HostRoundPreviewModel {
    enum RoundPlanMode: String, CaseIterable, Identifiable {
        case teePlan
        case stockNextShot
        case layupView

        var id: String { rawValue }

        var title: String {
            switch self {
            case .teePlan:
                return "Tee"
            case .stockNextShot:
                return "Stock"
            case .layupView:
                return "Layup"
            }
        }
    }

    struct HolePreview: Equatable {
        let holeNumber: Int
        let par: Int
        let scenarioName: String
        let packet: NextShotRecommendationPacket
        let voicePreview: String
    }

    struct HoleRoundState: Equatable {
        let shotStateContext: ShotStateContext
    }

    static let lieOptions: [ShotLie] = [
        .tee,
        .fairway,
        .rough,
        .bunker,
        .recovery
    ]

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
            planMode: .stockNextShot,
            selectedScenarioId: ""
        )
    }

    static func scenarios(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        holeNumber: Int,
        planMode: RoundPlanMode
    ) -> [HoleInspectorModel.ShotStateScenario] {
        guard let hole = hole(bundle: bundle, holeNumber: holeNumber) else {
            return []
        }

        return scenarios(
            for: hole,
            courseId: bundle.courseId,
            playerContext: playerContext,
            roundContext: roundContext,
            planMode: planMode
        )
    }

    static func preview(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        holeNumber: Int,
        planMode: RoundPlanMode,
        selectedScenarioId: String,
        holeStates: [Int: HoleRoundState] = [:]
    ) -> HolePreview? {
        guard let hole = hole(bundle: bundle, holeNumber: holeNumber) else {
            return nil
        }

        if let liveState = holeStates[holeNumber],
           let packet = NextShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: hole,
            playerContext: playerContext,
            roundContext: roundContext,
            shotStateContext: liveState.shotStateContext
           ) {
            return HolePreview(
                holeNumber: hole.holeNumber,
                par: hole.par,
                scenarioName: "Live state",
                packet: packet,
                voicePreview: HoleInspectorModel.voicePreviewText(for: packet)
            )
        }

        let scenarios = scenarios(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: roundContext,
            holeNumber: holeNumber,
            planMode: planMode
        )
        let defaultScenarioId = defaultScenarioId(for: hole, planMode: planMode, scenarios: scenarios)
        let scenario = scenarios.first(where: { $0.id == selectedScenarioId })
            ?? scenarios.first(where: { $0.id == defaultScenarioId })
            ?? scenarios.first
        guard let scenario else {
            return nil
        }

        let packet: NextShotRecommendationPacket?
        if planMode == .teePlan {
            packet = NextShotRecommendationEngine.build(
                courseId: bundle.courseId,
                for: hole,
                playerContext: playerContext,
                roundContext: roundContext,
                shotStateContext: scenario.shotStateContext
            )
        } else {
            packet = HoleInspectorModel.nextShotRecommendation(
                for: hole,
                courseId: bundle.courseId,
                playerContext: playerContext,
                roundContext: roundContext,
                selectedScenarioId: scenario.id
            )
        }

        guard let packet else {
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

    static func roundPreviews(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        planMode: RoundPlanMode,
        holeStates: [Int: HoleRoundState] = [:]
    ) -> [HolePreview] {
        bundle.holes.compactMap { hole in
            preview(
                bundle: bundle,
                playerContext: playerContext,
                roundContext: roundContext,
                holeNumber: hole.holeNumber,
                planMode: planMode,
                selectedScenarioId: "",
                holeStates: holeStates
            )
        }
    }

    static func defaultLiveShotState(
        for hole: CourseHole,
        courseId: String,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        planMode: RoundPlanMode
    ) -> ShotStateContext {
        let scenarios = scenarios(
            for: hole,
            courseId: courseId,
            playerContext: playerContext,
            roundContext: roundContext,
            planMode: planMode
        )
        let defaultScenarioId = defaultScenarioId(for: hole, planMode: planMode, scenarios: scenarios)

        return scenarios.first(where: { $0.id == defaultScenarioId })?.shotStateContext
            ?? scenarios.first?.shotStateContext
            ?? ShotStateContext(
                shotNumber: 1,
                remainingDistanceM: selectedTee(in: hole, roundContext: roundContext)?.teeLengthM ?? 0,
                lie: .tee
            )
    }

    private static func scenarios(
        for hole: CourseHole,
        courseId: String,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        planMode: RoundPlanMode
    ) -> [HoleInspectorModel.ShotStateScenario] {
        if planMode == .teePlan, let teeScenario = teeScenario(for: hole, roundContext: roundContext) {
            return [teeScenario]
        }

        return HoleInspectorModel.makeShotStateScenarios(
            for: hole,
            courseId: courseId,
            playerContext: playerContext,
            roundContext: roundContext
        )
    }

    private static func hole(bundle: CourseBundle, holeNumber: Int) -> CourseHole? {
        bundle.holes.first(where: { $0.holeNumber == holeNumber })
    }

    private static func teeScenario(
        for hole: CourseHole,
        roundContext: RoundContext
    ) -> HoleInspectorModel.ShotStateScenario? {
        guard let tee = selectedTee(in: hole, roundContext: roundContext) else {
            return nil
        }

        return HoleInspectorModel.ShotStateScenario(
            id: "tee",
            name: "Tee shot",
            detail: "Opening shot plan from the tee",
            shotStateContext: ShotStateContext(
                shotNumber: 1,
                remainingDistanceM: tee.teeLengthM,
                lie: .tee
            )
        )
    }

    private static func defaultScenarioId(
        for hole: CourseHole,
        planMode: RoundPlanMode,
        scenarios: [HoleInspectorModel.ShotStateScenario]
    ) -> String? {
        switch planMode {
        case .teePlan:
            return "tee"
        case .stockNextShot:
            return scenarios.first?.id
        case .layupView:
            if hole.par == 5, scenarios.contains(where: { $0.id == "layup" }) {
                return "layup"
            }

            return scenarios.first?.id
        }
    }

    private static func selectedTee(in hole: CourseHole, roundContext: RoundContext) -> Tee? {
        if let matchedTee = hole.tees.first(where: { $0.teeSetId == roundContext.teeSetId }) {
            return matchedTee
        }

        if let defaultTee = hole.tees.first(where: { $0.isDefault == true }) {
            return defaultTee
        }

        return hole.tees.first
    }
}
