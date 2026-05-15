# TrueCaddie Host UX Redesign

**Date:** 2026-05-15
**Status:** Approved, ready for implementation planning

## Motivation

The iOS host app today is a single dense screen that mixes the caddie conversation with the entire round-strategy inspector. It works for development but is unusable on the course — too many controls fighting for attention, the actual recommendation buried, no glance hierarchy.

The chosen product context is now explicit: someone standing over a ball, AirPods in, glancing at the phone briefly between shots. The redesign reorients both tabs around that context. The Caddie tab becomes a calm, glance-friendly voice-first surface. The Inspector tab absorbs everything else — round detail, strategy tuning, voice diagnostics, dev scaffolding — without polluting the on-course path.

This represents a deliberate shift from the AGENTS.md framing of "host app is currently a product-debugging surface, not final UX." The host app is starting to take product shape; the dev affordances stay reachable but stop being primary.

## Goals

- The Caddie tab can be operated with one hand, in sun, with gloves on, while looking at it for under two seconds.
- The current recommendation is visually unmissable — it's the centerpiece of the screen.
- All strategy/scenario controls and round-history detail leave the Caddie tab and live in the Inspector tab.
- Dev affordances (typed text harness, sim buttons) remain accessible but are no longer first-class — they live behind a toggle in Inspector.
- `ContentView.swift` shrinks from ~1500 lines to a thin tab container; the two tabs are separate, self-contained files of roughly 400 lines each.
- Apple-HIG-faithful visual style — system colors, SF typography, SF Symbols, semantic everything. No custom branding.

## Non-Goals

- Watch / widget / iPad surfaces — out of scope.
- Onboarding, settings, account screens — out of scope (the pilot key lives in `PilotSecrets.swift`).
- Voice-output playback work — already shipped in a separate slice.
- Behavioral changes to the recommendation engine, voice protocol, or audio plumbing — pure UX redesign.
- Coordinator / view-model extraction (`RoundCoordinator`) — deferred; `ContentView` continues to own state for this slice.
- Custom typography, color palette, or icon set beyond Apple defaults.
- Animation polish beyond minimal `withAnimation { }` defaults.

## Information Architecture

Two tabs, same as today. Their contents flip.

### Caddie tab (on-course primary surface)

Top to bottom:

1. **Status pill** — single compact line: `Hole 2 · Par 4 · 220 m · Fairway · −4`. Tappable; tap jumps to Inspector → Round.
2. **Recommendation hero** — large card with the current `NextShotRecommendationPacket` rendered as a headline (club + target) and a secondary subline (the short reason). Includes a low-key confidence indicator. Owns roughly 50% of vertical real estate.
3. **Voice controls cluster** — large primary button with three states (`Connect` / `Start Listening` / `Stop Listening`), an inline secondary row (`Interrupt`, `Finish Playback` as situationally relevant), and a status chip showing the live connection / playback state.
4. **Tap row** — a row of result chips (`Fairway` · `Rough` · `Bunker` · `Holed Out` · `Edit…`) fixed above the tab bar. Each chip submits a `reportResult` action through the same `HostCaddieSession` action layer that voice uses, so there is exactly one path that mutates round state. The `Edit…` chip jumps to Inspector → Shot context for rarer overrides.

Explicitly **not** on the Caddie tab anymore:
- Round summary card, round history list, Reset round.
- Strategy / scenario controls (Tee / Stock / Layup, Conservative / Balanced / Aggressive, Tee picker, Wind, Speed, Mode, Scenario).
- Typed-text input.
- Sim Voice / Partial / quick-action chips.
- Conversation log — the recommendation card is the on-screen confirmation; the spoken reply is the actual content.

### Inspector tab (tuning + round detail + dev sandbox)

Single scrollable view with native `Form`-style sections, in this order:

1. **Round** — round summary card, hole-by-hole list (each row has an `Edit` for that hole's score), `Reset round` at the bottom of the section with a confirmation prompt.
2. **Shot context** — current hole picker, lie picker (Tee / Fairway / Rough / Bunker / Recovery), distance override, tee picker. All directly mutate the `ShotStateContext` that the engine reads; changes reflect immediately on the Caddie tab's recommendation hero.
3. **Strategy & overlays** — plan mode (Stock / Tee / Layup), risk preference (Conservative / Balanced / Aggressive), wind toggle plus direction (Helping / Hurting / Cross) and speed, mode field, scenario picker.
4. **Voice diagnostics** — connection state, model name, session id, last failure message, full transcript history of the current session, a "Copy session" button.
5. **Developer** — hidden behind a `Show developer tools` toggle. When the toggle is on, this section reveals the typed `Type to the caddie` input, quick action chips (`What do you like?`, `Sim Voice`, `Partial`, plus existing siblings), and the existing `Simulate transport failure` button. Toggle state persists in `UserDefaults`; defaults to off so the Inspector reads as a tuning surface, not a dev panel.

## Caddie tab — layout details

### Status pill

- Font: `.footnote`, weight `.medium`, color `.secondary`.
- Score uses `.monospacedDigit()` so the number doesn't jiggle as the round advances.
- The `−4` segment uses signed formatting (`-4`, `E`, `+2`).
- Tap target is the whole pill; visual affordance is minimal (no chevron, just the implicit tap).

### Recommendation hero

- `RoundedRectangle(cornerRadius: 20)` filled with `Color(uiColor: .secondarySystemBackground)`.
- Padding: 24pt all around.
- Headline: `.title`, weight `.bold`, color `.primary` — e.g., `9 Iron to Center green`.
- Subline: `.subheadline`, color `.secondary` — e.g., `9I carry 132m fits a center green number with 5 m/s helping wind`.
- Confidence chip (top-right of the card, small): green tint for `high`, no chip for `medium`, orange-tinted "best guess" label for `low`. Color is paired with an accessibility text label.
- Empty state: when no packet is live, shows a calm hint based on connection state — `Tap Connect to start the caddie` (disconnected) or `Hole 2 ready · Tap Start Listening` (connected idle).
- Transitions: when the packet updates, the card cross-fades over 250ms (`.easeInOut`). Never blank-flashes to nothing — falls through to the previous packet until a new one arrives.

### Voice controls cluster

- Primary button: full-width-minus-padding pill (`.buttonStyle(.borderedProminent)`), `.title3` `.semibold` label. States:
  - `permissionState != .granted` → `Enable Mic` (taps `requestMicrophoneAccess`).
  - `connectionState == .disconnected` → `Connect`.
  - `connectionState == .connecting` → `Connecting…` (disabled).
  - `connectionState == .connected && turnState != .listening` → `Start Listening` with `mic.fill` glyph.
  - `connectionState == .connected && turnState == .listening` → `Stop Listening` (red tint, `mic.fill` with level meter).
- Secondary row (just below primary): two `.bordered` buttons, `Interrupt` (only when `playbackState == .speaking` or `turnState == .speaking`) and `Finish Playback` (only when `playbackState == .speaking`). A status chip on the right shows the live state: `Listening` / `Speaking` / `Connected` / `Connecting…` / `Disconnected` / `Failed`.
- The mic level meter animates subtly while listening; the speaking indicator pulses while assistant audio plays. Both use `withAnimation { }` and SwiftUI defaults — no Core Animation handwork.

### Tap row

- Horizontal row of `.bordered` capsule buttons sitting above the tab bar.
- Chips: `Fairway`, `Rough`, `Bunker`, `Holed Out`, `Edit…`.
- Each result chip calls `submitVoiceToolInvocation(.init(actionName: .reportResult, arguments: …))` (or the equivalent typed entry point) so the round state mutates through the same `HostCaddieSession` path that voice uses.
- The `Edit…` chip selects the Inspector tab and scrolls to the Shot context section.
- Chips disable when no `currentContext` is set yet.

## Inspector tab — layout details

The Inspector tab body is a single SwiftUI `Form` (or `List` styled the same) holding the five sections. Each section header uses native `Form.Section(header:)` styling.

### Round section

- A small header card showing `Through X: ±Y` and `Current hole N · M of 9 complete`.
- A list of holes with: hole number, par, score (or `—` if not played), `vs par` chip. Tapping a row opens an inline editor (or sheet) to set the score for that hole.
- `Reset round` button at the bottom, destructive style. Tapping presents a confirmation dialog before firing.

### Shot context section

- Picker: current hole (1–9 for the pilot bundle).
- Picker: lie (Tee / Fairway / Rough / Bunker / Recovery).
- Slider or steppers: distance override (e.g., 0–500m, defaulting to the engine-derived remaining distance).
- Picker: tee selection.
- Each change mutates `roundOverrides` / `ShotStateContext` directly; the Caddie tab's hero re-renders on the next frame.

### Strategy & overlays section

- Segmented control: plan mode (`Stock` / `Tee` / `Layup`).
- Segmented control: risk (`Conservative` / `Balanced` / `Aggressive`).
- Toggle: wind on/off.
- When wind on: segmented control for direction (`Helping` / `Hurting` / `Cross`) plus speed slider in m/s.
- Picker: mode (current `Stock` field — kept for now).
- Picker: scenario.

### Voice diagnostics section

- A small read-only block showing connection state, model name (truncated session id with a long-press to copy).
- The last failure message, if any, displayed in a muted block — clears when the session reconnects.
- A scrollable transcript view showing every user and assistant turn in the current session. Each entry shows speaker, text, and (very small) timestamp.
- `Copy session` button — copies a plain-text dump of the transcript to the clipboard.

### Developer section

- Header: `Developer`.
- Footer toggle: `Show developer tools` (Bool persisted as `developerToolsEnabled` in `UserDefaults`).
- When the toggle is off: only the toggle itself is visible.
- When on, the section reveals:
  - Typed input: `Type to the caddie` field and `Send` button.
  - Quick-action chip row: `What do you like?`, `Sim Voice`, `Partial`, and whatever else currently lives there.
  - `Simulate transport failure` button.

## State management & file structure

`ContentView.swift` continues to own all state for this slice. The UI is what splits, not the state.

New files:

- `ios/TrueCaddieHost/TrueCaddieHost/Features/CaddieTab/CaddieTabView.swift` — the Caddie tab body. Takes the data it needs from `ContentView` as `@Binding`s (editable: `selectedHoleNumber`, `roundOverrides`, etc. only if a tap-row action needs them) and plain reads (computed `NextShotRecommendationPacket`, `voiceController.state.statusLabel`, etc.). Owns no `@State` of its own beyond pure layout state.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorTabView.swift` — the Inspector tab body. Holds all of the round/strategy/scenario UI plus the voice diagnostics and developer toggle. Takes `@Binding`s for everything the existing controls already bind to.
- `ios/TrueCaddieHost/TrueCaddieHost/Features/Inspector/InspectorRoundSection.swift`, `InspectorShotContextSection.swift`, `InspectorStrategySection.swift`, `InspectorVoiceDiagnosticsSection.swift`, `InspectorDeveloperSection.swift` — one file per section, each one accepting the bindings it needs. Keeps each file ~100–200 lines.

Retired or absorbed:

- `ios/TrueCaddieHost/TrueCaddieHost/Features/BundleInspector/BundleInspectorView.swift` — the existing inspector view either retires entirely or its useful pieces (Overview / Strategy / Debug modes) get absorbed into the new Inspector sections. Decided at implementation time per piece; the structure stays the new five-section IA.

Shrunk:

- `ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift` — keeps all `@State`/`@StateObject` and the `init` that loads saved progress. Its `body` becomes a thin `TabView` with two children: `CaddieTabView(...)` and `InspectorTabView(...)`. Approximately 300 lines after the trim.

Persistence:

- Existing saved-progress loading (`HostRoundProgressStore`) stays where it is — in `ContentView.init`.
- New `developerToolsEnabled: Bool` lives in `UserDefaults` with key `truecaddie.developerToolsEnabled`. Read via `@AppStorage` inside `InspectorDeveloperSection`.

## Visual style

Apple-HIG-faithful. Semantic colors only — no hex literals. SF Pro typography via `.font(.title)` etc. SF Symbols only — no custom icons.

### Typography

| Element | Font | Weight | Color |
|---|---|---|---|
| Status pill | `.footnote` | `.medium` | `.secondary` |
| Recommendation headline | `.title` | `.bold` | `.primary` |
| Recommendation subline | `.subheadline` | `.regular` | `.secondary` |
| Voice primary button | `.title3` | `.semibold` | (inherited from `.borderedProminent`) |
| Voice secondary buttons | `.callout` | `.regular` | (inherited from `.bordered`) |
| Inspector section headers | `.headline` | `.semibold` | `.primary` |
| Inspector body | (Form defaults) | — | — |
| Round score `−4` | `.footnote.monospacedDigit()` | `.medium` | `.secondary` |

### Color

- Accent: keep system blue (current `AccentColor`).
- Recommendation confidence chip:
  - High → `.green` tint, subtle background.
  - Medium → no chip.
  - Low → `.orange` tint with `Best guess` label.
- Voice status chip dot:
  - Listening → `.red`, animating opacity ~1 Hz.
  - Speaking → `.blue`, gentle pulse.
  - Connected idle → `.gray`.
  - Connecting → `.gray`, system progress spinner.
  - Failed → `.orange`.
- Caddie tab cards: `Color(uiColor: .secondarySystemBackground)`.
- Inspector tab: native `Form` colors.

### Spacing & layout

- Caddie tab: `padding(24)` around cards, `padding(.vertical, 16)` between sections. Feels calm.
- Inspector tab: `Form` defaults — denser is fine here.
- Both tabs: `safeAreaInsets` respected; tap row sits above the home indicator.

### Iconography (SF Symbols)

- Mic idle: `mic.fill`.
- Mic listening: `mic.fill` with overlay level meter (small bars).
- Speaking indicator: `waveform.circle.fill`.
- Connect / disconnect: `bolt.fill` / `bolt.slash.fill`.
- Edit hole score: `pencil`.
- Reset round (in confirmation): `arrow.counterclockwise`.
- Tap-row chips: no icons — text only, keep glance time minimal.

### Animations

- Mic level meter: subtle bar-height animation while listening.
- Speaking pulse: gentle alpha on the `waveform` glyph while assistant audio plays.
- Recommendation card cross-fade on packet update: 250ms `.easeInOut`.
- All via `withAnimation { }` — no Core Animation, no custom timing curves.

### Empty / loading / disconnected states

- Recommendation card never blanks. When no live packet: falls through to the most recent known packet (grayed), or the static `Stock` recommendation for the current hole, or a calm hint if neither is available.
- Voice primary button is always tappable in some sensible state. Disabled appearance only during transient `connecting` states.
- Permission-denied state shows `Enable Mic` instead of `Connect`, with an explanatory subline.

### Accessibility

- Every color-coded status indicator has an accompanying text label (color is never the sole signal).
- Dynamic Type respected — hero text built around `.title` / `.largeTitle` so it scales with user settings.
- VoiceOver labels on voice controls describe the current state: `"Listening, double-tap to stop"`, `"Connected, double-tap to start listening"`.
- Tap row chips have explicit accessibility labels (`"Report fairway lie"` etc.) so they're clear in VoiceOver.

## Out of scope (deferred)

- `RoundCoordinator` extraction / view-model refactor — wait until there's a second consumer.
- watchOS / widget / iPad surfaces.
- Custom theming, brand colors, brand typography.
- Onboarding / settings screens.
- Caddie tab swipe-up gesture to peek at round detail (could be a future micro-feature).
- Voice tutorial / first-run flow.
- Localization beyond English.

## Verification

Visual decisions are verified on a physical device (Simulator audio quirks aside). Key checks once implementation lands:

- Caddie tab on iPhone 17 Pro at default Dynamic Type: status pill on one line, recommendation hero visible without scrolling, voice button comfortably reachable with the thumb.
- Tap row chips don't overlap the home indicator.
- Inspector tab `Form` scrolls smoothly, sections collapse-friendly if iOS adds that natively, dev section reveals/hides cleanly on toggle.
- The recommendation card never goes blank during normal operation.
- Dark mode renders correctly — no hard-coded light-only colors.
- All existing tests stay green: the redesign does not change behavior of `HostCaddieSession`, `RealtimeVoiceSessionManager`, `HostVoiceSessionController`, or any engine code. UI shuffle only.
