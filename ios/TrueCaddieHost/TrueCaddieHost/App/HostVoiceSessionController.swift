import Combine
import Foundation
import TrueCaddieDomain

final class HostVoiceSessionController: ObservableObject {
    @Published private(set) var state: VoiceSessionState
    @Published private(set) var permissionState: RealtimeVoicePermissionState

    private let sessionManager: RealtimeVoiceSessionManager
    private let permissionProvider: any RealtimeVoicePermissionProviding
    private let eventSource: any RealtimeVoiceEventSourcing
    private let microphoneSource: any MicrophonePCMSourcing
    private let playbackEngine: any RealtimePlaybackEngine
    private var currentContext: HostCaddieSession.TurnContext?
    private var lastEventResponse: VoiceTurnResponse?

    /// Optional source of live GPS-derived state, used by
    /// ``markBallPosition()`` and by the model-tool intercept for
    /// `mark_ball_position`. The location model is owned by ContentView and
    /// injected after construction so the controller doesn't itself depend on
    /// CoreLocation.
    var locationModel: LiveCourseLocationModel?

    init(
        sessionManager: RealtimeVoiceSessionManager = RealtimeVoiceSessionManager(
            credentialProvider: EmbeddedPilotCredentialProvider(apiKey: "pilot-placeholder")
        ),
        permissionProvider: any RealtimeVoicePermissionProviding = NativeRealtimeVoiceRuntimeFactory.permissionProvider(),
        eventSource: any RealtimeVoiceEventSourcing = NativeRealtimeVoiceRuntimeFactory.eventSource(),
        microphoneSource: any MicrophonePCMSourcing = NativeRealtimeVoiceRuntimeFactory.microphoneSource(),
        playbackEngine: any RealtimePlaybackEngine = NativeRealtimeVoiceRuntimeFactory.playbackEngine()
    ) {
        self.sessionManager = sessionManager
        self.permissionProvider = permissionProvider
        self.eventSource = eventSource
        self.microphoneSource = microphoneSource
        self.playbackEngine = playbackEngine
        self.state = sessionManager.state
        self.permissionState = permissionProvider.currentPermissionState()
        self.permissionProvider.onStateChange = { [weak self] state in
            self?.permissionState = state
            self?.refreshState()
        }
        self.eventSource.onEvent = { [weak self] event in
            self?.receiveRealtimeEvent(event)
        }
        self.microphoneSource.onChunk = { [weak self] chunk in
            self?.eventSource.submitMicrophonePCMChunk(chunk.samples, format: chunk.format)
        }
    }

    var statusLabel: String {
        switch permissionState {
        case .undetermined:
            return "Microphone access is required before starting voice."
        case .denied:
            return "Microphone access is denied. Enable it to test live voice."
        case .granted:
            break
        }

        switch state.connectionState {
        case .disconnected:
            return "Microphone ready. Voice session not connected."
        case .connecting:
            return "Connecting voice session..."
        case let .connected(descriptor):
            let sessionSuffix = state.activeSession.map { " • session \($0.id.prefix(8))" } ?? ""
            return state.turnState == .listening
                ? "Listening live with \(descriptor.model)\(sessionSuffix)"
                : "Voice session ready: \(descriptor.model)\(sessionSuffix)"
        case let .failed(message):
            return "Voice session unavailable: \(message)"
        }
    }

    var needsMicrophonePermission: Bool {
        permissionState != .granted
    }

    var isConnected: Bool {
        if case .connected = state.connectionState {
            return true
        }

        return false
    }

    var isListening: Bool {
        state.turnState == .listening
    }

    var isSpeaking: Bool {
        if case .speaking = state.turnState {
            return true
        }

        return false
    }

    var canConnect: Bool {
        permissionState == .granted && !isConnected
    }

    var canStartListening: Bool {
        permissionState == .granted && isConnected && !isListening
    }

    var canStopListening: Bool {
        isListening
    }

    var canInterrupt: Bool {
        isListening || isSpeaking
    }

    func updateContext(_ context: HostCaddieSession.TurnContext) {
        currentContext = context
        permissionState = permissionProvider.currentPermissionState()
        sessionManager.syncSnapshot(from: context)
        logDebug(
            "Updated voice context",
            category: .round,
            metadata: [
                "hole": String(context.selectedHoleNumber),
                "planMode": context.planMode.rawValue,
                "strategy": context.roundContext.strategyPreference.rawValue
            ]
        )
        refreshState()
    }

    func requestMicrophoneAccess() {
        permissionProvider.requestPermission()
        permissionState = permissionProvider.currentPermissionState()
        refreshState()
    }

    func connectIfNeeded() {
        guard permissionState == .granted, !isConnected else {
            return
        }

        logDebug("Connecting voice session", category: .voice)
        try? sessionManager.connect()
        eventSource.connect()
        do {
            try playbackEngine.start()
        } catch {
            print("[HostVoiceSession] Playback engine unavailable: \(error)")
        }
        refreshState()
    }

    func disconnect() {
        logDebug("Disconnecting voice session", category: .voice)
        microphoneSource.stop()
        playbackEngine.stop()
        sessionManager.disconnect()
        refreshState()
    }

    func beginListening() {
        guard currentContext != nil else {
            return
        }

        guard permissionState == .granted else {
            return
        }

        connectIfNeeded()
        logDebug("Begin listening", category: .voice)
        try? sessionManager.beginListening()
        do {
            try microphoneSource.start()
        } catch {
            print("[HostVoiceSession] Microphone source unavailable: \(error)")
        }
        eventSource.beginListening()
    }

    func stopListening() {
        guard currentContext != nil else {
            return
        }

        logDebug("Stop listening", category: .voice)
        microphoneSource.stop()
        sessionManager.stopListening()
        eventSource.stopListening()
    }

    func finishPlayback() {
        guard currentContext != nil else {
            return
        }

        eventSource.finishAssistantPlayback()
    }

    func interrupt() {
        guard currentContext != nil else {
            return
        }

        logDebug("Interrupt current turn", category: .voice)
        // Drain any queued playback so the user doesn't hear stale audio
        // after they cut the assistant off; restart so the engine stays
        // ready for the next turn.
        playbackEngine.stop()
        try? playbackEngine.start()
        eventSource.interrupt()
    }

    func submitTypedUtterance(_ utterance: String) -> VoiceTurnResponse? {
        guard let currentContext else {
            return nil
        }

        let response = sessionManager.submitTypedUtterance(
            utterance,
            context: currentContext
        )
        refreshState()
        return response
    }

    func submitVoiceUtterance(_ utterance: String) -> VoiceTurnResponse? {
        guard currentContext != nil else {
            return nil
        }

        logDebug(
            "Submit final utterance",
            category: .voice,
            metadata: ["utterance": utterance]
        )
        lastEventResponse = nil
        eventSource.submitFinalUtterance(utterance)
        let response = lastEventResponse
        if let response {
            eventSource.playAssistantReply(response.spokenReply)
        }
        return response
    }

    func submitPartialVoiceUtterance(_ utterance: String) {
        guard currentContext != nil else {
            return
        }

        logDebug(
            "Submit partial utterance",
            category: .voice,
            metadata: ["utterance": utterance]
        )
        eventSource.submitPartialUtterance(utterance)
    }

    func submitVoiceToolInvocation(_ invocation: VoiceToolInvocation) -> VoiceTurnResponse? {
        guard currentContext != nil else {
            return nil
        }

        logDebug(
            "Submit tool invocation",
            category: .voice,
            metadata: Self.metadata(for: invocation)
        )
        lastEventResponse = nil
        eventSource.submitToolInvocation(invocation)
        let response = lastEventResponse
        if let response {
            eventSource.playAssistantReply(response.spokenReply)
        }
        return response
    }

    /// Outcome of a "mark ball position" attempt — surfaced to UI so the
    /// Caddie tab can show a brief reason when capture isn't possible
    /// (no fix, poor accuracy, no hole started).
    enum MarkBallPositionResult: Equatable {
        case captured(remainingDistanceM: Double, lie: ShotLie)
        case noFix
        case poorAccuracy(horizontalAccuracyM: Double)
        case noActiveHole
        case sessionInactive
    }

    /// UI tap entry point (and the resolution target for the model-side
    /// `mark_ball_position` tool intercept). Reads the latest fix from the
    /// injected ``LiveCourseLocationModel``, gates on capture-accuracy,
    /// derives lie + remaining-distance, and submits a fully-populated voice
    /// tool invocation so the existing dispatch / persistence path handles
    /// the round-state mutation.
    @discardableResult
    func markBallPosition() -> MarkBallPositionResult {
        guard let context = currentContext else {
            logDebug("Mark ball position failed", category: .capture, metadata: ["reason": "session_inactive"])
            return .sessionInactive
        }
        guard let model = locationModel, let fix = model.lastFix else {
            logDebug("Mark ball position failed", category: .capture, metadata: ["reason": "no_fix"])
            return .noFix
        }

        guard fix.horizontalAccuracyM <= GolfGeometry.Constants.minimumAcceptableAccuracyM else {
            logDebug(
                "Mark ball position blocked by accuracy gate",
                category: .capture,
                metadata: [
                    "accuracyM": Self.metric(fix.horizontalAccuracyM),
                    "maxAccuracyM": Self.metric(GolfGeometry.Constants.minimumAcceptableAccuracyM)
                ]
            )
            return .poorAccuracy(horizontalAccuracyM: fix.horizontalAccuracyM)
        }

        guard
            let hole = context.bundle.holes.first(where: { $0.holeNumber == context.selectedHoleNumber }),
            let green = GeoCoordinate2D(lonLatPair: hole.baseMappingData.green.center)
        else {
            logDebug(
                "Mark ball position failed",
                category: .capture,
                metadata: ["reason": "no_active_hole"]
            )
            return .noActiveHole
        }

        let remainingDistanceM = GolfGeometry.haversineDistance(fix.coordinate, green)
        let lie = LieInference.lie(at: fix.coordinate, in: hole)
        logDebug(
            "Captured ball position",
            category: .capture,
            metadata: [
                "hole": String(context.selectedHoleNumber),
                "accuracyM": Self.metric(fix.horizontalAccuracyM),
                "distanceM": Self.metric(remainingDistanceM),
                "lie": lie.rawValue
            ]
        )

        _ = submitVoiceToolInvocation(
            VoiceToolInvocation(
                actionName: .markBallPosition,
                arguments: VoiceToolInvocationArguments(
                    lie: lie,
                    remainingDistanceM: remainingDistanceM
                )
            )
        )

        return .captured(remainingDistanceM: remainingDistanceM, lie: lie)
    }

    func simulateToolCallback(_ callback: RealtimeVoiceToolCallbackEvent) {
        guard currentContext != nil else {
            return
        }

        eventSource.emitToolCallback(callback)
    }

    func simulatePlaybackState(_ state: RealtimeVoicePlaybackState) {
        guard currentContext != nil else {
            return
        }

        eventSource.setPlaybackState(state)
    }

    func simulateTransportFailure(_ message: String) {
        guard currentContext != nil else {
            return
        }

        eventSource.failTransport(message)
    }

    private func receiveRealtimeEvent(_ event: RealtimeVoiceTransportEvent) {
        if case let .outputAudioChunk(data) = event {
            playbackEngine.enqueue(data)
        }

        // Intercept the model's mark_ball_position tool call before it
        // reaches the session manager. The model has no access to device GPS
        // so it sends the call with no arguments — we backfill lie +
        // remaining-distance from the device fix and dispatch through the
        // standard markBallPosition() path so UI and voice see the same
        // result whether the user tapped or spoke.
        if case let .toolInvocation(invocation) = event,
           invocation.actionName == .markBallPosition,
           invocation.arguments.lie == nil || invocation.arguments.remainingDistanceM == nil {
            logDebug(
                "Intercept model mark_ball_position request",
                category: .capture,
                metadata: Self.metadata(for: invocation)
            )
            _ = markBallPosition()
            return
        }

        guard let currentContext else {
            return
        }

        logDebug(
            "Received realtime event",
            category: .transport,
            metadata: ["event": Self.eventName(for: event)]
        )
        lastEventResponse = sessionManager.handleTransportEvent(
            event,
            context: currentContext
        )
        refreshState()
    }

    private func refreshState() {
        state = sessionManager.state
    }

    private func logDebug(
        _ message: String,
        category: AppDebugLogCategory,
        metadata: [String: String] = [:]
    ) {
        Task { @MainActor in
            AppDebugLogStore.shared.record(message, category: category, metadata: metadata)
        }
    }

    private static func eventName(for event: RealtimeVoiceTransportEvent) -> String {
        switch event {
        case .listeningStarted:
            return "listening_started"
        case .listeningStopped:
            return "listening_stopped"
        case .transcript:
            return "transcript"
        case .toolInvocation:
            return "tool_invocation"
        case .toolCallback:
            return "tool_callback"
        case .outputAudioChunk:
            return "output_audio_chunk"
        case .playbackStateChanged:
            return "playback_state_changed"
        case .interrupted:
            return "interrupted"
        case .transportFailed:
            return "transport_failed"
        }
    }

    private static func metadata(for invocation: VoiceToolInvocation) -> [String: String] {
        var metadata: [String: String] = ["action": invocation.actionName.rawValue]
        if let lie = invocation.arguments.lie {
            metadata["lie"] = lie.rawValue
        }
        if let remainingDistanceM = invocation.arguments.remainingDistanceM {
            metadata["distanceM"] = metric(remainingDistanceM)
        }
        if let strokesTaken = invocation.arguments.strokesTaken {
            metadata["strokes"] = String(strokesTaken)
        }
        if let holeNumber = invocation.arguments.holeNumber {
            metadata["hole"] = String(holeNumber)
        }
        return metadata
    }

    private static func metric(_ number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}

extension HostVoiceSessionController {
    /// Build a controller wired to the bundled pilot credential, if any.
    /// Falls back to the default (stub-backed) controller when
    /// `PilotSecrets.realtimeAPIKey` is `nil` so unauthenticated builds
    /// still run.
    static func makeWithPilotCredentials() -> HostVoiceSessionController {
        guard let credentialProvider = EmbeddedPilotCredentialProvider.fromBundledSecrets() else {
            return HostVoiceSessionController()
        }

        let (microphoneSource, playbackEngine) = NativeRealtimeVoiceRuntimeFactory.microphoneSourceAndPlaybackEngine()
        return HostVoiceSessionController(
            sessionManager: RealtimeVoiceSessionManager(credentialProvider: credentialProvider),
            eventSource: NativeRealtimeVoiceRuntimeFactory.eventSource(credentialProvider: credentialProvider),
            microphoneSource: microphoneSource,
            playbackEngine: playbackEngine
        )
    }
}
