# Caddie Host UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorient the iOS host app around the on-course voice user. The Caddie tab becomes a glance-friendly, voice-first surface (status pill, recommendation hero, voice cluster, between-shots tap row). The Inspector tab absorbs everything else (round detail, strategy/scenario, voice diagnostics, gated dev sims). `ContentView.swift` shrinks from ~1500 lines to a thin tab container.

**Architecture:** Two SwiftUI tabs in a `TabView`. `ContentView` keeps owning state (`@State` for round overrides, `@StateObject` for the voice controller) and threads bindings down. New `CaddieTabView` and `InspectorTabView` plus five Inspector section subviews split the UI. No view-model / coordinator extraction — that's deferred to a separate slice.

**Tech Stack:** Swift 5+, SwiftUI, iOS 17+. Existing types: `TrueCaddieDomain` (engine), `HostCaddieSession`, `HostVoiceSessionController`, `RealtimeVoiceSessionManager`, `RoundState`, `NextShotRecommendationPacket`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-15-caddie-host-ux-redesign-design.md`

**Verification model for UI refactor:** This project has no SwiftUI UI tests — only Swift Testing logic tests for the engine and voice layer. Each task verifies:
1. `xcodebuild` succeeds (or local build via Xcode).
2. The Swift Testing suite stays green (no behavior changes, so all current tests must continue to pass).
3. The user visually confirms the change on simulator or device.

The plan does **not** add new UI tests. Logic doesn't change in this slice.

**Plan reading convention.** This is a refactor plan — most tasks move existing code from `ContentView.swift` into new feature files, then reshape it. When a step says "move X verbatim from ContentView" or "use the existing helper here," it means: grep for the named identifier or block in `ContentView.swift`, copy the corresponding View / closure code into the new file, and adjust imports plus binding identifiers (e.g., a `@State` becomes a `@Binding` in the child view). The plan deliberately does not duplicate the ~1500 lines of existing UI source verbatim. Where binding identifiers in the new code don't match the existing model's properties (e.g., `roundOverrides.strategyPreference` vs. whatever the actual property is named), match the existing types exactly — the view shape stays as drafted.

---

## File Structure

**New files** (created during this plan):

- `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift` — the on-course primary surface. Composes the four Caddie tab pieces.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieStatusPill.swift` — top compact line (hole · par · distance · lie · round score).
- `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift` — the large recommendation card.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieVoiceCluster.swift` — primary voice button + secondary row + status chip.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTapRow.swift` — between-shots result chips.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift` — Inspector tab body composing all five sections.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorRoundSection.swift` — round summary, hole-by-hole list, Reset round.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorShotContextSection.swift` — hole / lie / distance / tee pickers.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift` — Stock/Tee/Layup, risk preference, wind, scenario.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorVoiceDiagnosticsSection.swift` — connection state, transcript history, last failure, Copy session.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift` — gated typed input + sim chips, `Show developer tools` toggle persisted via `@AppStorage`.

**Modified files:**

- `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — body shrinks to a `TabView` with the two child views. All `@State` and `@StateObject` declarations stay. Init (saved-progress loading) stays.

**Retired:**

- `ios/TrueCaddieHost/TrueCaddieHost/Features/BundleInspector/BundleInspectorView.swift` — the existing Overview / Strategy / Debug modes get folded into the new Inspector sections. Final task removes the file.

---

## Task 1: Scaffold the tab container with empty children

Goal: Get the `TabView` skeleton in place with both children present but minimal, while the existing UI continues to render unchanged through the Caddie tab. App must build and look identical to the user. No content moved yet — just the structural seam.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`

- [ ] **Step 1: Create `CaddieTabView.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct CaddieTabView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContext: RoundContext
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    @ObservedObject var voiceController: HostVoiceSessionController
    /// Imperative jump from "Edit…" tap chip into the Inspector tab.
    let onRequestInspector: () -> Void

    var body: some View {
        // Placeholder during scaffolding — real content lands in Tasks 2–6.
        Text("Caddie tab")
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 2: Create `InspectorTabView.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct InspectorTabView: View {
    let bundle: CourseBundle
    let playerContext: PlayerContext
    let baseRoundContext: RoundContext
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var roundState: RoundState
    @Binding var editingScoreHoleNumber: Int?
    @Binding var editingScoreStrokes: Int
    @ObservedObject var voiceController: HostVoiceSessionController

    var body: some View {
        // Placeholder during scaffolding — real sections land in Tasks 3, 4, 5, 7.
        Text("Inspector tab")
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Add an `enum` for tab selection inside `ContentView`**

Inside `ContentView` (top of the struct, alongside the other `@State`):

```swift
enum CaddieHostTab: Hashable { case caddie, inspector }

@State private var selectedTab: CaddieHostTab = .caddie
```

- [ ] **Step 4: Wrap the existing body in a `TabView`**

Modify `ContentView.body` so the existing content lives inside a `Tab` labeled `Caddie`, with an empty `InspectorTabView` in a second `Tab` labeled `Inspector`. The existing body is preserved verbatim inside the Caddie tab — do not move or trim it yet. Example shape:

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        existingBody // the current ContentView body, untouched, wrapped here
            .tabItem { Label("Caddie", systemImage: "figure.golf") }
            .tag(CaddieHostTab.caddie)

        InspectorTabView(
            bundle: bundle,
            playerContext: playerContext,
            baseRoundContext: baseRoundContext,
            selectedHoleNumber: $selectedHoleNumber,
            roundOverrides: $roundOverrides,
            roundState: $roundState,
            editingScoreHoleNumber: $editingScoreHoleNumber,
            editingScoreStrokes: $editingScoreStrokes,
            voiceController: voiceController
        )
        .tabItem { Label("Inspector", systemImage: "slider.horizontal.3") }
        .tag(CaddieHostTab.inspector)
    }
}

@ViewBuilder
private var existingBody: some View {
    // Exact contents of the current ContentView.body, copy-pasted here.
}
```

(If `ContentView` already uses `TabView`, this step just renames/reshapes the existing tabs to match the new `CaddieHostTab` enum.)

- [ ] **Step 5: Build and verify**

Run the existing build (via Xcode on the Mac, or `swift build` if it's wired for that). Verify it compiles.

Run the existing test suite: `xcodebuild test -scheme TrueCaddieHost -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (or however the team runs tests). Expect all current tests to pass — no behavior change.

Launch in simulator and verify the **Caddie tab looks identical to before**. The Inspector tab shows `Inspector tab` placeholder text. Tab bar shows the two tabs.

- [ ] **Step 6: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift \
        ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift
git commit -m "Scaffold Caddie/Inspector tab split with empty children"
```

---

## Task 2: Extract the Round section into `InspectorRoundSection`

Goal: Move the Round Summary card, Round History list (with `Edit` per row), and `Reset round` button out of `ContentView`'s Caddie-tab area and into a new `InspectorRoundSection` rendered inside `InspectorTabView`. After this task, the Caddie tab no longer shows the Round Summary / Round History / Reset round; the Inspector tab shows them in a Form-style section.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorRoundSection.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` (remove the Round section UI from the existing Caddie body)
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift` (embed `InspectorRoundSection`)

- [ ] **Step 1: Locate the Round Summary + Round History + Reset round UI in `ContentView.swift`**

Use `Grep` for `Round Summary` and `Reset round` to find the relevant view code. Note the exact `View` subtrees so they can be moved verbatim.

- [ ] **Step 2: Create `InspectorRoundSection.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct InspectorRoundSection: View {
    let bundle: CourseBundle
    @Binding var roundState: RoundState
    @Binding var editingScoreHoleNumber: Int?
    @Binding var editingScoreStrokes: Int
    /// Currently selected hole, used to highlight the current row in the list.
    let currentHoleNumber: Int
    /// Callback fired when the user confirms Reset round.
    let onResetRound: () -> Void

    @State private var showResetConfirmation = false

    var body: some View {
        Section("Round") {
            roundSummaryRow
            ForEach(bundle.holes, id: \.holeNumber) { hole in
                holeRow(for: hole)
            }
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset round", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog(
                "Reset the current round?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset round", role: .destructive) { onResetRound() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // Implementations of `roundSummaryRow` and `holeRow(for:)` are moved
    // verbatim from the existing ContentView body — copy the view code
    // that today renders "Through N: -X / Current hole / N of 9 complete"
    // and the per-hole rows with the `Edit` link.
}
```

Move the supporting view code (`roundSummaryRow`, `holeRow(for:)`) from `ContentView.swift` into this file as `private` computed properties or private subviews. If they reference `HostRoundProgressModel` or similar helpers, those helpers stay in `ContentView.swift` for now and are passed in via parameters if needed.

- [ ] **Step 3: Remove the Round Summary / Round History / Reset round UI from `ContentView`'s Caddie body**

Inside `ContentView.body` (the `existingBody` private property), delete the section that renders the Round Summary card, the Round History list, and the Reset round button. The surrounding scroll view / layout structure stays.

- [ ] **Step 4: Render `InspectorRoundSection` inside `InspectorTabView`**

Replace `InspectorTabView.body` with:

```swift
var body: some View {
    Form {
        InspectorRoundSection(
            bundle: bundle,
            roundState: $roundState,
            editingScoreHoleNumber: $editingScoreHoleNumber,
            editingScoreStrokes: $editingScoreStrokes,
            currentHoleNumber: selectedHoleNumber,
            onResetRound: {
                // The reset action wires to whatever the existing "Reset round"
                // button did in ContentView — move that closure body here.
            }
        )
    }
}
```

The `onResetRound` closure must call whatever existing logic resets the round state (likely setting `roundState = RoundState(courseId: bundle.courseId, holeStates: [])` plus any persistence flush via `HostRoundProgressStore`). Use the exact lines that the old Reset round button called.

- [ ] **Step 5: Build and verify**

Build. Tests pass. Launch the simulator.

Visual checks:
- The Caddie tab no longer shows the `Round Summary` card or the `Round History` list or `Reset round`.
- The Inspector tab shows a `Round` section with the same content.
- Tapping `Edit` on a hole row still opens the score editor (it shares state via `editingScoreHoleNumber`).
- Tapping `Reset round`, confirming, still wipes the round (and persists if the original logic did).

- [ ] **Step 6: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorRoundSection.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift \
        ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift
git commit -m "Extract Round section into InspectorRoundSection"
```

---

## Task 3: Extract Shot Context and Strategy sections into Inspector

Goal: Move the strategy/scenario stack — hole picker, lie picker, distance override, tee picker, Stock/Tee/Layup, Conservative/Balanced/Aggressive, wind, mode, scenario — from `ContentView`'s Caddie body into two new Inspector sections.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorShotContextSection.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift`

- [ ] **Step 1: Locate the strategy/scenario UI in `ContentView.swift`**

Grep for `planMode`, `roundOverrides`, `Stock`, `Layup`, `Conservative`, `Balanced`, `Aggressive`, `Helping`, `Hurting`, `Cross` to find the relevant view code. Note which controls are pure "shot context" (hole, lie, distance, tee) vs "strategy" (plan mode, risk preference, wind, scenario).

- [ ] **Step 2: Create `InspectorShotContextSection.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct InspectorShotContextSection: View {
    let bundle: CourseBundle
    @Binding var selectedHoleNumber: Int
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState

    var body: some View {
        Section("Shot context") {
            Picker("Current Hole", selection: $selectedHoleNumber) {
                ForEach(bundle.holes, id: \.holeNumber) { hole in
                    Text("Hole \(hole.holeNumber)").tag(hole.holeNumber)
                }
            }

            Picker("Lie", selection: $roundOverrides.lie) {
                ForEach(ShotLie.allCases, id: \.self) { lie in
                    Text(lie.rawValue.capitalized).tag(lie)
                }
            }

            // Distance override slider / steppers — move the existing
            // distance-override control from ContentView verbatim. The
            // binding target is whichever property of roundOverrides
            // (or sibling @State) currently drives it.

            Picker("Tee", selection: $roundOverrides.teeSetId) {
                // Move the existing tee picker options here.
            }
        }
    }
}
```

(Confirm that `ShotLie.allCases` is available — if `ShotLie` is not `CaseIterable`, list the cases explicitly: `.tee`, `.fairway`, `.rough`, `.bunker`, `.recovery`.)

- [ ] **Step 3: Create `InspectorStrategySection.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct InspectorStrategySection: View {
    @Binding var roundOverrides: HoleInspectorModel.RoundOverrideState
    @Binding var planMode: HoleInspectorModel.PlanMode

    var body: some View {
        Section("Strategy & overlays") {
            Picker("Plan", selection: $planMode) {
                Text("Tee").tag(HoleInspectorModel.PlanMode.tee)
                Text("Stock").tag(HoleInspectorModel.PlanMode.stockNextShot)
                Text("Layup").tag(HoleInspectorModel.PlanMode.layup)
            }
            .pickerStyle(.segmented)

            Picker("Risk", selection: $roundOverrides.strategyPreference) {
                Text("Conservative").tag("conservative")
                Text("Balanced").tag("balanced")
                Text("Aggressive").tag("aggressive")
            }
            .pickerStyle(.segmented)

            Toggle("Wind", isOn: $roundOverrides.windEnabled)

            if roundOverrides.windEnabled {
                Picker("Direction", selection: $roundOverrides.windDirection) {
                    Text("Helping").tag("helping")
                    Text("Hurting").tag("hurting")
                    Text("Cross").tag("cross")
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text("\(Int(roundOverrides.windSpeedMps)) m/s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $roundOverrides.windSpeedMps, in: 0...15, step: 1)
                }
            }

            // Mode + Scenario pickers — move the existing controls verbatim.
        }
    }
}
```

If the existing types use different binding paths (e.g., `roundOverrides.strategy` instead of `roundOverrides.strategyPreference`), match the existing code exactly. The view shape stays the same; the binding identifiers must match what `RoundOverrideState` actually exposes today.

- [ ] **Step 4: Remove the strategy / scenario / shot-context UI from `ContentView`'s Caddie body**

Inside `ContentView.body`'s `existingBody`, delete the entire `Round` controls block (the part of screen 2 below the conversation that has all the pickers). The surrounding scroll view stays.

- [ ] **Step 5: Render the two new sections inside `InspectorTabView`**

```swift
var body: some View {
    Form {
        InspectorRoundSection(
            bundle: bundle,
            roundState: $roundState,
            editingScoreHoleNumber: $editingScoreHoleNumber,
            editingScoreStrokes: $editingScoreStrokes,
            currentHoleNumber: selectedHoleNumber,
            onResetRound: { /* existing reset closure */ }
        )

        InspectorShotContextSection(
            bundle: bundle,
            selectedHoleNumber: $selectedHoleNumber,
            roundOverrides: $roundOverrides
        )

        InspectorStrategySection(
            roundOverrides: $roundOverrides,
            planMode: $planMode
        )
    }
}
```

`InspectorTabView` may need a new `@Binding planMode: HoleInspectorModel.PlanMode` parameter — add it to the struct's properties and update the call site in `ContentView` to pass `$planMode`.

- [ ] **Step 6: Build and verify**

Build. Tests pass. Simulator launch.

Visual checks:
- Caddie tab is now visibly less cluttered — no more strategy controls below the conversation.
- Inspector tab shows three sections: Round, Shot context, Strategy & overlays.
- Editing any picker on the Inspector tab still updates the recommendation visible on the Caddie tab.

- [ ] **Step 7: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorShotContextSection.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorStrategySection.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift \
        ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift
git commit -m "Move shot-context and strategy controls into Inspector sections"
```

---

## Task 4: Build the gated Developer section in Inspector

Goal: Move the typed `Type to the caddie` input, the quick-action chips (`What do you like?`, `Sim Voice`, `Partial`, etc.), and `Simulate transport failure` out of the Caddie tab and into a new `InspectorDeveloperSection`. Gate visibility on a `@AppStorage`-persisted `Show developer tools` toggle that defaults to off.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift`

- [ ] **Step 1: Locate the dev affordances in `ContentView.swift`**

Grep for `Type to the caddie`, `Send`, `Sim Voice`, `Partial`, `What do you like`, `Simulate transport failure`. Note the closure bodies tied to each chip — they call into `voiceController.submitTypedUtterance`, `voiceController.submitPartialVoiceUtterance`, `voiceController.simulateTransportFailure`, etc.

- [ ] **Step 2: Create `InspectorDeveloperSection.swift`**

```swift
import SwiftUI

struct InspectorDeveloperSection: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    @AppStorage("truecaddie.developerToolsEnabled") private var developerToolsEnabled = false
    @State private var typedInput = ""

    var body: some View {
        Section {
            Toggle("Show developer tools", isOn: $developerToolsEnabled)

            if developerToolsEnabled {
                HStack {
                    TextField("Type to the caddie", text: $typedInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        let trimmed = typedInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        _ = voiceController.submitTypedUtterance(trimmed)
                        typedInput = ""
                    }
                    .disabled(typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // Quick action chips — preserve every chip currently in
                // ContentView. Each chip calls the same controller method
                // it called before.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("What do you like?") {
                            _ = voiceController.submitVoiceUtterance("what do you like here")
                        }
                        chip("Sim Voice") {
                            // Move the existing "Sim Voice" closure body verbatim.
                        }
                        chip("Partial") {
                            voiceController.submitPartialVoiceUtterance("what do you")
                        }
                        // Preserve any additional chips ("Si...", etc.) here.
                    }
                }

                Button("Simulate transport failure") {
                    voiceController.simulateTransportFailure("Debug transport drop")
                }
                .foregroundStyle(.red)
            }
        } header: {
            Text("Developer")
        } footer: {
            if !developerToolsEnabled {
                Text("Typed input and simulators are hidden by default.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}
```

The list of chips must be exhaustive — copy every chip that exists in `ContentView` today. If the existing code shows `Si...` (a truncated label suggesting `Simulate ...`), look at the source and use the actual label.

- [ ] **Step 3: Remove the typed input + chips + Simulate failure UI from `ContentView`'s Caddie body**

Delete those sections from `ContentView.body`'s `existingBody`. The surrounding scroll view stays.

- [ ] **Step 4: Render `InspectorDeveloperSection` inside `InspectorTabView`**

Add it at the bottom of `InspectorTabView`'s `Form`:

```swift
InspectorDeveloperSection(voiceController: voiceController)
```

- [ ] **Step 5: Build and verify**

Build. Tests pass. Simulator launch.

Visual checks:
- Caddie tab no longer shows the typed input or any chips.
- Inspector tab has a `Developer` section at the bottom with only the toggle visible.
- Flipping the toggle reveals the typed input, chips, and Simulate transport failure.
- Each chip still does what it did before (Sim Voice, Partial, etc.).
- Closing and relaunching the app remembers the toggle state.

- [ ] **Step 6: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorDeveloperSection.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift \
        ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift
git commit -m "Gate dev sim affordances behind Inspector developer toggle"
```

---

## Task 5: Build the new on-course Caddie tab

Goal: Replace `CaddieTabView`'s placeholder body with the new four-piece layout: status pill, recommendation hero, voice controls cluster, between-shots tap row. Also remove what's left of the old Caddie-tab UI from `ContentView` (the conversation log, etc., that the spec drops entirely).

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieStatusPill.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieVoiceCluster.swift`
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTapRow.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`

- [ ] **Step 1: Create `CaddieStatusPill.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct CaddieStatusPill: View {
    let holeNumber: Int
    let par: Int
    let remainingDistanceM: Double
    let lie: ShotLie
    let roundScoreVsPar: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text("Hole \(holeNumber)")
                Text("·")
                Text("Par \(par)")
                Text("·")
                Text("\(Int(remainingDistanceM)) m")
                Text("·")
                Text(lieLabel)
                Text("·")
                Text(scoreLabel)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hole \(holeNumber), par \(par), \(Int(remainingDistanceM)) meters remaining, \(lieLabel), round \(scoreLabel)")
    }

    private var lieLabel: String { lie.rawValue.capitalized }

    private var scoreLabel: String {
        if roundScoreVsPar == 0 { return "E" }
        if roundScoreVsPar > 0 { return "+\(roundScoreVsPar)" }
        return "\(roundScoreVsPar)"
    }
}
```

- [ ] **Step 2: Create `CaddieRecommendationHero.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct CaddieRecommendationHero: View {
    let packet: NextShotRecommendationPacket?
    /// Fallback hint shown when no packet is available.
    let emptyStateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let packet {
                HStack(alignment: .firstTextBaseline) {
                    Text(packet.headline)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    confidenceChip(for: packet.confidenceBand)
                }

                if !packet.executionNote.isEmpty {
                    Text(packet.executionNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(emptyStateText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.25), value: packet?.headline)
    }

    @ViewBuilder
    private func confidenceChip(for band: String) -> some View {
        switch band {
        case "high":
            Text("High")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.green.opacity(0.18))
                )
                .foregroundStyle(.green)
                .accessibilityLabel("High confidence")
        case "low":
            Text("Best guess")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.orange.opacity(0.18))
                )
                .foregroundStyle(.orange)
                .accessibilityLabel("Low confidence, best guess")
        default:
            EmptyView()
        }
    }
}
```

- [ ] **Step 3: Create `CaddieVoiceCluster.swift`**

```swift
import SwiftUI

struct CaddieVoiceCluster: View {
    @ObservedObject var voiceController: HostVoiceSessionController

    var body: some View {
        VStack(spacing: 12) {
            primaryButton

            HStack(spacing: 12) {
                if voiceController.isSpeaking || voiceController.state.playbackState == .speaking {
                    Button("Interrupt") { voiceController.interrupt() }
                        .buttonStyle(.bordered)
                }
                if voiceController.state.playbackState == .speaking {
                    Button("Finish") { voiceController.finishPlayback() }
                        .buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
                statusChip
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if voiceController.needsMicrophonePermission {
            Button {
                voiceController.requestMicrophoneAccess()
            } label: {
                Label("Enable Mic", systemImage: "mic.slash.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        } else if !voiceController.isConnected {
            Button {
                voiceController.connectIfNeeded()
            } label: {
                Label("Connect", systemImage: "bolt.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        } else if voiceController.isListening {
            Button {
                voiceController.stopListening()
            } label: {
                Label("Stop Listening", systemImage: "mic.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button {
                voiceController.beginListening()
            } label: {
                Label("Start Listening", systemImage: "mic.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(stateLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityLabel("Voice session \(stateLabel)")
    }

    private var dotColor: Color {
        switch voiceController.state.connectionState {
        case .disconnected: return .gray
        case .connecting: return .gray
        case .connected:
            if voiceController.isListening { return .red }
            if voiceController.state.playbackState == .speaking { return .blue }
            return .gray
        case .failed: return .orange
        }
    }

    private var stateLabel: String {
        switch voiceController.state.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected:
            if voiceController.isListening { return "Listening" }
            if voiceController.state.playbackState == .speaking { return "Speaking" }
            return "Connected"
        case .failed: return "Failed"
        }
    }
}
```

(If any of those state accessors don't match the current `HostVoiceSessionController` API, the implementer should adjust the property names to whatever the controller exposes. The shape — primary button + secondary row + status chip — stays the same.)

- [ ] **Step 4: Create `CaddieTapRow.swift`**

```swift
import SwiftUI
import TrueCaddieDomain

struct CaddieTapRow: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    let isEnabled: Bool
    let onRequestEditor: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                resultChip(.fairway, label: "Fairway")
                resultChip(.rough, label: "Rough")
                resultChip(.bunker, label: "Bunker")
                holeOutChip
                Button("Edit…") { onRequestEditor() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!isEnabled)
            }
            .padding(.horizontal, 16)
        }
    }

    private func resultChip(_ lie: ShotLie, label: String) -> some View {
        Button(label) {
            let invocation = VoiceToolInvocation(
                actionName: .reportResult,
                arguments: .init(lie: lie)
            )
            _ = voiceController.submitVoiceToolInvocation(invocation)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isEnabled)
        .accessibilityLabel("Report \(label) result")
    }

    private var holeOutChip: some View {
        Button("Holed Out") {
            let invocation = VoiceToolInvocation(actionName: .holeOut, arguments: .init())
            _ = voiceController.submitVoiceToolInvocation(invocation)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isEnabled)
        .accessibilityLabel("Report holed out")
    }
}
```

The exact case names (`.reportResult`, `.holeOut`) and arg shape come from `HostCaddieSession.ActionName` and `VoiceToolInvocationArguments` as they exist today. If the constructor takes different parameters, match what's there.

- [ ] **Step 5: Replace `CaddieTabView`'s placeholder body with the composed layout**

```swift
var body: some View {
    VStack(spacing: 16) {
        CaddieStatusPill(
            holeNumber: currentHoleNumber,
            par: currentPar,
            remainingDistanceM: currentRemainingDistance,
            lie: currentLie,
            roundScoreVsPar: currentRoundScoreVsPar,
            onTap: onRequestInspector
        )

        CaddieRecommendationHero(
            packet: currentRecommendationPacket,
            emptyStateText: currentEmptyState
        )
        .padding(.horizontal, 16)

        CaddieVoiceCluster(voiceController: voiceController)
            .padding(.horizontal, 16)

        Spacer(minLength: 0)

        CaddieTapRow(
            voiceController: voiceController,
            isEnabled: voiceController.isConnected,
            onRequestEditor: onRequestInspector
        )
        .padding(.bottom, 8)
    }
    .padding(.top, 8)
    .background(Color(uiColor: .systemBackground))
}

private var currentHoleNumber: Int { selectedHoleNumber }

private var currentPar: Int {
    bundle.holes.first(where: { $0.holeNumber == selectedHoleNumber })?.par ?? 0
}

private var currentLie: ShotLie {
    // Pull from the current ShotStateContext via HoleInspectorModel /
    // RoundState as the existing code does. If the existing helper that
    // gives "the live shot context for the selected hole" still lives
    // in ContentView, expose it through a parameter or move it here.
    .fairway // placeholder; real value comes from existing helpers
}

private var currentRemainingDistance: Double {
    // Same pattern — use the existing helper.
    0
}

private var currentRoundScoreVsPar: Int {
    // Compute from roundState the same way "Through N: -X" is computed
    // in the existing Round Summary. If there's a shared helper, call
    // it; otherwise inline the sum logic here.
    0
}

private var currentRecommendationPacket: NextShotRecommendationPacket? {
    // The existing code computes a NextShotRecommendationPacket from
    // bundle + selected hole + roundOverrides + roundState. Reuse that
    // helper here. If it lives in ContentView, move it to a place both
    // tabs can call (or pass the computed packet in as a parameter).
    nil
}

private var currentEmptyState: String {
    if voiceController.needsMicrophonePermission {
        return "Enable microphone access to start the caddie."
    }
    if !voiceController.isConnected {
        return "Tap Connect to start the caddie."
    }
    return "Hole \(selectedHoleNumber) ready · Tap Start Listening"
}
```

The implementer's main task in this step is wiring `CaddieTabView` to the existing helpers in `ContentView` for `currentLie`, `currentRemainingDistance`, `currentRoundScoreVsPar`, and `currentRecommendationPacket`. Two acceptable approaches:

- **(A)** Pass the computed values into `CaddieTabView` as parameters from `ContentView`, where the helpers already live.
- **(B)** Move the helper functions into a new utility file under `Features/CaddieTab/` so both tabs (and `ContentView`) can call them.

Approach A is smaller-scope. Use that unless the helpers are also needed by Inspector sections.

- [ ] **Step 6: Delete the remaining old Caddie-tab UI from `ContentView`**

Everything inside `existingBody` that isn't already moved (the conversation log scroll, status banner, Connect/Start Listening cluster, etc.) gets deleted. `ContentView` now only owns state and persistence init.

- [ ] **Step 7: Build and verify**

Build. Tests pass. Simulator launch.

Visual checks (most important task — this is the one the user feels):
- Caddie tab shows: status pill at top, recommendation hero in the middle (large), voice cluster below, tap row at the bottom.
- Recommendation hero is visually the centerpiece — large bold club + target text.
- Voice controls work end-to-end: Connect, Start Listening, Stop Listening, Interrupt, Finish.
- Tap row chips submit results; the engine and recommendation card update.
- Tapping the status pill jumps to Inspector tab.
- Tapping `Edit…` in the tap row also jumps to Inspector.

- [ ] **Step 8: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieStatusPill.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieRecommendationHero.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieVoiceCluster.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTapRow.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift \
        ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift
git commit -m "Build new on-course Caddie tab: pill, hero, voice cluster, tap row"
```

---

## Task 6: Build the Voice Diagnostics section

Goal: Add `InspectorVoiceDiagnosticsSection` to Inspector — connection state, model name, session id, last failure, scrollable transcript history, Copy session button.

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorVoiceDiagnosticsSection.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift`

- [ ] **Step 1: Create `InspectorVoiceDiagnosticsSection.swift`**

```swift
import SwiftUI

struct InspectorVoiceDiagnosticsSection: View {
    @ObservedObject var voiceController: HostVoiceSessionController

    var body: some View {
        Section("Voice diagnostics") {
            LabeledContent("Connection", value: connectionLabel)

            if let sessionID = voiceController.state.activeSession?.id {
                LabeledContent("Session") {
                    Text(sessionID.prefix(8))
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let failure = lastFailureMessage {
                LabeledContent("Last error") {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            DisclosureGroup("Transcript history") {
                if voiceController.state.transcriptEntries.isEmpty {
                    Text("No transcript yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(voiceController.state.transcriptEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.speakerLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(entry.text)
                                .font(.footnote)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Button("Copy session") {
                UIPasteboard.general.string = transcriptDump
            }
            .disabled(voiceController.state.transcriptEntries.isEmpty)
        }
    }

    private var connectionLabel: String {
        switch voiceController.state.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case let .connected(descriptor): return "Connected · \(descriptor.model)"
        case let .failed(message): return "Failed: \(message)"
        }
    }

    private var lastFailureMessage: String? {
        if case let .failed(message) = voiceController.state.connectionState { return message }
        return nil
    }

    private var transcriptDump: String {
        voiceController.state.transcriptEntries
            .map { "\($0.speakerLabel): \($0.text)" }
            .joined(separator: "\n")
    }
}
```

If the existing transcript entry type doesn't have a `speakerLabel` or `text` accessor matching what's used above, adjust to its real properties. The shape — disclosure-group transcript list + copy button — stays.

- [ ] **Step 2: Render the new section inside `InspectorTabView`**

Add it to the Form right above `InspectorDeveloperSection`:

```swift
InspectorVoiceDiagnosticsSection(voiceController: voiceController)
InspectorDeveloperSection(voiceController: voiceController)
```

- [ ] **Step 3: Build and verify**

Build. Tests pass. Simulator launch.

Visual checks:
- Inspector tab has a Voice diagnostics section above Developer.
- Connection / Session / Last error update live as the voice session changes state.
- Tapping `Transcript history` expands a list of every turn in the current session.
- `Copy session` puts the transcript on the clipboard.

- [ ] **Step 4: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorVoiceDiagnosticsSection.swift \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift
git commit -m "Add InspectorVoiceDiagnosticsSection with transcript + copy"
```

---

## Task 7: Retire `BundleInspectorView` and trim `ContentView`

Goal: Remove the now-orphaned `BundleInspectorView.swift` (its modes — Overview / Strategy / Debug — are absorbed into the five new Inspector sections). Trim `ContentView.swift` to a pure tab container that owns state and persistence init but no UI beyond the `TabView`.

**Files:**
- Delete: `ios/TrueCaddieHost/TrueCaddieHost/Features/BundleInspector/BundleInspectorView.swift`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift`

- [ ] **Step 1: Confirm no remaining call sites reference `BundleInspectorView`**

Run `Grep` for `BundleInspectorView`. Expected: only the file itself defines/references it (no other call sites after Tasks 1–6).

If anything still references it (e.g., a test, a preview, a sibling Inspector view), either delete that reference (if dead code) or absorb its specific need into one of the new Inspector sections.

- [ ] **Step 2: Delete the file**

```bash
git rm ios/TrueCaddieHost/TrueCaddieHost/Features/BundleInspector/BundleInspectorView.swift
```

- [ ] **Step 3: Trim `ContentView.body` to its final shape**

`ContentView.body` should now contain only a `TabView` with two tabs. All `@State` declarations stay; the `init` (saved-progress loading) stays. The body looks roughly like:

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        CaddieTabView(
            bundle: bundle,
            playerContext: playerContext,
            baseRoundContext: baseRoundContext,
            selectedHoleNumber: $selectedHoleNumber,
            roundOverrides: $roundOverrides,
            roundState: $roundState,
            voiceController: voiceController,
            onRequestInspector: { selectedTab = .inspector }
        )
        .tabItem { Label("Caddie", systemImage: "figure.golf") }
        .tag(CaddieHostTab.caddie)

        InspectorTabView(
            bundle: bundle,
            playerContext: playerContext,
            baseRoundContext: baseRoundContext,
            selectedHoleNumber: $selectedHoleNumber,
            roundOverrides: $roundOverrides,
            roundState: $roundState,
            editingScoreHoleNumber: $editingScoreHoleNumber,
            editingScoreStrokes: $editingScoreStrokes,
            planMode: $planMode,
            voiceController: voiceController
        )
        .tabItem { Label("Inspector", systemImage: "slider.horizontal.3") }
        .tag(CaddieHostTab.inspector)
    }
}
```

Delete the `existingBody` private property — it should be empty now.

Confirm `ContentView.swift` is now in the neighborhood of 300 lines (state, init, body). If much larger, look for orphaned helpers — either delete them or move them to the relevant feature file.

- [ ] **Step 4: Build and verify**

Build. Tests pass. Simulator launch.

Visual checks:
- Everything works exactly as it did at the end of Task 6.
- No dead-code warnings about unused helpers in `ContentView`.

- [ ] **Step 5: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift
git commit -m "Retire BundleInspectorView and trim ContentView to tab container"
```

---

## Task 8: Visual polish pass

Goal: Apply the visual spec — typography weights, spacing, animations, dynamic confidence/status colors — across the new views. This is the "make it feel like a real iOS app" pass.

**Files:**
- Modify: any of the new `CaddieTab/*` and `Inspector/*` files

- [ ] **Step 1: Typography pass**

Open each new Caddie tab file. Confirm:
- `CaddieStatusPill`: `.footnote.weight(.medium)`, `.foregroundStyle(.secondary)`, score uses `.monospacedDigit()`.
- `CaddieRecommendationHero`: headline `.title.weight(.bold)`, subline `.subheadline` `.secondary`, confidence chip `.caption2.weight(.semibold)`.
- `CaddieVoiceCluster`: primary button label `.title3.weight(.semibold)`; secondary buttons inherit `.bordered` defaults.
- All Inspector section headers use the native `Section("Title")` rendering — no overrides.

Adjust anywhere a previous step landed on a different weight or color.

- [ ] **Step 2: Spacing pass**

- Caddie tab outer `VStack` spacing: 16pt between major elements.
- Recommendation hero internal padding: 24pt.
- Tap row horizontal padding: 16pt.
- Voice cluster horizontal padding: 16pt.
- Inspector tab: default `Form` spacing — no overrides.

- [ ] **Step 3: Animations**

Confirm:
- `CaddieRecommendationHero` cross-fades on `packet.headline` change (already present via `.animation(.easeInOut(duration: 0.25), value: packet?.headline)`).
- Voice cluster's status dot animates opacity ~1 Hz while listening. Add if not present:

```swift
Circle()
    .fill(dotColor)
    .frame(width: 8, height: 8)
    .opacity(isListeningAnimating ? 1.0 : 0.5)
    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: voiceController.isListening)
```

(Use a `@State private var isListeningAnimating = true` if needed to drive the cycle.)

- [ ] **Step 4: Semantic-color audit**

Grep across all new files for hex literals (`#`, `Color(red:`, `UIColor(red:`). Expect zero. If any are found, replace with semantic colors (`.primary`, `.secondary`, `.accentColor`, `.red`, `.green`, `.orange`) or `Color(uiColor: .secondarySystemBackground)` / `.tertiarySystemBackground`.

- [ ] **Step 5: Dynamic Type sanity**

In simulator, set Settings → Display → Text Size to the largest setting. Launch the app.

Verify:
- Caddie tab status pill wraps gracefully or scrolls horizontally — does not overflow.
- Recommendation headline still readable (it scales with `.title` automatically).
- Voice button still tappable.
- Inspector tab Form rows wrap naturally.

If anything breaks, adjust the affected view with `.lineLimit(2)`, `.minimumScaleFactor(0.8)`, or `ViewThatFits { ... }` as appropriate.

- [ ] **Step 6: Dark mode sanity**

In simulator, toggle Dark Mode (Settings → Developer → Dark Appearance, or `xcrun simctl ui booted appearance dark`).

Verify:
- All cards have appropriate backgrounds (system materials adjust automatically).
- Text remains readable.
- The accent / status colors look right.

If anything is wrong, the offender is usually a hard-coded color — replace with semantic.

- [ ] **Step 7: Commit**

```bash
git add ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/ \
        ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/
git commit -m "Visual polish: typography, spacing, animations, semantic colors"
```

---

## Final verification

After Task 8 is complete:

1. Run `swift test` (or the project's test command) on the Mac. Expect every test to pass — the redesign is structural only, no behavior change.
2. Build the iOS app target. Expect no warnings related to deprecated APIs introduced by the new views.
3. Run on a physical iPhone:
   - **Caddie tab**: status pill compact and tappable; recommendation hero readable in sun (head outside to check); voice controls flow through Connect → Start Listening → audible caddie reply → Stop; tap row chips submit results and update the recommendation.
   - **Inspector tab**: all five sections present; round controls, shot context, strategy controls all work and update the recommendation; voice diagnostics shows live state; developer toggle reveals/hides the dev sims as expected.
4. Toggle Dark Mode on the device. Both tabs render correctly.
5. Increase Dynamic Type to the second-largest setting. Layouts hold.

Once all of the above pass, the redesign is shipped.
