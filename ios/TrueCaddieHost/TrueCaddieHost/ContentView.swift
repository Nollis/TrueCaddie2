//
//  ContentView.swift
//  TrueCaddieHost
//
//  Created by user273008 on 5/12/26.
//

import SwiftUI
import TrueCaddieDomain

struct ContentView: View {
    enum CaddieHostTab: Hashable { case caddie, inspector }

    private let bundleResult = Result {
        try HostCourseBundleStore.loadKungsbackaNya()
    }
    private let playerContext = PlayerContext.pilotSample
    private let roundContext = RoundContext.pilotSample

    @State private var selectedTab: CaddieHostTab = .caddie

    var body: some View {
        switch bundleResult {
        case .success(let bundle):
            CaddieHostTabContainer(
                bundle: bundle,
                playerContext: playerContext,
                roundContext: roundContext,
                selectedTab: $selectedTab
            )
        case .failure(let error):
            ContentUnavailableView(
                "Course Bundle Missing",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }
}

private struct CaddieHostTabContainer: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContextBaseline: RoundContext
    @Binding var selectedTab: ContentView.CaddieHostTab

    @State private var selectedHoleNumber: Int
    @State private var roundOverrides: HoleInspectorModel.RoundOverrideState
    @State private var roundState: RoundState
    @State private var editingScoreHoleNumber: Int?
    @State private var editingScoreStrokes: Int = 0
    @State private var selectedPlanMode: HostRoundPreviewModel.RoundPlanMode = .stockNextShot
    @State private var selectedScenarioId: String = ""
    @State private var shotResultDraft: HostRoundProgressModel.ShotResultDraft?
    @State private var pendingHoleOutStrokes: Int?
    @StateObject private var voiceController: HostVoiceSessionController
    @StateObject private var locationModel: LiveCourseLocationModel
    @StateObject private var windModel: LiveWindModel

    init(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        selectedTab: Binding<ContentView.CaddieHostTab>
    ) {
        let savedProgress = HostRoundProgressStore.load(courseId: bundle.courseId)
        let initialRoundState = savedProgress?.roundState ?? RoundState(courseId: bundle.courseId, holeStates: [])
        let initialHoleNumber = HostRoundProgressModel.currentHoleNumber(
            bundle: bundle,
            roundState: initialRoundState,
            preferredHoleNumber: savedProgress?.selectedHoleNumber
        ) ?? bundle.holes.first?.holeNumber ?? 0
        self.bundle = bundle
        self.playerContext = playerContext
        self.baseRoundContextBaseline = roundContext
        _selectedTab = selectedTab
        _selectedHoleNumber = State(initialValue: initialHoleNumber)
        _roundOverrides = State(initialValue: HoleInspectorModel.makeRoundOverrideState(from: roundContext))
        _roundState = State(initialValue: initialRoundState)
        _voiceController = StateObject(wrappedValue: HostVoiceSessionController.makeWithPilotCredentials())
        _locationModel = StateObject(wrappedValue: LiveCourseLocationModel(
            provider: CoreLocationProvider(),
            bundle: bundle,
            currentHoleNumber: initialHoleNumber == 0 ? nil : initialHoleNumber
        ))
        _windModel = StateObject(wrappedValue: LiveWindModel(
            provider: WeatherKitWindProvider(),
            bundle: bundle
        ))
    }

    /// Effective base context: the original baseline with its `wind` replaced
    /// by the live observation whenever one is available. The Inspector's
    /// manual override (R7 cleanup in Unit 7 will remove it; until then it
    /// still wins via `makeEffectiveRoundContext`) layers on top.
    private var baseRoundContext: RoundContext {
        RoundContext(
            teeSetId: baseRoundContextBaseline.teeSetId,
            teeSetName: baseRoundContextBaseline.teeSetName,
            strategyPreference: baseRoundContextBaseline.strategyPreference,
            wind: windModel.windContext ?? baseRoundContextBaseline.wind
        )
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

    private var selectedHoleState: HoleRoundState? {
        roundState.holeState(for: selectedHoleNumber)
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

    private var scenarioOptions: [HoleInspectorModel.ShotStateScenario] {
        guard !usesLiveState else { return [] }
        return HostRoundPreviewModel.scenarios(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: effectiveRoundContext,
            holeNumber: selectedHoleNumber,
            planMode: selectedPlanMode
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
            roundState: roundState
        )
    }

    private var currentTurnContext: HostCaddieSession.TurnContext {
        HostCaddieSession.TurnContext(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: effectiveRoundContext,
            selectedHoleNumber: selectedHoleNumber,
            planMode: selectedPlanMode,
            roundState: roundState
        )
    }

    private var isShotResultSheetPresented: Binding<Bool> {
        Binding(
            get: { shotResultDraft != nil },
            set: { if !$0 { shotResultDraft = nil } }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CaddieTabView(
                bundle: bundle,
                playerContext: playerContext,
                baseRoundContext: baseRoundContext,
                selectedHoleNumber: $selectedHoleNumber,
                roundOverrides: $roundOverrides,
                roundState: $roundState,
                preview: preview,
                voiceController: voiceController,
                locationModel: locationModel,
                windModel: windModel,
                onRequestInspector: { selectedTab = .inspector }
            )
            .tabItem {
                Label("Caddie", systemImage: "figure.golf")
            }
            .tag(ContentView.CaddieHostTab.caddie)

            InspectorTabView(
                bundle: bundle,
                playerContext: playerContext,
                baseRoundContext: baseRoundContext,
                selectedHoleNumber: $selectedHoleNumber,
                roundOverrides: $roundOverrides,
                roundState: $roundState,
                editingScoreHoleNumber: $editingScoreHoleNumber,
                editingScoreStrokes: $editingScoreStrokes,
                selectedPlanMode: $selectedPlanMode,
                selectedScenarioId: $selectedScenarioId,
                pendingHoleOutStrokes: $pendingHoleOutStrokes,
                scenarioOptions: scenarioOptions,
                voiceController: voiceController,
                locationModel: locationModel,
                windModel: windModel,
                onResetRound: resetRound,
                onStartHole: startSelectedHole,
                onAdvanceHole: advanceSelectedHole,
                onConfirmHoleOut: confirmHoleOut,
                onCancelHoleOut: cancelHoleOut,
                onResetHole: resetSelectedHole,
                onBeginShotResultCapture: beginShotResultCapture
            )
            .tabItem {
                Label("Inspector", systemImage: "list.bullet.rectangle")
            }
            .tag(ContentView.CaddieHostTab.inspector)
        }
        .onAppear {
            syncSelection()
            syncVoiceSessionSnapshot()
            voiceController.locationModel = locationModel
            locationModel.currentHoleNumber = selectedHoleNumber == 0 ? nil : selectedHoleNumber
            locationModel.start()
            windModel.setCurrentHole(selectedHole, teeSetId: roundOverrides.teeSetId)
            if let fix = locationModel.lastFix {
                windModel.setLocation(fix.coordinate)
            }
            windModel.startRefreshLoop()
        }
        .onChange(of: selectedHoleNumber) {
            shotResultDraft = nil
            pendingHoleOutStrokes = nil
            editingScoreHoleNumber = nil
            syncTeeSelection()
            syncScenarioSelection()
            persistRoundProgress()
            syncVoiceSessionSnapshot()
            locationModel.currentHoleNumber = selectedHoleNumber == 0 ? nil : selectedHoleNumber
            windModel.setCurrentHole(selectedHole, teeSetId: roundOverrides.teeSetId)
        }
        .onChange(of: roundOverrides.teeSetId) {
            windModel.setCurrentHole(selectedHole, teeSetId: roundOverrides.teeSetId)
        }
        .onChange(of: locationModel.lastFix?.coordinate) { _, coord in
            if let coord {
                windModel.setLocation(coord)
            }
        }
        .onChange(of: selectedPlanMode) {
            syncScenarioSelection(forceReset: true)
            syncVoiceSessionSnapshot()
        }
        .onChange(of: effectiveRoundContext) {
            syncScenarioSelection()
            syncVoiceSessionSnapshot()
        }
        .onChange(of: roundState) {
            persistRoundProgress()
            syncVoiceSessionSnapshot()
        }
        .onChange(of: voiceController.state.lastResponse) { _, response in
            if let response { applyVoiceResponse(response) }
        }
        .onChange(of: locationModel.detectedHoleNumber) { _, detected in
            // Auto-select the detected hole. LiveCourseLocationModel already
            // enforces hysteresis (5 consecutive fixes > 80 m outside the
            // current hole) before emitting a different value, so simply
            // following it here is safe.
            guard let detected, detected != selectedHoleNumber else { return }
            selectedHoleNumber = detected
        }
        .sheet(isPresented: isShotResultSheetPresented) {
            shotResultSheet
        }
    }

    @ViewBuilder
    private var shotResultSheet: some View {
        if let shotResultDraft {
            NavigationStack {
                Form {
                    Section("Shot Result") {
                        LabeledContent("Shot", value: "\(shotResultDraft.currentShotNumber)")
                        Toggle("Holed out", isOn: shotResultHoledOutBinding)
                        if !shotResultDraft.holedOut {
                            Picker("Lie", selection: shotResultLieBinding) {
                                ForEach(HostRoundPreviewModel.lieOptions, id: \.rawValue) { lie in
                                    Text(lie.rawValue.capitalized).tag(lie)
                                }
                            }
                            .pickerStyle(.segmented)
                            LabeledContent("Remaining", value: "\(metric(shotResultDraft.remainingDistanceM)) m")
                            Slider(value: shotResultRemainingDistanceBinding, in: liveDistanceRange, step: 1)
                        }
                    }
                }
                .navigationTitle("Record Result")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { self.shotResultDraft = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveShotResultDraft() }
                    }
                }
            }
        }
    }

    private var shotResultHoledOutBinding: Binding<Bool> {
        Binding(get: { shotResultDraft?.holedOut ?? false }, set: { updateShotResultDraft(holedOut: $0) })
    }

    private var shotResultLieBinding: Binding<ShotLie> {
        Binding(get: { shotResultDraft?.resultingLie ?? .fairway }, set: { updateShotResultDraft(resultingLie: $0) })
    }

    private var shotResultRemainingDistanceBinding: Binding<Double> {
        Binding(get: { shotResultDraft?.remainingDistanceM ?? 0 }, set: { updateShotResultDraft(remainingDistanceM: $0) })
    }

    private func syncSelection() {
        if selectedHoleNumber == 0 {
            selectedHoleNumber = bundle.holes.first?.holeNumber ?? 0
        }
        syncTeeSelection()
        syncScenarioSelection()
    }

    private func syncTeeSelection() {
        guard !teeOptions.isEmpty else { return }
        if teeOptions.contains(where: { $0.teeSetId == roundOverrides.teeSetId }) { return }
        roundOverrides.teeSetId = teeOptions.first(where: { $0.isDefault == true })?.teeSetId
            ?? teeOptions.first?.teeSetId
            ?? roundOverrides.teeSetId
    }

    private func syncScenarioSelection(forceReset: Bool = false) {
        guard !usesLiveState else { selectedScenarioId = ""; return }
        if !forceReset, scenarioOptions.contains(where: { $0.id == selectedScenarioId }) { return }
        selectedScenarioId = scenarioOptions.first?.id ?? ""
    }

    private func syncVoiceSessionSnapshot() {
        voiceController.updateContext(currentTurnContext)
    }

    private func persistRoundProgress() {
        HostRoundProgressStore.save(
            .init(selectedHoleNumber: selectedHoleNumber, roundState: roundState),
            courseId: bundle.courseId
        )
    }

    private func resetRound() {
        shotResultDraft = nil
        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = nil
        roundState = RoundState(courseId: bundle.courseId, holeStates: [])
        selectedHoleNumber = HostRoundProgressModel.currentHoleNumber(
            bundle: bundle,
            roundState: roundState,
            preferredHoleNumber: nil
        ) ?? (bundle.holes.first?.holeNumber ?? 0)
        syncScenarioSelection(forceReset: true)
    }

    private func startSelectedHole() {
        guard let hole = selectedHole else { return }
        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = nil
        roundState = roundState.startHole(hole, roundContext: effectiveRoundContext)
        selectedHoleNumber = hole.holeNumber
        syncScenarioSelection(forceReset: true)
    }

    private func advanceSelectedHole() {
        roundState = roundState.advanceShot(for: selectedHoleNumber)
    }

    private func beginHoleOutFlow() {
        shotResultDraft = nil
        editingScoreHoleNumber = nil
        pendingHoleOutStrokes = selectedHoleState?.shotStateContext?.shotNumber
            ?? selectedHoleState?.strokesTaken ?? 1
    }

    private func confirmHoleOut() {
        guard let strokes = pendingHoleOutStrokes else { return }
        finishSelectedHole(strokesTaken: strokes)
    }

    private func cancelHoleOut() {
        pendingHoleOutStrokes = nil
    }

    private func finishSelectedHole(strokesTaken: Int) {
        let finishedRoundState = roundState.finishHole(selectedHoleNumber, strokesTaken: strokesTaken)
        pendingHoleOutStrokes = nil
        roundState = finishedRoundState
        selectedHoleNumber = HostRoundProgressModel.nextUnfinishedHoleNumber(
            after: selectedHoleNumber,
            bundle: bundle,
            roundState: finishedRoundState
        ) ?? selectedHoleNumber
        syncScenarioSelection(forceReset: true)
    }

    private func beginShotResultCapture(from shotStateContext: ShotStateContext) {
        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = nil
        shotResultDraft = HostRoundProgressModel.makeShotResultDraft(from: shotStateContext)
    }

    private func updateShotResultDraft(
        resultingLie: ShotLie? = nil,
        remainingDistanceM: Double? = nil,
        holedOut: Bool? = nil
    ) {
        guard let draft = shotResultDraft else { return }
        shotResultDraft = HostRoundProgressModel.ShotResultDraft(
            currentShotNumber: draft.currentShotNumber,
            resultingLie: resultingLie ?? draft.resultingLie,
            remainingDistanceM: remainingDistanceM ?? draft.remainingDistanceM,
            holedOut: holedOut ?? draft.holedOut
        )
    }

    private func saveShotResultDraft() {
        guard let shotResultDraft,
              let result = HostRoundProgressModel.applyShotResultDraft(shotResultDraft) else { return }
        switch result {
        case .advance(let ctx):
            roundState = roundState.updateShotState(ctx, for: selectedHoleNumber)
        case .holeOut(let strokesTaken):
            finishSelectedHole(strokesTaken: strokesTaken)
        }
        self.shotResultDraft = nil
    }

    private func resetSelectedHole() {
        shotResultDraft = nil
        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = nil
        roundState = roundState.resetHole(selectedHoleNumber)
        syncScenarioSelection(forceReset: true)
    }

    private func applyVoiceResponse(_ response: VoiceTurnResponse) {
        if let strategyPreference = response.strategyPreference {
            roundOverrides.strategyPreference = strategyPreference
        }
        roundState = response.sessionSnapshot.roundState
        selectedHoleNumber = response.sessionSnapshot.selectedHoleNumber
        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = nil
        shotResultDraft = nil
        syncScenarioSelection(forceReset: true)
    }

    private func metric(_ number: Double) -> String {
        if number.rounded() == number { return String(Int(number)) }
        return String(format: "%.1f", number)
    }
}

#Preview {
    ContentView()
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
            selectedScenarioId: "",
            roundState: RoundState(courseId: bundle.courseId, holeStates: [])
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
        roundState: RoundState = RoundState(courseId: "", holeStates: [])
    ) -> HolePreview? {
        guard let hole = hole(bundle: bundle, holeNumber: holeNumber) else {
            return nil
        }

        if let liveState = roundState.holeState(for: holeNumber),
           liveState.status == .inProgress,
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
        roundState: RoundState = RoundState(courseId: "", holeStates: [])
    ) -> [HolePreview] {
        bundle.holes.compactMap { hole in
            preview(
                bundle: bundle,
                playerContext: playerContext,
                roundContext: roundContext,
                holeNumber: hole.holeNumber,
                planMode: planMode,
                selectedScenarioId: "",
                roundState: roundState
            )
        }
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

struct HostSavedRoundProgress: Codable, Equatable {
    let selectedHoleNumber: Int
    let roundState: RoundState
}

enum HostRoundProgressModel {
    struct RoundSummary: Equatable {
        let currentHoleNumber: Int
        let currentHoleHeader: String
        let totalsHeader: String
        let progressLabel: String
        let isRoundComplete: Bool
    }

    struct ScorecardEntry: Equatable, Identifiable {
        let holeNumber: Int
        let par: Int
        let statusLabel: String
        let strokesLabel: String
        let relativeToParLabel: String
        let rawStrokesTaken: Int?
        let isCurrentHole: Bool
        let isFinished: Bool

        var id: Int { holeNumber }
    }

    struct ShotResultDraft: Equatable {
        let currentShotNumber: Int
        let resultingLie: ShotLie
        let remainingDistanceM: Double
        let holedOut: Bool
    }

    enum ShotResultApplication: Equatable {
        case advance(ShotStateContext)
        case holeOut(strokesTaken: Int)
    }

    static func currentHoleNumber(
        bundle: CourseBundle,
        roundState: RoundState,
        preferredHoleNumber: Int?
    ) -> Int? {
        if let preferredHoleNumber,
           bundle.holes.contains(where: { $0.holeNumber == preferredHoleNumber }),
           roundState.holeState(for: preferredHoleNumber)?.status != .finished {
            return preferredHoleNumber
        }

        if let inProgressHole = roundState.holeStates.first(where: { $0.status == .inProgress })?.holeNumber {
            return inProgressHole
        }

        if let firstUnfinishedHole = bundle.holes.first(where: {
            roundState.holeState(for: $0.holeNumber)?.status != .finished
        })?.holeNumber {
            return firstUnfinishedHole
        }

        return bundle.holes.first?.holeNumber
    }

    static func summary(
        bundle: CourseBundle,
        roundState: RoundState,
        currentHoleNumber: Int
    ) -> RoundSummary {
        let finishedHoles = roundState.holeStates.filter { $0.status == .finished }
        let inProgressHoles = roundState.holeStates.filter { $0.status == .inProgress }
        let finishedHoleCount = finishedHoles.count
        let totalHoleCount = bundle.holes.count
        let isRoundComplete = totalHoleCount > 0 && finishedHoleCount == totalHoleCount
        let relativeToPar = finishedHoles.reduce(0) { partialResult, holeState in
            let par = bundle.holes.first(where: { $0.holeNumber == holeState.holeNumber })?.par ?? 0
            let strokesTaken = holeState.strokesTaken ?? 0
            return partialResult + (strokesTaken - par)
        }

        return RoundSummary(
            currentHoleNumber: currentHoleNumber,
            currentHoleHeader: currentHoleHeader(
                roundState: roundState,
                holeNumber: currentHoleNumber,
                isRoundComplete: isRoundComplete
            ),
            totalsHeader: totalsHeader(
                relativeToPar: relativeToPar,
                finishedHoleCount: finishedHoleCount,
                inProgressHoleCount: inProgressHoles.count,
                isRoundComplete: isRoundComplete
            ),
            progressLabel: "\(finishedHoleCount) of \(totalHoleCount) complete",
            isRoundComplete: isRoundComplete
        )
    }

    static func makeShotResultDraft(from shotStateContext: ShotStateContext) -> ShotResultDraft {
        ShotResultDraft(
            currentShotNumber: shotStateContext.shotNumber,
            resultingLie: shotStateContext.lie == .tee ? .fairway : shotStateContext.lie,
            remainingDistanceM: shotStateContext.remainingDistanceM,
            holedOut: false
        )
    }

    static func applyShotResultDraft(_ draft: ShotResultDraft) -> ShotResultApplication? {
        if draft.holedOut {
            return .holeOut(strokesTaken: draft.currentShotNumber)
        }

        guard draft.remainingDistanceM >= 0 else {
            return nil
        }

        return .advance(
            ShotStateContext(
                shotNumber: draft.currentShotNumber + 1,
                remainingDistanceM: draft.remainingDistanceM,
                lie: draft.resultingLie
            )
        )
    }

    static func scorecardEntries(
        bundle: CourseBundle,
        roundState: RoundState,
        currentHoleNumber: Int
    ) -> [ScorecardEntry] {
        bundle.holes.compactMap { hole in
            guard let holeState = roundState.holeState(for: hole.holeNumber) else {
                return nil
            }

            let strokesTaken = holeState.strokesTaken ?? max((holeState.shotStateContext?.shotNumber ?? 1) - 1, 0)
            let relativeToPar = strokesTaken - hole.par

            return ScorecardEntry(
                holeNumber: hole.holeNumber,
                par: hole.par,
                statusLabel: statusLabel(for: holeState),
                strokesLabel: strokesTaken == 0 ? "-" : "\(strokesTaken)",
                relativeToParLabel: relativeLabel(for: relativeToPar),
                rawStrokesTaken: holeState.strokesTaken,
                isCurrentHole: hole.holeNumber == currentHoleNumber,
                isFinished: holeState.status == .finished
            )
        }
    }

    static func nextUnfinishedHoleNumber(
        after holeNumber: Int,
        bundle: CourseBundle,
        roundState: RoundState
    ) -> Int? {
        let orderedHoleNumbers = bundle.holes.map(\.holeNumber)
        guard let currentIndex = orderedHoleNumbers.firstIndex(of: holeNumber) else {
            return currentHoleNumber(bundle: bundle, roundState: roundState, preferredHoleNumber: nil)
        }

        let wrappedHoleNumbers = Array(orderedHoleNumbers.suffix(from: currentIndex + 1))
            + Array(orderedHoleNumbers.prefix(currentIndex + 1))
        return wrappedHoleNumbers.first(where: {
            roundState.holeState(for: $0)?.status != .finished
        })
    }

    private static func currentHoleHeader(
        roundState: RoundState,
        holeNumber: Int,
        isRoundComplete: Bool
    ) -> String {
        if isRoundComplete {
            return "Round complete"
        }

        switch roundState.holeState(for: holeNumber)?.status {
        case .inProgress:
            return "Current hole \(holeNumber)"
        case .finished:
            return "Hole \(holeNumber) complete"
        case nil:
            return "Current hole \(holeNumber)"
        }
    }

    private static func totalsHeader(
        relativeToPar: Int,
        finishedHoleCount: Int,
        inProgressHoleCount: Int,
        isRoundComplete: Bool
    ) -> String {
        guard finishedHoleCount > 0 else {
            return inProgressHoleCount > 0 ? "Round started" : "Round ready"
        }

        let relativeLabel: String
        switch relativeToPar {
        case ..<0:
            relativeLabel = "\(relativeToPar)"
        case 0:
            relativeLabel = "E"
        default:
            relativeLabel = "+\(relativeToPar)"
        }

        if isRoundComplete {
            return "Final: \(relativeLabel)"
        }

        return "Through \(finishedHoleCount): \(relativeLabel)"
    }

    private static func statusLabel(for holeState: HoleRoundState) -> String {
        switch holeState.status {
        case .inProgress:
            return "In progress"
        case .finished:
            return "Finished"
        }
    }

    private static func relativeLabel(for relativeToPar: Int) -> String {
        switch relativeToPar {
        case ..<0:
            return "\(relativeToPar)"
        case 0:
            return "E"
        default:
            return "+\(relativeToPar)"
        }
    }
}

private enum HostRoundProgressStore {
    static func load(courseId: String) -> HostSavedRoundProgress? {
        guard let data = UserDefaults.standard.data(forKey: key(for: courseId)) else {
            return nil
        }

        return try? JSONDecoder().decode(HostSavedRoundProgress.self, from: data)
    }

    static func save(_ progress: HostSavedRoundProgress, courseId: String) {
        guard let data = try? JSONEncoder().encode(progress) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(for: courseId))
    }

    private static func key(for courseId: String) -> String {
        "truecaddie.round-progress.\(courseId)"
    }
}
