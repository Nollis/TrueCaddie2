---
title: "feat: Live wind from Apple WeatherKit"
type: feat
status: active
date: 2026-05-17
---

# feat: Live wind from Apple WeatherKit

## Overview

Replace the hardcoded `WindContext(relativeDirection: .helping, speedMps: 5.0)` in `RoundContext.pilotSample` with live wind data from Apple WeatherKit, keyed off the player's current GPS coordinate. Convert the absolute compass wind into the existing `helping` / `hurting` / `cross` category relative to the current hole's tee→green bearing. Feed the result into the **base** `RoundContext` so the existing recommendation engine — and the Inspector's existing manual override — keep working exactly as they do today.

Mirror the architecture of the just-completed GPS work: a `WindProviding` protocol in the domain, a WeatherKit-backed provider and a stub provider in the host, an observable `LiveWindModel` published into `ContentView`, and a Caddie-tab readout plus stub-wind chips in the Inspector developer section.

As part of the same change, **remove the now-redundant manual wind override** (the `windEnabled` toggle / direction picker / speed slider in `InspectorStrategySection` and `BundleInspectorView`, plus the corresponding fields on `RoundOverrideState` and the merge logic in `HoleInspectorModel.makeEffectiveRoundContext`). With live wind flowing and the stub-wind developer chips serving the "force a specific value" use case through the same path, the override is duplicate machinery and a third source-of-truth that would otherwise confuse precedence.

## Problem Frame

Wind is one of the three primary inputs to club selection and shot strategy. The recommendation engine already consumes a `WindContext` (direction relative to the shot + speed in m/s), but the value is currently hardcoded into the bundled `RoundContext.pilotSample`. The Inspector lets the player override wind manually, but no live source feeds it.

With GPS now flowing, we can call WeatherKit at the player's location and stop pretending it's always a 5 m/s tailwind. The data needs to be converted from absolute compass-wind to shot-relative direction using the hole's tee→green bearing — straightforward great-circle math we already have most of the pieces for.

## Requirements Trace

- **R1.** When a round is active and GPS is available, the base `RoundContext.wind` reflects the actual wind at the player's location (within ~10 minutes of freshness).
- **R2.** Wind direction is computed relative to the current hole's tee→green bearing, mapped to one of the three existing `WindRelativeDirection` cases (`helping`, `hurting`, `cross`).
- **R3.** Wind speed is reported in m/s (the existing unit) using whichever unit WeatherKit returns, converted via `Measurement.converted(to:)`.
- **R4.** WeatherKit fetches refresh on round start, on hole change, and on a coarse ~10–15 minute cadence while the app is foregrounded.
- **R5.** Fetch failures are non-fatal — last known wind is retained, an error indicator is published, and the app keeps functioning.
- **R6.** The iOS Simulator (no WeatherKit network reach, no entitlement) can be driven by a stub provider with canned advisories from the Inspector developer section.
- **R7.** The manual wind override (toggle/picker/slider) and its supporting state are removed; the developer-section stub-wind chips become the single way to force a specific wind value, and they route through the same `LiveWindModel` path as real WeatherKit data.

## Scope Boundaries

- No support for **elevation** or **temperature** signals from WeatherKit — wind only. The recommendation engine doesn't consume them today.
- No **forecast** lookups (e.g., "wind in 30 minutes when I reach the green") — current observations only.
- No new `WindRelativeDirection` cases (no `quartering`, `leftCross`, `rightCross`). Mapping continuous compass angles to three categories is sufficient for the existing recommendation engine.
- No persisted wind history per shot. Dispersion logging is a separate planned effort; coordinates are the priority there, not weather.
- No background refresh while the app is suspended. WeatherKit has free-tier quota concerns and the app is foreground-only today anyway.

### Deferred to Separate Tasks

- **Wind history embedded in dispersion-log entries**: dispersion logging is its own planned effort; the wind-at-shot-time can be captured there by reading `LiveWindModel.advisory` at capture time. Listed here so it doesn't get tacked onto this plan.

## Context & Research

### Relevant Code and Patterns

- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/RoundContext.swift` — `WindContext`, `WindRelativeDirection` (three cases: `helping`, `hurting`, `cross`).
- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/LocationProviding.swift` — the protocol shape to mirror: `@MainActor protocol` with callback closures + `start()` / `stop()`.
- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/GolfGeometry.swift` — already has `haversineDistance(_:_:)`; the natural home for `bearingDeg(from:to:)` and the angle-to-category helper.
- `ios/TrueCaddieHost/TrueCaddieHost/App/CoreLocationProvider.swift` — pattern for an Apple-framework-backed provider (CoreLocation delegate → MainActor callbacks).
- `ios/TrueCaddieHost/TrueCaddieHost/App/StubLocationProvider.swift` — pattern for a simulator/test provider with an `emit`/`inject` method.
- `ios/TrueCaddieHost/TrueCaddieHost/App/LiveCourseLocationModel.swift` — pattern for an `@MainActor` `ObservableObject` that owns the provider, publishes derived state, and exposes `injectStubFix(_:)` for the Inspector.
- `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — pattern for owning a `@StateObject` provider model, threading it down through tabs, and starting it on `.onAppear`.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift` — manual wind override UI lives here (`windEnabled` toggle, direction picker, speed slider). This stays the override; live wind feeds the base.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift` — pattern for stub-injector chips.
- `ios/TrueCaddieHost/TrueCaddieHost.xcodeproj/project.pbxproj` — the file used to add the previous `NSLocationWhenInUseUsageDescription` and `INFOPLIST_KEY_*` entries; the entry point for the WeatherKit capability addition.

### Institutional Learnings

The just-completed GPS work established the seam pattern (domain protocol, host providers, observable model, ContentView wiring) and the simulator-stub developer chip pattern. This plan deliberately reuses both verbatim so reviewers can read it as "GPS work, but for wind."

### External References

- WeatherKit Swift documentation: `WeatherService.shared.weather(for: CLLocation)` is async, returns a `Weather` whose `currentWeather.wind` exposes:
  - `wind.speed: Measurement<UnitSpeed>` — convert to m/s with `.converted(to: .metersPerSecond).value`.
  - `wind.direction: Measurement<UnitAngle>` — degrees clockwise from north, indicating the direction the wind is **coming from** (meteorological convention).
- WeatherKit requires:
  - The `com.apple.developer.weatherkit` capability/entitlement on the target.
  - The bundle ID registered for WeatherKit in the Apple Developer portal.
  - Free quota of 500k calls/month per Apple ID. At one fetch per 10 minutes per user this is ~4.3k/month per user — comfortably within bounds.

## Key Technical Decisions

- **Live wind is the single wind source.** The manual override is removed in the same change. With live wind plus stub-wind developer chips both flowing through `LiveWindModel`, the override is redundant machinery and a confusing third source of truth. The stub-wind chips cover all "force a specific value" use cases (debugging, coaching scenarios, simulator testing) via the same code path as real WeatherKit data.
- **Categorization at the host layer, not WeatherKit-provider layer.** The provider publishes a raw `WindAdvisory` (absolute compass direction + speed). The mapping to `helping`/`hurting`/`cross` happens in `LiveWindModel`, which knows the current hole's tee→green bearing. Keeps the provider single-purpose and the math testable.
- **Refresh cadence: round-start + hole-change + 600s periodic timer.** Hole changes are the main "interesting" trigger (player physically moved hundreds of meters). The 600s timer covers the case of staying on one hole for >10 minutes (par-5 walk-up, waiting on the group ahead). All three triggers funnel through one `refresh()` method.
- **`WindAdvisory` lives in the domain.** Same pattern as `LocationFix`: a platform-free value type so the math/UI code can reason about it without importing WeatherKit.
- **Bearing math returns to `GolfGeometry`.** I removed `initialBearingDeg` during the GPS work per YAGNI; re-adding it now with an actual caller is the right move. Also add a `WindRelativeDirection.from(windFromDeg:shotBearingDeg:)` helper next to it so the categorization is unit-testable.
- **Fail soft.** A failed WeatherKit fetch (network, quota, no entitlement) leaves `LiveWindModel.advisory` unchanged and publishes a non-fatal `lastFetchError`. The base `RoundContext.wind` becomes `nil` only if there's never been a successful fetch — never reverts to nil after one succeeds.
- **No new `@Published` on every fix** — the model only republishes when a successful fetch produces a different advisory, to avoid SwiftUI churn.

## Open Questions

### Resolved During Planning

- **Where does live wind write?** The base `RoundContext`. The manual override is being removed in the same change (see Key Technical Decisions and Unit 7).
- **What replaces the override as a "force a specific value" tool?** The stub-wind chips in the Inspector developer section, which feed `LiveWindModel.advisory` directly via `StubWindProvider.emit(_:)`. Same path as real WeatherKit data, no precedence ambiguity.
- **How granular should the relative direction be?** Three buckets — match existing `WindRelativeDirection`. Mapping bands: ±45° from "behind shot" → helping, ±45° from "into shot" → hurting, otherwise → cross.
- **How often to refresh?** Round start + hole change + every 600s. WeatherKit free tier easily accommodates this.
- **Should the provider own a timer, or should the model?** The model. Provider stays single-purpose (fetch on demand); model owns lifecycle/cadence.
- **What about temperature / humidity / pressure?** Out of scope — recommendation engine doesn't use them.
- **Tee→green bearing — which tee?** The currently selected tee (`roundOverrides.teeSetId` or default). The bearing barely changes between tees on the same hole so this is a small detail, but use the selected tee for consistency.

### Deferred to Implementation

- **Exact WeatherKit error types to handle.** WeatherKit throws `WeatherError` enum cases; pick the right ones during implementation rather than trying to enumerate them here.
- **Whether to show a "wind ±N°" precision chip in the Caddie tab.** A nice-to-have UX detail; decide once the live readout is visible.
- **Whether the 600s timer should pause when the app goes inactive.** Default is to let it run — `Task` keeps going on foreground, suspends on background.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification.*

```
GPS fix (already wired)
   |
   v
LiveCourseLocationModel.lastFix.coordinate
   |
   v
LiveWindModel.setLocation(coord) ----+
                                      |
ContentView .onChange(selectedHole)   |---> WindProviding.fetch()
                                      |          |
600s Task timer (model-owned)  -------+          v
                                            WeatherKitWindProvider
                                                  |
                                                  v (async)
                                            WindAdvisory { dirFromDeg, speedMps, fetchedAt }
                                                  |
                                                  v
LiveWindModel computes shot bearing for current hole (GolfGeometry.bearingDeg)
   converts (dirFromDeg, shotBearingDeg) -> WindRelativeDirection
   publishes WindContext { relativeDirection, speedMps }
   |
   v
ContentView computes base RoundContext using live WindContext
   |
   v
HoleInspectorModel.makeEffectiveRoundContext(base, overrides)
   (after Unit 7: wind portion of overrides is gone; base.wind passes through)
   |
   v
NextShotRecommendationEngine (already consumes RoundContext.wind)
```

Three independent triggers (`location set`, `hole change`, `timer tick`) all funnel to one `refresh()` method on `LiveWindModel`, which is idempotent and cheap when called rapidly.

## Implementation Units

- [ ] **Unit 1: Domain — `WindAdvisory` value type + `WindProviding` protocol**

**Goal:** Introduce the platform-free domain types that the rest of the work hangs off of.

**Requirements:** R1, R2, R3

**Dependencies:** None.

**Files:**
- Create: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/WindProviding.swift`
- Test: `ios/TrueCaddieDomain/Tests/TrueCaddieDomainTests/WindAdvisoryTests.swift`

**Approach:**
- `WindAdvisory` struct: `directionDegFromNorth: Double` (meteorological convention — direction wind is FROM), `speedMps: Double`, `fetchedAt: Date`.
- `WindProvidingError` enum (for the failure callback): `notAuthorized`, `network(String)`, `unknown(String)`.
- `WindProviding` `@MainActor` protocol mirroring `LocationProviding`: `var onAdvisory: ((WindAdvisory) -> Void)?`, `var onError: ((WindProvidingError) -> Void)?`, `func setLocation(_ coordinate: GeoCoordinate2D)`, `func refresh()`. No `start()`/`stop()` — refresh is explicit, the model drives cadence.

**Patterns to follow:**
- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/LocationProviding.swift`

**Test scenarios:**
- Happy path: `WindAdvisory(directionDegFromNorth: 270, speedMps: 5, fetchedAt: now)` round-trips through `Equatable`.
- Edge case: `WindAdvisory` constructible with `directionDegFromNorth: 0` (due north) and `directionDegFromNorth: 359.9` without normalization concerns.
- Edge case: protocol can be conformed to by a minimal stub class in the test (verifies the protocol's surface is usable).

**Verification:**
- `swift build` on the domain package succeeds.
- `WindAdvisoryTests` pass.

---

- [ ] **Unit 2: Domain — bearing math + wind-categorization helper in `GolfGeometry`**

**Goal:** Restore `bearingDeg(from:to:)` (removed during the GPS-foundation YAGNI pass) and add the `windFromDeg + shotBearingDeg → WindRelativeDirection` helper.

**Requirements:** R2

**Dependencies:** Unit 1 (uses `WindAdvisory` only in tests; the math itself doesn't need the new types).

**Files:**
- Modify: `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/GolfGeometry.swift`
- Modify: `ios/TrueCaddieDomain/Tests/TrueCaddieDomainTests/GolfGeometryTests.swift`

**Approach:**
- `GolfGeometry.bearingDeg(from:to:) -> Double` — initial great-circle bearing in degrees clockwise from north, normalized to `[0, 360)`.
- `WindRelativeDirection.from(windFromDeg:shotBearingDeg:) -> WindRelativeDirection` extension. Compute `relative = (shotBearingDeg - windFromDeg) mod 360`. Map `[135, 225]` → `.helping`, `[315, 360) ∪ [0, 45]` → `.hurting`, otherwise `.cross`.
- Add a `Constants.windHelpingHurtingBandDeg = 45.0` so the bucket widths are tunable without code spelunking.

**Execution note:** Write the bearing and category tests first — both functions are pure with known reference values, so test-first is cheap and locks the math in before the rest of the plan starts depending on it.

**Patterns to follow:**
- The existing `GolfGeometry.haversineDistance(_:_:)` and `WindRelativeDirection` enum.

**Test scenarios:**
- Happy: bearing from Hole 1 White tee to Hole 1 green centre matches an externally computed value (compute reference in a sibling Python or by hand, ±1°).
- Happy: bearing east-to-due-east ≈ 90°; north-to-due-north ≈ 0° (when `to` is slightly north of `from`).
- Edge: bearing from a point to itself returns 0 without crashing.
- Edge: bearing is normalized — never negative, never ≥ 360°.
- Happy: `from(windFromDeg: 90, shotBearingDeg: 90)` returns `.hurting` (wind blowing right back at the shot).
- Happy: `from(windFromDeg: 270, shotBearingDeg: 90)` returns `.helping` (tailwind).
- Happy: `from(windFromDeg: 0, shotBearingDeg: 90)` returns `.cross` (90° off the shot line).
- Edge: `from(windFromDeg: 45, shotBearingDeg: 90)` (exactly on the `.hurting` boundary) returns `.hurting` (boundary-inclusive on the hurting side per the band defined above).
- Edge: `from(windFromDeg: 360, shotBearingDeg: 0)` is normalized correctly and returns `.hurting` (wind directly opposing).

**Verification:**
- `GolfGeometryTests` and the new wind-mapping tests pass.

---

- [ ] **Unit 3: Host — `WeatherKitWindProvider` + `StubWindProvider` + entitlement**

**Goal:** Wrap WeatherKit behind `WindProviding` and provide a deterministic stub for simulator/tests.

**Requirements:** R1, R3, R6, R7

**Dependencies:** Unit 1.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/WeatherKitWindProvider.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/StubWindProvider.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost.xcodeproj/project.pbxproj` (add WeatherKit framework link + `com.apple.developer.weatherkit = YES` capability entry to both Debug and Release configurations)

**Approach:**
- `WeatherKitWindProvider` (`@MainActor`, `final class`):
  - Holds `currentLocation: GeoCoordinate2D?`.
  - `setLocation(_:)` stores it; if missing, `refresh()` is a no-op (silently — first GPS fix will trigger a fresh refresh anyway).
  - `refresh()` launches a `Task` that calls `WeatherService.shared.weather(for: CLLocation(latitude:longitude:))`, reads `currentWeather.wind.speed.converted(to: .metersPerSecond).value` and `currentWeather.wind.direction.converted(to: .degrees).value`, builds a `WindAdvisory`, and invokes `onAdvisory(_:)` on `@MainActor`.
  - WeatherKit errors map to `WindProvidingError` and surface via `onError`. Last good advisory is the caller's concern (model holds state, provider is stateless beyond `currentLocation`).
- `StubWindProvider`:
  - `emit(_ advisory: WindAdvisory)` and `emitError(_ error: WindProvidingError)` for direct injection from the Inspector / tests.
  - `setLocation(_:)` and `refresh()` are no-ops (or echo the last emitted advisory on refresh, TBD during implementation).

**Patterns to follow:**
- `ios/TrueCaddieHost/TrueCaddieHost/App/CoreLocationProvider.swift` (framework wrapper, `@MainActor`, callback hand-off).
- `ios/TrueCaddieHost/TrueCaddieHost/App/StubLocationProvider.swift` (stub shape).
- The previous Info.plist edit in `project.pbxproj` (the GPS plan added `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` to both Debug and Release).

**Test scenarios:**
- `WeatherKitWindProvider` itself isn't unit-testable without WeatherKit credentials — only the *protocol conformance* matters. Skip dedicated unit tests for this class; coverage comes via `LiveWindModelTests` with the stub.
- StubWindProvider:
  - Happy: `emit(advisory)` → `onAdvisory` fires with that advisory.
  - Happy: `emitError(.network("…"))` → `onError` fires.
  - Edge: emit before any handler attached → no crash; emit after handler attached → fires.

**Verification:**
- App builds with the new WeatherKit capability and runs on the simulator (where WeatherKit returns no data, which is the expected stub-driven scenario).
- StubWindProvider tests pass.

---

- [ ] **Unit 4: Host — `LiveWindModel` observable**

**Goal:** Own the refresh lifecycle, derive the relative `WindContext` from the absolute advisory + current hole bearing, and publish state to SwiftUI.

**Requirements:** R1, R2, R3, R5, R6

**Dependencies:** Units 1, 2, 3.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/LiveWindModel.swift`
- Test: `ios/TrueCaddieHost/TrueCaddieHostTests/LiveWindModelTests.swift`

**Approach:**
- `@MainActor final class LiveWindModel: ObservableObject`.
- `@Published private(set) var advisory: WindAdvisory?` — last successful fetch.
- `@Published private(set) var windContext: WindContext?` — derived (current hole bearing + advisory).
- `@Published private(set) var lastFetchError: WindProvidingError?`.
- `currentHole: CourseHole?` (settable; ContentView writes via `.onChange`). When this changes, recompute `windContext` from the existing advisory without re-fetching.
- Initialiser: `init(provider: any WindProviding, bundle: CourseBundle, periodicRefreshSeconds: TimeInterval = 600)`.
- Owns a `Task` that loops `try await Task.sleep(for: .seconds(period))` then `provider.refresh()`. Task is cancelled on `deinit`.
- `setLocation(_:)` proxies to the provider, then calls `provider.refresh()`.
- `setCurrentHole(_:)` updates the stored hole and recomputes `windContext` from the existing advisory (no fetch); also calls `provider.refresh()` so the player gets fresh data after walking to a new hole.
- Categorization uses `WindRelativeDirection.from(windFromDeg:shotBearingDeg:)` (Unit 2) with the tee→green bearing of the current hole's selected tee.

**Patterns to follow:**
- `ios/TrueCaddieHost/TrueCaddieHost/App/LiveCourseLocationModel.swift` (state ownership, `@Published` discipline, callback wiring).

**Test scenarios:**
- Happy: feed an advisory via `StubWindProvider` with `directionDegFromNorth: 270, speedMps: 5`, set current hole to one whose tee→green bearing is roughly 90° (east) → `windContext` becomes `WindContext(relativeDirection: .helping, speedMps: 5)`.
- Happy: feed the same advisory then change current hole to one with bearing 270° → `windContext` becomes `.hurting`.
- Happy: hole-change with no advisory yet → `windContext` stays `nil`, no fetch loop crash.
- Edge: two successive identical advisories → `windContext` publishes only once (avoid SwiftUI churn). Optional polish — flag in the test as `// nice-to-have`.
- Error path: provider emits `.network("offline")` → `lastFetchError` becomes that value, `advisory` and `windContext` unchanged from prior good values.
- Error path: failure after a good fetch → good `advisory` and `windContext` persist; UI can show "stale" if it wants.
- Integration: setLocation → provider refresh called → advisory emitted → windContext derived. Exercises the full happy-path chain through stub provider.

**Verification:**
- `LiveWindModelTests` pass.
- Manual: tap a stub-wind chip in the Inspector developer section (added in Unit 6) and watch the Caddie tab readout (added in Unit 5) update.

---

- [ ] **Unit 5: Host — `ContentView` wiring and live readout in `CaddieRecommendationHero`**

**Goal:** Own `LiveWindModel` in `ContentView`, thread location + hole changes into it, build the dynamic base `RoundContext`, and surface a "Wind: 4 m/s, helping" chip in the Caddie tab.

**Requirements:** R1, R4, R5

**Dependencies:** Units 1–4.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift` (to pass the new `LiveWindModel` through)

**Approach:**
- `ContentView` (the `CaddieHostTabContainer` inside it):
  - Add `@StateObject private var windModel: LiveWindModel`, initialised with `WeatherKitWindProvider()` and the bundle.
  - Convert `baseRoundContext` from a stored `let` to a computed property that reads `windModel.windContext` and substitutes it into the previously-hardcoded `RoundContext.pilotSample` shape.
  - `.onAppear`: set initial hole on windModel; if `locationModel.lastFix` already exists, call `windModel.setLocation(_:)`.
  - `.onChange(of: locationModel.lastFix?.coordinate)`: forward to `windModel.setLocation(_:)`.
  - `.onChange(of: selectedHoleNumber)`: forward the current `CourseHole` to `windModel.setCurrentHole(_:)`.
- `CaddieRecommendationHero` grows a small `liveWindChip(_ context: WindContext)` underneath the live distance row, rendering `"Wind: 4 m/s helping"` (or similar). Add a constructor parameter `liveWind: WindContext?` defaulted to `nil` so existing call sites compile, then thread it from `CaddieTabView`.

**Patterns to follow:**
- The existing `livePinDistanceM` parameter on `CaddieRecommendationHero` and the way it was threaded from `CaddieTabView` in the GPS unit-4 work.
- The existing `@StateObject locationModel` ownership pattern in `ContentView`.

**Test scenarios:**
- This unit is mostly wiring/UI; covered by manual verification + the integration in Unit 4's stub-driven tests.
- Manual: launch, accept GPS prompt on device, watch the Caddie tab chip populate within ~5 seconds.
- Manual on simulator: tap stub-fix chip + stub-wind chip in the Inspector developer section; Caddie tab chip reflects both.

**Verification:**
- App builds.
- The Caddie hero shows a wind chip once both location and wind advisory are available.
- Toggling the Inspector "Wind" override still overrides the live value (`HoleInspectorModel.makeEffectiveRoundContext` keeps doing its job).

---

- [ ] **Unit 6: Host — Inspector live-wind readout + stub-wind chips**

**Goal:** Add a read-only live-wind row to `InspectorStrategySection` (replacing the area the override UI occupied — see Unit 7) and canned-advisory injectors in the developer section.

**Requirements:** R6

**Dependencies:** Units 1–4 (and Unit 5 for the threading pattern). Sequencing note: this can land before or after Unit 7; if it lands first, the live readout sits above the soon-to-be-removed override UI temporarily.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift` (thread `LiveWindModel` through)

**Approach:**
- `InspectorStrategySection`: when `liveWindModel.windContext` is non-nil, show a row reading `"Wind: 4 m/s helping"`. When it's nil and `lastFetchError` is set, show `"Wind unavailable — \(error description)"`. When both are nil (just launched), show `"Wind: warming up"`. Pure read-only display.
- `InspectorDeveloperSection`: add a "Stub wind" scroll row of chips mirroring the GPS chip row. Canned advisories:
  - `"5 m/s tailwind"` — direction set so it resolves to `.helping` against the current selected hole's bearing.
  - `"10 m/s headwind"` — `.hurting`.
  - `"8 m/s crosswind"` — `.cross`.
  - `"Calm"` — speed 0.
  - `"Error: offline"` — calls `stubWindProvider.emitError(.network("offline"))` so the error UX is reachable.
- Compute the canned-advisory direction at chip-tap time using the current selected hole's tee→green bearing so the chips remain accurate as the player walks the course.

**Patterns to follow:**
- The existing stub-GPS chip row in `InspectorDeveloperSection` and its `stubFixes(for:)` helper.
- The existing `liveWindModel`-threading approach from Unit 5.

**Test scenarios:**
- This unit is UI; covered by manual smoke. No new XCTest cases.

**Verification:**
- Stub-wind chips in the Inspector developer section trigger live-wind chip updates on the Caddie tab.
- Live wind readout in `InspectorStrategySection` matches what's published.

---

- [ ] **Unit 7: Remove the manual wind override**

**Goal:** Rip out the now-redundant manual wind override (state + UI + merge logic + tests) so live wind is the single source of truth.

**Requirements:** R7

**Dependencies:** Units 4 and 5 must land first (so the live source is in place and feeding the base `RoundContext`). Unit 6 can land before or after.

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/BundleInspector/BundleInspectorView.swift` — remove `windEnabled`, `windDirection`, `windSpeedMps` fields from `RoundOverrideState` (~line 882–887), the corresponding constructor params and merge logic (`makeRoundOverrideState`, `makeEffectiveRoundContext` around line 1118 and 1133), and the wind UI block in the same file (~lines 263–266).
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift` — remove the `Toggle("Wind", isOn:)`, `Picker("Direction", selection:)`, `LabeledContent("Speed", ...)`, and the wind `Slider` (~lines 29–41). The new live-wind readout from Unit 6 takes that space.
- Modify: `ios/TrueCaddieHost/TrueCaddieHostTests/TrueCaddieHostTests.swift` — remove `windSpeedMps:` references (lines 150, 173, 301) and any test that exercised the override toggle directly.
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — if any `onChange(of: roundOverrides)` paths depend on the wind fields, simplify them. (Search for `wind` in this file during execution.)

**Approach:**
- Remove fields first, follow the compile errors. The Swift compiler enumerates every call site that referenced the removed fields, so the cleanup is mechanical once the struct shrinks.
- `HoleInspectorModel.makeEffectiveRoundContext(...)` should now just pass the base `RoundContext.wind` through unchanged — no merge with overrides.
- Check the voice-session wire types (`ios/TrueCaddieHost/TrueCaddieHost/App/VoiceWireTypes.swift` lines 39–40): `windRelativeDirection` and `windSpeedMps` on `WireRoundContextSnapshot` stay — they serialize the effective wind, which now equals the base wind, which now equals the live wind. No change.

**Patterns to follow:**
- No new pattern; this is a deletion. The compile-error-driven cleanup pattern is the same one we used during the GPS-foundation YAGNI passes.

**Test scenarios:**
- Edge: existing tests that built a `RoundOverrideState` with `windSpeedMps: X` need to drop that argument. Verify the affected tests still assert the right thing about the *effective* wind (which now comes from the base `RoundContext`, not the override).
- Integration: a test that constructs `RoundContext(... wind: .helping/5)` and runs the recommendation engine through it produces the same packet as before. (The recommendation engine doesn't care where the wind came from — it just reads `RoundContext.wind`.)
- Test expectation: no new feature behavior; this unit is pure removal.

**Verification:**
- App builds with no references to the removed fields.
- `TrueCaddieHostTests` pass after the test-side edits.
- The Inspector strategy section no longer shows the wind toggle/picker/slider.
- The Caddie tab still shows the wind chip from Unit 5, driven by live or stubbed wind via Unit 6.

## System-Wide Impact

- **Interaction graph:** New flow `LiveWindModel ← (WindProviding | timer | onChange selectedHole | onChange location)`. ContentView grows a second observable, parallel to `LiveCourseLocationModel`. Nothing else changes structure.
- **Error propagation:** WeatherKit failures stay inside `LiveWindModel.lastFetchError`. They never invalidate prior good wind data. They never crash the app or block the recommendation engine.
- **State lifecycle risks:** The model owns a long-lived refresh `Task`. Must be cancelled on `deinit`. Not auto-paused on app background — that's fine for v1.
- **API surface parity:** `HostCaddieSession` wire serialization already includes `windRelativeDirection` and `windSpeedMps` (see `ios/TrueCaddieHost/TrueCaddieHost/App/VoiceWireTypes.swift`). It picks up live wind automatically through the base `RoundContext` — no voice-session changes needed.
- **Integration coverage:** The provider → model → ContentView → engine chain is exercised manually + via the Unit 4 integration test using the stub provider.
- **Removed surfaces (Unit 7):**
  - `RoundOverrideState.windEnabled`, `.windDirection`, `.windSpeedMps` fields and their constructor params.
  - The wind `Toggle` / `Picker` / `Slider` blocks in `InspectorStrategySection` and `BundleInspectorView`.
  - The override-merge branch for wind in `HoleInspectorModel.makeEffectiveRoundContext` — it now passes `base.wind` through unchanged.
  - Test fixtures that set `windSpeedMps:` on `RoundOverrideState`.
- **Unchanged invariants:**
  - `RoundContext.pilotSample` still exists for previews/tests that need a deterministic value.
  - `WindContext` shape and `WindRelativeDirection` cases are unchanged.
  - `NextShotRecommendationEngine` is not touched.
  - Voice-session wire types (`WireRoundContextSnapshot.windRelativeDirection` / `windSpeedMps`) are unchanged — they serialize the effective wind regardless of source.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| WeatherKit capability/entitlement not enabled in the Apple Developer portal for the bundle ID | First successful run on a real device will surface a clear WeatherKit error; the stub path keeps the simulator usable while it's being configured. |
| WeatherKit free quota exhaustion (500k/month) | At ~6/hour/user the headroom is huge, but bursting from short-interval debugging is possible. Keep the 600s period; don't shorten for "snappier" iteration. |
| Bearing math drift across the GPS-relevant area | Already validated for haversine distance; the same equirectangular projection isn't used for bearing (great-circle bearing formula is direct), so it's robust at any hole-scale. |
| Stale wind when player stands still for >10 min | Acceptable for v1. The next hole change refetches; the next timer tick refetches. |
| WeatherKit returning unexpected units (some regions get Imperial defaults) | `Measurement.converted(to:)` neutralises this — speed always becomes m/s, direction always becomes degrees. |
| User permission semantics — WeatherKit doesn't prompt the user but the entitlement implies data use | Add a brief mention in the existing privacy copy if/when there is one; no UI gating needed for v1. |

## Documentation / Operational Notes

- The WeatherKit capability addition is a one-time portal step. Document it in the project README's "First-time setup" section if one exists; otherwise note it inline in `WeatherKitWindProvider.swift`.
- No new feature flag — live wind ships on by default. The manual override toggle is the existing escape hatch.

## Sources & References

- Related code:
  - `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/RoundContext.swift`
  - `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/GolfGeometry.swift`
  - `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/LocationProviding.swift`
  - `ios/TrueCaddieHost/TrueCaddieHost/App/CoreLocationProvider.swift`
  - `ios/TrueCaddieHost/TrueCaddieHost/App/LiveCourseLocationModel.swift`
  - `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift`
- Related plan: [2026-05-17-001-feat-gps-location-positioning-plan.md](docs/plans/2026-05-17-001-feat-gps-location-positioning-plan.md)
- External docs: Apple WeatherKit Swift documentation (`WeatherService`, `Weather.currentWeather.wind`).
