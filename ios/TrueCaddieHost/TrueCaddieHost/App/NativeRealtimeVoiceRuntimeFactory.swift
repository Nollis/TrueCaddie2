import Foundation
#if canImport(AVFoundation)
import AVFoundation
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

    static func eventSource(
        credentialProvider: (any RealtimeVoiceCredentialProviding)? = nil
    ) -> any RealtimeVoiceEventSourcing {
        let connection: any OpenAIRealtimeConnectioning
        if let credentialProvider, let credential = try? credentialProvider.currentCredential() {
            connection = OpenAIRealtimeWebRTCConnection(
                configuration: .default,
                credential: credential
            )
        } else {
            connection = StubOpenAIRealtimeConnection()
        }

        return DirectRealtimeVoiceEventSourceAdapter(
            client: OpenAIRealtimeClientShell(
                connection: connection,
                configuration: .default
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

    static func playbackEngine() -> any RealtimePlaybackEngine {
#if canImport(AVFoundation)
        return AVAudioPlayerNodeRealtimePlaybackEngine()
#else
        return StubRealtimePlaybackEngine()
#endif
    }

    /// Builds a microphone source and a playback engine that share the same
    /// underlying `AVAudioEngine` instance. Both consumers attach to one
    /// engine so a single `AVAudioSession.playAndRecord` category powers
    /// capture and playback without contention.
    static func microphoneSourceAndPlaybackEngine() -> (any MicrophonePCMSourcing, any RealtimePlaybackEngine) {
#if canImport(AVFoundation)
        let sharedEngine = AVAudioEngine()
        let source = AVAudioEngineMicrophonePCMSource(engine: sharedEngine)
        let player = AVAudioPlayerNodeRealtimePlaybackEngine(engine: sharedEngine)
        return (source, player)
#else
        return (StubMicrophonePCMSource(), StubRealtimePlaybackEngine())
#endif
    }
}
