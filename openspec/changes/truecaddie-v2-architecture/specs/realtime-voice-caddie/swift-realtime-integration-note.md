# Swift Realtime Integration Note

This note describes the preferred pilot architecture for TrueCaddie voice: one native Swift iOS app, no separate TrueCaddie server, and a dedicated Swift realtime voice subsystem that routes all golf decisions through the existing caddie session layer.

## Status

This note supersedes the JS-first voice-integration direction as the preferred pilot path.

- Preferred path: Swift-first native realtime voice in the iOS app
- Fallback/reference path: JS/OpenAI Agents SDK bridge artifacts already in the repo
- Pilot auth posture: embedded app-managed credential behind a replaceable abstraction

## Design goals

1. Keep the shipped product as one iOS app.
2. Keep `RoundState`, `ShotStateContext`, and `NextShotRecommendationPacket` as the golf truth.
3. Keep recommendation logic and round-state mutation out of SwiftUI views.
4. Keep typed transcript UI as temporary scaffolding only.
5. Preserve a future migration path to hardened auth or a thin backend without rewriting the golf/session layer.

## Current Swift seams

The current Swift-side grounding surface already exists:

- `HostCaddieSession`
- `RoundState`
- `ShotStateContext`
- `NextShotRecommendationPacket`

The new native realtime layer should sit above that surface:

- `RealtimeVoiceSessionManager`
- `VoiceTurnRequest`
- `VoiceTurnResponse`
- `VoiceToolCatalog`
- `VoiceToolDispatch`
- `RealtimeVoiceCredentialProviding`
- `RealtimeVoiceSessionBootstrapping`

## Recommended runtime flow

### 1. App bootstraps a native realtime session

The iOS app should:

1. resolve the current credential through `RealtimeVoiceCredentialProviding`
2. bootstrap the pilot session through `RealtimeVoiceSessionBootstrapping`
3. prepare audio through `RealtimeVoiceAudioSessionCoordinating`
4. move the session manager into a connected state

For the pilot phase, direct app auth is acceptable only because it is isolated behind replaceable abstractions.

### 2. Incoming voice events become grounded turn requests

Incoming user input should become one of:

- `VoiceTurnInput.utterance`
- `VoiceTurnInput.toolInvocation`

That request must carry a grounded `HostCaddieSession.TurnContext` including:

- current hole
- current `RoundContext`
- current `RoundState`
- current bundle/player context

### 3. Caddie session handles the turn

`VoiceToolDispatch` should translate the native voice request into a `HostCaddieSession.SessionRequestEnvelope`.

`HostCaddieSession` remains responsible for:

- interpreting guidance vs safer/aggressive/balanced requests
- applying `report_result`
- applying `hole_out`
- applying `correct_score`
- producing short voice-ready replies grounded in the latest packet and round state

### 4. Voice system speaks the grounded reply

The realtime voice subsystem should treat the resulting `VoiceTurnResponse.spokenReply` as the caddie’s spoken answer.

The voice transport layer should not:

- invent strategy
- mutate round state directly
- decide clubs or targets

## Interruption handling

The voice session manager should own interruption-safe state:

- connection state
- listening/resolving/speaking state
- last response
- last interrupted turn ID
- latest grounded session snapshot

When the player interrupts:

1. the active turn is marked interrupted
2. the current speaking state is cleared
3. the latest grounded snapshot is preserved
4. the next turn reuses that snapshot as context

## Pilot auth and hardening path

### Pilot direct-auth mode

- embedded app-managed credential
- direct realtime connection from the app
- no separate TrueCaddie server

### Future hardened mode

- replace `RealtimeVoiceCredentialProviding`
- replace `RealtimeVoiceSessionBootstrapping`
- leave `HostCaddieSession`, `RoundState`, and `VoiceToolDispatch` unchanged

That keeps the security migration isolated from golf logic.

## Suggested future implementation slices

1. keep moving `HostCaddieSession` and adjacent voice scaffolding out of `ContentView.swift`
2. add a concrete native audio/realtime transport adapter behind `RealtimeVoiceSessionManager`
3. let the UI observe session state rather than own conversation logic
4. reduce the on-screen typed transcript to a debug-only development surface

## Inspiration references

Use these as implementation references, not as hard architectural dependencies:

- [lzell/OpenAIRealtime](https://github.com/lzell/OpenAIRealtime)
- [lzell/AIProxySwift](https://github.com/lzell/AIProxySwift)
- [dylanshine/openai-kit](https://github.com/dylanshine/openai-kit)

`OpenAIRealtime` and `AIProxySwift` are the closest inspiration for a Swift-first realtime path. `openai-kit` is background reference material rather than the primary foundation for this pilot architecture.
