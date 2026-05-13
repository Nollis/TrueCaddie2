//
//  RealtimeVoiceSession.swift
//  TrueCaddieHost
//
//  Created by Codex on 5/13/26.
//

import Combine
import Foundation
import TrueCaddieDomain

enum RealtimeVoiceAuthMode: String, Equatable, Codable {
    case pilotDirectEmbedded
    case futureHardened
}

struct RealtimeVoiceCredential: Equatable {
    let apiKey: String
    let authMode: RealtimeVoiceAuthMode
}

protocol RealtimeVoiceCredentialProviding {
    func currentCredential() throws -> RealtimeVoiceCredential
}

struct EmbeddedPilotCredentialProvider: RealtimeVoiceCredentialProviding {
    let apiKey: String

    func currentCredential() throws -> RealtimeVoiceCredential {
        RealtimeVoiceCredential(
            apiKey: apiKey,
            authMode: .pilotDirectEmbedded
        )
    }
}

enum RealtimeVoiceTransport: String, Equatable, Codable {
    case rawRealtimeWebRTC
    case rawRealtimeWebSocket
}

struct RealtimeVoiceSessionDescriptor: Equatable, Codable {
    let model: String
    let transport: RealtimeVoiceTransport
    let authMode: RealtimeVoiceAuthMode
}

protocol RealtimeVoiceSessionBootstrapping {
    func bootstrapSession(using credential: RealtimeVoiceCredential) throws -> RealtimeVoiceSessionDescriptor
}

struct DirectAppRealtimeSessionBootstrapper: RealtimeVoiceSessionBootstrapping {
    let model: String
    let transport: RealtimeVoiceTransport

    init(
        model: String = "gpt-realtime-2",
        transport: RealtimeVoiceTransport = .rawRealtimeWebRTC
    ) {
        self.model = model
        self.transport = transport
    }

    func bootstrapSession(using credential: RealtimeVoiceCredential) throws -> RealtimeVoiceSessionDescriptor {
        _ = credential.apiKey

        return RealtimeVoiceSessionDescriptor(
            model: model,
            transport: transport,
            authMode: credential.authMode
        )
    }
}

protocol RealtimeVoiceAudioSessionCoordinating {
    func prepareForVoiceSession() throws
    func beginListening() throws
    func stopListening()
    func endVoiceSession()
}

struct NoopRealtimeVoiceAudioSessionCoordinator: RealtimeVoiceAudioSessionCoordinating {
    func prepareForVoiceSession() throws {}
    func beginListening() throws {}
    func stopListening() {}
    func endVoiceSession() {}
}

protocol RealtimeVoiceTransporting: AnyObject {
    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws
    func beginListening() throws
    func stopListening()
    func disconnect()
}

final class NoopRealtimeVoiceTransport: RealtimeVoiceTransporting {
    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws {}
    func beginListening() throws {}
    func stopListening() {}
    func disconnect() {}
}

final class StubRealtimeVoiceTransport: RealtimeVoiceTransporting {
    private(set) var connectedDescriptor: RealtimeVoiceSessionDescriptor?
    private(set) var isListening = false
    private(set) var disconnectCount = 0

    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws {
        connectedDescriptor = descriptor
    }

    func beginListening() throws {
        isListening = true
    }

    func stopListening() {
        isListening = false
    }

    func disconnect() {
        disconnectCount += 1
        connectedDescriptor = nil
        isListening = false
    }
}

enum VoiceToolParameterType: String, Equatable {
    case shotLie
    case decimal
    case integer
}

struct VoiceToolParameterDefinition: Equatable, Identifiable {
    let name: String
    let type: VoiceToolParameterType
    let required: Bool
    let description: String
    let allowedValues: [String]

    var id: String {
        name
    }
}

struct VoiceToolDefinition: Equatable, Identifiable {
    let actionName: HostCaddieSession.ActionName
    let description: String
    let parameters: [VoiceToolParameterDefinition]
    let sampleUtterances: [String]

    var id: String {
        actionName.rawValue
    }

    var name: String {
        actionName.rawValue
    }
}

struct VoiceToolCatalog: Equatable {
    let tools: [VoiceToolDefinition]

    func tool(named name: String) -> VoiceToolDefinition? {
        tools.first(where: { $0.name == name })
    }
}

struct VoiceToolInvocationArguments: Equatable {
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

struct VoiceToolInvocation: Equatable {
    let actionName: HostCaddieSession.ActionName
    let arguments: VoiceToolInvocationArguments
}

enum VoiceTurnInput: Equatable {
    case utterance(String)
    case toolInvocation(VoiceToolInvocation)
}

struct VoiceTurnRequest {
    let turnID: UUID
    let input: VoiceTurnInput
    let context: HostCaddieSession.TurnContext

    init(
        turnID: UUID = UUID(),
        input: VoiceTurnInput,
        context: HostCaddieSession.TurnContext
    ) {
        self.turnID = turnID
        self.input = input
        self.context = context
    }
}

struct VoiceTurnResponse: Equatable {
    let turnID: UUID
    let actionName: HostCaddieSession.ActionName
    let spokenReply: String
    let sessionSnapshot: HostCaddieSession.SessionStateSnapshot
    let strategyPreference: StrategyPreference?
}

enum RealtimeVoiceTransportEvent: Equatable {
    case listeningStarted
    case listeningStopped
    case finalUserUtterance(String)
    case toolInvocation(VoiceToolInvocation)
    case assistantPlaybackFinished
    case interrupted
    case transportFailed(String)
}

enum VoiceSessionConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(RealtimeVoiceSessionDescriptor)
    case failed(String)
}

enum VoiceSessionTurnState: Equatable {
    case idle
    case listening
    case resolving(UUID)
    case speaking(UUID)
}

struct VoiceSessionState: Equatable {
    var connectionState: VoiceSessionConnectionState = .disconnected
    var turnState: VoiceSessionTurnState = .idle
    var latestSnapshot: HostCaddieSession.SessionStateSnapshot?
    var lastResponse: VoiceTurnResponse?
    var lastInterruptedTurnID: UUID?
    var transcriptEntries: [HostCaddieSession.TranscriptEntry] = []
}

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

    static func sessionEnvelope(
        from request: VoiceTurnRequest
    ) -> HostCaddieSession.SessionRequestEnvelope? {
        switch request.input {
        case let .utterance(utterance):
            let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            return HostCaddieSession.SessionRequestEnvelope(
                source: .utterance(trimmed),
                context: request.context
            )

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

            return HostCaddieSession.SessionRequestEnvelope(
                source: .toolCall(toolCall),
                context: request.context
            )
        }
    }

    static func respond(
        to request: VoiceTurnRequest
    ) -> VoiceTurnResponse? {
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

    private static func parameterDefinition(
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

    private static func parameterType(for rawType: String) -> VoiceToolParameterType {
        switch rawType {
        case "ShotLie":
            return .shotLie
        case "Int":
            return .integer
        default:
            return .decimal
        }
    }

    private static func allowedValues(for rawType: String) -> [String] {
        guard rawType == "ShotLie" else {
            return []
        }

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
        audioCoordinator: any RealtimeVoiceAudioSessionCoordinating = NoopRealtimeVoiceAudioSessionCoordinator(),
        transport: any RealtimeVoiceTransporting = NoopRealtimeVoiceTransport()
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
            state.connectionState = .connected(descriptor)
        } catch {
            state.connectionState = .failed(String(describing: error))
            throw error
        }
    }

    func disconnect() {
        audioCoordinator.stopListening()
        transport.stopListening()
        transport.disconnect()
        audioCoordinator.endVoiceSession()
        state.connectionState = .disconnected
        state.turnState = .idle
    }

    func beginListening() throws {
        guard case .connected = state.connectionState else {
            throw RealtimeVoiceSessionManagerError.notConnected
        }

        try audioCoordinator.beginListening()
        try transport.beginListening()
        state.turnState = .listening
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

        case let .finalUserUtterance(utterance):
            return submitInput(
                .utterance(utterance),
                userVisibleText: utterance,
                context: context,
                autoFinishSpeaking: false
            )

        case let .toolInvocation(invocation):
            return submitInput(
                .toolInvocation(invocation),
                userVisibleText: Self.transcriptText(for: invocation),
                context: context,
                autoFinishSpeaking: false
            )

        case .assistantPlaybackFinished:
            finishSpeaking()
            return nil

        case .interrupted:
            interruptCurrentTurn()
            return nil

        case let .transportFailed(message):
            state.connectionState = .failed(message)
            state.turnState = .idle
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
    }

    func finishSpeaking() {
        if case .speaking = state.turnState {
            state.turnState = .idle
        }
    }

    private func submitInput(
        _ input: VoiceTurnInput,
        userVisibleText: String,
        context: HostCaddieSession.TurnContext,
        autoFinishSpeaking: Bool
    ) -> VoiceTurnResponse? {
        let trimmed = userVisibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        syncSnapshot(from: context)
        state.transcriptEntries.append(.user(trimmed))

        if case .disconnected = state.connectionState {
            try? connect()
        }

        guard let response = handleTurn(
            VoiceTurnRequest(
                input: input,
                context: context
            )
        ) else {
            state.transcriptEntries.append(
                .assistant("I couldn't ground that yet. Try asking for guidance or say something like rough 128.")
            )
            return nil
        }

        state.transcriptEntries.append(.assistant(response.spokenReply))
        if autoFinishSpeaking {
            finishSpeaking()
        }
        return response
    }

    private static func transcriptText(for invocation: VoiceToolInvocation) -> String {
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

    private static func format(number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}
