import Combine
import Foundation
import TrueCaddieDomain
#if canImport(AVFoundation)
import AVFoundation
#endif

// Audio capture / playback, credentials, transport, event-source, and
// session-bootstrap plumbing for the realtime voice pipeline. The file is
// still chunky but every type here is part of a coherent runtime layer that
// `HostVoiceSessionController` and `RealtimeVoiceSessionManager` sit on top
// of. Further splitting (credentials / audio / transport into separate files)
// would be straightforward if it ever feels worthwhile.

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

    static func fromBundledSecrets() -> EmbeddedPilotCredentialProvider? {
        guard let trimmed = PilotSecrets.realtimeAPIKey?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return EmbeddedPilotCredentialProvider(apiKey: trimmed)
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
        model: String = "gpt-4o-realtime-preview",
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

    let engine: AVAudioEngine
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

        // Simulator / no-mic environments return a degenerate format
        // (typically 0 Hz, 2 ch). installTap throws an NSException for that,
        // which try? can't catch — short-circuit with a real Swift error.
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw MicrophonePCMSourceError.unableToStartEngine(
                "Input audio format unavailable (sampleRate=\(inputFormat.sampleRate), channelCount=\(inputFormat.channelCount)). On Simulator, microphone input is not provided; run on a device for live mic."
            )
        }

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

protocol RealtimePlaybackEngine: AnyObject {
    func start() throws
    func stop()
    func enqueue(_ pcm16Bytes: Data)
}

enum RealtimePlaybackError: Error, Equatable {
    case unableToStartEngine(String)
}

final class StubRealtimePlaybackEngine: RealtimePlaybackEngine {
    var nextStartError: Error?
    private(set) var enqueuedChunks: [Data] = []
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

    func enqueue(_ pcm16Bytes: Data) {
        guard !pcm16Bytes.isEmpty else { return }
        enqueuedChunks.append(pcm16Bytes)
    }
}

#if canImport(AVFoundation)
final class AVAudioPlayerNodeRealtimePlaybackEngine: RealtimePlaybackEngine {
    let engine: AVAudioEngine
    private let playerNode = AVAudioPlayerNode()
    private let outputFormat: AVAudioFormat
    private(set) var isRunning = false
    private var isAttached = false

    init(
        engine: AVAudioEngine = AVAudioEngine(),
        sampleRate: Double = 24_000,
        channelCount: AVAudioChannelCount = 1
    ) {
        self.engine = engine
        // Realtime API sends pcm16 LE at the session's output_audio_format.
        // AVAudioEngine will negotiate to the mixer's float format internally
        // when nodes are connected.
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: true
        ) ?? AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )!
    }

    func start() throws {
        guard !isRunning else { return }

        if !isAttached {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
            isAttached = true
        }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                throw RealtimePlaybackError.unableToStartEngine(String(describing: error))
            }
        }

        playerNode.play()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        playerNode.stop()
        isRunning = false
    }

    func enqueue(_ pcm16Bytes: Data) {
        guard let buffer = Self.makeBuffer(from: pcm16Bytes, format: outputFormat) else {
            return
        }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    static func makeBuffer(from pcm16Bytes: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !pcm16Bytes.isEmpty else { return nil }
        guard pcm16Bytes.count % 2 == 0 else { return nil }

        let frameCount = AVAudioFrameCount(pcm16Bytes.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let int16Channel = buffer.int16ChannelData?[0] else {
            return nil
        }

        pcm16Bytes.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            int16Channel.update(
                from: baseAddress.assumingMemoryBound(to: Int16.self),
                count: Int(frameCount)
            )
        }
        return buffer
    }
}
#endif

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
    case outputAudioChunk(Data)
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
        // Typed dev harness only — synthesize the partial transcript locally.
        // Real audio goes through sendMicrophonePCMChunk; pushing raw text
        // bytes as PCM is what the realtime API correctly rejects.
        outboundActions.append("synthetic-partial:\(utterance)")
        onEvent?(.inputTranscriptPartial(utterance))
    }

    func sendFinalUtterance(_ utterance: String) {
        // Typed dev harness only — synthesize the final transcript locally.
        // The real input_audio_buffer.commit lives on the mic path.
        outboundActions.append("synthetic-final:\(utterance)")
        onEvent?(.inputTranscriptFinal(utterance))
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
        let payload = OpenAIRealtimeSessionUpdatePayload(
            type: "realtime",
            instructions: configuration.instructions,
            toolChoice: "auto",
            audio: .init(
                input: .init(turnDetection: .init(
                    type: "server_vad",
                    createResponse: true,
                    interruptResponse: true
                )),
                output: .init(voice: configuration.voice)
            )
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
        guard !audioData.isEmpty else { return }
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
            guard let base64 = envelope.delta,
                  let bytes = Data(base64Encoded: base64) else {
                return nil
            }
            return .outputAudioChunk(bytes)

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
        case let .outputAudioChunk(data):
            return .outputAudioChunk(data)
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

