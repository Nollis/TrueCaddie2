---
title: "feat: Welcome screen, GPS course picker, and round lifecycle gates"
type: feat
status: active
date: 2026-05-18
---

# feat: Welcome screen, GPS course picker, and round lifecycle gates

## Overview

The app currently launches cold into the Caddie tab on Kungsbacka Nya with whatever round state was
last persisted — no greeting, no course selection, no explicit start, no finish ceremony. This plan
introduces a proper end-user journey: a Welcome screen surfaces the GPS-closest course, the user
taps **Start Round**, plays through all holes, and the round ends automatically when the last hole is
completed. The Inspector tab moves behind a developer toggle in a new Settings screen.

## Problem Frame

Five UX problems to fix in one cohesive sweep:

1. **Cold-start disorientation** — the user lands inside an active hole with no orientation or
   intent-setting step.
2. **No course selection** — `ContentView` hard-wires `HostCourseBundleStore.loadKungsbackaNya()`;
   no picker, no GPS suggestion.
3. **No explicit round start** — `CaddieHostTabContainer` initialises round state from
   `UserDefaults` automatically; there is no "I want to play now" gesture.
4. **No round completion ceremony** — when the final hole is finished the app just stays on the last hole.
   `HostRoundProgressModel` already computes `isRoundComplete` but nothing acts on it.
5. **Inspector tab always visible** — real users see a confusing developer/debug tab.

## Requirements Trace

- R1. App launches to a Welcome screen, not directly into the Caddie tab.
- R2. Welcome screen ranks nearby courses by GPS proximity and highlights the closest one.
- R3. User explicitly selects a course and taps **Start Round** before play begins.
- R4. A round ends automatically when the final hole is marked complete (`isRoundComplete = true`).
- R5. A Round Summary screen is shown on completion with full scorecard and a **New Round** action.
- R6. Inspector tab is hidden by default; a developer toggle in Settings makes it visible.
- R7. Settings screen is reachable from the Welcome screen toolbar.
- R8. Course registry is extensible; the pilot ships with Kungsbacka Nya as the sole bundled course.

## Scope Boundaries

- No remote course catalog or download flow (courses stay as local bundle JSON files).
- No user account, profile, or cloud sync.
- No round handicap computation or stroke-index display on the summary.
- No in-round "abandon round" confirmation dialog (tap New Round from summary, or use Inspector reset).
- Tee selection (white/yellow/etc.) is deferred; the default tee is used, consistent with today.

### Deferred to Separate Tasks

- Tee-set picker on the Start Round screen: separate iteration once multi-tee UX is designed.
- "Resume saved round" prompt on launch: natural follow-on once the welcome screen exists.
- Remote course catalog and download: separate infrastructure task.

## Context & Research

### Relevant Code and Patterns

- `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — current root; owns `@State`/`@StateObject`
  for all round data inside the private `CaddieHostTabContainer` struct; the insertion point for the
  pre-round / in-round state router.
- `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift` — single-course loader;
  extension point for the course registry and multi-course loading.
- `ios/TrueCaddieHost/TrueCaddieHost/App/LiveCourseLocationModel.swift` — `@MainActor
  ObservableObject` already publishing `lastFix`; reuse as the GPS source for course proximity.
- `ios/TrueCaddieHost/TrueCaddieHost/App/CoreLocationProvider.swift` — `CLLocationManager`
  bridge; "When In Use" authorisation already in place.
- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/GolfGeometry.swift` — `haversineDistance`
  available for proximity ranking.
- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/CourseBundleModels.swift` — `CourseBundle`,
  `CourseHole`, `Tee`; tee coordinates are GeoJSON `[lon, lat]` pairs.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift` —
  canonical example of `@AppStorage("truecaddie.developerToolsEnabled")` gating.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorRoundSection.swift` —
  `onResetRound` pattern; scorecard rendering to reuse in summary view.

### Institutional Learnings

- **Coordinate order pitfall**: course bundle coordinates are GeoJSON `[longitude, latitude]`; always
  use `GeoCoordinate2D(lonLatPair:)` when reading from bundles. Never pass raw `CLLocation` values
  directly into `GolfGeometry` functions.
- **Import discipline**: `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — every new host
  file that uses domain types must carry an explicit `import TrueCaddieDomain`.
- **Xcode 16 auto-sync**: `PBXFileSystemSynchronizedRootGroup` is active — new `.swift` files under
  the `TrueCaddieHost` folder are picked up automatically on next Xcode open; no `project.pbxproj`
  edit needed.
- **No `@EnvironmentObject`**: the project wires dependencies as explicit init parameters or
  `@ObservedObject var` properties; do not introduce environment injection.
- **`@AppStorage` key namespace**: `"truecaddie.<feature>.<key>"` — follow this for any new
  persisted flags.
- **`import CoreLocation` forbidden in domain layer** — proximity ranking must live in the host
  layer, not `TrueCaddieDomain`.

## Key Technical Decisions

- **ContentView becomes a state router, not a container**: `ContentView` switches between
  `WelcomeView` and `CaddieHostTabContainer` based on whether a round is active. This keeps the
  welcome screen outside the tab hierarchy while preserving `CaddieHostTabContainer`'s existing
  ownership of all in-round state.

- **CourseDescriptor lives in HostCourseBundleStore**: a lightweight value type capturing `id`,
  `name`, `bundleResourceName`, and `centerCoordinate`. The registry is a `static let` array.
  Bundle loading stays lazy (on Start Round tap), keeping cold launch fast.

- **CourseProximityModel observes `LiveCourseLocationModel.lastFix`, not a second provider**:
  `LocationProviding` has a single-subscriber `onFix` closure; wiring two models to one provider
  would require a multicast wrapper. The simpler approach: `CourseProximityModel` accepts
  `LiveCourseLocationModel` (the already-lifted model) as its data source and reacts to
  `lastFix` via `objectWillChange` or an injected callback. This avoids a second
  `CLLocationManager` and a second authorization request. `CourseProximityModel` remains a
  separate `@MainActor ObservableObject` so its proximity logic and published state are
  independently testable (using `StubLocationProvider` → mock `LiveCourseLocationModel`).

- **LiveCourseLocationModel is lifted to ContentView scope**: it is already needed for GPS, and
  the welcome screen needs a location fix for proximity ranking. Creating it in `ContentView` (not
  `CaddieHostTabContainer`) means GPS is running while the user is on the welcome screen.
  `CaddieHostTabContainer` receives it as an `@ObservedObject` parameter — same as today.

- **Inspector tab gated by existing `developerToolsEnabled` key**: reuse
  `@AppStorage("truecaddie.developerToolsEnabled")` inside `CaddieHostTabContainer.body` to
  conditionally include the Inspector tab item. No new key, no new mechanism.

- **SettingsView is accessible from both WelcomeView and the active round**: a toolbar gear button
  on `WelcomeView` and an identical gear button in `CaddieTabView`'s toolbar both present
  `SettingsView` as a sheet. This ensures the Developer Tools toggle is reachable mid-round — a
  developer who hides the Inspector tab can re-enable it without abandoning the round.

- **`Start Round` explicitly clears saved round state before starting**: the `onStartRound` closure
  in `ContentView` calls `HostRoundProgressStore.delete(courseId:)` on the selected course before
  setting `roundActive = true`. This prevents `CaddieHostTabContainer.init` from loading a stale
  partial round from UserDefaults. A `delete(courseId:)` method is added to
  `HostRoundProgressStore` in Unit 1.

- **`selectedTab` is reset to `.caddie` on every new round start**: inside the `onStartRound`
  closure, `selectedTab` is set to `.caddie` before `roundActive = true`, so every new round
  opens on the Caddie tab regardless of which tab was active when the last round ended.

- **RoundSummaryView is a `.sheet` from CaddieHostTabContainer**: triggered by `.onChange` on
  `roundState` detecting `isRoundComplete`. Presents scorecard and a **New Round** button that
  calls back to `ContentView` to return to the welcome screen. The sheet sets
  `.interactiveDismissDisabled(true)` and the `onDismiss` handler re-asserts `showRoundSummary =
  true` to prevent the user returning to the completed round without explicitly starting a new one.

- **Voice session is paused when the round summary sheet appears**: when `showRoundSummary` is set
  to `true`, `voiceController.stopListening()` is called immediately. The session is not
  disconnected (preserving the WebRTC connection state) — the user may still tap **New Round** and
  have the voice session available in the new round. Full `voiceController.disconnect()` happens in
  `CaddieHostTabContainer.onDisappear`, which fires when `ContentView` replaces the container with
  `WelcomeView`.

## Open Questions

### Resolved During Planning

- **Should `LiveCourseLocationModel` be lifted or duplicated?** Lift to `ContentView` scope — GPS
  runs for the full session, and creating two instances would cause redundant location updates.

- **Which AppStorage key gates the Inspector tab?** Reuse `"truecaddie.developerToolsEnabled"` —
  it already exists, the `InspectorDeveloperSection` already reads it, and there is no reason to
  separate "show dev tools within Inspector" from "show Inspector tab at all".

- **Does the Round Summary clear UserDefaults?** Yes — when **New Round** is tapped,
  `HostRoundProgressStore.delete(courseId:)` is called and then `onRoundEnded` fires, removing
  `CaddieHostTabContainer` from the view tree and returning to `WelcomeView`.

- **What is the "center coordinate" for GPS proximity ranking?** Use the coordinate of the first
  tee on hole 1 (`holes[0].tees.first(where: { $0.isDefault == true }) ?? holes[0].tees[0]`) as a
  stable representative point. Consistent with how `HoleDetector` seeds proximity.

- **Should `Start Round` clear saved UserDefaults progress?** Yes — the `onStartRound` closure
  calls `HostRoundProgressStore.delete(courseId:)` before constructing the container. Without
  this, `CaddieHostTabContainer.init` would reload the old partial round silently, making the
  "fresh round" guarantee impossible to verify.

- **How does `CourseProximityModel` get location fixes without a second `CLLocationManager`?**
  It observes `LiveCourseLocationModel.lastFix` (the lifted model in `ContentView`) rather than
  owning its own `LocationProviding` subscription. This avoids a multicast wrapper and a second
  authorization request.

- **Should `WelcomeView` auto-select the first ranked course?** Only when `selectedDescriptor ==
  nil` — the auto-select guard checks `selectedDescriptor == nil` before assigning, preventing GPS
  fix updates from clobbering a manual selection.

- **How many holes triggers round completion?** `bundle.holes.count` — not hardcoded 18. Kungsbacka
  Nya is a 9-hole course for the pilot. All test scenarios use the bundle count, not 18.

### Deferred to Implementation

- **Exact threshold for "nearby" label**: the welcome screen copy ("Closest course", distance badge)
  depends on how many courses are registered and how far the player is. Implement as a display
  decision in `WelcomeView`; no domain rule needed.
- **Animation/transition between WelcomeView and CaddieHostTabContainer**: choose at implementation
  time based on feel (`.transition(.opacity)` vs slide).
- **What to show on WelcomeView when GPS is denied or unavailable**: implement a graceful fallback
  (show full course list alphabetically) — the exact empty-state copy is an implementation detail.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not
> implementation specification. The implementing agent should treat it as context, not code to
> reproduce.*

**App-level state machine** (owned by `ContentView`):

```
┌─────────────────────────────────────────────────────────────────┐
│  ContentView                                                    │
│                                                                 │
│  @StateObject  locationModel: LiveCourseLocationModel           │
│  @StateObject  proximityModel: CourseProximityModel             │
│  @State        activeBundle: CourseBundle?   = nil              │
│  @State        roundActive: Bool             = false            │
│                                                                 │
│  if roundActive, let bundle = activeBundle                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  CaddieHostTabContainer(bundle:, locationModel:,         │   │
│  │                         onRoundEnded: { roundActive=false│   │
│  │                                         activeBundle=nil })  │
│  └──────────────────────────────────────────────────────────┘   │
│  else                                                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  WelcomeView(proximityModel:,                            │   │
│  │              onStartRound: { bundle in                   │   │
│  │                activeBundle = bundle                     │   │
│  │                roundActive = true })                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Round completion path** (inside `CaddieHostTabContainer`):

```
finishSelectedHole(strokesTaken:)
    → roundState updated (value type)
    → .onChange(of: roundState) fires
        → HostRoundProgressModel.summary(...).isRoundComplete == true
            → @State showRoundSummary = true
                → .sheet: RoundSummaryView(roundState:, bundle:,
                                           onNewRound: onRoundEnded)
```

**Course proximity ranking** (inside `CourseProximityModel`):

```
LocationProviding.onFix
    → for each CourseDescriptor in registry
        distance = GolfGeometry.haversineDistance(fix.coordinate,
                                                   descriptor.centerCoordinate)
    → sort ascending by distance
    → publish rankedCourses
```

## Implementation Units

---

- [ ] **Unit 1: Course registry and multi-bundle loader**

**Goal:** Extend `HostCourseBundleStore` with a `CourseDescriptor` type and a static course
registry, and generalise bundle loading so any registered course can be loaded by ID.

**Requirements:** R2, R8

**Dependencies:** None

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift`

**Approach:**
- Add `struct CourseDescriptor`: `id: String`, `name: String`, `bundleResourceName: String`,
  `centerCoordinate: GeoCoordinate2D`. Conforms to `Identifiable`, `Equatable`.
- Add `static let availableCourses: [CourseDescriptor]` with the Kungsbacka Nya entry.
  `centerCoordinate` is **hard-coded at authoring time**: open the bundle JSON, read
  `holes[0].tees` for the entry with `"isDefault": true` (or the first tee if none is flagged),
  and write those `[lon, lat]` values as a `GeoCoordinate2D(lon:lat:)` literal in the descriptor.
  Do not compute this at runtime; the coordinate is a stable property of the course layout and
  hard-coding keeps `CourseDescriptor` a simple value type with no bundle dependency.
- Add `static func load(_ descriptor: CourseDescriptor) -> Result<CourseBundle, Error>` — mirrors
  the existing `loadKungsbackaNya()` but resolves `bundleResourceName` via `Bundle.main`.
- Add `static func delete(courseId: String)` to `HostRoundProgressStore` — removes the
  `"truecaddie.round-progress.<courseId>"` key from `UserDefaults.standard`. Called by
  `ContentView`'s `onStartRound` closure and by `RoundSummaryView`'s **New Round** action.
- Keep `loadKungsbackaNya()` as a non-deprecated call-through to avoid breaking `ContentView`
  during the migration; it will be removed in Unit 3.

**Patterns to follow:**
- Existing `loadKungsbackaNya()` in `HostCourseBundleStore.swift`.
- `GeoCoordinate2D` from `GolfGeometry.swift`; use `(lon:lat:)` init, not `lonLatPair:` (that init
  is for decoding `[Double]` arrays from JSON).

**Test scenarios:**
- Happy path: `HostCourseBundleStore.load(availableCourses[0])` returns `.success` with a bundle
  whose `courseId` matches the descriptor `id`.
- Edge case: A descriptor with a non-existent `bundleResourceName` returns `.failure`.
- Happy path: `availableCourses` is non-empty and the Kungsbacka Nya entry has a valid
  `centerCoordinate` with longitude in roughly `[11–13]` and latitude in roughly `[57–58]`.

**Verification:**
- `HostCourseBundleStore.availableCourses` compiles and contains exactly one entry.
- `load(_:)` succeeds for that entry in a unit test or a fresh app run.

---

- [ ] **Unit 2: CourseProximityModel**

**Goal:** New `@MainActor ObservableObject` that accepts a `LocationProviding` instance and the
course registry, and publishes courses sorted by distance from the player's last GPS fix.

**Requirements:** R2

**Dependencies:** Unit 1 (needs `CourseDescriptor` and `availableCourses`)

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/App/CourseProximityModel.swift`

**Approach:**
- `@MainActor final class CourseProximityModel: ObservableObject`
- `@Published var rankedCourses: [CourseDescriptor] = []` — empty until first fix arrives.
- Init takes `locationModel: LiveCourseLocationModel` and `courses: [CourseDescriptor]`.
  Does **not** take a `LocationProviding` directly — it observes `locationModel.lastFix` via
  `locationModel.objectWillChange` sink (or by receiving an injected callback from `ContentView`
  in `locationModel`'s `.onChange` handler). This avoids a second `CLLocationManager` and a
  second authorization request.
- When a new `lastFix` arrives: compute `GolfGeometry.haversineDistance` from `fix.coordinate` to
  each descriptor's `centerCoordinate`; sort ascending; publish to `rankedCourses`.
- Publish `locationModel.authorizationStatus` forwarded as a convenience computed property for
  `WelcomeView` to read (no new stored property needed — just a `var authorizationStatus`
  forwarding to `locationModel.authorizationStatus`).
- All location accuracy filtering is already handled upstream by `LiveCourseLocationModel`; only
  non-nil `lastFix` values need to trigger ranking.
- Add `import TrueCaddieDomain` explicitly (SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY).

**Patterns to follow:**
- `LiveCourseLocationModel.swift` — same `@MainActor ObservableObject`, no Combine pipelines.
- For testability: accept a `LocationFix?` feed via a closure or pass a mock `LiveCourseLocationModel` subclass.

**Test scenarios:**
- Happy path: given two descriptors and a fix closer to descriptor B, `rankedCourses[0]` is B.
- Happy path: `lastFix == nil` → `rankedCourses` is empty.
- Edge case: single descriptor in registry → `rankedCourses` has one entry after any fix.
- Edge case: two fixes arrive in sequence with different closest courses → `rankedCourses[0]`
  updates correctly both times (no stale ordering).

**Verification:**
- Given a mock that emits a fix near descriptor B's coordinate: `rankedCourses[0] == B`.

---

- [ ] **Unit 3: WelcomeView and ContentView state router**

**Goal:** Replace `ContentView`'s direct `CaddieHostTabContainer` construction with a pre-round /
in-round router. Add `WelcomeView` with GPS-ranked course list and **Start Round** CTA.

**Requirements:** R1, R2, R3, R7

**Dependencies:** Units 1 and 2

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Welcome/WelcomeView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`

**Approach — ContentView:**
- Create `@StateObject private var locationModel: LiveCourseLocationModel` (moved from
  `CaddieHostTabContainer`) using a single `CoreLocationProvider()`.
- Create `@StateObject private var proximityModel: CourseProximityModel` initialised with
  `locationModel` and `HostCourseBundleStore.availableCourses`.
- Add `@State private var activeBundle: CourseBundle? = nil`,
  `@State private var roundActive = false`, and `@State private var selectedTab: CaddieHostTab = .caddie`.
- Body: `if roundActive, let bundle = activeBundle { CaddieHostTabContainer(bundle:,
  locationModel:, selectedTab: $selectedTab, onRoundEnded: { ... }) } else { WelcomeView(...) }`.
- Remove `loadKungsbackaNya()` call; bundle loading happens in the `onStartRound` closure.
- `onStartRound(bundle)` closure: (1) call `HostRoundProgressStore.delete(courseId: bundle.courseId)`,
  (2) set `selectedTab = .caddie`, (3) set `activeBundle = bundle`, (4) set `roundActive = true`.
- `onRoundEnded` closure: set `roundActive = false`, `activeBundle = nil`.
- Thread `locationModel` into `CaddieHostTabContainer` as an `@ObservedObject` parameter.

**Approach — WelcomeView:**
- Receives `proximityModel: CourseProximityModel` as `@ObservedObject` and
  `onStartRound: (CourseBundle) -> Void` callback.
- Layout: app title header, "Nearby" section listing `proximityModel.rankedCourses` (or a state-
  specific placeholder), a **Start Round** button enabled only when a course is selected.
- Course row shows name and distance (formatted as "X km" or "X m"). Top result gets a "Closest"
  badge.
- On **Start Round**: call `HostCourseBundleStore.load(selectedDescriptor)`. On success, call
  `onStartRound(bundle)`. On failure, show an alert.
- Toolbar trailing item: gear `Button` → `@State var showSettings = true` → `.sheet { SettingsView() }`.
- GPS state handling (three distinct states read from `proximityModel.authorizationStatus`):
  - `.notDetermined` → show "Requesting location…" placeholder; the system permission dialog
    fires automatically once `LiveCourseLocationModel` starts.
  - `.denied` or `.restricted` → show full course list from `HostCourseBundleStore.availableCourses`
    alphabetically, with a note: "Location unavailable — showing all courses."
  - `.authorized` (but `rankedCourses` is empty) → show "Finding nearest course…" spinner.
  - `.authorized` and `rankedCourses` non-empty → show ranked list.
- `@State private var selectedDescriptor: CourseDescriptor?` — auto-selects `rankedCourses.first`
  **only when `selectedDescriptor == nil`**, preventing GPS updates from overriding a manual pick.

**Patterns to follow:**
- `CaddieTabView.swift` for SwiftUI layout conventions (VStack, `.padding`, `.background`).
- `InspectorDeveloperSection.swift` for `@AppStorage` and `@State` sheet presentation patterns.

**Test scenarios:**
- Happy path: `proximityModel.rankedCourses` has one entry → course row visible, **Start Round**
  enabled, tapping it calls `onStartRound` with the loaded bundle.
- Happy path: `onStartRound` is called → `ContentView` transitions to `CaddieHostTabContainer`
  (no `WelcomeView` visible).
- Edge case: `rankedCourses` is empty (no GPS fix yet) → **Start Round** disabled, placeholder
  text visible.
- Error path: `HostCourseBundleStore.load` fails → alert shown, user stays on `WelcomeView`.
- Integration: gear icon tap → `SettingsView` sheet presented.

**Verification:**
- Fresh app launch shows `WelcomeView`, not the Caddie tab.
- After tapping **Start Round**, the Caddie tab is visible and the round state is fresh (no
  leftover holes).

---

- [ ] **Unit 4: SettingsView and Inspector tab gating**

**Goal:** New `SettingsView` sheet with a Developer Tools toggle. Inspector tab in
`CaddieHostTabContainer` conditionally rendered based on the toggle.

**Requirements:** R6, R7

**Dependencies:** Unit 3 (SettingsView is presented from WelcomeView)

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Settings/SettingsView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` (Inspector tab condition)
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift` (gear toolbar button)

**Approach — SettingsView:**
- Simple `Form` with a `Toggle("Developer Tools", isOn: $developerToolsEnabled)`.
- `@AppStorage("truecaddie.developerToolsEnabled") private var developerToolsEnabled = false`
  — same key already used in `InspectorDeveloperSection`.
- Footer text: `"Enables the Inspector tab and debug controls. For development use only."` —
  consistent with the existing footer pattern in `InspectorDeveloperSection`.
- Navigation title `"Settings"`. Presented as a `.sheet` from **both** `WelcomeView` and
  `CaddieTabView` (via an identical gear toolbar button in each).
- Optionally show app version string (`Bundle.main.infoDictionary["CFBundleShortVersionString"]`).

**Approach — Inspector tab gating in CaddieHostTabContainer:**
- Add `@AppStorage("truecaddie.developerToolsEnabled") private var showInspector = false` inside
  `CaddieHostTabContainer`.
- Wrap the Inspector `tabItem` block in `if showInspector { ... }`.
- When the toggle flips during an active round, the tab appears/disappears immediately (SwiftUI
  re-renders automatically via `@AppStorage`).

**Approach — Settings entry point in CaddieTabView:**
- Add `@State private var showSettings = false` to `CaddieTabView`.
- Add `.toolbar { ToolbarItem(placement: .topBarTrailing) { Button(systemImage: "gearshape") {
  showSettings = true } } }` and `.sheet(isPresented: $showSettings) { SettingsView() }`.

**Patterns to follow:**
- `InspectorDeveloperSection.swift` — `@AppStorage` key, `Toggle` in `Form`, footer text style.

**Test scenarios:**
- Happy path: `developerToolsEnabled = false` (default) → Inspector tab absent from `TabView`.
- Happy path: `developerToolsEnabled = true` → Inspector tab present.
- Integration: toggle in `SettingsView` persists across app restarts (AppStorage).
- Happy path: toggling on mid-round → Inspector tab appears immediately without disrupting Caddie
  tab.

**Verification:**
- Fresh install: gear icon → Settings sheet visible; toggle is off; Inspector tab absent.
- After toggling on: dismiss Settings; Inspector tab is visible in the active round.

---

- [ ] **Unit 5: Round completion detection and RoundSummaryView**

**Goal:** Detect when the final hole is completed and present a `RoundSummaryView` sheet with the
full scorecard and a **New Round** action.

**Requirements:** R4, R5

**Dependencies:** Unit 3 (needs `onRoundEnded` callback wired in `ContentView`)

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/RoundSummary/RoundSummaryView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` (add `@State showRoundSummary`)

**Approach — detection in CaddieHostTabContainer:**
- Add `@State private var showRoundSummary = false`.
- In the existing `.onChange(of: roundState)` handler, after persisting, check
  `HostRoundProgressModel.summary(roundState:...).isRoundComplete`. If true **and
  `!showRoundSummary`**, call `voiceController.stopListening()` then set `showRoundSummary = true`.
- Add `.sheet(isPresented: $showRoundSummary, onDismiss: { if /* round still complete */ true {
  showRoundSummary = true } }) { RoundSummaryView(...) }` — the `onDismiss` handler re-asserts the
  sheet if it was dismissed by any means other than the **New Round** button, ensuring the user
  cannot return to the completed round without explicitly starting a new one.
- Add `.onDisappear { voiceController.disconnect() }` to `CaddieHostTabContainer` — ensures mic
  and WebRTC resources are released when `ContentView` swaps in `WelcomeView`.

**Approach — RoundSummaryView:**
- Receives `bundle: CourseBundle`, `roundState: RoundState`, `onNewRound: () -> Void`.
- Shows: "Round complete" headline, total score vs par, per-hole scorecard rows (reuse or mirror
  the scorecard rendering already present in `InspectorRoundSection`).
- Hole count in all copy uses `bundle.holes.count`, not a hardcoded 18 — Kungsbacka Nya is 9 holes.
- **New Round** button: calls `HostRoundProgressStore.delete(courseId: bundle.courseId)` then
  `onNewRound()` → `ContentView` clears `activeBundle` and `roundActive` → `WelcomeView` shown.
- `.interactiveDismissDisabled(true)` — the round is over; the primary exit is **New Round**.
  The `onDismiss` re-show in the parent is a safety net for edge-case dismissal paths.

**Patterns to follow:**
- Scorecard rendering in `InspectorRoundSection.swift`.
- `HostRoundProgressModel.summary(...)` for `isRoundComplete`, `finishedHoleCount`,
  `totalHoleCount`.

**Test scenarios:**
- Happy path: `roundState` with all `bundle.holes.count` holes finished → `isRoundComplete == true`
  → sheet presented and voice session stops listening.
- Happy path: `RoundSummaryView` renders correct total strokes and per-hole scores; hole count
  matches `bundle.holes.count` (9 for Kungsbacka Nya), not 18.
- Happy path: tapping **New Round** calls `delete(courseId:)`, dismisses sheet, returns to
  `WelcomeView`.
- Edge case: `roundState` with `bundle.holes.count - 1` holes finished → sheet not presented.
- Integration: round summary → **New Round** → `WelcomeView` → **Start Round** → fresh round state
  (no leftover holes; scorecard shows all holes as unplayed).
- Edge case: `isRoundComplete` fires in `.onChange` twice — `if !showRoundSummary` guard ensures
  the voice stop and sheet-show happen exactly once.
- Edge case: summary sheet dismissed via system gesture (not **New Round**) → `onDismiss` handler
  re-shows sheet; user cannot return to the completed round.
- Integration: `CaddieHostTabContainer` `.onDisappear` fires after **New Round** → `WelcomeView`
  appears and no WebRTC connection or microphone is held.

**Verification:**
- Complete all holes via Inspector stub controls → summary sheet appears; caddie voice stops.
- Tap **New Round** → Welcome screen shown; starting a new round shows a completely clean scorecard.
- Relaunch after a completed round → Welcome screen shown (not the old completed round).

---

## System-Wide Impact

- **Interaction graph:** `ContentView` now owns `LiveCourseLocationModel` and
  `CourseProximityModel` as `@StateObject`; `CaddieHostTabContainer` receives `locationModel` as a
  parameter. The wind model remains scoped to the in-round container. Voice session controller
  continues to be created inside `CaddieHostTabContainer.init`.
- **Error propagation:** Bundle load failure (currently a `ContentUnavailableView` on `ContentView`)
  moves to an alert inside `WelcomeView`. The `ContentUnavailableView` branch in `ContentView` can
  be removed once Unit 3 lands.
- **State lifecycle risks:** `CaddieHostTabContainer` is now conditionally constructed — ensure
  `@StateObject` instances (voice controller, wind model) are properly torn down when
  `roundActive` flips to `false` (SwiftUI destroys `@StateObject` on view removal; verify no
  lingering background tasks in `HostVoiceSessionController` or `LiveWindModel` after the view
  is gone).
- **API surface parity:** No public API changes. `HostCourseBundleStore.loadKungsbackaNya()` stays
  as a shim through Unit 3 to avoid a flag day; can be removed in a cleanup pass after landing.
- **Unchanged invariants:** `RoundState`, `CourseBundle`, and all domain value types are untouched.
  `CaddieHostTabContainer`'s internal state ownership model (`@State` + binding propagation) is
  preserved — only the round-end callback and the Inspector tab condition are new.
- **Integration coverage:** The full journey (launch → course select → start → play → complete →
  summary → new round) must be manually verified end-to-end, as no automated integration test
  harness currently exists.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| `LiveCourseLocationModel` created in two places during migration (ContentView + old CaddieHostTabContainer init) | Unit 3 removes it from `CaddieHostTabContainer.init`; pass as parameter instead. Verify only one `CLLocationManager` is running via Instruments during testing. |
| `HostVoiceSessionController` holds microphone/WebRTC resources after `CaddieHostTabContainer` leaves the view tree | `CaddieHostTabContainer.onDisappear` calls `voiceController.disconnect()` (Unit 5). Test: New Round → Welcome → Start Round → confirm fresh voice session, no double-init. |
| Start Round silently loading stale UserDefaults round progress | Resolved: `onStartRound` closure calls `HostRoundProgressStore.delete(courseId:)` before setting `roundActive = true` (Units 1 + 3). |
| Round summary re-firing immediately at the start of a new round (completed round still in UserDefaults) | Resolved: `RoundSummaryView`'s **New Round** button also calls `delete(courseId:)` before `onNewRound()` (Unit 5). |
| Only one bundled course — welcome screen "course list" is a list of one | Design `WelcomeView` with a prominent single-course card layout; use "Nearest course" heading. The registry is extensible but the pilot ships with one entry. |
| `showRoundSummary` sheet fires more than once on repeated `onChange` callbacks | Guard: `if !showRoundSummary { voiceController.stopListening(); showRoundSummary = true }` (Unit 5). |
| Summary sheet dismissed by system gesture returns user to completed round | `onDismiss` handler re-asserts `showRoundSummary = true` (Unit 5). |

## Documentation / Operational Notes

- `NSLocationWhenInUseUsageDescription` is already present in `Info.plist` — no change needed.
- `com.apple.developer.weatherkit` entitlement is unaffected.
- `PilotSecrets.swift` (API key) is unaffected.
- After landing, the `loadKungsbackaNya()` shim in `HostCourseBundleStore` should be removed in a
  follow-up cleanup commit.

## Sources & References

- Related plans: `docs/plans/2026-05-17-001-feat-gps-location-positioning-plan.md` (GPS stack)
- Related plans: `docs/plans/2026-05-17-002-feat-live-wind-weatherkit-plan.md` (wind integration)
- `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — current root to refactor
- `ios/TrueCaddieHost/TrueCaddieHost/App/HostCourseBundleStore.swift` — registry extension point
- `ios/TrueCaddieHost/TrueCaddieHost/App/LiveCourseLocationModel.swift` — GPS model to lift
- `ios/TrueCaddieDomain/Sources/TrueCaddieDomain/GolfGeometry.swift` — `haversineDistance`
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift` —
  `@AppStorage` gating pattern
