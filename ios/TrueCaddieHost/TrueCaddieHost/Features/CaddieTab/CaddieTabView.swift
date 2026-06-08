import SwiftUI
import TrueCaddieDomain

struct CaddieTabView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContext: RoundContext
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    let preview: HostRoundPreviewModel.HolePreview?
    @ObservedObject var voiceController: HostVoiceSessionController
    @ObservedObject var locationModel: LiveCourseLocationModel
    @ObservedObject var windModel: LiveWindModel
    /// Controls whether Inspector-only UI (pill chevron, Edit button) is visible.
    var showInspectorControls: Bool = false
    let onRequestInspector: () -> Void
    let onEndRound: () -> Void

    @State private var showSettings = false

    private var currentPar: Int {
        bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })?.par ?? 0
    }

    private var currentLie: ShotLie {
        if let lie = roundState.holeState(for: selectedHoleNumber)?.shotStateContext?.lie {
            return lie
        }

        if locationModel.distanceToPinM != nil {
            return liveShotStateContext?.lie ?? locationModel.inferredLie ?? .fairway
        }

        return .tee
    }

    private var currentRemainingDistanceM: Double {
        roundState.holeState(for: selectedHoleNumber)?.shotStateContext?.remainingDistanceM
            ?? locationModel.distanceToPinM
            ?? 0
    }

    private var currentRoundScoreVsPar: Int {
        roundState.holeStates.filter { $0.status == .finished }.reduce(0) { total, holeState in
            let par = bundle.holes.first(where: { $0.holeNumber == holeState.holeNumber })?.par ?? 0
            return total + ((holeState.strokesTaken ?? 0) - par)
        }
    }

    private var currentShotNumber: Int {
        roundState.holeState(for: selectedHoleNumber)?.shotStateContext?.shotNumber ?? 1
    }

    private var currentHoleScore: Int {
        roundState.holeState(for: selectedHoleNumber)?.strokesTaken ?? 0
    }

    private var isHoleFinished: Bool {
        roundState.holeState(for: selectedHoleNumber)?.status == .finished
    }

    private var emptyStateText: String {
        if voiceController.needsMicrophonePermission {
            return "Enable microphone access to start the caddie."
        }
        return "Hole \(selectedHoleNumber) ready"
    }

    private var usesLiveRoundState: Bool {
        roundState.holeState(for: selectedHoleNumber)?.status == .inProgress
    }

    private var selectedHole: CourseHole? {
        bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })
    }

    private var effectiveRoundContext: RoundContext {
        HoleInspectorModel.makeEffectiveRoundContext(
            from: roundOverrides,
            baseRoundContext: baseRoundContext,
            hole: selectedHole
        )
    }

    private var liveShotStateContext: ShotStateContext? {
        guard let selectedHole, let distanceToPinM = locationModel.distanceToPinM else {
            return nil
        }

        return HostRoundPreviewModel.liveShotStateContext(
            for: selectedHole,
            roundContext: effectiveRoundContext,
            livePinDistanceM: distanceToPinM,
            inferredLie: locationModel.inferredLie
        )
    }

    private var displayPreview: HostRoundPreviewModel.HolePreview? {
        if usesLiveRoundState {
            return preview
        }

        if let distanceToPinM = locationModel.distanceToPinM,
           let livePreview = HostRoundPreviewModel.liveGPSPreview(
            bundle: bundle,
            playerContext: playerContext,
            roundContext: effectiveRoundContext,
            holeNumber: selectedHoleNumber,
            livePinDistanceM: distanceToPinM,
            inferredLie: locationModel.inferredLie
           ) {
            return livePreview
        }

        return preview
    }

    private var heroDistanceToPinM: Double? {
        if usesLiveRoundState {
            return roundState.holeState(for: selectedHoleNumber)?.shotStateContext?.remainingDistanceM
        }

        return locationModel.distanceToPinM
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color.blue.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 18) {
                        CaddieRecommendationHero(
                            packet: displayPreview?.packet,
                            emptyStateText: emptyStateText,
                            livePinDistanceM: heroDistanceToPinM,
                            locationAuthorizationStatus: locationModel.authorizationStatus,
                            liveWind: windModel.windContext
                        )
                        .padding(.horizontal, 16)

                        CaddieVoiceCluster(
                            voiceController: voiceController,
                            locationModel: locationModel
                        )
                        .padding(.horizontal, 16)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }

                CaddieTapRow(
                    holeNumber: selectedHoleNumber,
                    par: currentPar,
                    currentScore: currentHoleScore,
                    currentShotNumber: currentShotNumber,
                    currentRemainingDistanceM: currentRemainingDistanceM,
                    currentLie: currentLie,
                    isHoleFinished: isHoleFinished,
                    showEditButton: showInspectorControls,
                    onRequestEditor: onRequestInspector,
                    onStartHole: startHoleIfNeeded,
                    onReportResult: reportShotResult,
                    onCompleteHole: completeHole
                )
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onEndRound: onEndRound)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            CaddieStatusPill(
                holeNumber: selectedHoleNumber,
                par: currentPar,
                remainingDistanceM: currentRemainingDistanceM,
                lie: currentLie,
                roundScoreVsPar: currentRoundScoreVsPar,
                onTap: showInspectorControls ? onRequestInspector : nil
            )

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Open Settings")
        }
    }

    private func startHoleIfNeeded() {
        guard roundState.holeState(for: selectedHoleNumber) == nil,
              let selectedHole else {
            return
        }

        roundState = roundState.startHole(selectedHole, roundContext: effectiveRoundContext)
    }

    private func reportShotResult(_ lie: ShotLie) {
        startHoleIfNeeded()
        _ = voiceController.submitResolvedVoiceToolInvocation(
            VoiceToolInvocation(
                actionName: .reportResult,
                arguments: .init(
                    lie: lie,
                    remainingDistanceM: currentRemainingDistanceM
                )
            )
        )
    }

    private func completeHole(strokesTaken: Int) {
        startHoleIfNeeded()
        let finishedRoundState = roundState.finishHole(selectedHoleNumber, strokesTaken: strokesTaken)
        roundState = finishedRoundState
        selectedHoleNumber = HostRoundProgressModel.nextUnfinishedHoleNumber(
            after: selectedHoleNumber,
            bundle: bundle,
            roundState: finishedRoundState
        ) ?? selectedHoleNumber
    }
}
