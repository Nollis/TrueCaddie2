# TrueCaddie Agent Guide

This repo is a small monorepo for turning course intelligence into round intelligence and, next, into voice-ready caddie guidance.

## Product Direction

The current product path is:

1. Publish canonical course bundles from Course Studio.
2. Load them into the Swift domain contract.
3. Resolve live recommendations from real shot state, not just tee-length heuristics.
4. Expose one unified `NextShotRecommendationPacket` for host UI and future voice consumers.
5. Use that packet and `RoundState` as the grounded backend for a realtime voice caddie.

Recent work has already established:

- `ShotStateContext` as the live state bridge.
- layup candidate shelves in course data.
- unified next-shot recommendations in the domain layer.
- an iOS host inspector with scenario switching, live round controls, and a voice preview.
- a host round flow with saved progress, score correction, and a first typed conversation bridge.

When in doubt, preserve that direction. Prefer improving the shared recommendation packet and its inputs over adding one-off UI logic.

## Voice Plan

TrueCaddie is not aiming for a traditional:

1. speech-to-text
2. separate text chat/reasoning layer
3. separate text-to-speech layer

Instead, the target architecture is a realtime voice caddie built around OpenAI realtime voice models, with the golf logic grounded in local course and round state.

That means:

- `RoundState` and the recommendation engine remain the source of truth.
- A `CaddieSession` or equivalent action layer should sit between realtime voice sessions and the golf domain.
- The session layer should accept grounded caddie intents, mutate round state when needed, and return short voice-ready responses.
- Any on-screen typed transcript is temporary scaffolding for development, not the final product experience.
- Do not build speculative STT -> LLM -> TTS plumbing unless the product direction explicitly changes.

## Realtime Voice Roadmap

Prefer this order for voice-facing work:

1. Formalize the caddie action contract.
   - `guidance`
   - `safer_play`
   - `aggressive_play`
   - `report_result`
   - `hole_out`
   - `score_correction`
   - `repeat`
2. Extract conversation rules out of `ContentView` into a real session/action layer.
3. Shape that layer for `GPT-Realtime-2` style realtime sessions with tool/action hooks.
4. Keep spoken replies short, grounded, and state-aware.
5. Only after that, replace the typed harness with true voice session UX.

## Repo Map

- `course-studio/`
  Builds and publishes canonical course bundles.
  Key entry point: `course-studio/app/publish-kungsbacka-nya.mjs`

- `shared/`
  Shared contract artifacts.
  Key files:
  - `shared/course-bundle-schema/course-bundle.v1.schema.json`
  - `shared/sample-bundles/kungsbacka-nya.v1.json`

- `ios/TrueCaddieDomain/`
  Swift package for bundle loading, validation, and recommendation logic.
  Key files:
  - `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/ShotStateContext.swift`
  - `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/NextShotRecommendation.swift`

- `ios/TrueCaddieHost/`
  iOS host app used as the current inspector/debug surface.
  Key file:
  - `ios/TrueCaddieHost/TrueCaddieHost/Features/BundleInspector/BundleInspectorView.swift`

- `openspec/`
  Architecture and implementation proposals.

## Working Rules

- Keep changes surgical. This repo is still defining its contract surface.
- Prefer domain-layer fixes over host-only fixes when recommendation behavior is involved.
- Do not split recommendation logic across multiple UI call sites. Route through `NextShotRecommendationEngine`.
- Keep voice output deterministic for now. Use structured packet fields, not freeform generation.
- Keep voice architecture aligned with realtime voice models. Do not drift into a legacy STT/TTS pipeline by accident.
- Treat Course Studio bundle output, shared schema, and Swift loaders as one contract. If one side changes, check the others.
- Avoid speculative abstractions. Add only what the active recommendation flow needs.
- When the user says `push`, stage only the relevant files for the accepted slice, commit them, and push to `main` unless the user asks for a branch instead.

## Recommendation Stack

For strategy/recommendation work, keep this flow intact:

1. Course Studio publishes bundle overlays and layup candidates.
2. `ShotStateContext` describes the current shot:
   - `shotNumber`
   - `remainingDistanceM`
   - `lie`
3. Domain engines resolve tee, approach, or layup guidance.
4. `NextShotRecommendationPacket` becomes the single output contract.
5. Host and future voice layers render that packet without re-deciding strategy.

If a change bypasses that pipeline, it is probably the wrong layer.

## Host Inspector Intent

The host app is currently a product-debugging surface, not final UX.

That means:

- `Overview` should stay compact and decision-focused.
- `Strategy` can expose live controls and overlay reasoning.
- `Debug` can keep raw metadata and diagnostics.

Do not let the inspector become the place where recommendation rules live. It should inspect and stress-test the packet, not invent it.

## Verification

Preferred repo-level verification:

- Windows: `pwsh scripts/check.ps1`
- macOS / Linux: `scripts/check.sh`

The check path should publish the pilot bundle, validate the shared schema, and run Swift tests when `swift` is available.

If working only on the host inspector, still add or update Swift tests where practical.

## Current Priorities

If you need to choose the next useful slice, prefer this order:

1. Extract a real `CaddieSession` / action layer from the host conversation bridge.
2. Keep `RoundState` and `NextShotRecommendationPacket` as the grounded backend for that session.
3. Tighten reply style for spoken caddie use.
4. Only then replace the typed harness with realtime voice session UX.
5. Continue improving round-state fidelity and bundle quality as supporting work.

## Cautions

- Do not overwrite unrelated local edits in `shared/sample-bundles/kungsbacka-nya.v1.json` unless explicitly asked.
- Keep bundle schema updates backward-aware across Course Studio and Swift loading code.
- On this machine, `swift` or `xcodebuild` may be unavailable. If so, say exactly what you changed and what you could not run.
