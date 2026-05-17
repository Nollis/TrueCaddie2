import Foundation

// MARK: - Server -> Client

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

// MARK: - Client -> Server

enum OpenAIRealtimeClientEventType: String, Codable, Equatable {
    case sessionUpdate = "session.update"
    case responseCreate = "response.create"
    case inputAudioBufferAppend = "input_audio_buffer.append"
    case inputAudioBufferCommit = "input_audio_buffer.commit"
    case responseCancel = "response.cancel"
}

// MARK: - Audio configuration

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

// MARK: - Session configuration

struct OpenAIRealtimeSessionConfiguration: Equatable, Codable {
    let model: String
    let webSocketURL: String
    let audio: OpenAIRealtimeAudioConfiguration
    let instructions: String
    let voice: String

    static let `default` = OpenAIRealtimeSessionConfiguration(
        model: "gpt-realtime-2",
        webSocketURL: "wss://api.openai.com/v1/realtime",
        audio: .default,
        instructions: "You are a concise, grounded golf caddie. Use the live round state and tool outputs. Keep spoken replies short. When the player says they are at their ball or have walked up to it, call mark_ball_position with no arguments — the host fills in the lie and remaining distance from GPS.",
        voice: "alloy"
    )
}

// MARK: - Session update envelope

struct OpenAIRealtimeSessionUpdateTurnDetection: Codable, Equatable {
    let type: String
    let createResponse: Bool
    let interruptResponse: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case createResponse = "create_response"
        case interruptResponse = "interrupt_response"
    }
}

struct OpenAIRealtimeSessionUpdateAudioInput: Codable, Equatable {
    let turnDetection: OpenAIRealtimeSessionUpdateTurnDetection

    enum CodingKeys: String, CodingKey {
        case turnDetection = "turn_detection"
    }
}

struct OpenAIRealtimeSessionUpdateAudioOutput: Codable, Equatable {
    let voice: String
}

struct OpenAIRealtimeSessionUpdateAudio: Codable, Equatable {
    let input: OpenAIRealtimeSessionUpdateAudioInput
    let output: OpenAIRealtimeSessionUpdateAudioOutput
}

struct OpenAIRealtimeSessionUpdatePayload: Codable, Equatable {
    let type: String
    let instructions: String
    let toolChoice: String
    let audio: OpenAIRealtimeSessionUpdateAudio

    enum CodingKeys: String, CodingKey {
        case type
        case instructions
        case toolChoice = "tool_choice"
        case audio
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

// MARK: - Response envelope

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
