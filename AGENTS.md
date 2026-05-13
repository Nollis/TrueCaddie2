# TrueCaddie Agent Guide

This repo is a small monorepo for turning course intelligence into round intelligence and, next, into voice-ready caddie guidance.

## Product Direction

The current product path is:

1. Publish canonical course bundles from Course Studio.
2. Load them into the Swift domain contract.
3. Resolve live recommendations from real shot state, not just tee-length heuristics.
4. Expose one unified `NextShotRecommendationPacket` for host UI and future voice consumers.

Recent work has already established:

- `ShotStateContext` as the live state bridge.
- layup candidate shelves in course data.
- unified next-shot recommendations in the domain layer.
- an iOS host inspector with scenario switching, live round controls, and a voice preview.

When in doubt, preserve that direction. Prefer improving the shared recommendation packet and its inputs over adding one-off UI logic.

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
- Treat Course Studio bundle output, shared schema, and Swift loaders as one contract. If one side changes, check the others.
- Avoid speculative abstractions. Add only what the active recommendation flow needs.

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

1. Improve packet honesty and confidence behavior.
2. Improve live round/shot-state inspection.
3. Tighten bundle overlays and layup shelf quality.
4. Wire the unified packet into real app-facing flows.
5. Only then expand the first true voice-facing layer.

## Cautions

- Do not overwrite unrelated local edits in `shared/sample-bundles/kungsbacka-nya.v1.json` unless explicitly asked.
- Keep bundle schema updates backward-aware across Course Studio and Swift loading code.
- On this machine, `swift` or `xcodebuild` may be unavailable. If so, say exactly what you changed and what you could not run.
