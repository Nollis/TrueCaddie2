import Combine
import Foundation
import TrueCaddieDomain

enum RealtimeVoiceSessionManagerError: Error, Equatable {
    case notConnected
}

enum VoiceToolDispatch {
    static func catalog() -> VoiceToolCatalog {
        VoiceToolCatalog(
            tools: HostCaddieSession.supportedVoiceTools.map { tool in
                VoiceToolDefinition(
                    actionName: tool.name,
                    description: tool.description,
                    parameters: tool.fields.map(parameterDefinition(from:)),
                    sampleUtterances: tool.sampleUtterances
                )
            }
        )
    }

    static func sessionEnvelope(from request: VoiceTurnRequest) -> HostCaddieSession.SessionRequestEnvelope? {
        switch request.input {
        case let .utterance(utterance):
            let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return HostCaddieSession.SessionRequestEnvelope(source: .utterance(trimmed), context: request.context)

        case let .toolInvocation(invocation):
            guard let toolCall = HostCaddieSession.toolCall(
                named: invocation.actionName,
                lie: invocation.arguments.lie,
                remainingDistanceM: invocation.arguments.remainingDistanceM,
                strokesTaken: invocation.arguments.strokesTaken,
                holeNumber: invocation.arguments.holeNumber
            ) else {
                return nil
            }

            return HostCaddieSession.SessionRequestEnvelope(source: .toolCall(toolCall), context: request.context)
        }
    }

    static func respond(to request: VoiceTurnRequest) -> VoiceTurnResponse? {
        guard let envelope = sessionEnvelope(from: request),
              let response = HostCaddieSession.respond(to: envelope) else {
            return nil
        }

        return VoiceTurnResponse(
            turnID: request.turnID,
            actionName: response.actionName,
            spokenReply: response.assistantReply,
            sessionSnapshot: response.state,
            strategyPreference: response.strategyPreference
        )
    }

    nonisolated private static func parameterDefinition(
        from field: HostCaddieSession.VoiceToolFieldDefinition
    ) -> VoiceToolParameterDefinition {
        VoiceToolParameterDefinition(
            name: field.name,
            type: parameterType(for: field.type),
            required: field.required,
            description: field.description,
            allowedValues: allowedValues(for: field.type)
        )
    }

    nonisolated private static func parameterType(for rawType: String) -> VoiceToolParameterType {
        switch rawType {
        case "ShotLie":
            return .shotLie
        case "Int":
            return .integer
        default:
            return .decimal
        }
    }

    nonisolated private static func allowedValues(for rawType: String) -> [String] {
        guard rawType == "ShotLie" else { return [] }
        return [
            ShotLie.tee.rawValue,
            ShotLie.fairway.rawValue,
            ShotLie.rough.rawValue,
            ShotLie.bunker.rawValue,
            ShotLie.recovery.rawValue
        ]
    }
}

final class RealtimeVoiceSessionManager: ObservableObject {
    private let credentialProvider: any RealtimeVoiceCredentialProviding
    private let bootstrapper: any RealtimeVoiceSessionBootstrapping
    private let audioCoordinator: any RealtimeVoiceAudioSessionCoordinating
    private let transport: any RealtimeVoiceTransporting

    @Published private(set) var state = VoiceSessionState()

    init(
        credentialProvider: any RealtimeVoiceCredentialProviding,
        bootstrapper: any RealtimeVoiceSessionBootstrapping = DirectAppRealtimeSessionBootstrapper(),
        audioCoordinator: any RealtimeVoiceAudioSessionCoordinating = NativeRealtimeVoiceRuntimeFactory.audioCoordinator(),
        transport: any RealtimeVoiceTransporting = NativeRealtimeVoiceRuntimeFactory.transport()
    ) {
        self.credentialProvider = credentialProvider
        self.bootstrapper = bootstrapper
        self.audioCoordinator = audioCoordinator
        self.transport = transport
    }

    func toolCatalog() -> VoiceToolCatalog {
        VoiceToolDispatch.catalog()
    }

    func syncSnapshot(from context: HostCaddieSession.TurnContext) {
        state.latestSnapshot = HostCaddieSession.snapshot(from: context)
    }

    func connect() throws {
        state.connectionState = .connecting

        do {
            let credential = try credentialProvider.currentCredential()
            try audioCoordinator.prepareForVoiceSession()
            let descriptor = try bootstrapper.bootstrapSession(using: credential)
            try transport.connect(to: descriptor)
            state.activeSession = transport.currentSession
            state.connectionState = .connected(descriptor)
            state.playbackState = .idle
        } catch {
            state.activeSession = nil
            state.connectionState = .failed(String(describing: error))
            throw error
        }
    }

    func disconnect() {
        audioCoordinator.stopListening()
        transport.stopListening()
        transport.disconnect()
        audioCoordinator.endVoiceSession()
        state.activeSession = nil
        state.connectionState = .disconnected
        state.turnState = .idle
        state.playbackState = .idle
        state.partialUserTranscript = nil
        state.partialAssistantTranscript = nil
    }

    func beginListening() throws {
        guard case .connected = state.connectionState else {
            throw RealtimeVoiceSessionManagerError.notConnected
        }

        try audioCoordinator.beginListening()
        try transport.beginListening()
        state.turnState = .listening
        state.partialUserTranscript = nil
    }

    func stopListening() {
        audioCoordinator.stopListening()
        transport.stopListening()

        if case .listening = state.turnState {
            state.turnState = .idle
        }
    }

    func handleTurn(_ request: VoiceTurnRequest) -> VoiceTurnResponse? {
        state.turnState = .resolving(request.turnID)

        guard let response = VoiceToolDispatch.respond(to: request) else {
            state.turnState = .idle
            return nil
        }

        state.latestSnapshot = response.sessionSnapshot
        state.lastResponse = response
        state.turnState = .speaking(request.turnID)
        return response
    }

    func submitTypedUtterance(
        _ utterance: String,
        context: HostCaddieSession.TurnContext
    ) -> VoiceTurnResponse? {
        submitInput(
            .utterance(utterance),
            userVisibleText: utterance,
            context: context,
            autoFinishSpeaking: true
        )
    }

    func handleTransportEvent(
        _ event: RealtimeVoiceTransportEvent,
        context: HostCaddieSession.TurnContext
    ) -> VoiceTurnResponse? {
        switch event {
        case .listeningStarted:
            state.turnState = .listening
            return nil

        case .listeningStopped:
            if case .listening = state.turnState {
                state.turnState = .idle
            }
            return nil

        case let .transcript(transcript):
            return handleTranscriptEvent(transcript, context: context)

        case let .toolInvocation(invocation):
            state.lastToolCallback = .init(invocation: invocation, phase: .requested)
            return submitInput(
                .toolInvocation(invocation),
                userVisibleText: Self.transcriptText(for: invocation),
                context: context,
                autoFinishSpeaking: false
            )

        case let .toolCallback(callback):
            state.lastToolCallback = callback
            return nil

        case let .playbackStateChanged(playbackState):
            state.playbackState = playbackState
            if playbackState == .finished {
                finishSpeaking()
            }
            return nil

        case .outputAudioChunk:
            // The controller layer routes the bytes to the playback engine;
            // here we only nudge the visible state into "speaking" on first
            // chunk so the UI reflects that the assistant is talking.
            if state.playbackState == .idle {
                state.playbackState = .speaking
            }
            return nil

        case .interrupted:
            interruptCurrentTurn()
            return nil

        case let .transportFailed(message):
            state.activeSession = nil
            state.connectionState = .failed(message)
            state.turnState = .idle
            state.playbackState = .idle
            return nil
        }
    }

    func interruptCurrentTurn() {
        switch state.turnState {
        case let .resolving(turnID), let .speaking(turnID):
            state.lastInterruptedTurnID = turnID
            state.turnState = .idle
        case .listening:
            state.turnState = .idle
        case .idle:
            break
        }

        state.playbackState = .idle
        state.partialAssistantTranscript = nil
    }

    func finishSpeaking() {
        if case .speaking = state.turnState {
            state.turnState = .idle
        }
        state.playbackState = .idle
        state.partialAssistantTranscript = nil
    }

    private func submitInput(
        _ input: VoiceTurnInput,
        userVisibleText: String,
        context: HostCaddieSession.TurnContext,
        autoFinishSpeaking: Bool
    ) -> VoiceTurnResponse? {
        let trimmed = userVisibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        syncSnapshot(from: context)
        state.partialUserTranscript = nil
        state.transcriptEntries.append(.user(trimmed))

        if case .disconnected = state.connectionState {
            try? connect()
        }

        guard let response = handleTurn(
            VoiceTurnRequest(input: input, context: context)
        ) else {
            state.transcriptEntries.append(
                .assistant("I couldn't ground that yet. Try asking for guidance or say something like rough 128.")
            )
            return nil
        }

        state.transcriptEntries.append(.assistant(response.spokenReply))
        state.playbackState = .speaking
        if autoFinishSpeaking {
            finishSpeaking()
        }
        return response
    }

    private func handleTranscriptEvent(
        _ transcript: RealtimeVoiceTranscriptEvent,
        context: HostCaddieSession.TurnContext
    ) -> VoiceTurnResponse? {
        switch (transcript.speaker, transcript.kind) {
        case (.user, .partial):
            state.partialUserTranscript = transcript.text
            return nil

        case (.user, .final):
            return submitInput(
                .utterance(transcript.text),
                userVisibleText: transcript.text,
                context: context,
                autoFinishSpeaking: false
            )

        case (.assistant, .partial):
            state.partialAssistantTranscript = transcript.text
            state.playbackState = .speaking
            return nil

        case (.assistant, .final):
            state.partialAssistantTranscript = nil
            state.playbackState = .speaking
            return nil
        }
    }

    nonisolated private static func transcriptText(for invocation: VoiceToolInvocation) -> String {
        switch invocation.actionName {
        case .guidance:
            return "what do you like here"
        case .saferPlay:
            return "safe play"
        case .aggressivePlay:
            return "aggressive"
        case .balancedPlay:
            return "back to balanced"
        case .repeatGuidance:
            return "repeat"
        case .reportResult:
            let lie = invocation.arguments.lie?.rawValue ?? "result"
            let distance = invocation.arguments.remainingDistanceM.map(format(number:)) ?? ""
            return distance.isEmpty ? lie : "\(lie) \(distance)"
        case .markBallPosition:
            let lie = invocation.arguments.lie?.rawValue ?? "ball"
            let distance = invocation.arguments.remainingDistanceM.map(format(number:)) ?? ""
            return distance.isEmpty ? "I'm at my ball" : "I'm at my ball (\(lie) \(distance)m)"
        case .holeOut:
            return "holed out"
        case .correctScore:
            let strokes = invocation.arguments.strokesTaken ?? 0
            if let holeNumber = invocation.arguments.holeNumber {
                return "hole \(holeNumber) was \(strokes)"
            }
            return "make that \(strokes)"
        }
    }

    nonisolated private static func format(number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}
