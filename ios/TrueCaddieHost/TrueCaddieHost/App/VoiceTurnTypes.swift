import Foundation
import TrueCaddieDomain

// In-memory voice-session value types: tool definitions and invocations,
// turn requests/responses, transport events, and the session state shape that
// `HostVoiceSessionController` publishes. Pure value types — no I/O,
// transport, or platform dependencies live here.

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

    var id: String { name }
}

struct VoiceToolDefinition: Equatable, Identifiable {
    let actionName: HostCaddieSession.ActionName
    let description: String
    let parameters: [VoiceToolParameterDefinition]
    let sampleUtterances: [String]

    var id: String { actionName.rawValue }
    var name: String { actionName.rawValue }
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

enum RealtimeVoiceTranscriptSpeaker: Equatable {
    case user
    case assistant
}

enum RealtimeVoiceTranscriptKind: Equatable {
    case partial
    case final
}

struct RealtimeVoiceTranscriptEvent: Equatable {
    let speaker: RealtimeVoiceTranscriptSpeaker
    let kind: RealtimeVoiceTranscriptKind
    let text: String
}

enum RealtimeVoicePlaybackState: Equatable {
    case idle
    case speaking
    case finished
}

enum RealtimeVoiceToolCallbackPhase: Equatable {
    case requested
    case completed
}

struct RealtimeVoiceToolCallbackEvent: Equatable {
    let invocation: VoiceToolInvocation
    let phase: RealtimeVoiceToolCallbackPhase
}

enum RealtimeVoiceTransportEvent: Equatable {
    case listeningStarted
    case listeningStopped
    case transcript(RealtimeVoiceTranscriptEvent)
    case toolInvocation(VoiceToolInvocation)
    case toolCallback(RealtimeVoiceToolCallbackEvent)
    case outputAudioChunk(Data)
    case playbackStateChanged(RealtimeVoicePlaybackState)
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
    var activeSession: RealtimeVoiceClientSession?
    var playbackState: RealtimeVoicePlaybackState = .idle
    var partialUserTranscript: String?
    var partialAssistantTranscript: String?
    var lastToolCallback: RealtimeVoiceToolCallbackEvent?
    var latestSnapshot: HostCaddieSession.SessionStateSnapshot?
    var lastResponse: VoiceTurnResponse?
    var lastInterruptedTurnID: UUID?
    var transcriptEntries: [HostCaddieSession.TranscriptEntry] = []
}
