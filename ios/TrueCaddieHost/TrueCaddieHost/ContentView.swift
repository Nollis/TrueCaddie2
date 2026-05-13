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
    @State private var conversationInput = ""
    @State private var shotResultDraft: HostRoundProgressModel.ShotResultDraft?
    @State private var pendingHoleOutStrokes: Int?
    @State private var editingScoreHoleNumber: Int?
    @State private var editingScoreStrokes = 0
    @State private var roundOverrides: HoleInspectorModel.RoundOverrideState
    @State private var roundState: RoundState
    @StateObject private var voiceSessionManager: RealtimeVoiceSessionManager

    init(
        bundle: CourseBundle,
        playerContext: PlayerContext,
        roundContext: RoundContext
    ) {
        let savedProgress = HostRoundProgressStore.load(courseId: bundle.courseId)
        self.bundle = bundle
        self.playerContext = playerContext
        self.baseRoundContext = roundContext
        _selectedHoleNumber = State(
            initialValue: HostRoundProgressModel.currentHoleNumber(
                bundle: bundle,
                roundState: savedProgress?.roundState ?? RoundState(courseId: bundle.courseId, holeStates: []),
                preferredHoleNumber: savedProgress?.selectedHoleNumber
            ) ?? 0
        )
        _roundOverrides = State(initialValue: HoleInspectorModel.makeRoundOverrideState(from: roundContext))
        _roundState = State(initialValue: savedProgress?.roundState ?? RoundState(courseId: bundle.courseId, holeStates: []))
        _voiceSessionManager = StateObject(
            wrappedValue: RealtimeVoiceSessionManager(
                credentialProvider: EmbeddedPilotCredentialProvider(apiKey: "pilot-placeholder")
            )
        )
    }

    private var selectedHole: CourseHole? {
        bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })
    }

    private var holeOptions: [CourseHole] {
        bundle.holes
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

    private var roundSummary: HostRoundProgressModel.RoundSummary {
        HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: roundState,
            currentHoleNumber: selectedHoleNumber
        )
    }

    private var scorecardEntries: [HostRoundProgressModel.ScorecardEntry] {
        HostRoundProgressModel.scorecardEntries(
            bundle: bundle,
            roundState: roundState,
            currentHoleNumber: selectedHoleNumber
        )
    }

    private var scenarioOptions: [HoleInspectorModel.ShotStateScenario] {
        guard !usesLiveState else {
            return []
        }

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
            set: { isPresented in
                if !isPresented {
                    shotResultDraft = nil
                }
            }
        )
    }

    private var voiceSessionStatusLabel: String? {
        switch voiceSessionManager.state.connectionState {
        case .disconnected:
            return "Typed harness only. Voice session not connected."
        case .connecting:
            return "Connecting voice session..."
        case let .connected(descriptor):
            return "Voice session ready: \(descriptor.model)"
        case let .failed(message):
            return "Voice session unavailable: \(message)"
        }
    }

    var body: some View {
        List {
            if let preview {
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
                                    Button {
                                        selectedHoleNumber = entry.holeNumber
                                    } label: {
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
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

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

                                    HStack {
                                        Button("Save score") {
                                            saveEditedScore(for: entry.holeNumber)
                                        }
                                        .tint(.green)

                                        Spacer()

                                        Button("View hole") {
                                            selectedHoleNumber = entry.holeNumber
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button("Reset round") {
                        resetRound()
                    }
                    .tint(.red)
                }

                // Temporary typed harness until the realtime voice session replaces this UI.
                Section("Caddie Conversation") {
                    // Temporary typed harness while the realtime voice session moves
                    // into the native Swift voice subsystem outside the view layer.
                    if let statusLabel = voiceSessionStatusLabel {
                        Text(statusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if voiceSessionManager.state.transcriptEntries.isEmpty {
                        Text("Ask for guidance or report a shot result.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(voiceSessionManager.state.transcriptEntries.suffix(6)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.speakerLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(entry.text)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickPromptButton("What do you like?") {
                                submitConversationInput("what do you like here")
                            }
                            quickPromptButton("Safe play") {
                                submitConversationInput("safe play")
                            }
                            quickPromptButton("Aggressive") {
                                submitConversationInput("aggressive")
                            }
                            quickPromptButton("Repeat") {
                                submitConversationInput("repeat")
                            }
                        }
                    }

                    HStack {
                        TextField("Type to the caddie", text: $conversationInput)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(true)

                        Button("Send") {
                            submitConversationInput(conversationInput)
                        }
                        .disabled(conversationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Round") {
                    Picker("Current Hole", selection: $selectedHoleNumber) {
                        ForEach(holeOptions, id: \.holeNumber) { hole in
                            Text("Hole \(hole.holeNumber)").tag(hole.holeNumber)
                        }
                    }
                    .pickerStyle(.menu)

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

                    LabeledContent("Mode", value: selectedPlanMode.title)

                    if isHoleFinished {
                        LabeledContent("Scenario", value: "Hole finished")
                    } else if usesLiveState {
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
                    if usesLiveState,
                       let selectedHoleState,
                       let shotStateContext = selectedHoleState.shotStateContext {
                        HStack {
                            Button("Advance shot") {
                                advanceSelectedHole()
                            }

                            Spacer()

                            Button("Record shot result") {
                                beginShotResultCapture(from: shotStateContext)
                            }
                            .tint(.blue)

                            Spacer()

                            Button("Hole out") {
                                beginHoleOutFlow()
                            }
                            .tint(.green)
                        }

                        if let pendingHoleOutStrokes {
                            Stepper(
                                "Finish in \(pendingHoleOutStrokes) strokes",
                                value: Binding(
                                    get: { pendingHoleOutStrokes },
                                    set: { self.pendingHoleOutStrokes = $0 }
                                ),
                                in: 1...15
                            )

                            HStack {
                                Button("Confirm score") {
                                    confirmHoleOut()
                                }
                                .tint(.green)

                                Spacer()

                                Button("Cancel") {
                                    cancelHoleOut()
                                }
                            }
                        }

                        Stepper(
                            "Shot \(shotStateContext.shotNumber)",
                            value: Binding(
                                get: { shotStateContext.shotNumber },
                                set: updateSelectedHoleShotNumber
                            ),
                            in: 1...10
                        )

                        Picker(
                            "Lie",
                            selection: Binding(
                                get: { shotStateContext.lie },
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
                            value: "\(metric(shotStateContext.remainingDistanceM)) m"
                        )

                        Slider(
                            value: Binding(
                                get: { shotStateContext.remainingDistanceM },
                                set: updateSelectedHoleRemainingDistance
                            ),
                            in: liveDistanceRange,
                            step: 1
                        )
                    } else if isHoleFinished {
                        LabeledContent("Status", value: "Finished")
                        LabeledContent("Score", value: "\(selectedHoleState?.strokesTaken ?? 0)")

                        Button("Reset hole") {
                            resetSelectedHole()
                        }
                    } else {
                        Button("Start hole") {
                            startSelectedHole()
                        }
                    }
                }

                if isHoleFinished {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hole complete")
                                .font(.title3.weight(.semibold))

                            Text("Hole \(preview.holeNumber) is marked finished in the live round state.")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
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
                        LabeledContent("Scenario", value: currentScenarioLabel(for: preview))
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
            syncVoiceSessionSnapshot()
        }
        .sheet(isPresented: isShotResultSheetPresented) {
            shotResultSheet
        }
        .onChange(of: selectedHoleNumber) {
            shotResultDraft = nil
            pendingHoleOutStrokes = nil
            editingScoreHoleNumber = nil
            syncTeeSelection()
            syncScenarioSelection()
            persistRoundProgress()
            syncVoiceSessionSnapshot()
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

                            LabeledContent(
                                "Remaining",
                                value: "\(metric(shotResultDraft.remainingDistanceM)) m"
                            )

                            Slider(
                                value: shotResultRemainingDistanceBinding,
                                in: liveDistanceRange,
                                step: 1
                            )
                        }
                    }
                }
                .navigationTitle("Record Result")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            self.shotResultDraft = nil
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveShotResultDraft()
                        }
                    }
                }
            }
        }
    }

    private var shotResultHoledOutBinding: Binding<Bool> {
        Binding(
            get: { shotResultDraft?.holedOut ?? false },
            set: { updateShotResultDraft(holedOut: $0) }
        )
    }

    private var shotResultLieBinding: Binding<ShotLie> {
        Binding(
            get: { shotResultDraft?.resultingLie ?? .fairway },
            set: { updateShotResultDraft(resultingLie: $0) }
        )
    }

    private var shotResultRemainingDistanceBinding: Binding<Double> {
        Binding(
            get: { shotResultDraft?.remainingDistanceM ?? 0 },
            set: { updateShotResultDraft(remainingDistanceM: $0) }
        )
    }

    private func metric(_ number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }

    @ViewBuilder
    private func quickPromptButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
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

    private func currentScenarioLabel(for preview: HostRoundPreviewModel.HolePreview) -> String {
        usesLiveState ? "Live state" : preview.scenarioName
    }

    private func submitConversationInput(_ rawInput: String) {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return
        }

        conversationInput = ""

        guard let response = voiceSessionManager.submitTypedUtterance(
            trimmedInput,
            context: currentTurnContext
        ) else {
            return
        }

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

    private func syncVoiceSessionSnapshot() {
        voiceSessionManager.syncSnapshot(from: currentTurnContext)
    }

    private func startSelectedHole() {
        guard let hole = selectedHole else {
            return
        }

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
            ?? selectedHoleState?.strokesTaken
            ?? 1
    }

    private func confirmHoleOut() {
        guard let pendingHoleOutStrokes else {
            return
        }

        finishSelectedHole(strokesTaken: pendingHoleOutStrokes)
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

    private func toggleScoreEdit(for entry: HostRoundProgressModel.ScorecardEntry) {
        if editingScoreHoleNumber == entry.holeNumber {
            editingScoreHoleNumber = nil
            return
        }

        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = entry.holeNumber
        editingScoreStrokes = entry.rawStrokesTaken ?? 1
    }

    private func saveEditedScore(for holeNumber: Int) {
        roundState = roundState.updateFinishedHoleScore(editingScoreStrokes, for: holeNumber)
        editingScoreHoleNumber = nil
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
        guard let draft = shotResultDraft else {
            return
        }

        shotResultDraft = HostRoundProgressModel.ShotResultDraft(
            currentShotNumber: draft.currentShotNumber,
            resultingLie: resultingLie ?? draft.resultingLie,
            remainingDistanceM: remainingDistanceM ?? draft.remainingDistanceM,
            holedOut: holedOut ?? draft.holedOut
        )
    }

    private func saveShotResultDraft() {
        guard let shotResultDraft,
              let result = HostRoundProgressModel.applyShotResultDraft(shotResultDraft) else {
            return
        }

        switch result {
        case .advance(let shotStateContext):
            roundState = roundState.updateShotState(shotStateContext, for: selectedHoleNumber)
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

    private func updateSelectedHoleShotNumber(_ shotNumber: Int) {
        guard let shotStateContext = selectedHoleState?.shotStateContext else {
            return
        }

        roundState = roundState.updateShotState(
            ShotStateContext(
                shotNumber: shotNumber,
                remainingDistanceM: shotStateContext.remainingDistanceM,
                lie: shotStateContext.lie
            ),
            for: selectedHoleNumber
        )
    }

    private func updateSelectedHoleLie(_ lie: ShotLie) {
        guard let shotStateContext = selectedHoleState?.shotStateContext else {
            return
        }

        roundState = roundState.updateShotState(
            ShotStateContext(
                shotNumber: shotStateContext.shotNumber,
                remainingDistanceM: shotStateContext.remainingDistanceM,
                lie: lie
            ),
            for: selectedHoleNumber
        )
    }

    private func updateSelectedHoleRemainingDistance(_ remainingDistanceM: Double) {
        guard let shotStateContext = selectedHoleState?.shotStateContext else {
            return
        }

        roundState = roundState.updateShotState(
            ShotStateContext(
                shotNumber: shotStateContext.shotNumber,
                remainingDistanceM: remainingDistanceM,
                lie: shotStateContext.lie
            ),
            for: selectedHoleNumber
        )
    }

    private func persistRoundProgress() {
        HostRoundProgressStore.save(
            .init(
                selectedHoleNumber: selectedHoleNumber,
                roundState: roundState
            ),
            courseId: bundle.courseId
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
