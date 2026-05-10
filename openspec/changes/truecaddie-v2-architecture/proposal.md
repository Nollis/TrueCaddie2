## Why

TrueCaddie V2 needs a production-grade architecture before feature work starts because the product's value depends on deterministic golf intelligence, low-latency voice interaction, and reliable mobile round context working together. The current reusable assets are promising but incomplete: `C:\Users\niklasb\Documents\New project` provides a minimal OpenAI realtime WebRTC voice prototype, while the existing golf GIS assets in `C:\Users\niklasb\Documents` appear to be centerline and corridor geometry rather than a full semantic course model.

## What Changes

- Define a layered V2 architecture that separates course intelligence, player context, deterministic strategy logic, realtime voice orchestration, and mobile round UX.
- Use `kungsbacka-nya` holes 1-9 as the first pilot course dataset for validating the V1 architecture and recommendation loop.
- Define `TrueCaddie Course Studio` as the upstream internal system that ingests provider data, derives strategy overlays, scores confidence, and publishes versioned course bundles before they reach the iOS app.
- Define the deterministic strategy engine as a separate on-device module inside the iOS app, with a stable input/output contract that consumes published course bundles and player context.
- Establish a canonical semantic course data model that can reuse existing centerline and corridor assets while expanding toward fairways, greens, bunkers, penalty areas, layup zones, and target corridors.
- Define a player and round context model that supports both static golfer preferences and live within-round adaptation.
- Define a deterministic strategy packet contract so club, line, and risk decisions come from the strategy engine rather than the LLM.
- Define a realtime voice architecture that uses OpenAI realtime voice models as the conversational interface layer, with secure server-side tool orchestration and interruption handling.
- Define an iPhone-first, AirPods-first round UX with offline fallback and minimal screen friction.
- Create a phased V1, V2, and V3 delivery plan so the MVP stays narrowly focused on a shippable conversational caddie.

## Capabilities

### New Capabilities

- `course-studio-pipeline`: Provider ingestion, normalization, overlay derivation, confidence scoring, review, and bundle publishing for mobile consumption.
- `structured-hole-intelligence`: Semantic modeling, ingestion, storage, and delivery of course and hole geometry for strategy use.
- `player-round-context`: Persistent player profile plus live round-state modeling for personalization and within-round adjustments.
- `deterministic-strategy-engine`: Deterministic candidate-shot evaluation and recommendation packet generation.
- `realtime-voice-caddie`: Low-latency voice session orchestration that turns structured strategy packets into concise caddie dialogue.
- `mobile-round-companion`: Mobile-first round flow, quick overrides, and offline-ready next-shot UX.

### Modified Capabilities

- None.

## Impact

- Affects product architecture, backend service boundaries, mobile stack choice, data platform design, and OpenAI realtime integration strategy.
- Introduces likely dependencies on PostgreSQL/PostGIS, a mobile local store, weather data services, vector tile or bundled geometry delivery, and OpenAI realtime voice infrastructure.
- Reuses and reframes existing assets from `C:\Users\niklasb\Documents\New project`, the current GIS files under `C:\Users\niklasb\Documents`, and the semantic pilot-course JSON files under `C:\Projekt\TrueCaddie\Sources\TrueCaddieAppSupport\Resources\Courses`.
