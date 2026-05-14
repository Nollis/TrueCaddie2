---
title: "feat: Inbound realtime audio playback"
type: feat
status: active
date: 2026-05-14
---

# feat: Inbound realtime audio playback

## Overview

Close the output side of the realtime voice loop so the caddie can actually speak. Today the WebSocket is healthy and `response.output_audio.delta` server events reach the client shell — but the base64 PCM payload is dropped, so the only thing that surfaces is a `.playbackStateChanged(.speaking)` state hint. This plan decodes the audio bytes, threads them up through the existing event chain, and plays them through an `AVAudioPlayerNode` attached to a shared `AVAudioEngine`.

## Problem Frame

- The previous slices established a working WebSocket, authenticated sessions, a valid `session.update` payload shape, a clean typed-harness path with zero wire traffic, and a simulator-safe mic source.
- The realtime session is now half-duplex: the model can hear (mic → wire) but the host can't hear the model. The user-visible result is that the caddie is silent — only the deterministic local recommendation appears in the transcript.
- The audio bytes already arrive — `OpenAIRealtimeServerEventEnvelope.delta` is the right field — but `OpenAIRealtimeClientShell.map(_:)` ignores them for the `outputAudioDelta` case.
- Without playback there is no voice product. Closing this loop unlocks live verification on a physical device.

## Requirements Trace

- **R1.** Decode `response.output_audio.delta` payloads and surface them as a typed event up to the host controller layer, preserving the raw PCM16 bytes.
- **R2.** Introduce a Swift-native `RealtimePlaybackEngine` abstraction with a stub plus an `AVAudioPlayerNode`-backed concrete implementation that schedules buffers from streamed Int16 LE chunks.
- **R3.** Wire the playback engine through `RealtimeVoiceEventSourcing`, the adapter, and `HostVoiceSessionController` so its lifecycle (start / enqueue / stop / clear-on-interrupt) mirrors the existing mic source plumbing.
- **R4.** Share a single `AVAudioEngine` instance between the mic source and the playback engine to avoid `AVAudioSession` contention.
- **R5.** Preserve every existing behavior: typed-harness flow, mic source path, status labels, and the existing test suite remain green without semantic changes.

## Scope Boundaries

- Out of scope: audio session interruption / route-change handling.
- Out of scope: reconnect, backoff, jitter recovery.
- Out of scope: tool-call response round-trip (separate planned slice).
- Out of scope: spoken-style copy improvements to the deterministic caddie text.
- Out of scope: any change to outbound mic plumbing beyond accepting an injected engine.

### Deferred to Separate Tasks

- AVAudioSession interruption + route change handling: future slice once playback works on hardware.
- Adaptive buffer pacing / jitter handling: future slice if real-world latency surfaces audible gaps.
- Function-tool response wiring: separate planned slice.

## Context & Research

### Relevant Code and Patterns

- `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`
  - `OpenAIRealtimeServerEventEnvelope` — the `delta: String?` field is already in place; no schema change required.
  - `OpenAIRealtimeServerEventType.outputAudioDelta` / `outputAudioDone` — current raw event names.
  - `OpenAIRealtimeClientShell.map(_:)` — the discard happens here for `.outputAudioDelta`.
  - `DirectRealtimeClientEvent` — receives a new `.outputAudioChunk(Data)` case.
  - `RealtimeVoiceTransportEvent` — receives the matching `.outputAudioChunk(Data)` case.
  - `DirectRealtimeVoiceEventSourceAdapter.map(_:)` — gets one new switch arm.
  - `MicrophonePCMSourcing` / `AVAudioEngineMicrophonePCMSource` / `StubMicrophonePCMSource` — the shape to mirror for the playback engine.
  - `NativeRealtimeVoiceRuntimeFactory` — extended with a `playbackEngine()` (and a paired-with-mic factory once engine sharing lands).
  - `HostVoiceSessionController` — add a playback engine property, route chunks in `receiveRealtimeEvent`, start/stop in lifecycle methods.
- `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — only touched if `makeWithPilotCredentials()` needs to thread an explicit shared engine.

### Institutional Learnings

- No `docs/solutions/` corpus exists yet; this is the first formal plan in the repo.
- AGENTS.md anticipates this work in its voice roadmap (item 5: "Tighten reply style for spoken caddie use" presupposes playback exists).

### External References

- OpenAI realtime API streams output audio as base64-encoded chunks of the format declared in `session.output_audio_format`. We've configured `"pcm16"`, which means 24 kHz mono Int16 little-endian.
- `AVAudioPlayerNode.scheduleBuffer(_:completionHandler:)` is the canonical streaming playback path. Buffers can be `pcmFormatInt16`; `AVAudioEngine` handles conversion to the output node's native float format automatically when nodes are connected.
- Shared `AVAudioEngine` is the conventional pattern when a single `AVAudioSession.playAndRecord` category is in use — two engines competing for the same session is a known source of instability.

## Key Technical Decisions

- **Decode at the wire layer, surface raw `Data` upward.** `OpenAIRealtimeClientShell.map(_:)` does the base64 decode and emits `.outputAudioChunk(Data)`. Adapter and controller never see base64 strings. Rationale: keeps decoding off the UI thread's hot path and keeps the controller untyped-string-free.
- **One `AVAudioEngine`, two consumers.** The mic source and the playback engine attach their nodes to the same `AVAudioEngine` instance vended by the factory. Rationale: matches Apple's intended use of `AVAudioEngine` and avoids `AVAudioSession.playAndRecord` contention.
- **Player consumes Int16 PCM directly.** Construct an `AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24_000, channels: 1, interleaved: true)` and copy delta bytes straight into `buffer.int16ChannelData`. `AVAudioEngine` handles internal Float32 conversion through the main mixer. Rationale: less code, no manual sample conversion, OpenAI's wire format matches Apple's buffer format byte-for-byte.
- **`.outputAudioDelta` no longer drives the "speaking" state directly.** The mapper emits only `.outputAudioChunk(data)` for deltas. The controller infers "speaking" the first time a chunk arrives and falls back to `.idle` on the existing `.playbackStateChanged(.finished)` triggered by `outputAudioDone`. Rationale: one source of truth — the byte stream — drives both UI state and audible output.
- **Player lifecycle ties to the connection, not the listening flag.** `playbackEngine.start()` runs in `connectIfNeeded()` so the player is ready before the first delta arrives. `stop()` runs in `disconnect()`. `interrupt()` does a stop+restart to drain the scheduled queue without tearing down the engine. Rationale: incoming audio can arrive even when the user isn't actively speaking (server VAD turn boundaries).

## Open Questions

### Resolved During Planning

- **Shared vs separate `AVAudioEngine`** → shared. See Decisions.
- **Int16 vs Float32 buffer format** → Int16. See Decisions.
- **Where audio is decoded** → client shell. See Decisions.
- **How "speaking" state is driven** → first chunk arrival in the controller. See Decisions.

### Deferred to Implementation

- Whether to clear the player on interrupt via `stop()`+`play()` or a more surgical buffer-queue API. Pick whichever AVFoundation supports cleanly; document the choice in the resulting commit.
- Whether to drop or pad chunks with odd byte counts. Default to drop (simpler, safer); revisit if real-world traffic shows OpenAI ever sends odd lengths.
- Whether `engine.start()` is reliably idempotent when called from two consumers in any order. Validate on device; if unreliable, centralize engine start through the factory or controller.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```mermaid
sequenceDiagram
  participant API as OpenAI Realtime
  participant WS as OpenAIRealtimeWebSocketConnection
  participant Client as OpenAIRealtimeClientShell
  participant Adapter as DirectRealtimeVoiceEventSourceAdapter
  participant Ctrl as HostVoiceSessionController
  participant Player as AVAudioPlayerNodeRealtimePlaybackEngine
  participant Engine as AVAudioEngine (shared)

  API->>WS: response.output_audio.delta (base64 PCM16)
  WS->>Client: onJSONMessage
  Client->>Client: decode envelope, base64 -> Data
  Client->>Adapter: onEvent(.outputAudioChunk(Data))
  Adapter->>Ctrl: onEvent(.outputAudioChunk(Data))
  Ctrl->>Player: enqueue(Data)
  Player->>Engine: scheduleBuffer(AVAudioPCMBuffer)
  Engine-->>Engine: mainMixerNode -> outputNode -> speakers

  API->>WS: response.output_audio.done
  WS->>Client: onJSONMessage
  Client->>Adapter: onEvent(.playbackStateChanged(.finished))
  Adapter->>Ctrl: .playbackStateChanged(.finished)
  Ctrl->>Player: (no-op; queued buffers drain)
```

## Implementation Units

- [ ] **Unit 1: Surface output audio bytes through realtime events**

**Goal:** Decode the base64 PCM payload of `response.output_audio.delta` and surface it as a typed `.outputAudioChunk(Data)` event all the way to the controller.

**Requirements:** R1

**Dependencies:** None.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`
- Test: `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift`

**Approach:**
- Add `.outputAudioChunk(Data)` to `DirectRealtimeClientEvent`.
- Add `.outputAudioChunk(Data)` to `RealtimeVoiceTransportEvent`.
- Change `OpenAIRealtimeClientShell.map(_:)` so the `.outputAudioDelta` arm reads `envelope.delta`, base64-decodes it, and returns `.outputAudioChunk(Data)`. Return nil if `delta` is missing or `Data(base64Encoded:)` fails.
- Keep the `.outputAudioDone` arm emitting `.playbackStateChanged(.finished)` unchanged.
- Add a switch arm in `DirectRealtimeVoiceEventSourceAdapter.map(_:)` that forwards `.outputAudioChunk(data)` → `.outputAudioChunk(data)`.

**Patterns to follow:**
- Existing single-payload variants like `.inputTranscriptPartial(String)` and `.outputTranscriptPartial(String)`.
- Adapter's `static func map(_:)` switch shape.

**Test scenarios:**
- Happy path — receiving `{"type":"response.output_audio.delta","delta":"<base64>"}` produces exactly one `DirectRealtimeClientEvent.outputAudioChunk` whose `Data` matches the base64-decoded bytes.
- Happy path — `response.output_audio.done` still produces `.playbackStateChanged(.finished)` with no chunk emitted.
- Edge case — `.outputAudioDelta` with `delta: nil` produces no event.
- Edge case — `.outputAudioDelta` with a non-base64 `delta` value produces no event (decode failure dropped silently, no crash).
- Integration — `DirectRealtimeVoiceEventSourceAdapter` forwards the chunk variant onto a transport `.outputAudioChunk(data)` with byte-equal payload.

**Verification:**
- The new tests pass.
- Existing decoder tests (`...CanDecodeServerEventJSON`, `...ReceivesServerJSONThroughConnection`) still pass without modification.

---

- [ ] **Unit 2: Build a `RealtimePlaybackEngine` abstraction**

**Goal:** Introduce a Swift-native playback protocol with a stub for tests and an `AVAudioPlayerNode`-backed concrete implementation that schedules PCM16 buffers.

**Requirements:** R2

**Dependencies:** None.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`
- Test: `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift`

**Approach:**
- Define `protocol RealtimePlaybackEngine: AnyObject` with `start() throws`, `stop()`, `enqueue(_ pcm16Bytes: Data)`.
- Define `enum RealtimePlaybackError: Error, Equatable { case unableToStartEngine(String) }`.
- Add `StubRealtimePlaybackEngine`: records `enqueuedChunks: [Data]`, `startCount`, `stopCount`, exposes `nextStartError: Error?` for failure injection.
- Add `AVAudioPlayerNodeRealtimePlaybackEngine` under `#if canImport(AVFoundation)`:
  - Init takes `engine: AVAudioEngine`, `sampleRate: Double = 24_000`, `channelCount: AVAudioChannelCount = 1`.
  - `start()` attaches an `AVAudioPlayerNode` if not already attached, connects it to `engine.mainMixerNode` using the Int16 format, calls `engine.start()` if needed, and calls `playerNode.play()`.
  - `stop()` calls `playerNode.stop()` only; never tears down the engine (the mic source may still be using it).
  - `enqueue(_:)` builds an `AVAudioPCMBuffer` via the static helper below and calls `playerNode.scheduleBuffer(buffer)`. No-op for empty data.
  - Add a static helper `static func makeBuffer(from bytes: Data, format: AVAudioFormat) -> AVAudioPCMBuffer?` so buffer construction is testable without starting any engine.

**Patterns to follow:**
- `MicrophonePCMSourcing` / `AVAudioEngineMicrophonePCMSource` / `StubMicrophonePCMSource` for shape, error type, and `#if canImport(AVFoundation)` gating.

**Test scenarios:**
- Happy path — `AVAudioPlayerNodeRealtimePlaybackEngine.makeBuffer(from:format:)` produces an `AVAudioPCMBuffer` whose `int16ChannelData` matches the input bytes for a known 24 kHz mono Int16 input.
- Edge case — empty `Data` to `makeBuffer` returns `nil`.
- Edge case — odd-byte-count `Data` to `makeBuffer` returns `nil` (not a valid Int16 stream).
- Happy path — `StubRealtimePlaybackEngine.enqueue(_:)` appends the chunk to `enqueuedChunks`.
- Happy path — `StubRealtimePlaybackEngine.start()` and `.stop()` increment their respective counts.
- Error path — `StubRealtimePlaybackEngine.nextStartError` set to a custom error causes `start()` to throw it once.

**Verification:**
- Tests above pass.
- The protocol provides enough surface for unit 4 to wire it through the controller.

---

- [ ] **Unit 3: Share the `AVAudioEngine` between mic source and playback engine**

**Goal:** Make a single `AVAudioEngine` power both input capture and output playback so they share one `AVAudioSession`.

**Requirements:** R4

**Dependencies:** Unit 2.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`
- Test: `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift`

**Approach:**
- Keep `AVAudioEngineMicrophonePCMSource.init(engine:bufferSize:)` (already injectable).
- In `NativeRealtimeVoiceRuntimeFactory`, add:
  - `static func playbackEngine() -> any RealtimePlaybackEngine` — returns the AVFoundation impl on Apple platforms, stub elsewhere, constructed around its own engine for direct callers.
  - `static func microphoneSourceAndPlaybackEngine() -> (any MicrophonePCMSourcing, any RealtimePlaybackEngine)` — constructs a single shared `AVAudioEngine`, then builds the mic source and playback engine around it.
- Leave `microphoneSource()` as-is for backward compatibility with existing tests and call sites.

**Patterns to follow:**
- Existing `NativeRealtimeVoiceRuntimeFactory.permissionProvider()` / `audioCoordinator()` / `microphoneSource()` factories.

**Test scenarios:**
- Happy path — `NativeRealtimeVoiceRuntimeFactory.playbackEngine()` returns a `AVAudioPlayerNodeRealtimePlaybackEngine` on Apple platforms and a stub elsewhere (mirror of the existing `microphoneSource()` test).
- Happy path — `NativeRealtimeVoiceRuntimeFactory.microphoneSourceAndPlaybackEngine()` returns two non-nil objects on Apple platforms. Engine identity sharing is asserted via a test-only seam (either a Mirror-readable property or an internal accessor on the AVFoundation impls).
- Regression — Existing `microphoneSource()` no-arg factory still returns the expected concrete type.

**Verification:**
- Tests above pass.
- Existing mic source tests remain unchanged and green.

---

- [ ] **Unit 4: Route output audio chunks through the controller**

**Goal:** Wire the playback engine into `HostVoiceSessionController` so output chunks reach the player and the player's lifecycle follows connect/disconnect/interrupt.

**Requirements:** R3, R5

**Dependencies:** Units 1, 2, 3.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` *(only if `makeWithPilotCredentials()` ergonomics require it)*
- Test: `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift`

**Approach:**
- Add `playbackEngine: any RealtimePlaybackEngine = NativeRealtimeVoiceRuntimeFactory.playbackEngine()` to `HostVoiceSessionController.init`.
- In `connectIfNeeded()`: call `try? playbackEngine.start()` after `eventSource.connect()` (engine should be ready before the first delta).
- In `disconnect()`: call `playbackEngine.stop()` after the existing mic-stop and session teardown.
- In `interrupt()`: call `playbackEngine.stop()` then `try? playbackEngine.start()` to drain the queue cleanly.
- In `receiveRealtimeEvent(_:)`: add `case let .outputAudioChunk(data):` → `playbackEngine.enqueue(data)` and, if `state.playbackState == .idle`, set it to `.speaking`.
- Update `HostVoiceSessionController.makeWithPilotCredentials()`: when constructing with a credential provider, use `microphoneSourceAndPlaybackEngine()` so both ends share one engine; otherwise default behavior.
- Update the two existing tests that already inject a `StubMicrophonePCMSource` so they also inject a `StubRealtimePlaybackEngine` and assert the default-factory player isn't constructed in the simulator hot path.
- `NoopRealtimeVoiceEventSource` / `StubRealtimeVoiceEventSource` need no method additions — `.outputAudioChunk(Data)` flows through `onEvent`, not via a `submitX` method.

**Patterns to follow:**
- Mic source wiring already present in `HostVoiceSessionController.init`, `beginListening`, `stopListening`, `disconnect`.

**Test scenarios:**
- Happy path — controller receiving `.outputAudioChunk(data)` calls `playbackEngine.enqueue(data)` exactly once with byte-equal payload.
- Happy path — receiving a chunk while `state.playbackState == .idle` flips it to `.speaking`.
- Happy path — `controller.connectIfNeeded()` increments `playbackEngine.startCount` once.
- Happy path — `controller.disconnect()` increments `playbackEngine.stopCount` once.
- Happy path — `controller.interrupt()` results in at least one `stop()` + one `start()` (or the equivalent buffer-clear contract) on the playback engine.
- Regression — typed-harness `submitVoiceUtterance("what do you like here")` still produces a transcript reply with `playbackEngine.enqueuedChunks.isEmpty` (typed flow never reaches the wire).
- Regression — existing `...TracksConnectionAndListeningState` and `...UsesStubEventSourceForRealtimeLifecycle` tests stay green after adding the stub playback engine injection.

**Verification:**
- All tests above pass.
- All existing tests in the suite remain green.
- On a physical device: tap Connect → the player attaches silently; tap "What do you like?" or speak via Start Listening → the caddie's voice reply is audible.

## System-Wide Impact

- **Interaction graph:** WebSocket → client shell → adapter → controller → playback engine → AVAudioEngine output. Exact mirror of the existing mic input chain.
- **Error propagation:** Base64 decode failures drop the chunk silently and log nothing (consistent with prior decoder behavior). Playback engine start failures are caught with `try?` and a `print("[HostVoiceSession] …")` so they're visible in console without crashing.
- **State lifecycle risks:** Two consumers on one engine — `engine.start()` must be idempotent; `playerNode.stop()` must not tear down the engine; the mic source's existing `engine.stop()` in its own `stop()` must not orphan the player. Mitigated by sharing engine ownership at the factory and never calling `engine.stop()` from either consumer.
- **API surface parity:** New `RealtimePlaybackEngine` protocol, two new event cases (`DirectRealtimeClientEvent.outputAudioChunk`, `RealtimeVoiceTransportEvent.outputAudioChunk`), two new factory methods on `NativeRealtimeVoiceRuntimeFactory`.
- **Integration coverage:** Unit tests cover wire decode, event routing, and controller dispatch. Audible playback can only be verified on hardware; that's the explicit "definitive verification" step in unit 4.
- **Unchanged invariants:** Typed-harness `sendPartialUtterance` / `sendFinalUtterance` still produce zero wire traffic. Mic source's existing wire format and tests remain identical. The default `OpenAIRealtimeSessionConfiguration` is unchanged.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| `engine.start()` races between mic and player consumers | Share one engine, document idempotent-start expectation; controller catches throws via `try?` |
| Audible gaps when deltas arrive faster than playback rate | Accept jitter for v1; `AVAudioPlayerNode` queues buffers in order. Re-evaluate after device testing. |
| Stale buffers playing after `interrupt()` | `interrupt()` issues `stop()` then `start()` on the player node, which clears scheduled buffers per AVFoundation contract. |
| Simulator audio output is sometimes flaky for streamed Int16 buffers | Document that authoritative verification is device-only; simulator may exhibit gaps unrelated to plan correctness. |
| `AVAudioFormat` with `.pcmFormatInt16` rejected by engine connection on some iOS versions | Deferred fallback: convert to Float32 in `makeBuffer`. Documented under deferred implementation notes. |

## Documentation / Operational Notes

- AGENTS.md needs no update — the voice roadmap already anticipates output audio.
- No rollout, monitoring, or migration concerns for a pilot iOS host.
- This plan is complete when units 1–4 land and the user confirms audible caddie speech on a physical device.

## Sources & References

- Origin document: none — plan derives from the prior in-session diagnosis on the `claude/reverent-fermat-f1bbcf` branch.
- Related code:
  - `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`
  - `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`
  - `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift`
- Related commits on this branch: `7619329` (WebSocket auth + diagnostics), `c2090e6` (audio format string fix), `b63f01d` (typed input synthesis), `0e2e287` (simulator mic guard).
- External: OpenAI realtime API `response.output_audio.*` events; `AVAudioPlayerNode.scheduleBuffer` documentation.
