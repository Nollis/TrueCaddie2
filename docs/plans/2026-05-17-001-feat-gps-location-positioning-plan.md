---
title: GPS Location Positioning Foundation
type: feat
status: active
date: 2026-05-17
---

# GPS Location Positioning Foundation

## Overview

Add CoreLocation integration to TrueCaddieHost so the app knows where the player is during a round. This is the foundation for everything position-aware: live distance-to-pin, automatic hole detection, automatic lie inference, and ball-position capture (the "I'm at my ball" gesture).

Scope is intentionally narrow: ship the location plumbing and the per-shot capture mechanism, leave persisted dispersion analytics and recommendation-engine rework to a follow-up plan. Once the foundation exists, the existing recommendation engine continues to consume `ShotStateContext` exactly as it does today — the difference is that `remainingDistanceM` and `lie` get computed from GPS instead of typed in.

## Problem Frame

Today the app collects `remainingDistanceM` and `lie` either by voice tool call (`report_result`) or by manual entry in the Inspector. There is no awareness of the player's actual position, which means:

- The caddie can't tell which hole the player is on (you have to pick it manually in the Inspector tab).
- The remaining-distance field is always whatever the player or model claims, never measured.
- There is no possible feedback loop on shot outcome — the app cannot collect dispersion data because it has no notion of "ball started at X, ended at Y".

The course bundle already carries everything needed: per-tee coordinates, green center/front/back, feature polygons (`fairway`, `green`, `tee`, `bunker`, `water`, `woods`), centerlines, OOB lines, and `default_play_direction` per hole. We just need device GPS and a small amount of math to turn raw fixes into golf-meaningful state.

## Requirements Trace

- R1. The app requests "When In Use" location permission and surfaces a graceful unauthorized/denied state.
- R2. While a hole is in progress, the Caddie tab shows a live remaining-distance-to-green-center value derived from GPS.
- R3. On round start (no hole in progress), the app auto-selects the current hole from GPS using a deterministic algorithm.
- R4. The player can mark "I'm at my ball" via a Caddie-tab button OR a voice intent. That gesture closes the current shot and starts the next one with `remainingDistanceM` and `lie` derived from the captured fix.
- R5. The lie is inferred from feature polygons, mapping to the existing `ShotLie` enum (`tee | fairway | rough | bunker | recovery`).
- R6. When GPS is unavailable, denied, or low accuracy, the existing manual entry path continues to work (no regression).
- R7. Geometry math (distance, point-in-polygon, hole detection, lie inference) lives in `TrueCaddieDomain` with no platform dependency, and is fully unit-tested with known coordinates.

## Scope Boundaries

- No persisted per-shot dispersion log (start coord + end coord per shot stored as a round artifact).
- No changes to `NextShotRecommendationEngine` — it keeps consuming `ShotStateContext` as-is.
- No on-screen map view. Live distance is a number, not a rendered hole.
- No background location updates. Foreground-only is fine for the pilot.
- No external GPS hardware (Garmin watch, laser rangefinder) — pure iPhone GPS.
- No support for putting / on-green shots beyond what the existing `ShotLie` enum already encodes (there is no `.green` case; on the green the player either holes out or treats the next shot as `fairway`-ish — preserving today's behavior).

### Deferred to Separate Tasks

- Persisted shot-dispersion record + analytics UI: follow-up plan, "GPS shot dispersion logging".
- Recommendation engine consuming actual dispersion: follow-up plan after dispersion data exists.
- Wind direction derived from compass/heading: out of scope; wind stays user-supplied via `RoundContext`.
- Hole-out detection from GPS (proximity to cup): manual hole-out remains the source of truth.

## Context & Research

### Relevant Code and Patterns

- [ios/TrueCaddieDomain/Sources/TrueCaddieDomain/CourseBundleModels.swift](ios/TrueCaddieDomain/Sources/TrueCaddieDomain/CourseBundleModels.swift) — `Tee.teeCoordinate` (`[lng, lat]`), `GreenReference.center/frontCenter/backCenter`, `CourseFeature.featureType` (`fairway`, `green`, `tee`, `bunker`, `water`, `woods`), `CourseFeature.geometry` (GeoJSONGeometry), `DefaultPlayDirection.bearingDeg`. Coordinates are GeoJSON `[longitude, latitude]` decimal degrees, WGS84.
- [ios/TrueCaddieDomain/Sources/TrueCaddieDomain/ShotStateContext.swift](ios/TrueCaddieDomain/Sources/TrueCaddieDomain/ShotStateContext.swift) — the value type GPS-derived shots will populate. No struct changes in this plan.
- [ios/TrueCaddieDomain/Sources/TrueCaddieDomain/RoundState.swift](ios/TrueCaddieDomain/Sources/TrueCaddieDomain/RoundState.swift) — `advanceShot(for:remainingDistanceM:lie:)` is the seam the capture gesture calls.
- [ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift](ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift) — `HostVoiceSessionController` and `NativeRealtimeVoiceRuntimeFactory` live here; this is the file where DI for a `LocationProviding` happens and where voice tool dispatch lives.
- [ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift](ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift) — owns `roundState`, `selectedHoleNumber`, and the `resetRound()` reset path. Auto-hole-detection writes into `selectedHoleNumber`.
- [ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieVoiceCluster.swift](ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieVoiceCluster.swift) — natural home for the "I'm at my ball" button alongside Interrupt/Finish.
- [ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift](ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift) — natural surface to render the live distance-to-pin.
- [ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift](ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift) — pattern for adding a developer toggle (used for simulator-friendly stub location).

### Institutional Learnings

- `PBXFileSystemSynchronizedRootGroup` (Xcode 16 auto-sync) is already in use — new `.swift` files are picked up on Xcode reopen, no project file edits required.
- The app must build clean against `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`, so every file that touches domain types must `import TrueCaddieDomain` explicitly.
- iOS Simulator has no real GPS — anything we ship must have a stub-friendly seam so simulator runs continue to work.

### External References

- Apple `CLLocationManager` docs: `requestWhenInUseAuthorization`, `startUpdatingLocation`, `CLLocationAccuracy`, `CLLocation.horizontalAccuracy`. Best-effort indoor fix on iPhone Pro models with dual-frequency GNSS is ~3 m horizontal under open sky; this is sufficient for hole detection and roughly sufficient for distance-to-pin (golf-grade rangefinders are sub-meter, so we will not market a measured pin distance as authoritative).
- Haversine formula for great-circle distance on WGS84 sphere; adequate at golf-hole scales (< ~600 m). For point-in-polygon containment at this scale, a flat equirectangular projection around the polygon's centroid is sufficient and avoids dealing with antimeridian / pole edge cases.

## Key Technical Decisions

- **Domain math has no platform import.** `GolfGeometry`, `HoleDetector`, and `LieInference` live in `TrueCaddieDomain` and operate on a plain `GeoCoordinate2D` value type (lng + lat doubles). CoreLocation only lives in the host module. This keeps the math unit-testable on any platform and avoids leaking `CLLocation` into the domain.
- **Coordinate ordering is enforced at the boundary.** A `GeoCoordinate2D.init(lonLatPair: [Double])` factory exists specifically because the course bundle stores raw `[lng, lat]` arrays — a typed wrapper prevents accidental lat/lng swaps in math code.
- **Hole detection algorithm:** point-in-polygon against the hole's `fairway` feature first; if no hole contains the player, fall back to the closest tee (any tee, any hole) within a sanity radius (say 200 m). If even that fails, leave the current selection untouched and surface a "no fix" state.
- **Hole-switch hysteresis:** auto-detection writes the selected hole only when no hole is currently in progress, OR when the player is more than 80 m outside every feature of the current hole for at least 5 consecutive fixes. This avoids flipping holes mid-shot when the player is between two adjacent fairways.
- **Lie inference precedence:** `green` → `bunker` → `water` (mapped to `.recovery` since water is a penalty drop) → `tee` (only on shot 1) → `fairway` → fallback `.rough`. The existing `ShotLie` enum has no `.green` case; landing on the green is treated as `.fairway` for lie purposes (the player still has a putt; this is consistent with today's behavior).
- **Live distance target:** green center (not front/back). Center is the only field guaranteed present in the bundle and matches how the existing recommendation engine reasons about target. Front/back are deferred to a richer distance UI later.
- **Permission model:** "When In Use" only. The app does not need background location for the foundation, and asking for "Always" without justification is App Store-risky.
- **Accuracy gate:** capture is only allowed when `horizontalAccuracy <= 15 m`. Below that, the button shows a disabled "GPS warming up" state; the voice intent responds with "I don't have a confident GPS fix yet". This number is conservative and can be tuned without code changes (constant in `GolfGeometry`).
- **Capture writes minimal state:** the captured fix updates `ShotStateContext` via existing `advanceShot(remainingDistanceM:lie:)`. The raw lat/lng of each capture is held only in a transient session-scoped model (not persisted), pending the dispersion-logging follow-up plan.
- **Voice intent:** add `.markBallPosition` action to `VoiceToolInvocation`. The argument set is empty — position comes from device GPS at the moment the tool fires, not from anything the model says. The system prompt teaches the model when to call it ("when the user indicates they have reached their ball").
- **Stub location provider for simulator:** a `StubLocationProvider` configurable from `InspectorDeveloperSection` lets the player toggle through canned fixes ("on tee box hole 1", "150 m out", "in the bunker") so end-to-end testing works without a real device.

## Open Questions

### Resolved During Planning

- *Coordinate format in course bundle:* GeoJSON `[lng, lat]` decimal degrees WGS84 — verified by reading `shared/sample-bundles/kungsbacka-nya.v1.json`.
- *Target for live distance:* green center; front/back are deferred.
- *Should we add a `.green` lie?* No, out of scope. Preserves existing enum and recommendation behavior.
- *Background location?* No. Foreground-only for the pilot.
- *Should hole detection run during an in-progress hole?* Only with hysteresis (5 consecutive fixes > 80 m outside any feature of the current hole). Otherwise the manually started hole wins.

### Deferred to Implementation

- *Exact tap target / placement of "I'm at my ball" button:* settled during execution by trying it in `CaddieVoiceCluster` next to the existing secondary buttons; might end up as a primary action card if it feels awkward there.
- *Whether to debounce live-distance UI to ~1 Hz vs every CLLocationManager update:* tuned during testing on a real device.
- *Whether GPS warming-up state needs its own visual chip or is absorbed into the existing voice-state pill:* settled during UI pass.
- *Polygon parsing detail:* GeoJSON polygons in `CourseFeature.geometry` are `JSONValue` blobs today; the geometry helper either inflates them lazily or normalizes them at bundle-load time — pick whichever feels cleanest when wiring `LieInference`.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
                                  ┌─────────────────────────────┐
                                  │      CLLocationManager      │ (iOS)
                                  └──────────────┬──────────────┘
                                                 │ CLLocation
                                                 ▼
                ┌──────────────────────────────────────────────────────┐
                │ CoreLocationProvider  (TrueCaddieHost, @MainActor)   │
                │   • requests "When In Use"                           │
                │   • filters horizontalAccuracy                       │
                │   • publishes LocationFix(coord, accuracy, ts)       │
                └──────────────┬─────────────────────────────────┬─────┘
                               │                                 │
                               ▼                                 ▼
              ┌─────────────────────────────┐    ┌──────────────────────────────┐
              │ LiveCourseLocationModel     │    │ HostVoiceSessionController   │
              │  (ObservableObject)         │    │   .markBallPosition() ───────┼──▶ advanceShot(...)
              │   • currentFix              │◀───┤                              │
              │   • currentHoleNumber       │    └──────────────────────────────┘
              │   • distanceToPinM          │
              │   • inferredLie             │
              └──┬──────────────────────────┘
                 │           uses (pure)
                 ▼
   ┌──────────────────────────────────────────────────────────┐
   │ GolfGeometry / HoleDetector / LieInference               │
   │   (TrueCaddieDomain — no platform deps)                  │
   │   • haversine(a, b) → meters                             │
   │   • pointInPolygon(coord, polygon) → Bool                │
   │   • HoleDetector.activeHole(fix, bundle, current) → Int? │
   │   • LieInference.lie(at, in: hole) → ShotLie             │
   └──────────────────────────────────────────────────────────┘
```

Caddie tab subscribes to `LiveCourseLocationModel` for live distance display. The "I'm at my ball" button and voice intent both go through `HostVoiceSessionController.markBallPosition()`, which reads the current fix from the location model, computes derived state via the geometry helpers, and calls `RoundState.advanceShot(...)`.

## Implementation Units

- [ ] **Unit 1: Domain geometry foundation**

**Goal:** Pure, platform-free geometry utilities — distance, point-in-polygon, GeoJSON polygon extraction, and the `GeoCoordinate2D` value type that all higher layers consume.

**Requirements:** R7

**Dependencies:** None

**Files:**
- Create: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/GolfGeometry.swift`
- Test: `ios/TrueCaddieDomain/Tests/TrueCaddieDomainTests/GolfGeometryTests.swift`

**Approach:**
- Define `GeoCoordinate2D` as a `struct { lon: Double; lat: Double }` with `init(lonLatPair: [Double])` for direct decode from the bundle.
- Define `LocationFix { coordinate, horizontalAccuracyM, timestamp }`.
- Implement `haversineDistance(_ a: GeoCoordinate2D, _ b: GeoCoordinate2D) -> Double` (meters).
- Implement `pointInPolygon(_ coord: GeoCoordinate2D, polygon: [[GeoCoordinate2D]]) -> Bool` using ray casting on an equirectangular projection around the polygon centroid (fine at hole scale).
- Add a helper `extractPolygons(from geometry: GeoJSONGeometry) -> [[GeoCoordinate2D]]` that handles `Polygon` and `MultiPolygon` GeoJSON types and ignores anything else.
- Expose a single `Constants` enum with `minimumAcceptableAccuracyM = 15.0` and `holeSwitchOuterRadiusM = 80.0`.

**Execution note:** Test-first. Start by writing failing tests against known coordinates (e.g., the published hole-1 tee → green-center distance from the bundle) and implement just enough to pass each one.

**Patterns to follow:**
- Existing pure value types like `RoundContext` and `ShotStateContext` — `Sendable`, no platform imports, simple inits.

**Test scenarios:**
- Happy path: `haversineDistance` between hole-1 White tee and hole-1 green center returns within ±1 m of the expected ~640 m (verify the actual number from the bundle first; treat the bundle as ground truth).
- Happy path: `haversineDistance(a, a)` returns 0.
- Edge case: `pointInPolygon` with a coordinate at a vertex of the polygon returns true.
- Edge case: `pointInPolygon` with a coordinate exactly outside a square polygon by 0.0001° lng returns false.
- Edge case: `extractPolygons` returns `[]` for a `Point` geometry type and does not throw.
- Edge case: `GeoCoordinate2D(lonLatPair: [lng, lat])` throws or returns nil when the array has fewer than 2 elements (decide which during impl, but cover both directions in tests).
- Integration: `extractPolygons` then `pointInPolygon` round-trip against the hole-1 fairway feature returns true for the fairway centroid and false for a coordinate 200 m outside the centerline.

**Verification:**
- `swift test` (or Xcode test target for TrueCaddieDomain) is green.
- No `import CoreLocation` anywhere in `TrueCaddieDomain`.

---

- [ ] **Unit 2: Hole detection and lie inference**

**Goal:** Given a `LocationFix` and a `CourseBundle`, deterministically return the active hole and the inferred lie. This is the brain that turns "the player is somewhere" into "the player is on hole 4, in a bunker".

**Requirements:** R3, R5

**Dependencies:** Unit 1

**Files:**
- Create: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/HoleDetector.swift`
- Create: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/LieInference.swift`
- Test: `ios/TrueCaddieDomain/Tests/TrueCaddieDomainTests/HoleDetectorTests.swift`
- Test: `ios/TrueCaddieDomain/Tests/TrueCaddieDomainTests/LieInferenceTests.swift`

**Approach:**
- `HoleDetector.activeHole(fix:bundle:current:)` returns `Int?` (hole number).
  - Algorithm: for each hole, build the union of polygons from `fairway`, `green`, `tee`, `bunker` features; if fix is inside any, return that hole.
  - Tiebreaker (player standing in tee feature of two adjacent holes): the hole whose green is *farther* from the fix wins (i.e., the hole the player is about to play, not the one they just finished).
  - Fallback: if no containment, find closest tee across all holes; return that hole only if within `holeSwitchOuterRadiusM`.
  - Hysteresis: if `current` is non-nil, only return a different hole when the fix has been outside every feature of `current` by > 80 m. Caller is responsible for tracking the streak; the detector takes an extra `consecutiveMisses: Int` parameter and only returns a new hole when `consecutiveMisses >= 5`.
- `LieInference.lie(at:in:)` takes a fix and a single `CourseHole`, returns `ShotLie`.
  - Precedence order: `green` → `bunker` → `water` (→ `.recovery`) → `tee` → `fairway` → fallback `.rough`.
  - `tee` lie only returned when shot count is 1 (caller passes shot number; or simpler: `tee` is never inferred and the caller forces `.tee` on shot 1).

**Patterns to follow:**
- `RoundState.swift` `selectedTee(in:roundContext:)` style — pure function, no side effects, returns optional gracefully.

**Test scenarios:**
- Happy path: tee coordinate of hole 1 White → `HoleDetector.activeHole` returns 1.
- Happy path: green center of hole 1 → `LieInference.lie` returns `.fairway` (no `.green` case; treated as `.fairway` for now).
- Happy path: a coordinate 100 m short of green center along centerline of hole 1 → `LieInference.lie` returns `.fairway`.
- Edge case: coordinate not contained in any hole's features but within 50 m of hole 5 tee → `HoleDetector.activeHole` returns 5.
- Edge case: coordinate 500 m from any tee → `HoleDetector.activeHole` returns nil.
- Edge case: water hazard coordinate → `LieInference.lie` returns `.recovery`.
- Edge case: bunker coordinate → `LieInference.lie` returns `.bunker`.
- Integration: hysteresis — given `current = 1` and a fix outside all hole-1 features but inside hole-2 features, `activeHole(..., consecutiveMisses: 4)` returns 1; `activeHole(..., consecutiveMisses: 5)` returns 2.

**Verification:**
- All four feature types from the kungsbacka bundle round-trip into the right `ShotLie`.
- Hysteresis prevents single-fix flips.

---

- [ ] **Unit 3: CoreLocation provider and host-side location model**

**Goal:** Bridge CoreLocation into the app via a `LocationProviding` seam, and publish derived state (current hole, distance to pin, inferred lie, current fix) for the rest of the app to observe.

**Requirements:** R1, R2, R6

**Dependencies:** Unit 1, Unit 2

**Files:**
- Create: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/LocationProviding.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/CoreLocationProvider.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/StubLocationProvider.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/LiveCourseLocationModel.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Info.plist` (or equivalent — add `NSLocationWhenInUseUsageDescription`)

**Approach:**
- `LocationProviding` (domain): an `AsyncStream<LocationFix>`-shaped protocol or a Combine `Publisher`-shaped protocol — pick the one that matches the existing voice/audio surfaces in the host. Either way it exposes `var authorizationStatus: LocationAuthorizationStatus` and `func start()` / `func stop()`.
- `CoreLocationProvider` (host): `@MainActor`, owns a `CLLocationManager`, requests "When In Use" the first time `start()` is called, sets desired accuracy `kCLLocationAccuracyBest`, drops fixes with `horizontalAccuracy > Constants.minimumAcceptableAccuracyM * 2` (filter, not gate — the gate happens at capture time).
- `StubLocationProvider` (host): publishes a configurable canned fix; controlled from the Inspector Developer section. Defaults to "hole 1 white tee" so simulator launches feel sane.
- `LiveCourseLocationModel`: `ObservableObject`, takes a `LocationProviding`, a `CourseBundle`, and a function `currentHole: () -> Int?`. Publishes `@Published var distanceToPinM: Double?`, `@Published var detectedHoleNumber: Int?`, `@Published var inferredLie: ShotLie?`, `@Published var lastFix: LocationFix?`, `@Published var authorizationStatus: LocationAuthorizationStatus`. Internally tracks the `consecutiveMisses` streak for hysteresis.
- Add `NSLocationWhenInUseUsageDescription` with a copy like: "TrueCaddie uses your location during a round to know which hole you're on and how far to the pin."

**Patterns to follow:**
- `NativeRealtimeVoiceRuntimeFactory` in `HostCourseBundleStore.swift` for DI/factory style.
- The `OpenAIRealtimeWebSocketConnection` / WebRTC pattern of `@MainActor` host objects with `onX` callback closures or `@Published` outputs.

**Test scenarios:**
- Happy path: `StubLocationProvider` configured with hole-1 tee → `LiveCourseLocationModel.detectedHoleNumber` becomes 1 after subscription.
- Happy path: stub fix at 150 m short of hole 1 green → `distanceToPinM` is within ±1 m of 150.
- Edge case: stub provider configured with a fix in a bunker → `inferredLie` is `.bunker`.
- Edge case: provider transitions authorization from `notDetermined` → `denied` → `authorizedWhenInUse` and `LiveCourseLocationModel.authorizationStatus` reflects each.
- Edge case: fix with `horizontalAccuracy = 50 m` is published — `LiveCourseLocationModel.lastFix` is still updated (so UI can render "GPS warming up"), but capture is gated separately in Unit 4.
- Integration: hysteresis — three sequential stub fixes outside hole 1, with `current = 1`, leave `detectedHoleNumber == 1`; a fifth consecutive miss flips it to the new hole.

**Verification:**
- Run on a physical device: hole number and distance update on screen as the player walks.
- Run in simulator with `StubLocationProvider`: the Developer section can flip the stub fix and the Caddie tab reacts.

---

- [ ] **Unit 4: Caddie-tab live distance + "I'm at my ball" capture (button + voice intent)**

**Goal:** Surface live distance-to-pin on the Caddie tab and wire the player-facing capture gesture (tap and voice). Capturing closes the current shot and starts the next one with GPS-derived `remainingDistanceM` and `lie`.

**Requirements:** R2, R4

**Dependencies:** Unit 3

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift` (or a new sibling view for the distance pill — pick during execution)
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieVoiceCluster.swift` (adds "I'm at my ball" secondary button)
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift` — `HostVoiceSessionController.markBallPosition()` method; thread `LiveCourseLocationModel` through DI; extend voice tool dispatch and the session-update instructions string to teach the model about the new intent.
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — owns the `LiveCourseLocationModel`, passes it down.
- Modify: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/` voice tool invocation types (file TBD — search for `VoiceToolInvocation` and add a `.markBallPosition` action).
- Test: extend `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift` with `HostVoiceSessionController.markBallPosition` round-trip tests.

**Approach:**
- The Caddie hero shows the live distance number ("142 m to pin") whenever `LiveCourseLocationModel.distanceToPinM` is non-nil and a hole is in progress. When nil, it shows the existing empty/placeholder state.
- "I'm at my ball" button: secondary button in `CaddieVoiceCluster`, enabled only when `lastFix.horizontalAccuracy <= 15 m`. Disabled label reads "GPS warming up". Tap calls `voiceController.markBallPosition()`.
- `HostVoiceSessionController.markBallPosition()`:
  - Reads `lastFix` from the location model.
  - If accuracy gate fails, surfaces a voice/Caddie message ("I don't have a confident GPS fix yet") and returns.
  - If pass: computes `remainingDistanceM = haversineDistance(fix, green.center)` for the current hole, computes `lie = LieInference.lie(at: fix, in: currentHole)`, then calls `roundState.advanceShot(for: selectedHoleNumber, remainingDistanceM: ..., lie: ...)`.
  - Emits a `VoiceToolInvocation(.markBallPosition, ...)` echo for diagnostics / scorecard parity.
- Voice intent: `.markBallPosition` action; the OpenAI session prompt is updated to teach the model "when the user says they are at their ball, call mark_ball_position" with no required arguments. The handler in `HostVoiceSessionController` routes both UI taps and voice tool calls through `markBallPosition()`.

**Patterns to follow:**
- `submitVoiceToolInvocation(_:)` and the existing `.reportResult` action are the closest analogues — mirror their dispatch and persistence.
- `CaddieVoiceCluster.swift` styling for the Interrupt/Finish secondary buttons (`.font(.callout)`).
- `InspectorDeveloperSection.swift` for any developer-only diagnostic surface added during this unit.

**Test scenarios:**
- Happy path: with a stub fix on the hole-1 fairway 140 m from green and shot in progress, `markBallPosition()` advances shot to `shotNumber + 1` with `remainingDistanceM` ≈ 140 and `lie == .fairway`.
- Happy path: voice tool dispatch with `.markBallPosition` and a fairway stub fix produces the same end state as a UI tap.
- Edge case: `lastFix.horizontalAccuracy = 25 m` → button is disabled and `markBallPosition()` returns without mutating round state.
- Edge case: no `lastFix` yet → button is disabled; voice intent surfaces "no GPS fix" message.
- Edge case: bunker stub fix → after capture, `roundState.holeState(for: current)?.shotStateContext?.lie == .bunker`.
- Integration: end-to-end — stub provider seeded to tee, hole started, `markBallPosition` called; resulting `shotStateContext` matches GPS-derived values and `NextShotRecommendationEngine.build(...)` returns a recommendation built on those values without engine changes.

**Verification:**
- Caddie tab on a physical device shows a live distance number that decreases as the player walks toward the pin.
- Saying "I'm at my ball" advances the shot just like tapping the button.
- Manual entry / `report_result` still works when GPS is unavailable (no regression in existing tests).

---

- [ ] **Unit 5: Auto-hole selection + permission UX + stub location toggle**

**Goal:** Wire the detected hole into `ContentView.selectedHoleNumber` on round start, render graceful permission UX, and expose the stub location provider in the Inspector developer section.

**Requirements:** R1, R3, R6

**Dependencies:** Unit 3, Unit 4

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — subscribe to `LiveCourseLocationModel.detectedHoleNumber`, write into `selectedHoleNumber` when no hole is in progress (or hysteresis fires).
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift` — add stub-location controls (toggle to enable stub, picker of canned fixes).
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift` or a sibling view — render a single-line "Location permission denied" / "GPS warming up" state when authorization is not granted or accuracy is poor.
- Test: extend tests for `HostRoundProgressModel.currentHoleNumber(...)` if behavior changes there, otherwise integration tests on the `ContentView` model layer for auto-selection.

**Approach:**
- `ContentView` owns one `LiveCourseLocationModel`. On launch it calls `provider.start()`. When `detectedHoleNumber` changes and `roundState` has no in-progress hole, write the detected hole into `selectedHoleNumber`. When a hole *is* in progress, defer to the model's hysteresis (which already enforces the 5-consecutive-miss rule).
- Permission UX: a thin chip / banner on the Caddie tab when `authorizationStatus == .denied`, with a button to open Settings. When `.notDetermined`, the first `start()` triggers the system prompt — no custom UI required.
- Inspector developer section gets a "Use stub GPS" toggle and a picker of fixes: `hole 1 tee`, `hole 1 fairway 140 m out`, `hole 1 greenside bunker`, `hole 5 tee`, etc. Off by default.

**Patterns to follow:**
- `InspectorDeveloperSection.swift` `@AppStorage("truecaddie.developerToolsEnabled")` pattern for the stub toggle.
- `ContentView` existing `onChange` modifiers for round-state persistence — same pattern, different source.

**Test scenarios:**
- Happy path: on launch with no saved round and stub fix on hole 3 tee, `selectedHoleNumber` becomes 3.
- Happy path: hole 1 is in progress; stub fix moves to hole 2 fairway for fewer than 5 consecutive fixes → `selectedHoleNumber` remains 1.
- Happy path: same setup but 5 consecutive fixes outside hole 1 → `selectedHoleNumber` becomes 2.
- Edge case: `authorizationStatus == .denied` → `detectedHoleNumber` is nil and `selectedHoleNumber` is unchanged from its saved value; the Caddie tab shows a "Location permission denied" chip.
- Edge case: enabling the stub toggle in the Inspector and selecting "hole 5 tee" updates `selectedHoleNumber` to 5 within one update cycle.
- Integration: cold launch → permission prompt → "allow" → first real fix arrives → hole detection writes `selectedHoleNumber` (no manual hole tap needed).

**Verification:**
- Open the app on a physical device on the course → it lands on the right hole.
- Deny permission → manual hole selection in Inspector still works; no crash, no UI lockup.
- Simulator-only: Inspector toggle drives the whole flow without a real device.

## System-Wide Impact

- **Interaction graph:** `LiveCourseLocationModel` is a new always-on subscriber. Any view that wants live position derivatives observes it; nothing else changes. `HostVoiceSessionController.markBallPosition()` is a new entry point parallel to `submitVoiceToolInvocation(.reportResult, ...)`.
- **Error propagation:** Location errors (denied permission, no fix, low accuracy) never throw into the round state — they degrade gracefully into `nil` published values, and capture refuses to mutate round state until accuracy is acceptable. The existing manual entry path is the universal fallback.
- **State lifecycle risks:** None for foundation. The transient `LiveCourseLocationModel` is not persisted; auto-detected hole writes go through the same `selectedHoleNumber` that `HostRoundProgressStore` already persists. Per-fix coordinates are *not* written to UserDefaults in this plan — that is dispersion-plan scope.
- **API surface parity:** `markBallPosition` is wired for both UI tap and voice tool — agent-native parity is preserved. The agent can do anything the user can do.
- **Integration coverage:** Auto-hole detection + live distance + capture flow needs at least one end-to-end test using `StubLocationProvider` to prove the full chain (stub → location model → voice controller → round state).
- **Unchanged invariants:** `ShotStateContext`, `RoundState`, `NextShotRecommendationEngine`, `CourseBundle`, and `RoundContext` schemas do not change. Existing voice intents (`report_result`, etc.) keep working unchanged. The existing manual-entry developer chips in the Inspector still produce identical state.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| iPhone GPS accuracy varies (forest cover, tall trees) — distance numbers may be off by 5–10 m in worst case | Surface the accuracy chip; never market live distance as "measured" in user-facing copy; capture is gated at 15 m accuracy. |
| Battery cost of `kCLLocationAccuracyBest` over a 4-hour round | Foreground-only and pause-when-Inspector-active are easy follow-ups if the pilot shows it matters. Not solved in this plan. |
| Hole-switch hysteresis flips at adjacent fairways anyway (parallel holes are common at Kungsbacka) | The "stay on current hole until 5 consecutive misses > 80 m" rule is conservative; tunable via constants without code changes. Real-course feedback drives the tuning. |
| Permission denial on first launch leaves the app feature-degraded with no obvious recovery path | The "Location permission denied" chip links directly to Settings; manual hole selection remains as a fallback. |
| GeoJSON polygon parsing from `JSONValue` is more boilerplate than expected | Contained to one helper in `GolfGeometry`; the cost is paid once and tested with the kungsbacka bundle. |
| App Store rejects "When In Use" string as too generic | Usage description specifically mentions golf-hole tracking and distance-to-pin, which is exactly what's happening. Low risk. |

## Documentation / Operational Notes

- Add `NSLocationWhenInUseUsageDescription` to the app's Info.plist with copy reviewed by the user before submission.
- Note in the pilot release notes: GPS is foreground-only; battery cost expected to be moderate over a full round.
- Inspector → Developer section gains a stub-location toggle for simulator/regression testing; document this in the Inspector tab's footer text.

## Sources & References

- Origin: direct user request — "Makes no sense without location positioning, how could we collect dispersion data and calculate next shot without knowing where we are?"
- Course bundle inspection: `shared/sample-bundles/kungsbacka-nya.v1.json` (coordinate format verified: GeoJSON `[lng, lat]`, WGS84 decimal degrees; six feature types: `fairway`, `green`, `tee`, `bunker`, `water`, `woods`).
- Related code: [ios/TrueCaddieDomain/Sources/TrueCaddieDomain/CourseBundleModels.swift](ios/TrueCaddieDomain/Sources/TrueCaddieDomain/CourseBundleModels.swift), [ios/TrueCaddieDomain/Sources/TrueCaddieDomain/RoundState.swift](ios/TrueCaddieDomain/Sources/TrueCaddieDomain/RoundState.swift), [ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift](ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift), [ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift](ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift).
- Apple docs: `CLLocationManager`, `CLLocationAccuracy`, `NSLocationWhenInUseUsageDescription`.
