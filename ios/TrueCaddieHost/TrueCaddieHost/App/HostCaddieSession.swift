import Combine
import Foundation
import TrueCaddieDomain
#if canImport(AVFoundation)
import AVFoundation
#endif

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
        case markBallPosition = "mark_ball_position"
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

    struct MarkBallPositionPayload: Equatable {
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
        case markBallPosition(MarkBallPositionPayload)
        case correctScore(CorrectScorePayload)
    }

    struct RealtimeToolCall: Equatable {
        let name: ActionName
        let payload: RealtimeToolPayload
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
        case markBallPosition(lie: ShotLie, remainingDistanceM: Double)
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
            case .markBallPosition:
                return .markBallPosition
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
            case let .markBallPosition(payload):
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
            name: .markBallPosition,
            description: "Capture the player's current GPS position as the end of the previous shot and the start of the next one. The host fills in the lie and remaining distance from device GPS — call this with no arguments when the player indicates they have reached their ball.",
            fields: [],
            sampleUtterances: ["I'm at my ball", "we're at the ball"]
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

        case .markBallPosition:
            // The model calls this with no arguments; the controller layer
            // backfills lie + remainingDistanceM from device GPS before the
            // call reaches this factory. If we get here without populated
            // arguments, drop the call rather than fabricate state.
            guard let lie, let remainingDistanceM else { return nil }
            return RealtimeToolCall(
                name: name,
                payload: .markBallPosition(
                    MarkBallPositionPayload(lie: lie, remainingDistanceM: remainingDistanceM)
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
        case let (.markBallPosition, .markBallPosition(payload)):
            .markBallPosition(lie: payload.lie, remainingDistanceM: payload.remainingDistanceM)
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

        case let .markBallPosition(lie, remainingDistanceM):
            let currentShotNumber = context.roundState.holeState(
                for: context.selectedHoleNumber
            )?.shotStateContext?.shotNumber

            guard let currentShotNumber else {
                return TurnOutcome(
                    actionName: action.name,
                    assistantReply: "Start the hole first, then I can pick up your ball position.",
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
                assistantReply: "You're \(format(number: remainingDistanceM))m out from the \(lie.rawValue). \(preview.voicePreview)",
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
