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
    @State private var conversationLog: [HostCaddieSession.TranscriptEntry] = []
    @State private var shotResultDraft: HostRoundProgressModel.ShotResultDraft?
    @State private var pendingHoleOutStrokes: Int?
    @State private var editingScoreHoleNumber: Int?
    @State private var editingScoreStrokes = 0
    @State private var roundOverrides: HoleInspectorModel.RoundOverrideState
    @State private var roundState: RoundState

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
                    if conversationLog.isEmpty {
                        Text("Ask for guidance or report a shot result.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(conversationLog.suffix(6)) { entry in
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
        }
        .onChange(of: selectedPlanMode) {
            syncScenarioSelection(forceReset: true)
        }
        .onChange(of: effectiveRoundContext) {
            syncScenarioSelection()
        }
        .onChange(of: roundState) {
            persistRoundProgress()
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

        let request = HostCaddieSession.TurnRequest(
            utterance: trimmedInput,
            context: .init(
                bundle: bundle,
                playerContext: playerContext,
                roundContext: effectiveRoundContext,
                selectedHoleNumber: selectedHoleNumber,
                planMode: selectedPlanMode,
                roundState: roundState
            )
        )

        guard let outcome = HostCaddieSession.respond(
            to: request
        ) else {
            conversationLog.append(.user(trimmedInput))
            conversationLog.append(.assistant("I couldn't ground that yet. Try asking for guidance or say something like rough 128."))
            return
        }

        conversationLog.append(.user(trimmedInput))
        conversationLog.append(.assistant(outcome.assistantReply))

        if let strategyPreference = outcome.strategyPreference {
            roundOverrides.strategyPreference = strategyPreference
        }

        roundState = outcome.roundState
        selectedHoleNumber = outcome.selectedHoleNumber
        pendingHoleOutStrokes = nil
        editingScoreHoleNumber = nil
        shotResultDraft = nil
        syncScenarioSelection(forceReset: true)
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

enum HostCaddieSession {
    struct VoiceToolFieldDefinition: Equatable, Identifiable {
        let name: String
        let type: String
        let required: Bool
        let description: String

        var id: String {
            name
        }
    }

    struct TranscriptEntry: Equatable, Identifiable {
        enum Speaker: String, Equatable {
            case user
            case assistant
        }

        let speaker: Speaker
        let text: String
        let id: UUID

        var speakerLabel: String {
            speaker == .user ? "You" : "Caddie"
        }

        static func user(_ text: String) -> TranscriptEntry {
            TranscriptEntry(speaker: .user, text: text, id: UUID())
        }

        static func assistant(_ text: String) -> TranscriptEntry {
            TranscriptEntry(speaker: .assistant, text: text, id: UUID())
        }
    }

    enum ActionName: String, CaseIterable, Equatable, Codable {
        case guidance
        case saferPlay = "safer_play"
        case aggressivePlay = "aggressive_play"
        case balancedPlay = "balanced_play"
        case repeatGuidance = "repeat_guidance"
        case reportResult = "report_result"
        case holeOut = "hole_out"
        case correctScore = "correct_score"
    }

    struct VoiceToolDefinition: Equatable, Identifiable {
        let name: ActionName
        let description: String
        let fields: [VoiceToolFieldDefinition]
        let sampleUtterances: [String]

        var id: String {
            name.rawValue
        }
    }

    struct ReportResultPayload: Equatable {
        let lie: ShotLie
        let remainingDistanceM: Double
    }

    struct CorrectScorePayload: Equatable {
        let strokesTaken: Int
        let holeNumber: Int?
    }

    enum RealtimeToolPayload: Equatable {
        case none
        case reportResult(ReportResultPayload)
        case correctScore(CorrectScorePayload)
    }

    struct RealtimeToolCall: Equatable {
        let name: ActionName
        let payload: RealtimeToolPayload
    }

    struct WireToolArguments: Codable, Equatable {
        let lie: ShotLie?
        let remainingDistanceM: Double?
        let strokesTaken: Int?
        let holeNumber: Int?

        init(
            lie: ShotLie? = nil,
            remainingDistanceM: Double? = nil,
            strokesTaken: Int? = nil,
            holeNumber: Int? = nil
        ) {
            self.lie = lie
            self.remainingDistanceM = remainingDistanceM
            self.strokesTaken = strokesTaken
            self.holeNumber = holeNumber
        }
    }

    struct WireToolCall: Codable, Equatable {
        let name: String
        let arguments: WireToolArguments
    }

    enum SessionTurnSource: Equatable {
        case utterance(String)
        case toolCall(RealtimeToolCall)
    }

    enum Action: Equatable {
        case guidance
        case saferPlay
        case aggressivePlay
        case balancedPlay
        case repeatGuidance
        case reportShotResult(lie: ShotLie, remainingDistanceM: Double)
        case holeOut
        case correctScore(strokesTaken: Int, holeNumber: Int?)

        var name: ActionName {
            switch self {
            case .guidance:
                return .guidance
            case .saferPlay:
                return .saferPlay
            case .aggressivePlay:
                return .aggressivePlay
            case .balancedPlay:
                return .balancedPlay
            case .repeatGuidance:
                return .repeatGuidance
            case .reportShotResult:
                return .reportResult
            case .holeOut:
                return .holeOut
            case .correctScore:
                return .correctScore
            }
        }
    }

    struct TurnContext {
        let bundle: CourseBundle
        let playerContext: PlayerContext
        let roundContext: RoundContext
        let selectedHoleNumber: Int
        let planMode: HostRoundPreviewModel.RoundPlanMode
        let roundState: RoundState
    }

    struct TurnRequest {
        let utterance: String
        let context: TurnContext
    }

    struct TurnOutcome: Equatable {
        let actionName: ActionName
        let assistantReply: String
        let roundState: RoundState
        let selectedHoleNumber: Int
        let strategyPreference: StrategyPreference?
    }

    struct SessionStateSnapshot: Equatable {
        let selectedHoleNumber: Int
        let roundContext: RoundContext
        let roundState: RoundState
        let availableToolNames: [ActionName]
    }

    struct SessionRequestEnvelope {
        let source: SessionTurnSource
        let context: TurnContext
    }

    struct SessionResponseEnvelope: Equatable {
        let actionName: ActionName
        let assistantReply: String
        let state: SessionStateSnapshot
        let strategyPreference: StrategyPreference?
    }

    struct WireRoundContextSnapshot: Codable, Equatable {
        let teeSetId: String
        let teeSetName: String
        let strategyPreference: String
        let windRelativeDirection: String?
        let windSpeedMps: Double?
    }

    struct WireSessionStateSnapshot: Codable, Equatable {
        let selectedHoleNumber: Int
        let roundContext: WireRoundContextSnapshot
        let roundState: RoundState
        let availableToolNames: [String]
    }

    struct WireSessionRequest: Codable, Equatable {
        let utterance: String?
        let toolCall: WireToolCall?
    }

    struct WireSessionResponse: Codable, Equatable {
        let actionName: String
        let assistantReply: String
        let state: WireSessionStateSnapshot
        let strategyPreference: String?
    }

    struct WireToolParameterDefinition: Codable, Equatable, Identifiable {
        let name: String
        let type: String
        let required: Bool
        let description: String
        let allowedValues: [String]?

        var id: String {
            name
        }
    }

    struct WireToolCatalogEntry: Codable, Equatable, Identifiable {
        let name: String
        let description: String
        let parameters: [WireToolParameterDefinition]
        let sampleUtterances: [String]

        var id: String {
            name
        }
    }

    struct OpenAIPropertySchema: Codable, Equatable {
        let type: String
        let description: String
        let enumValues: [String]?

        enum CodingKeys: String, CodingKey {
            case type
            case description
            case enumValues = "enum"
        }
    }

    struct OpenAIParametersSchema: Codable, Equatable {
        let type: String
        let properties: [String: OpenAIPropertySchema]
        let required: [String]
        let additionalProperties: Bool
    }

    struct OpenAIFunctionToolDefinition: Codable, Equatable, Identifiable {
        let type: String
        let name: String
        let description: String
        let parameters: OpenAIParametersSchema
        let strict: Bool

        var id: String {
            name
        }
    }

    struct OpenAIFunctionToolCall: Codable, Equatable {
        let name: String
        let arguments: WireToolArguments
    }

    struct RealtimeAgentStubConfiguration: Codable, Equatable {
        let agentName: String
        let instructions: String
        let tools: [OpenAIFunctionToolDefinition]
    }

    enum RealtimeAgentStub {
        static func configuration() -> RealtimeAgentStubConfiguration {
            RealtimeAgentStubConfiguration(
                agentName: "TrueCaddie Voice Caddie",
                instructions: """
                You are a calm, concise golf caddie. Use tools to get grounded recommendations and update round state. Do not invent strategy. Prefer short spoken replies.
                """,
                tools: VoiceSessionBridge.openAIFunctionTools()
            )
        }

        static func resolveToolCall(
            name: String,
            argumentsJSON: String,
            context: TurnContext
        ) -> WireSessionResponse? {
            guard let wireRequest = VoiceSessionBridge.wireRequest(
                toolName: name,
                argumentsJSON: argumentsJSON
            ) else {
                return nil
            }

            return VoiceSessionBridge.respond(
                to: wireRequest,
                context: context
            )
        }
    }

    enum VoiceSessionBridge {
        static func toolCatalog() -> [WireToolCatalogEntry] {
            supportedVoiceTools.map { tool in
                WireToolCatalogEntry(
                    name: tool.name.rawValue,
                    description: tool.description,
                    parameters: tool.fields.map { field in
                        WireToolParameterDefinition(
                            name: field.name,
                            type: field.type,
                            required: field.required,
                            description: field.description,
                            allowedValues: allowedValues(for: field)
                        )
                    },
                    sampleUtterances: tool.sampleUtterances
                )
            }
        }

        static func openAIFunctionTools() -> [OpenAIFunctionToolDefinition] {
            toolCatalog().map { tool in
                OpenAIFunctionToolDefinition(
                    type: "function",
                    name: tool.name,
                    description: tool.description,
                    parameters: OpenAIParametersSchema(
                        type: "object",
                        properties: Dictionary(
                            uniqueKeysWithValues: tool.parameters.map { parameter in
                                (
                                    parameter.name,
                                    OpenAIPropertySchema(
                                        type: jsonSchemaType(for: parameter.type),
                                        description: parameter.description,
                                        enumValues: parameter.allowedValues
                                    )
                                )
                            }
                        ),
                        required: tool.parameters
                            .filter(\.required)
                            .map(\.name),
                        additionalProperties: false
                    ),
                    strict: true
                )
            }
        }

        static func wireToolCall(from toolCall: RealtimeToolCall) -> WireToolCall {
            switch toolCall.payload {
            case .none:
                return WireToolCall(
                    name: toolCall.name.rawValue,
                    arguments: WireToolArguments()
                )
            case let .reportResult(payload):
                return WireToolCall(
                    name: toolCall.name.rawValue,
                    arguments: WireToolArguments(
                        lie: payload.lie,
                        remainingDistanceM: payload.remainingDistanceM
                    )
                )
            case let .correctScore(payload):
                return WireToolCall(
                    name: toolCall.name.rawValue,
                    arguments: WireToolArguments(
                        strokesTaken: payload.strokesTaken,
                        holeNumber: payload.holeNumber
                    )
                )
            }
        }

        static func toolCall(from wireToolCall: WireToolCall) -> RealtimeToolCall? {
            guard let name = ActionName(rawValue: wireToolCall.name) else {
                return nil
            }

            return HostCaddieSession.toolCall(
                named: name,
                lie: wireToolCall.arguments.lie,
                remainingDistanceM: wireToolCall.arguments.remainingDistanceM,
                strokesTaken: wireToolCall.arguments.strokesTaken,
                holeNumber: wireToolCall.arguments.holeNumber
            )
        }

        static func requestEnvelope(
            from wireRequest: WireSessionRequest,
            context: TurnContext
        ) -> SessionRequestEnvelope? {
            if let utterance = wireRequest.utterance?.trimmingCharacters(in: .whitespacesAndNewlines),
               !utterance.isEmpty {
                return SessionRequestEnvelope(
                    source: .utterance(utterance),
                    context: context
                )
            }

            guard let wireToolCall = wireRequest.toolCall,
                  let toolCall = toolCall(from: wireToolCall) else {
                return nil
            }

            return SessionRequestEnvelope(
                source: .toolCall(toolCall),
                context: context
            )
        }

        static func wireRequest(
            from openAIToolCall: OpenAIFunctionToolCall
        ) -> WireSessionRequest? {
            guard toolCatalog().contains(where: { $0.name == openAIToolCall.name }) else {
                return nil
            }

            return WireSessionRequest(
                utterance: nil,
                toolCall: WireToolCall(
                    name: openAIToolCall.name,
                    arguments: openAIToolCall.arguments
                )
            )
        }

        static func wireRequest(
            toolName: String,
            argumentsJSON: String
        ) -> WireSessionRequest? {
            guard let data = argumentsJSON.data(using: .utf8),
                  let arguments = try? JSONDecoder().decode(
                    WireToolArguments.self,
                    from: data
                  ) else {
                return nil
            }

            return wireRequest(
                from: OpenAIFunctionToolCall(
                    name: toolName,
                    arguments: arguments
                )
            )
        }

        static func wireState(from state: SessionStateSnapshot) -> WireSessionStateSnapshot {
            WireSessionStateSnapshot(
                selectedHoleNumber: state.selectedHoleNumber,
                roundContext: WireRoundContextSnapshot(
                    teeSetId: state.roundContext.teeSetId,
                    teeSetName: state.roundContext.teeSetName,
                    strategyPreference: state.roundContext.strategyPreference.rawValue,
                    windRelativeDirection: state.roundContext.wind?.relativeDirection.rawValue,
                    windSpeedMps: state.roundContext.wind?.speedMps
                ),
                roundState: state.roundState,
                availableToolNames: state.availableToolNames.map(\.rawValue)
            )
        }

        static func wireResponse(from response: SessionResponseEnvelope) -> WireSessionResponse {
            WireSessionResponse(
                actionName: response.actionName.rawValue,
                assistantReply: response.assistantReply,
                state: wireState(from: response.state),
                strategyPreference: response.strategyPreference?.rawValue
            )
        }

        static func respond(
            to wireRequest: WireSessionRequest,
            context: TurnContext
        ) -> WireSessionResponse? {
            guard let envelope = requestEnvelope(
                from: wireRequest,
                context: context
            ),
            let response = HostCaddieSession.respond(to: envelope) else {
                return nil
            }

            return wireResponse(from: response)
        }

        static func dispatchTool(
            named toolName: String,
            arguments: WireToolArguments,
            context: TurnContext
        ) -> WireSessionResponse? {
            respond(
                to: WireSessionRequest(
                    utterance: nil,
                    toolCall: WireToolCall(
                        name: toolName,
                        arguments: arguments
                    )
                ),
                context: context
            )
        }

        private static func allowedValues(
            for field: VoiceToolFieldDefinition
        ) -> [String]? {
            guard field.type == "ShotLie" else {
                return nil
            }

            return [
                ShotLie.tee.rawValue,
                ShotLie.fairway.rawValue,
                ShotLie.rough.rawValue,
                ShotLie.bunker.rawValue,
                ShotLie.recovery.rawValue
            ]
        }

        private static func jsonSchemaType(for parameterType: String) -> String {
            switch parameterType {
            case "Double":
                return "number"
            case "Int":
                return "integer"
            default:
                return "string"
            }
        }
    }

    static let supportedVoiceTools: [VoiceToolDefinition] = [
        VoiceToolDefinition(
            name: .guidance,
            description: "Get the grounded caddie recommendation for the current shot.",
            fields: [],
            sampleUtterances: ["what do you like here", "what's the play"]
        ),
        VoiceToolDefinition(
            name: .saferPlay,
            description: "Shift the recommendation toward the conservative play.",
            fields: [],
            sampleUtterances: ["safe play", "give me the safer option"]
        ),
        VoiceToolDefinition(
            name: .aggressivePlay,
            description: "Shift the recommendation toward the aggressive play.",
            fields: [],
            sampleUtterances: ["aggressive", "let's attack"]
        ),
        VoiceToolDefinition(
            name: .balancedPlay,
            description: "Return to the balanced default strategy.",
            fields: [],
            sampleUtterances: ["back to balanced", "normal plan"]
        ),
        VoiceToolDefinition(
            name: .repeatGuidance,
            description: "Repeat the current grounded recommendation.",
            fields: [],
            sampleUtterances: ["repeat that", "say it again"]
        ),
        VoiceToolDefinition(
            name: .reportResult,
            description: "Report the lie and remaining distance after a shot.",
            fields: [
                VoiceToolFieldDefinition(
                    name: "lie",
                    type: "ShotLie",
                    required: true,
                    description: "The player's resulting lie after the shot."
                ),
                VoiceToolFieldDefinition(
                    name: "remainingDistanceM",
                    type: "Double",
                    required: true,
                    description: "The remaining distance to the target in meters."
                )
            ],
            sampleUtterances: ["rough 128", "fairway 96"]
        ),
        VoiceToolDefinition(
            name: .holeOut,
            description: "Finish the current hole using the current live shot count.",
            fields: [],
            sampleUtterances: ["holed out", "that's in"]
        ),
        VoiceToolDefinition(
            name: .correctScore,
            description: "Correct a finished hole's score.",
            fields: [
                VoiceToolFieldDefinition(
                    name: "strokesTaken",
                    type: "Int",
                    required: true,
                    description: "The confirmed score for the finished hole."
                ),
                VoiceToolFieldDefinition(
                    name: "holeNumber",
                    type: "Int",
                    required: false,
                    description: "The finished hole to correct. Defaults to the current hole when omitted."
                )
            ],
            sampleUtterances: ["make that 5", "hole 1 was 6"]
        )
    ]

    static func toolCall(
        named name: ActionName,
        lie: ShotLie? = nil,
        remainingDistanceM: Double? = nil,
        strokesTaken: Int? = nil,
        holeNumber: Int? = nil
    ) -> RealtimeToolCall? {
        switch name {
        case .guidance, .saferPlay, .aggressivePlay, .balancedPlay, .repeatGuidance, .holeOut:
            return RealtimeToolCall(name: name, payload: .none)

        case .reportResult:
            guard let lie, let remainingDistanceM else {
                return nil
            }

            return RealtimeToolCall(
                name: name,
                payload: .reportResult(
                    ReportResultPayload(
                        lie: lie,
                        remainingDistanceM: remainingDistanceM
                    )
                )
            )

        case .correctScore:
            guard let strokesTaken else {
                return nil
            }

            return RealtimeToolCall(
                name: name,
                payload: .correctScore(
                    CorrectScorePayload(
                        strokesTaken: strokesTaken,
                        holeNumber: holeNumber
                    )
                )
            )
        }
    }

    static func action(for toolCall: RealtimeToolCall) -> Action? {
        switch (toolCall.name, toolCall.payload) {
        case (.guidance, .none):
            return .guidance
        case (.saferPlay, .none):
            return .saferPlay
        case (.aggressivePlay, .none):
            return .aggressivePlay
        case (.balancedPlay, .none):
            return .balancedPlay
        case (.repeatGuidance, .none):
            return .repeatGuidance
        case let (.reportResult, .reportResult(payload)):
            return .reportShotResult(
                lie: payload.lie,
                remainingDistanceM: payload.remainingDistanceM
            )
        case (.holeOut, .none):
            return .holeOut
        case let (.correctScore, .correctScore(payload)):
            return .correctScore(
                strokesTaken: payload.strokesTaken,
                holeNumber: payload.holeNumber
            )
        default:
            return nil
        }
    }

    static func snapshot(from context: TurnContext) -> SessionStateSnapshot {
        SessionStateSnapshot(
            selectedHoleNumber: context.selectedHoleNumber,
            roundContext: context.roundContext,
            roundState: context.roundState,
            availableToolNames: supportedVoiceTools.map(\.name)
        )
    }

    static func respond(
        to toolCall: RealtimeToolCall,
        in context: TurnContext
    ) -> TurnOutcome? {
        guard let action = action(for: toolCall) else {
            return nil
        }

        return perform(action, in: context)
    }

    static func respond(to request: TurnRequest) -> TurnOutcome? {
        guard let action = interpret(request.utterance) else {
            return nil
        }

        return perform(action, in: request.context)
    }

    static func respond(
        to envelope: SessionRequestEnvelope
    ) -> SessionResponseEnvelope? {
        let turnOutcome: TurnOutcome?

        switch envelope.source {
        case let .utterance(utterance):
            turnOutcome = respond(
                to: TurnRequest(
                    utterance: utterance,
                    context: envelope.context
                )
            )
        case let .toolCall(toolCall):
            turnOutcome = respond(
                to: toolCall,
                in: envelope.context
            )
        }

        guard let turnOutcome else {
            return nil
        }

        let updatedRoundContext: RoundContext
        if let strategyPreference = turnOutcome.strategyPreference {
            updatedRoundContext = RoundContext(
                teeSetId: envelope.context.roundContext.teeSetId,
                teeSetName: envelope.context.roundContext.teeSetName,
                strategyPreference: strategyPreference,
                wind: envelope.context.roundContext.wind
            )
        } else {
            updatedRoundContext = envelope.context.roundContext
        }

        return SessionResponseEnvelope(
            actionName: turnOutcome.actionName,
            assistantReply: turnOutcome.assistantReply,
            state: SessionStateSnapshot(
                selectedHoleNumber: turnOutcome.selectedHoleNumber,
                roundContext: updatedRoundContext,
                roundState: turnOutcome.roundState,
                availableToolNames: supportedVoiceTools.map(\.name)
            ),
            strategyPreference: turnOutcome.strategyPreference
        )
    }

    static func perform(_ action: Action, in context: TurnContext) -> TurnOutcome? {
        switch action {
        case .guidance:
            guard let preview = preview(for: context) else {
                return nil
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: preview.voicePreview,
                roundState: context.roundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: nil
            )

        case .saferPlay:
            let saferRoundContext = RoundContext(
                teeSetId: context.roundContext.teeSetId,
                teeSetName: context.roundContext.teeSetName,
                strategyPreference: .conservative,
                wind: context.roundContext.wind
            )
            guard let preview = preview(
                for: context,
                roundContext: saferRoundContext
            ) else {
                return nil
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Let's take the safer play. \(preview.voicePreview)",
                roundState: context.roundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: .conservative
            )

        case .aggressivePlay:
            let aggressiveRoundContext = RoundContext(
                teeSetId: context.roundContext.teeSetId,
                teeSetName: context.roundContext.teeSetName,
                strategyPreference: .aggressive,
                wind: context.roundContext.wind
            )
            guard let preview = preview(
                for: context,
                roundContext: aggressiveRoundContext
            ) else {
                return nil
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "If you want to press it, this is the line. \(preview.voicePreview)",
                roundState: context.roundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: .aggressive
            )

        case .balancedPlay:
            let balancedRoundContext = RoundContext(
                teeSetId: context.roundContext.teeSetId,
                teeSetName: context.roundContext.teeSetName,
                strategyPreference: .balanced,
                wind: context.roundContext.wind
            )
            guard let preview = preview(
                for: context,
                roundContext: balancedRoundContext
            ) else {
                return nil
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Let's get back to the stock plan. \(preview.voicePreview)",
                roundState: context.roundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: .balanced
            )

        case .repeatGuidance:
            guard let preview = preview(for: context) else {
                return nil
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Here it is again. \(preview.voicePreview)",
                roundState: context.roundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: nil
            )

        case let .reportShotResult(lie, remainingDistanceM):
            let currentShotNumber = context.roundState.holeState(
                for: context.selectedHoleNumber
            )?.shotStateContext?.shotNumber
            guard let currentShotNumber else {
                return TurnOutcome(
                    actionName: action.name,
                    assistantReply: "Start the hole first, then I can update the next shot from the result.",
                    roundState: context.roundState,
                    selectedHoleNumber: context.selectedHoleNumber,
                    strategyPreference: nil
                )
            }

            let updatedRoundState = context.roundState.updateShotState(
                ShotStateContext(
                    shotNumber: currentShotNumber + 1,
                    remainingDistanceM: remainingDistanceM,
                    lie: lie
                ),
                for: context.selectedHoleNumber
            )
            guard let preview = preview(
                for: context,
                roundState: updatedRoundState
            ) else {
                return nil
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Got it. From \(lie.rawValue) at \(format(number: remainingDistanceM))m: \(preview.voicePreview)",
                roundState: updatedRoundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: nil
            )

        case .holeOut:
            let strokesTaken = context.roundState.holeState(
                for: context.selectedHoleNumber
            )?.shotStateContext?.shotNumber
                ?? context.roundState.holeState(
                    for: context.selectedHoleNumber
                )?.strokesTaken
                ?? 1
            let finishedRoundState = context.roundState.finishHole(
                context.selectedHoleNumber,
                strokesTaken: strokesTaken
            )
            let nextHoleNumber = HostRoundProgressModel.nextUnfinishedHoleNumber(
                after: context.selectedHoleNumber,
                bundle: context.bundle,
                roundState: finishedRoundState
            ) ?? context.selectedHoleNumber
            let summary = HostRoundProgressModel.summary(
                bundle: context.bundle,
                roundState: finishedRoundState,
                currentHoleNumber: nextHoleNumber
            )

            if summary.isRoundComplete {
                return TurnOutcome(
                    actionName: action.name,
                    assistantReply: "Nice work. Round complete. \(summary.totalsHeader).",
                    roundState: finishedRoundState,
                    selectedHoleNumber: nextHoleNumber,
                    strategyPreference: nil
                )
            }

            if let nextPreview = preview(
                for: context,
                selectedHoleNumber: nextHoleNumber,
                roundState: finishedRoundState
            ) {
                return TurnOutcome(
                    actionName: action.name,
                    assistantReply: "Nice. That's \(strokesTaken) on hole \(context.selectedHoleNumber). Current hole \(nextHoleNumber). \(nextPreview.voicePreview)",
                    roundState: finishedRoundState,
                    selectedHoleNumber: nextHoleNumber,
                    strategyPreference: nil
                )
            }

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Nice. That's \(strokesTaken) on hole \(context.selectedHoleNumber).",
                roundState: finishedRoundState,
                selectedHoleNumber: nextHoleNumber,
                strategyPreference: nil
            )

        case let .correctScore(strokesTaken, holeNumber):
            let targetHoleNumber = holeNumber ?? context.selectedHoleNumber
            guard let holeState = context.roundState.holeState(for: targetHoleNumber),
                  holeState.status == .finished else {
                return TurnOutcome(
                    actionName: action.name,
                    assistantReply: "I can correct the score once that hole is finished.",
                    roundState: context.roundState,
                    selectedHoleNumber: context.selectedHoleNumber,
                    strategyPreference: nil
                )
            }

            let updatedRoundState = context.roundState.updateFinishedHoleScore(
                strokesTaken,
                for: targetHoleNumber
            )
            let summary = HostRoundProgressModel.summary(
                bundle: context.bundle,
                roundState: updatedRoundState,
                currentHoleNumber: context.selectedHoleNumber
            )

            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Got it. Hole \(targetHoleNumber) is \(strokesTaken). \(summary.totalsHeader).",
                roundState: updatedRoundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: nil
            )
        }
    }

    static func interpret(_ input: String) -> Action? {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedInput.contains("repeat") {
            return .repeatGuidance
        }

        if normalizedInput.contains("balanced") || normalizedInput.contains("normal plan") || normalizedInput.contains("stock plan") {
            return .balancedPlay
        }

        if normalizedInput.contains("safe") || normalizedInput.contains("safer") || normalizedInput.contains("conservative") {
            return .saferPlay
        }

        if normalizedInput.contains("aggressive") || normalizedInput.contains("attack") {
            return .aggressivePlay
        }

        if normalizedInput.contains("holed out") || normalizedInput.contains("made it") || normalizedInput.contains("hole out") {
            return .holeOut
        }

        if let correctionAction = scoreCorrection(in: normalizedInput) {
            return correctionAction
        }

        if let lie = reportedLie(in: normalizedInput),
           let remainingDistanceM = firstNumber(in: normalizedInput) {
            return .reportShotResult(lie: lie, remainingDistanceM: remainingDistanceM)
        }

        return .guidance
    }

    private static func preview(
        for context: TurnContext,
        roundContext: RoundContext? = nil,
        selectedHoleNumber: Int? = nil,
        roundState: RoundState? = nil
    ) -> HostRoundPreviewModel.HolePreview? {
        HostRoundPreviewModel.preview(
            bundle: context.bundle,
            playerContext: context.playerContext,
            roundContext: roundContext ?? context.roundContext,
            holeNumber: selectedHoleNumber ?? context.selectedHoleNumber,
            planMode: context.planMode,
            selectedScenarioId: "",
            roundState: roundState ?? context.roundState
        )
    }

    private static func reportedLie(in input: String) -> ShotLie? {
        if input.contains("fairway") {
            return .fairway
        }
        if input.contains("rough") {
            return .rough
        }
        if input.contains("bunker") || input.contains("sand") {
            return .bunker
        }
        if input.contains("recovery") || input.contains("trees") {
            return .recovery
        }
        if input.contains("tee") {
            return .tee
        }

        return nil
    }

    private static func firstNumber(in input: String) -> Double? {
        let tokens = input.split { character in
            !character.isNumber && character != "."
        }

        for token in tokens {
            if let value = Double(token) {
                return value
            }
        }

        return nil
    }

    private static func scoreCorrection(in input: String) -> Action? {
        let looksLikeScoreCorrection =
            input.contains("make that") ||
            input.contains("put me down") ||
            input.contains("score") ||
            input.contains("strokes") ||
            input.contains("card") ||
            (input.contains("hole") && input.contains("was"))

        guard looksLikeScoreCorrection else {
            return nil
        }

        let numbers = integerNumbers(in: input)
        guard let strokesTaken = numbers.last else {
            return nil
        }

        let holeNumber: Int?
        if input.contains("hole"), numbers.count >= 2 {
            holeNumber = numbers.first
        } else {
            holeNumber = nil
        }

        return .correctScore(strokesTaken: strokesTaken, holeNumber: holeNumber)
    }

    private static func integerNumbers(in input: String) -> [Int] {
        input.split { character in
            !character.isNumber
        }
        .compactMap { token in
            Int(token)
        }
    }

    private static func format(number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}
