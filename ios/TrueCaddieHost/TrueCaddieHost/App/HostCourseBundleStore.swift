import Combine
import Foundation
import TrueCaddieDomain
#if canImport(AVFoundation)
import AVFoundation
#endif

enum HostCourseBundleStore {
    static func loadKungsbackaNya(bundle: Bundle = .main) throws -> CourseBundle {
        guard let url = bundle.url(forResource: "kungsbacka-nya.v1", withExtension: "json") else {
            throw HostCourseBundleStoreError.missingBundledCourse("kungsbacka-nya.v1.json")
        }

        let data = try Data(contentsOf: url)
        return try CourseBundleLoader().load(data: data)
    }
}

enum HostCourseBundleStoreError: Error, Equatable {
    case missingBundledCourse(String)
}

enum HostCaddieSession {
    struct VoiceToolFieldDefinition: Equatable, Identifiable {
        let name: String
        let type: String
        let required: Bool
        let description: String

        var id: String { name }
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

        var id: String { name.rawValue }
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

        var id: String { name }
    }

    struct WireToolCatalogEntry: Codable, Equatable, Identifiable {
        let name: String
        let description: String
        let parameters: [WireToolParameterDefinition]
        let sampleUtterances: [String]

        var id: String { name }
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

        var id: String { name }
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
                        required: tool.parameters.filter(\.required).map(\.name),
                        additionalProperties: false
                    ),
                    strict: true
                )
            }
        }

        static func wireToolCall(from toolCall: RealtimeToolCall) -> WireToolCall {
            switch toolCall.payload {
            case .none:
                return WireToolCall(name: toolCall.name.rawValue, arguments: WireToolArguments())
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
            guard let name = ActionName(rawValue: wireToolCall.name) else { return nil }

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
                return SessionRequestEnvelope(source: .utterance(utterance), context: context)
            }

            guard let wireToolCall = wireRequest.toolCall,
                  let toolCall = toolCall(from: wireToolCall) else {
                return nil
            }

            return SessionRequestEnvelope(source: .toolCall(toolCall), context: context)
        }

        static func wireRequest(from openAIToolCall: OpenAIFunctionToolCall) -> WireSessionRequest? {
            guard toolCatalog().contains(where: { $0.name == openAIToolCall.name }) else { return nil }

            return WireSessionRequest(
                utterance: nil,
                toolCall: WireToolCall(
                    name: openAIToolCall.name,
                    arguments: openAIToolCall.arguments
                )
            )
        }

        static func wireRequest(toolName: String, argumentsJSON: String) -> WireSessionRequest? {
            guard let data = argumentsJSON.data(using: .utf8),
                  let arguments = try? JSONDecoder().decode(WireToolArguments.self, from: data) else {
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

        static func respond(to wireRequest: WireSessionRequest, context: TurnContext) -> WireSessionResponse? {
            guard let envelope = requestEnvelope(from: wireRequest, context: context),
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
                    toolCall: WireToolCall(name: toolName, arguments: arguments)
                ),
                context: context
            )
        }

        private static func allowedValues(for field: VoiceToolFieldDefinition) -> [String]? {
            guard field.type == "ShotLie" else { return nil }
            return [
                ShotLie.tee.rawValue,
                ShotLie.fairway.rawValue,
                ShotLie.rough.rawValue,
                ShotLie.bunker.rawValue,
                ShotLie.recovery.rawValue
            ]
        }

        nonisolated private static func jsonSchemaType(for parameterType: String) -> String {
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
            guard let lie, let remainingDistanceM else { return nil }
            return RealtimeToolCall(
                name: name,
                payload: .reportResult(
                    ReportResultPayload(lie: lie, remainingDistanceM: remainingDistanceM)
                )
            )

        case .correctScore:
            guard let strokesTaken else { return nil }
            return RealtimeToolCall(
                name: name,
                payload: .correctScore(
                    CorrectScorePayload(strokesTaken: strokesTaken, holeNumber: holeNumber)
                )
            )
        }
    }

    static func action(for toolCall: RealtimeToolCall) -> Action? {
        switch (toolCall.name, toolCall.payload) {
        case (.guidance, .none): .guidance
        case (.saferPlay, .none): .saferPlay
        case (.aggressivePlay, .none): .aggressivePlay
        case (.balancedPlay, .none): .balancedPlay
        case (.repeatGuidance, .none): .repeatGuidance
        case let (.reportResult, .reportResult(payload)):
            .reportShotResult(lie: payload.lie, remainingDistanceM: payload.remainingDistanceM)
        case (.holeOut, .none): .holeOut
        case let (.correctScore, .correctScore(payload)):
            .correctScore(strokesTaken: payload.strokesTaken, holeNumber: payload.holeNumber)
        default: nil
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

    static func respond(to toolCall: RealtimeToolCall, in context: TurnContext) -> TurnOutcome? {
        guard let action = action(for: toolCall) else { return nil }
        return perform(action, in: context)
    }

    static func respond(to request: TurnRequest) -> TurnOutcome? {
        guard let action = interpret(request.utterance) else { return nil }
        return perform(action, in: request.context)
    }

    static func respond(to envelope: SessionRequestEnvelope) -> SessionResponseEnvelope? {
        let turnOutcome: TurnOutcome?

        switch envelope.source {
        case let .utterance(utterance):
            turnOutcome = respond(
                to: TurnRequest(utterance: utterance, context: envelope.context)
            )
        case let .toolCall(toolCall):
            turnOutcome = respond(to: toolCall, in: envelope.context)
        }

        guard let turnOutcome else { return nil }

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
            guard let preview = preview(for: context) else { return nil }
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
            guard let preview = preview(for: context, roundContext: saferRoundContext) else { return nil }
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
            guard let preview = preview(for: context, roundContext: aggressiveRoundContext) else { return nil }
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
            guard let preview = preview(for: context, roundContext: balancedRoundContext) else { return nil }
            return TurnOutcome(
                actionName: action.name,
                assistantReply: "Let's get back to the stock plan. \(preview.voicePreview)",
                roundState: context.roundState,
                selectedHoleNumber: context.selectedHoleNumber,
                strategyPreference: .balanced
            )

        case .repeatGuidance:
            guard let preview = preview(for: context) else { return nil }
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
            guard let preview = preview(for: context, roundState: updatedRoundState) else { return nil }
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
                ?? context.roundState.holeState(for: context.selectedHoleNumber)?.strokesTaken
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

        if normalizedInput.contains("repeat") { return .repeatGuidance }
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
        if input.contains("fairway") { return .fairway }
        if input.contains("rough") { return .rough }
        if input.contains("bunker") || input.contains("sand") { return .bunker }
        if input.contains("recovery") || input.contains("trees") { return .recovery }
        if input.contains("tee") { return .tee }
        return nil
    }

    private static func firstNumber(in input: String) -> Double? {
        let tokens = input.split { character in
            !character.isNumber && character != "."
        }

        for token in tokens {
            if let value = Double(token) { return value }
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

        guard looksLikeScoreCorrection else { return nil }

        let numbers = integerNumbers(in: input)
        guard let strokesTaken = numbers.last else { return nil }

        let holeNumber: Int?
        if input.contains("hole"), numbers.count >= 2 {
            holeNumber = numbers.first
        } else {
            holeNumber = nil
        }

        return .correctScore(strokesTaken: strokesTaken, holeNumber: holeNumber)
    }

    private static func integerNumbers(in input: String) -> [Int] {
        input.split { character in !character.isNumber }
            .compactMap { token in Int(token) }
    }

    private static func format(number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}

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
        RealtimeVoiceCredential(apiKey: apiKey, authMode: .pilotDirectEmbedded)
    }
}

enum RealtimeVoiceTransport: String, Equatable, Codable {
    case rawRealtimeWebRTC
    case rawRealtimeWebSocket
}

enum RealtimeVoiceSessionBootstrapSource: String, Equatable, Codable {
    case directAppStub
    case testStub
}

struct RealtimeVoiceSessionDescriptor: Equatable, Codable {
    let model: String
    let transport: RealtimeVoiceTransport
    let authMode: RealtimeVoiceAuthMode
}

struct RealtimeVoiceClientSession: Equatable, Codable, Identifiable {
    let id: String
    let descriptor: RealtimeVoiceSessionDescriptor
    let bootstrapSource: RealtimeVoiceSessionBootstrapSource
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

#if canImport(AVFoundation)
final class AVFoundationRealtimeVoiceAudioSessionCoordinator: RealtimeVoiceAudioSessionCoordinating {
    private let audioSession = AVAudioSession.sharedInstance()

    func prepareForVoiceSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try audioSession.setActive(true)
    }

    func beginListening() throws {
        try audioSession.setActive(true)
    }

    func stopListening() {}

    func endVoiceSession() {
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif

struct MicrophonePCMChunk: Equatable {
    let samples: [Float]
    let format: RealtimeMicrophonePCMFormat
}

protocol MicrophonePCMSourcing: AnyObject {
    var onChunk: ((MicrophonePCMChunk) -> Void)? { get set }

    func start() throws
    func stop()
}

enum MicrophonePCMSourceError: Error, Equatable {
    case unableToStartEngine(String)
}

enum MicrophonePCMInterleaver {
    static func interleave(_ channels: [[Float]]) -> [Float] {
        guard !channels.isEmpty else { return [] }
        if channels.count == 1 { return channels[0] }
        let frameCount = channels[0].count
        var output = [Float]()
        output.reserveCapacity(frameCount * channels.count)
        for frame in 0..<frameCount {
            for channelIndex in channels.indices {
                output.append(channels[channelIndex][frame])
            }
        }
        return output
    }
}

final class StubMicrophonePCMSource: MicrophonePCMSourcing {
    var onChunk: ((MicrophonePCMChunk) -> Void)?
    var nextStartError: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isRunning = false

    func start() throws {
        startCount += 1
        if let error = nextStartError {
            nextStartError = nil
            throw error
        }
        isRunning = true
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }

    func emit(_ chunk: MicrophonePCMChunk) {
        onChunk?(chunk)
    }
}

#if canImport(AVFoundation)
final class AVAudioEngineMicrophonePCMSource: MicrophonePCMSourcing {
    var onChunk: ((MicrophonePCMChunk) -> Void)?

    private let engine: AVAudioEngine
    private let bufferSize: AVAudioFrameCount
    private(set) var isRunning = false

    init(engine: AVAudioEngine = AVAudioEngine(), bufferSize: AVAudioFrameCount = 1024) {
        self.engine = engine
        self.bufferSize = bufferSize
    }

    func start() throws {
        guard !isRunning else { return }
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer)
        }

        do {
            try engine.start()
            isRunning = true
        } catch {
            inputNode.removeTap(onBus: 0)
            throw MicrophonePCMSourceError.unableToStartEngine(String(describing: error))
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    func handle(_ buffer: AVAudioPCMBuffer) {
        guard let samples = Self.flatten(buffer), !samples.isEmpty else { return }
        let chunkFormat = RealtimeMicrophonePCMFormat(
            sampleRateHz: buffer.format.sampleRate,
            channelCount: Int(buffer.format.channelCount)
        )
        onChunk?(MicrophonePCMChunk(samples: samples, format: chunkFormat))
    }

    static func flatten(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        guard frameCount > 0, channelCount > 0 else { return [] }

        if buffer.format.isInterleaved {
            let pointer = floatChannelData[0]
            return Array(UnsafeBufferPointer(start: pointer, count: frameCount * channelCount))
        }

        if channelCount == 1 {
            let pointer = floatChannelData[0]
            return Array(UnsafeBufferPointer(start: pointer, count: frameCount))
        }

        var channels = [[Float]]()
        channels.reserveCapacity(channelCount)
        for channel in 0..<channelCount {
            let pointer = floatChannelData[channel]
            channels.append(Array(UnsafeBufferPointer(start: pointer, count: frameCount)))
        }
        return MicrophonePCMInterleaver.interleave(channels)
    }
}
#endif

enum MicrophonePCMBridge {
    static func connect(
        _ source: any MicrophonePCMSourcing,
        to client: any DirectRealtimeClienting
    ) {
        source.onChunk = { [weak client] chunk in
            client?.sendMicrophonePCMChunk(chunk.samples, format: chunk.format)
        }
    }
}

enum RealtimeVoicePermissionState: Equatable {
    case undetermined
    case granted
    case denied
}

protocol RealtimeVoicePermissionProviding: AnyObject {
    var onStateChange: ((RealtimeVoicePermissionState) -> Void)? { get set }

    func currentPermissionState() -> RealtimeVoicePermissionState
    func requestPermission()
}

final class GrantedPilotVoicePermissionProvider: RealtimeVoicePermissionProviding {
    var onStateChange: ((RealtimeVoicePermissionState) -> Void)?

    func currentPermissionState() -> RealtimeVoicePermissionState {
        .granted
    }

    func requestPermission() {
        onStateChange?(.granted)
    }
}

final class StubRealtimeVoicePermissionProvider: RealtimeVoicePermissionProviding {
    var onStateChange: ((RealtimeVoicePermissionState) -> Void)?
    var state: RealtimeVoicePermissionState
    var requestedCount = 0

    init(state: RealtimeVoicePermissionState) {
        self.state = state
    }

    func currentPermissionState() -> RealtimeVoicePermissionState {
        state
    }

    func requestPermission() {
        requestedCount += 1
        onStateChange?(state)
    }

    func setState(_ state: RealtimeVoicePermissionState, notify: Bool = true) {
        self.state = state
        if notify {
            onStateChange?(state)
        }
    }
}

#if canImport(AVFoundation)
final class AVFoundationRealtimeVoicePermissionProvider: RealtimeVoicePermissionProviding {
    var onStateChange: ((RealtimeVoicePermissionState) -> Void)?

    func currentPermissionState() -> RealtimeVoicePermissionState {
        if #available(iOS 17, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                return .undetermined
            case .denied:
                return .denied
            case .granted:
                return .granted
            @unknown default:
                return .denied
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .undetermined:
                return .undetermined
            case .denied:
                return .denied
            case .granted:
                return .granted
            @unknown default:
                return .denied
            }
        }
    }

    func requestPermission() {
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                let state: RealtimeVoicePermissionState = granted ? .granted : .denied
                DispatchQueue.main.async {
                    self?.onStateChange?(state)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                let state: RealtimeVoicePermissionState = granted ? .granted : .denied
                DispatchQueue.main.async {
                    self?.onStateChange?(state)
                }
            }
        }
    }
}
#endif

enum NativeRealtimeVoiceRuntimeFactory {
    static func permissionProvider() -> any RealtimeVoicePermissionProviding {
#if canImport(AVFoundation)
        return AVFoundationRealtimeVoicePermissionProvider()
#else
        return GrantedPilotVoicePermissionProvider()
#endif
    }

    static func audioCoordinator() -> any RealtimeVoiceAudioSessionCoordinating {
#if canImport(AVFoundation)
        return AVFoundationRealtimeVoiceAudioSessionCoordinator()
#else
        return NoopRealtimeVoiceAudioSessionCoordinator()
#endif
    }

    static func transport() -> any RealtimeVoiceTransporting {
        DirectAppRealtimeVoiceTransportAdapter()
    }

    static func eventSource() -> any RealtimeVoiceEventSourcing {
        DirectRealtimeVoiceEventSourceAdapter(
            client: OpenAIRealtimeClientShell(
                connection: OpenAIRealtimeWebSocketConnection(
                    configuration: .default
                )
            )
        )
    }

    static func microphoneSource() -> any MicrophonePCMSourcing {
#if canImport(AVFoundation)
        return AVAudioEngineMicrophonePCMSource()
#else
        return StubMicrophonePCMSource()
#endif
    }
}

protocol RealtimeVoiceClientSessionStarting {
    func startSession(for descriptor: RealtimeVoiceSessionDescriptor) throws -> RealtimeVoiceClientSession
}

final class UUIDRealtimeVoiceClientSessionStarter: RealtimeVoiceClientSessionStarting {
    func startSession(for descriptor: RealtimeVoiceSessionDescriptor) throws -> RealtimeVoiceClientSession {
        RealtimeVoiceClientSession(
            id: UUID().uuidString.lowercased(),
            descriptor: descriptor,
            bootstrapSource: .directAppStub
        )
    }
}

final class StubRealtimeVoiceClientSessionStarter: RealtimeVoiceClientSessionStarting {
    private(set) var startedDescriptors: [RealtimeVoiceSessionDescriptor] = []
    var nextSessionID = "stub-session"
    var bootstrapSource: RealtimeVoiceSessionBootstrapSource = .testStub

    func startSession(for descriptor: RealtimeVoiceSessionDescriptor) throws -> RealtimeVoiceClientSession {
        startedDescriptors.append(descriptor)
        return RealtimeVoiceClientSession(
            id: nextSessionID,
            descriptor: descriptor,
            bootstrapSource: bootstrapSource
        )
    }
}

enum RealtimeVoiceTransportError: Error, Equatable {
    case noActiveSession
}

protocol RealtimeVoiceTransporting: AnyObject {
    var currentSession: RealtimeVoiceClientSession? { get }

    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws
    func beginListening() throws
    func stopListening()
    func disconnect()
}

final class NoopRealtimeVoiceTransport: RealtimeVoiceTransporting {
    var currentSession: RealtimeVoiceClientSession?

    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws {}
    func beginListening() throws {}
    func stopListening() {}
    func disconnect() {}
}

final class DirectAppRealtimeVoiceTransportAdapter: RealtimeVoiceTransporting {
    private let sessionStarter: any RealtimeVoiceClientSessionStarting
    private(set) var currentSession: RealtimeVoiceClientSession?
    private(set) var isListening = false

    init(sessionStarter: any RealtimeVoiceClientSessionStarting = UUIDRealtimeVoiceClientSessionStarter()) {
        self.sessionStarter = sessionStarter
    }

    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws {
        currentSession = try sessionStarter.startSession(for: descriptor)
    }

    func beginListening() throws {
        guard currentSession != nil else {
            throw RealtimeVoiceTransportError.noActiveSession
        }

        isListening = true
    }

    func stopListening() {
        isListening = false
    }

    func disconnect() {
        currentSession = nil
        isListening = false
    }
}

final class StubRealtimeVoiceTransport: RealtimeVoiceTransporting {
    private(set) var connectedDescriptor: RealtimeVoiceSessionDescriptor?
    private(set) var currentSession: RealtimeVoiceClientSession?
    private(set) var isListening = false
    private(set) var disconnectCount = 0

    func connect(to descriptor: RealtimeVoiceSessionDescriptor) throws {
        connectedDescriptor = descriptor
        currentSession = RealtimeVoiceClientSession(
            id: "stub-session",
            descriptor: descriptor,
            bootstrapSource: .testStub
        )
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
        currentSession = nil
        isListening = false
    }
}

protocol RealtimeVoiceEventSourcing: AnyObject {
    var onEvent: ((RealtimeVoiceTransportEvent) -> Void)? { get set }

    func connect()
    func beginListening()
    func stopListening()
    func submitPartialUtterance(_ utterance: String)
    func submitFinalUtterance(_ utterance: String)
    func submitToolInvocation(_ invocation: VoiceToolInvocation)
    func submitMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat)
    func playAssistantReply(_ reply: String)
    func emitToolCallback(_ callback: RealtimeVoiceToolCallbackEvent)
    func setPlaybackState(_ state: RealtimeVoicePlaybackState)
    func finishAssistantPlayback()
    func interrupt()
    func failTransport(_ message: String)
}

enum DirectRealtimeClientPlaybackState: Equatable {
    case speaking
    case finished
}

enum DirectRealtimeClientToolPhase: Equatable {
    case requested
    case completed
}

struct DirectRealtimeClientToolEvent: Equatable {
    let invocation: VoiceToolInvocation
    let phase: DirectRealtimeClientToolPhase
}

enum DirectRealtimeClientEvent: Equatable {
    case inputAudioStarted
    case inputAudioStopped
    case inputTranscriptPartial(String)
    case inputTranscriptFinal(String)
    case outputTranscriptPartial(String)
    case outputTranscriptFinal(String)
    case toolEvent(DirectRealtimeClientToolEvent)
    case playbackStateChanged(DirectRealtimeClientPlaybackState)
    case interrupted
    case failed(String)
}

protocol DirectRealtimeClienting: AnyObject {
    var onEvent: ((DirectRealtimeClientEvent) -> Void)? { get set }

    func connect()
    func beginListening()
    func stopListening()
    func sendPartialUtterance(_ utterance: String)
    func sendFinalUtterance(_ utterance: String)
    func sendToolInvocation(_ invocation: VoiceToolInvocation)
    func sendMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat)
    func emitAssistantReply(_ reply: String)
    func interrupt()
    func disconnect()
}

enum OpenAIRealtimeServerEventType: String, Codable, Equatable {
    case inputAudioTranscriptionDelta = "conversation.item.input_audio_transcription.delta"
    case inputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed"
    case outputAudioTranscriptDelta = "response.output_audio_transcript.delta"
    case outputAudioTranscriptDone = "response.output_audio_transcript.done"
    case outputAudioDelta = "response.output_audio.delta"
    case outputAudioDone = "response.output_audio.done"
    case functionCallArgumentsDone = "response.function_call_arguments.done"
    case error
}

struct OpenAIRealtimeErrorPayload: Codable, Equatable {
    let message: String
}

struct OpenAIRealtimeServerEventEnvelope: Codable, Equatable {
    let type: String
    let delta: String?
    let transcript: String?
    let name: String?
    let arguments: String?
    let error: OpenAIRealtimeErrorPayload?
}

enum OpenAIRealtimeClientEventType: String, Codable, Equatable {
    case sessionUpdate = "session.update"
    case responseCreate = "response.create"
    case inputAudioBufferAppend = "input_audio_buffer.append"
    case inputAudioBufferCommit = "input_audio_buffer.commit"
    case responseCancel = "response.cancel"
}

struct OpenAIRealtimeAudioConfiguration: Equatable, Codable {
    let apiSampleRateHz: Int
    let apiChannelCount: Int
    let pcmBitDepth: Int
    let preferredInputSampleRateHz: Int
    let voiceProcessingEnabled: Bool

    static let `default` = OpenAIRealtimeAudioConfiguration(
        apiSampleRateHz: 24_000,
        apiChannelCount: 1,
        pcmBitDepth: 16,
        preferredInputSampleRateHz: 48_000,
        voiceProcessingEnabled: true
    )
}

struct RealtimeMicrophonePCMFormat: Equatable {
    let sampleRateHz: Double
    let channelCount: Int

    init(sampleRateHz: Double, channelCount: Int) {
        self.sampleRateHz = sampleRateHz
        self.channelCount = max(1, channelCount)
    }

    static let typicalIOSMicrophone = RealtimeMicrophonePCMFormat(
        sampleRateHz: 48_000,
        channelCount: 1
    )
}

struct RealtimeMicrophonePCMEncoder: Equatable {
    let targetSampleRateHz: Double
    let targetChannelCount: Int

    init(audio: OpenAIRealtimeAudioConfiguration = .default) {
        self.targetSampleRateHz = Double(audio.apiSampleRateHz)
        self.targetChannelCount = max(1, audio.apiChannelCount)
    }

    init(targetSampleRateHz: Double, targetChannelCount: Int) {
        self.targetSampleRateHz = targetSampleRateHz
        self.targetChannelCount = max(1, targetChannelCount)
    }

    func encode(_ samples: [Float], format: RealtimeMicrophonePCMFormat) -> Data {
        guard !samples.isEmpty else { return Data() }

        let mono = Self.downmixToMono(samples, channelCount: format.channelCount)
        let resampled = Self.linearResample(
            mono,
            sourceSampleRateHz: format.sampleRateHz,
            targetSampleRateHz: targetSampleRateHz
        )
        return Self.encodeLittleEndianInt16(resampled)
    }

    static func downmixToMono(_ samples: [Float], channelCount: Int) -> [Float] {
        guard channelCount > 1 else { return samples }
        let frameCount = samples.count / channelCount
        var mono = [Float]()
        mono.reserveCapacity(frameCount)
        let divisor = Float(channelCount)
        for frame in 0..<frameCount {
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += samples[frame * channelCount + channel]
            }
            mono.append(sum / divisor)
        }
        return mono
    }

    static func linearResample(
        _ samples: [Float],
        sourceSampleRateHz: Double,
        targetSampleRateHz: Double
    ) -> [Float] {
        guard sourceSampleRateHz > 0, targetSampleRateHz > 0, !samples.isEmpty else {
            return []
        }
        if sourceSampleRateHz == targetSampleRateHz {
            return samples
        }

        let ratio = targetSampleRateHz / sourceSampleRateHz
        let outputCount = Int((Double(samples.count) * ratio).rounded(.down))
        guard outputCount > 0 else { return [] }

        let stepSourcePerOutput = sourceSampleRateHz / targetSampleRateHz
        let lastIndex = samples.count - 1

        var output = [Float]()
        output.reserveCapacity(outputCount)
        for outIndex in 0..<outputCount {
            let sourcePos = Double(outIndex) * stepSourcePerOutput
            let i0 = min(Int(sourcePos), lastIndex)
            let i1 = min(i0 + 1, lastIndex)
            let t = Float(sourcePos - Double(i0))
            let s0 = samples[i0]
            let s1 = samples[i1]
            output.append(s0 + (s1 - s0) * t)
        }
        return output
    }

    static func encodeLittleEndianInt16(_ samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(Float(-1.0), min(Float(1.0), sample))
            let scaled = (clamped * 32_767.0).rounded()
            let int16 = Int16(scaled)
            withUnsafeBytes(of: int16.littleEndian) { buffer in
                data.append(contentsOf: buffer)
            }
        }
        return data
    }
}

struct OpenAIRealtimeSessionConfiguration: Equatable, Codable {
    let model: String
    let webSocketURL: String
    let audio: OpenAIRealtimeAudioConfiguration
    let instructions: String
    let voice: String
    let inputTranscriptionModel: String
    let turnDetection: String?

    static let `default` = OpenAIRealtimeSessionConfiguration(
        model: "gpt-realtime-2",
        webSocketURL: "wss://api.openai.com/v1/realtime",
        audio: .default,
        instructions: "You are a concise, grounded golf caddie. Use the live round state and tool outputs. Keep spoken replies short.",
        voice: "alloy",
        inputTranscriptionModel: "gpt-4o-mini-transcribe",
        turnDetection: "server_vad"
    )
}

struct OpenAIRealtimeSessionAudioFormat: Codable, Equatable {
    let type: String
}

struct OpenAIRealtimeInputAudioTranscriptionConfiguration: Codable, Equatable {
    let model: String
}

struct OpenAIRealtimeTurnDetectionConfiguration: Codable, Equatable {
    let type: String
}

struct OpenAIRealtimeSessionUpdatePayload: Codable, Equatable {
    let model: String
    let instructions: String
    let voice: String
    let inputAudioFormat: OpenAIRealtimeSessionAudioFormat
    let outputAudioFormat: OpenAIRealtimeSessionAudioFormat
    let inputAudioTranscription: OpenAIRealtimeInputAudioTranscriptionConfiguration
    let turnDetection: OpenAIRealtimeTurnDetectionConfiguration?

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case voice
        case inputAudioFormat = "input_audio_format"
        case outputAudioFormat = "output_audio_format"
        case inputAudioTranscription = "input_audio_transcription"
        case turnDetection = "turn_detection"
    }
}

struct OpenAIRealtimeSessionUpdateEventEnvelope: Codable, Equatable {
    let type: String
    let eventID: String
    let session: OpenAIRealtimeSessionUpdatePayload

    enum CodingKeys: String, CodingKey {
        case type
        case eventID = "event_id"
        case session
    }
}

struct OpenAIRealtimeResponseConfiguration: Codable, Equatable {
    let conversation: String
    let modalities: [String]
}

struct OpenAIRealtimeResponseCreateEventEnvelope: Codable, Equatable {
    let type: String
    let eventID: String
    let response: OpenAIRealtimeResponseConfiguration

    enum CodingKeys: String, CodingKey {
        case type
        case eventID = "event_id"
        case response
    }
}

struct OpenAIRealtimeClientEventEnvelope: Codable, Equatable {
    let type: String
    let eventID: String?
    let audio: String?

    enum CodingKeys: String, CodingKey {
        case type
        case eventID = "event_id"
        case audio
    }
}

protocol OpenAIRealtimeConnectioning: AnyObject {
    var onJSONMessage: ((String) -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }

    func connect()
    func disconnect()
    func sendJSON(_ json: String)
}

final class OpenAIRealtimeWebSocketConnection: OpenAIRealtimeConnectioning {
    let configuration: OpenAIRealtimeSessionConfiguration
    var onJSONMessage: ((String) -> Void)?
    var onDisconnected: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private(set) var sentJSONMessages: [String] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    init(configuration: OpenAIRealtimeSessionConfiguration = .default) {
        self.configuration = configuration
    }

    func connect() {
        connectCount += 1
    }

    func disconnect() {
        disconnectCount += 1
        onDisconnected?()
    }

    func sendJSON(_ json: String) {
        sentJSONMessages.append(json)
    }

    func receiveJSON(_ json: String) {
        onJSONMessage?(json)
    }
}

final class StubOpenAIRealtimeConnection: OpenAIRealtimeConnectioning {
    var onJSONMessage: ((String) -> Void)?
    var onDisconnected: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private(set) var sentJSONMessages: [String] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    func connect() {
        connectCount += 1
    }

    func disconnect() {
        disconnectCount += 1
        onDisconnected?()
    }

    func sendJSON(_ json: String) {
        sentJSONMessages.append(json)
    }

    func receiveJSON(_ json: String) {
        onJSONMessage?(json)
    }

    func fail(_ message: String) {
        onFailure?(message)
    }
}

final class OpenAIRealtimeClientShell: DirectRealtimeClienting {
    var onEvent: ((DirectRealtimeClientEvent) -> Void)?
    private(set) var outboundActions: [String] = []
    private let connection: any OpenAIRealtimeConnectioning
    private let configuration: OpenAIRealtimeSessionConfiguration
    private let microphoneEncoder: RealtimeMicrophonePCMEncoder

    init(
        connection: any OpenAIRealtimeConnectioning = StubOpenAIRealtimeConnection(),
        configuration: OpenAIRealtimeSessionConfiguration = .default
    ) {
        self.connection = connection
        self.configuration = configuration
        self.microphoneEncoder = RealtimeMicrophonePCMEncoder(audio: configuration.audio)
        self.connection.onJSONMessage = { [weak self] json in
            self?.receiveServerEventJSON(json)
        }
        self.connection.onDisconnected = { [weak self] in
            self?.onEvent?(.interrupted)
        }
        self.connection.onFailure = { [weak self] message in
            self?.onEvent?(.failed(message))
        }
    }

    func connect() {
        outboundActions.append("connect")
        connection.connect()
        sendSessionUpdate()
    }

    func beginListening() {
        outboundActions.append("beginListening")
        onEvent?(.inputAudioStarted)
    }

    func stopListening() {
        outboundActions.append("stopListening")
        onEvent?(.inputAudioStopped)
    }

    func sendPartialUtterance(_ utterance: String) {
        outboundActions.append("input_audio_buffer.append:\(utterance)")
        sendAudioBufferAppend(Data(utterance.utf8))
    }

    func sendFinalUtterance(_ utterance: String) {
        outboundActions.append("input_audio_buffer.commit:\(utterance)")
        _ = utterance
        sendClientEvent(
            .init(
                type: OpenAIRealtimeClientEventType.inputAudioBufferCommit.rawValue,
                eventID: UUID().uuidString.lowercased(),
                audio: nil
            )
        )
    }

    func sendToolInvocation(_ invocation: VoiceToolInvocation) {
        outboundActions.append("tool:\(invocation.actionName.rawValue)")
    }

    func emitAssistantReply(_ reply: String) {
        outboundActions.append("assistant:\(reply)")
    }

    func interrupt() {
        outboundActions.append("interrupt")
        sendClientEvent(
            .init(
                type: OpenAIRealtimeClientEventType.responseCancel.rawValue,
                eventID: UUID().uuidString.lowercased(),
                audio: nil
            )
        )
        onEvent?(.interrupted)
    }

    func disconnect() {
        outboundActions.append("disconnect")
        connection.disconnect()
    }

    func sendSessionUpdate() {
        sendSessionUpdate(configuration)
    }

    func sendSessionUpdate(_ configuration: OpenAIRealtimeSessionConfiguration) {
        let audioFormat = OpenAIRealtimeSessionAudioFormat(type: "pcm16")
        let payload = OpenAIRealtimeSessionUpdatePayload(
            model: configuration.model,
            instructions: configuration.instructions,
            voice: configuration.voice,
            inputAudioFormat: audioFormat,
            outputAudioFormat: audioFormat,
            inputAudioTranscription: .init(model: configuration.inputTranscriptionModel),
            turnDetection: configuration.turnDetection.map { .init(type: $0) }
        )

        let envelope = OpenAIRealtimeSessionUpdateEventEnvelope(
            type: OpenAIRealtimeClientEventType.sessionUpdate.rawValue,
            eventID: UUID().uuidString.lowercased(),
            session: payload
        )

        sendEnvelope(envelope)
    }

    func sendResponseCreate() {
        let envelope = OpenAIRealtimeResponseCreateEventEnvelope(
            type: OpenAIRealtimeClientEventType.responseCreate.rawValue,
            eventID: UUID().uuidString.lowercased(),
            response: .init(
                conversation: "auto",
                modalities: ["audio", "text"]
            )
        )

        sendEnvelope(envelope)
    }

    func sendAudioBufferAppend(_ audioData: Data) {
        sendClientEvent(
            .init(
                type: OpenAIRealtimeClientEventType.inputAudioBufferAppend.rawValue,
                eventID: UUID().uuidString.lowercased(),
                audio: audioData.base64EncodedString()
            )
        )
    }

    func sendMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat) {
        let encoded = microphoneEncoder.encode(samples, format: format)
        outboundActions.append("input_audio_buffer.append:mic:\(encoded.count)")
        guard !encoded.isEmpty else { return }
        sendAudioBufferAppend(encoded)
    }

    func receiveServerEventJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else {
            return
        }

        receiveServerEventData(data)
    }

    func receiveServerEventData(_ data: Data) {
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(OpenAIRealtimeServerEventEnvelope.self, from: data),
              let event = Self.map(envelope) else {
            return
        }

        onEvent?(event)
    }

    static func map(_ envelope: OpenAIRealtimeServerEventEnvelope) -> DirectRealtimeClientEvent? {
        guard let type = OpenAIRealtimeServerEventType(rawValue: envelope.type) else {
            return nil
        }

        switch type {
        case .inputAudioTranscriptionDelta:
            guard let delta = envelope.delta else { return nil }
            return .inputTranscriptPartial(delta)

        case .inputAudioTranscriptionCompleted:
            guard let transcript = envelope.transcript else { return nil }
            return .inputTranscriptFinal(transcript)

        case .outputAudioTranscriptDelta:
            guard let delta = envelope.delta else { return nil }
            return .outputTranscriptPartial(delta)

        case .outputAudioTranscriptDone:
            guard let transcript = envelope.transcript else { return nil }
            return .outputTranscriptFinal(transcript)

        case .outputAudioDelta:
            return .playbackStateChanged(.speaking)

        case .outputAudioDone:
            return .playbackStateChanged(.finished)

        case .functionCallArgumentsDone:
            guard let name = envelope.name,
                  let arguments = envelope.arguments,
                  let invocation = toolInvocation(name: name, argumentsJSON: arguments) else {
                return nil
            }

            return .toolEvent(.init(invocation: invocation, phase: .completed))

        case .error:
            guard let message = envelope.error?.message else { return nil }
            return .failed(message)
        }
    }

    private func sendClientEvent(_ envelope: OpenAIRealtimeClientEventEnvelope) {
        sendEnvelope(envelope)
    }

    private func sendEnvelope<T: Encodable>(_ envelope: T) {
        guard let data = try? JSONEncoder().encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        connection.sendJSON(json)
    }

    private static func toolInvocation(
        name: String,
        argumentsJSON: String
    ) -> VoiceToolInvocation? {
        guard let actionName = HostCaddieSession.ActionName(rawValue: name),
              let data = argumentsJSON.data(using: .utf8),
              let arguments = try? JSONDecoder().decode(HostCaddieSession.WireToolArguments.self, from: data) else {
            return nil
        }

        return VoiceToolInvocation(
            actionName: actionName,
            arguments: .init(
                lie: arguments.lie,
                remainingDistanceM: arguments.remainingDistanceM,
                strokesTaken: arguments.strokesTaken,
                holeNumber: arguments.holeNumber
            )
        )
    }
}

final class StubDirectRealtimeClient: DirectRealtimeClienting {
    var onEvent: ((DirectRealtimeClientEvent) -> Void)?
    private(set) var outboundActions: [String] = []

    func connect() {
        outboundActions.append("connect")
    }

    func beginListening() {
        outboundActions.append("beginListening")
    }

    func stopListening() {
        outboundActions.append("stopListening")
    }

    func sendPartialUtterance(_ utterance: String) {
        outboundActions.append("partial:\(utterance)")
        onEvent?(.inputTranscriptPartial(utterance))
    }

    func sendFinalUtterance(_ utterance: String) {
        outboundActions.append("final:\(utterance)")
        onEvent?(.inputTranscriptFinal(utterance))
    }

    func sendToolInvocation(_ invocation: VoiceToolInvocation) {
        outboundActions.append("tool:\(invocation.actionName.rawValue)")
        onEvent?(
            .toolEvent(
                .init(
                    invocation: invocation,
                    phase: .requested
                )
            )
        )
    }

    func sendMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat) {
        outboundActions.append("mic:\(samples.count)@\(Int(format.sampleRateHz))x\(format.channelCount)")
    }

    func emitAssistantReply(_ reply: String) {
        outboundActions.append("assistant:\(reply)")
        onEvent?(.playbackStateChanged(.speaking))

        let partial = String(reply.prefix(min(24, reply.count)))
        if !partial.isEmpty, partial != reply {
            onEvent?(.outputTranscriptPartial(partial))
        }

        onEvent?(.outputTranscriptFinal(reply))
    }

    func interrupt() {
        outboundActions.append("interrupt")
        onEvent?(.interrupted)
    }

    func disconnect() {
        outboundActions.append("disconnect")
    }

    func emit(_ event: DirectRealtimeClientEvent) {
        onEvent?(event)
    }
}

final class DirectRealtimeVoiceEventSourceAdapter: RealtimeVoiceEventSourcing {
    var onEvent: ((RealtimeVoiceTransportEvent) -> Void)?

    private let client: any DirectRealtimeClienting

    init(client: any DirectRealtimeClienting = StubDirectRealtimeClient()) {
        self.client = client
        self.client.onEvent = { [weak self] event in
            guard let mapped = Self.map(event) else {
                return
            }

            self?.onEvent?(mapped)
        }
    }

    func connect() {
        client.connect()
    }

    func beginListening() {
        client.beginListening()
        onEvent?(.listeningStarted)
    }

    func stopListening() {
        client.stopListening()
        onEvent?(.listeningStopped)
    }

    func submitPartialUtterance(_ utterance: String) {
        client.sendPartialUtterance(utterance)
    }

    func submitFinalUtterance(_ utterance: String) {
        client.sendFinalUtterance(utterance)
    }

    func submitToolInvocation(_ invocation: VoiceToolInvocation) {
        client.sendToolInvocation(invocation)
    }

    func submitMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat) {
        client.sendMicrophonePCMChunk(samples, format: format)
    }

    func playAssistantReply(_ reply: String) {
        client.emitAssistantReply(reply)
    }

    func emitToolCallback(_ callback: RealtimeVoiceToolCallbackEvent) {
        onEvent?(.toolCallback(callback))
    }

    func setPlaybackState(_ state: RealtimeVoicePlaybackState) {
        onEvent?(.playbackStateChanged(state))
    }

    func finishAssistantPlayback() {
        onEvent?(.playbackStateChanged(.finished))
    }

    func interrupt() {
        client.interrupt()
    }

    func failTransport(_ message: String) {
        onEvent?(.transportFailed(message))
    }

    nonisolated static func map(_ event: DirectRealtimeClientEvent) -> RealtimeVoiceTransportEvent? {
        switch event {
        case .inputAudioStarted:
            return .listeningStarted
        case .inputAudioStopped:
            return .listeningStopped
        case let .inputTranscriptPartial(text):
            return .transcript(.init(speaker: .user, kind: .partial, text: text))
        case let .inputTranscriptFinal(text):
            return .transcript(.init(speaker: .user, kind: .final, text: text))
        case let .outputTranscriptPartial(text):
            return .transcript(.init(speaker: .assistant, kind: .partial, text: text))
        case let .outputTranscriptFinal(text):
            return .transcript(.init(speaker: .assistant, kind: .final, text: text))
        case let .toolEvent(toolEvent):
            switch toolEvent.phase {
            case .requested:
                return .toolInvocation(toolEvent.invocation)
            case .completed:
                return .toolCallback(
                    .init(
                        invocation: toolEvent.invocation,
                        phase: .completed
                    )
                )
            }
        case let .playbackStateChanged(state):
            switch state {
            case .speaking:
                return .playbackStateChanged(.speaking)
            case .finished:
                return .playbackStateChanged(.finished)
            }
        case .interrupted:
            return .interrupted
        case let .failed(message):
            return .transportFailed(message)
        }
    }
}

final class NoopRealtimeVoiceEventSource: RealtimeVoiceEventSourcing {
    var onEvent: ((RealtimeVoiceTransportEvent) -> Void)?

    func connect() {}
    func beginListening() {}
    func stopListening() {}
    func submitPartialUtterance(_ utterance: String) {}
    func submitFinalUtterance(_ utterance: String) {}
    func submitToolInvocation(_ invocation: VoiceToolInvocation) {}
    func submitMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat) {}
    func playAssistantReply(_ reply: String) {}
    func emitToolCallback(_ callback: RealtimeVoiceToolCallbackEvent) {}
    func setPlaybackState(_ state: RealtimeVoicePlaybackState) {}
    func finishAssistantPlayback() {}
    func interrupt() {}
    func failTransport(_ message: String) {}
}

final class StubRealtimeVoiceEventSource: RealtimeVoiceEventSourcing {
    var onEvent: ((RealtimeVoiceTransportEvent) -> Void)?
    private(set) var emittedEvents: [RealtimeVoiceTransportEvent] = []
    private(set) var receivedMicrophoneChunks: [MicrophonePCMChunk] = []
    private(set) var connectCount = 0

    func connect() {
        connectCount += 1
    }

    func beginListening() {
        emit(.listeningStarted)
    }

    func stopListening() {
        emit(.listeningStopped)
    }

    func submitPartialUtterance(_ utterance: String) {
        emit(
            .transcript(
                RealtimeVoiceTranscriptEvent(
                    speaker: .user,
                    kind: .partial,
                    text: utterance
                )
            )
        )
    }

    func submitFinalUtterance(_ utterance: String) {
        emit(
            .transcript(
                RealtimeVoiceTranscriptEvent(
                    speaker: .user,
                    kind: .final,
                    text: utterance
                )
            )
        )
    }

    func submitToolInvocation(_ invocation: VoiceToolInvocation) {
        emit(.toolInvocation(invocation))
    }

    func submitMicrophonePCMChunk(_ samples: [Float], format: RealtimeMicrophonePCMFormat) {
        receivedMicrophoneChunks.append(MicrophonePCMChunk(samples: samples, format: format))
    }

    func playAssistantReply(_ reply: String) {
        emit(.playbackStateChanged(.speaking))
        let partial = String(reply.prefix(min(24, reply.count)))
        if !partial.isEmpty, partial != reply {
            emit(.transcript(.init(speaker: .assistant, kind: .partial, text: partial)))
        }
        emit(.transcript(.init(speaker: .assistant, kind: .final, text: reply)))
    }

    func emitToolCallback(_ callback: RealtimeVoiceToolCallbackEvent) {
        emit(.toolCallback(callback))
    }

    func setPlaybackState(_ state: RealtimeVoicePlaybackState) {
        emit(.playbackStateChanged(state))
    }

    func finishAssistantPlayback() {
        emit(.playbackStateChanged(.finished))
    }

    func interrupt() {
        emit(.interrupted)
    }

    func failTransport(_ message: String) {
        emit(.transportFailed(message))
    }

    private func emit(_ event: RealtimeVoiceTransportEvent) {
        emittedEvents.append(event)
        onEvent?(event)
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

final class HostVoiceSessionController: ObservableObject {
    @Published private(set) var state: VoiceSessionState
    @Published private(set) var permissionState: RealtimeVoicePermissionState

    private let sessionManager: RealtimeVoiceSessionManager
    private let permissionProvider: any RealtimeVoicePermissionProviding
    private let eventSource: any RealtimeVoiceEventSourcing
    private let microphoneSource: any MicrophonePCMSourcing
    private var currentContext: HostCaddieSession.TurnContext?
    private var lastEventResponse: VoiceTurnResponse?

    init(
        sessionManager: RealtimeVoiceSessionManager = RealtimeVoiceSessionManager(
            credentialProvider: EmbeddedPilotCredentialProvider(apiKey: "pilot-placeholder")
        ),
        permissionProvider: any RealtimeVoicePermissionProviding = NativeRealtimeVoiceRuntimeFactory.permissionProvider(),
        eventSource: any RealtimeVoiceEventSourcing = NativeRealtimeVoiceRuntimeFactory.eventSource(),
        microphoneSource: any MicrophonePCMSourcing = NativeRealtimeVoiceRuntimeFactory.microphoneSource()
    ) {
        self.sessionManager = sessionManager
        self.permissionProvider = permissionProvider
        self.eventSource = eventSource
        self.microphoneSource = microphoneSource
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

        try? sessionManager.connect()
        eventSource.connect()
        refreshState()
    }

    func disconnect() {
        microphoneSource.stop()
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
        try? sessionManager.beginListening()
        try? microphoneSource.start()
        eventSource.beginListening()
    }

    func stopListening() {
        guard currentContext != nil else {
            return
        }

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

        lastEventResponse = nil
        eventSource.submitFinalUtterance(utterance)
        if let response = lastEventResponse {
            eventSource.playAssistantReply(response.spokenReply)
        }
        return lastEventResponse
    }

    func submitPartialVoiceUtterance(_ utterance: String) {
        guard currentContext != nil else {
            return
        }

        eventSource.submitPartialUtterance(utterance)
    }

    func submitVoiceToolInvocation(_ invocation: VoiceToolInvocation) -> VoiceTurnResponse? {
        guard currentContext != nil else {
            return nil
        }

        lastEventResponse = nil
        eventSource.submitToolInvocation(invocation)
        if let response = lastEventResponse {
            eventSource.playAssistantReply(response.spokenReply)
        }
        return lastEventResponse
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
        guard let currentContext else {
            return
        }

        lastEventResponse = sessionManager.handleTransportEvent(
            event,
            context: currentContext
        )
        refreshState()
    }

    private func refreshState() {
        state = sessionManager.state
    }
}
