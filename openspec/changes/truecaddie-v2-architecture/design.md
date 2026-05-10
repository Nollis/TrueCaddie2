## Context

TrueCaddie V2 is being planned from a nearly empty repository, but there are several useful predecessor assets:

- `C:\Users\niklasb\Documents\New project` is a minimal OpenAI realtime WebRTC voice demo. It proves the basic browser pattern of SDP exchange, `oai-events` data channel use, and function-calling flow, but it is not yet a production architecture.
- Existing GIS assets in `C:\Users\niklasb\Documents` include centerline, corridor, and smoothed line geometry. The geopackage currently appears to contain a single `LINESTRING` layer with `hole` and `par`, which is useful as a routing backbone but not a full semantic golf model.
- `C:\Projekt\TrueCaddie\Sources\TrueCaddieAppSupport\Resources\Courses\kungsbacka-nya-*.json` provides a much stronger pilot dataset for holes 1-9. It already includes per-hole centerlines, tee sets, green front/center/back references, out-of-bounds lines, context points, elevations, and semantic feature polygons such as fairway, green, bunker, water, rough, tee, and woods.

The architecture now explicitly separates into two product systems:

- `TrueCaddie Course Studio`: an upstream internal course-intelligence system that prepares, validates, and publishes course bundles.
- `TrueCaddie Mobile`: the iPhone-first runtime that consumes published bundles during a round for strategy and voice interaction.

Within `TrueCaddie Mobile`, the strategy engine should still be treated as its own architectural boundary rather than as ad hoc view or controller logic. It runs on-device in V1, but still needs stable inputs and outputs independent of SwiftUI or UI-layer concerns.

The product goal is a calm, premium, voice-first golf caddie that behaves like a strategic playing partner instead of a generic AI assistant. That creates three hard constraints:

1. Club, line, and risk recommendations must be deterministic and explainable.
2. Voice interaction must be fast, interruptible, and concise.
3. The system must work in real on-course conditions with weak connectivity and imperfect GPS.

Stakeholders include golfers using the app live on course, the product team defining the tone and UX, and engineering responsible for long-term extensibility into personalization and richer course intelligence.

## Goals / Non-Goals

**Goals:**

- Define a production-viable layered architecture for V1 through V3.
- Define the responsibilities and publish contract for `TrueCaddie Course Studio` as a separate upstream system.
- Define the strategy engine as a separate on-device module with a stable input/output contract.
- Make the deterministic strategy engine the source of golf truth.
- Reuse existing geometry and voice prototype assets where useful without inheriting their limitations.
- Keep V1 narrow enough to ship as a high-quality conversational caddie on a curated set of courses.
- Preserve clear API and data contracts between hole intelligence, player context, strategy, voice, and mobile UX.
- Support offline fallback for core course and recommendation functions.

**Non-Goals:**

- Designing a generic RAG assistant for golf questions.
- Treating the LLM as the primary reasoning engine for golf strategy.
- Solving swing analysis, computer vision swing coaching, or full satellite-first automation in V1.
- Optimizing for maximum course coverage before correctness on pilot courses is proven.
- Defining every endpoint or UI screen in implementation-level detail.

## Decisions

### 1. Use a layered architecture with deterministic strategy in the middle

The system will be split into:

- Course Studio pipeline
- Structured hole intelligence
- Player and round context
- Deterministic strategy engine
- Realtime voice caddie layer
- Mobile round companion

This keeps the LLM from becoming the source of truth and gives each layer a clear contract.

Alternatives considered:

- End-to-end LLM reasoning from raw context
  - Rejected because it is difficult to trust, test, and tune for golf correctness.
- Rules engine only, without explicit layer boundaries
  - Rejected because it would grow brittle and make future personalization difficult.

### 2. Treat existing course geometry as a seed, not the final model

The existing centerline and corridor data will be reused for:

- hole routing
- distance-along-hole calculations
- GPS snap-to-hole logic
- initial target corridor derivation

The canonical V2 course model must expand to include semantic polygons and decision zones such as fairways, greens, bunkers, penalty areas, layup windows, preferred misses, and approach corridors.

For V1, `kungsbacka-nya` holes 1-9 becomes the pilot course because it already crosses an important threshold: it is not just a routing skeleton. The current dataset appears sufficient for a first deterministic strategy slice because every inspected hole includes semantic polygons plus a centerline and support context. What still appears missing for a premium caddie engine are explicit recommendation-layer constructs such as:

- curated layup zones
- target corridors by club band
- preferred miss regions
- player-facing aim references
- richer elevation and slope treatment beyond a few anchor points
- confidence metadata about how each feature was sourced or derived

Important note on centerlines:

- the current centerlines are acceptable as seed geometry for V1 bundle publication and early strategy work
- they should not be treated as the final long-term truth when they contain only a few coarse points
- over time, `TrueCaddie Course Studio` should be able to derive a denser geometric centerline automatically from tee anchors, green anchors, and the playable fairway corridor
- that derived geometric centerline should remain distinct from later strategic overlays such as target corridors, since the best scoring line may differ from the purely geometric middle path

Important note on strategic lines:

- there should not be one universal final strategic line for every player
- the best scoring route is player-dependent and may change with distance, dispersion, confidence, risk posture, and conditions
- Course Studio should define the hole's neutral geometry and possible route structures
- the on-device strategy engine should choose the right route for the current player and shot context
- in practice, this means:
  - one shared geometric centerline can exist
  - multiple candidate corridors or route options can exist
  - the final recommended line is computed, not statically stored as one truth for all golfers

Alternatives considered:

- Keep the centerline-only model for V1
  - Rejected because premium strategic recommendations need hazard and landing-area awareness.
- Depend entirely on external course APIs
  - Rejected because current course APIs are useful for metadata and points of interest but do not guarantee the semantic geometry depth required for strategy.

### 3. Use PostgreSQL with PostGIS as the source of truth for course intelligence

PostGIS is the right fit for:

- vector geometry storage
- spatial indexing
- geometry versioning and enrichment workflows
- server-side preprocessing for mobile bundles

Client delivery should use lightweight per-course bundles or vector tiles rather than raw GeoJSON as the canonical format.

Alternatives considered:

- Raw GeoJSON files in object storage
  - Rejected because versioning, indexing, and enrichment workflows become awkward.
- SQLite-only server storage
  - Rejected because spatial querying and multi-user service workflows will quickly outgrow it.

### 4. Put provider ingestion and overlay derivation in a separate upstream system called TrueCaddie Course Studio

`TrueCaddie Course Studio` will be the internal system that:

- ingests provider data such as iGolf
- stores raw source snapshots
- normalizes provider payloads into the canonical TrueCaddie schema
- derives strategy overlays automatically
- scores confidence for every derived overlay
- routes weak holes into review
- publishes versioned course bundles for mobile download

The iOS app should consume the published bundle and should not depend directly on provider payload structure.

Alternatives considered:

- Let the iOS app consume provider data directly
  - Rejected because provider payloads are unstable product boundaries and do not encode TrueCaddie strategy semantics.
- Perform full overlay derivation on-device
  - Rejected because heavy course processing belongs upstream, not in the live round runtime.

### 5. Model player context as persistent profile plus live round state

Player intelligence will have two coordinated models:

- persistent profile: club gapping, dispersion, tendencies, risk posture, confidence archetype
- live round state: current hole, lie, misses today, confidence drift, wind adjustments, fatigue proxy, override signals

This allows personalization to improve over time without over-claiming knowledge in V1.

Alternatives considered:

- Only static player profile
  - Rejected because within-round adaptation is central to caddie-like behavior.
- Fully learned personalization from day one
  - Rejected because it adds complexity and false precision too early.

### 6. The strategy engine should be hybrid deterministic, not rules-only and not simulation-only

The strategy engine will:

- generate candidate shots
- transform expected landing distributions using player tendencies, weather, and lie
- evaluate expected outcomes and hazard exposure
- score conservative and aggressive options
- emit a structured recommendation packet

This is a hybrid because it combines policy rules with expected-outcome estimation.

The strategy engine should be implemented as a separate on-device module inside the iOS app, not as tightly coupled UI logic. That gives several advantages:

- easier testing and replay of identical shot scenarios
- easier isolation of golf logic from UI logic
- cleaner ownership boundaries between mobile UX and golf logic
- replay tooling and offline validation during development

Alternatives considered:

- Embed all strategy logic directly in views or controller-style app code
  - Rejected because it tightly couples golf intelligence to UI state and makes the engine harder to test or replay cleanly.
- Make the strategy engine a required cloud dependency
  - Rejected because reliable live play requires strong offline and low-latency behavior.

Alternatives considered:

- Fixed if/then rule tree
  - Rejected because it becomes difficult to personalize or explain edge cases cleanly.
- Pure black-box optimization
  - Rejected because explainability and product tuning would suffer.

### 7. Use OpenAI realtime voice over WebRTC with server-side sideband control

The mobile client should handle live audio transport over WebRTC while the backend holds secure strategy and business logic. The backend should maintain sideband control of sessions so it can:

- answer tool calls
- update instructions
- monitor state
- keep proprietary logic off-device and out of the prompt

The current `Voice Agent` project is a good reference for the session bootstrap shape, but the production design should target the current OpenAI realtime model stack rather than freezing around the older demo naming.

Alternatives considered:

- WebSocket-only audio architecture
  - Rejected for mobile browser-style voice UX because WebRTC is the recommended low-latency transport for client voice sessions.
- Put strategy tools directly in the client prompt surface
  - Rejected because security and product correctness would be weaker.

### 8. Build V1 as a native iPhone-first product

The first release should optimize for:

- AirPods-first use
- reliable location and audio integration
- low cognitive load
- smooth backgrounding and reconnection behavior

A native iOS stack is the least risky path for the first premium experience.

Alternatives considered:

- Cross-platform first
  - Rejected because it adds abstraction cost before the core voice and on-course UX are proven.

### 9. Design V1 around a curated-course launch strategy

V1 should be great on a limited set of well-modeled courses rather than merely available on many poorly modeled ones.

The initial curated course will be `kungsbacka-nya` holes 1-9. This gives the project a concrete proving ground for:

- validating the hole schema against real data
- testing the recommendation loop across par 3, 4, and 5 situations
- measuring how much additional semantic enrichment is needed before strategy quality feels trustworthy

Alternatives considered:

- Broad coverage MVP
  - Rejected because poor geometry or poor strategy will destroy trust faster than missing course availability.

### 10. Derive overlays automatically, then gate them with confidence rather than hand-authoring every hole

The overlay derivation pipeline inside `TrueCaddie Course Studio` will create TrueCaddie-owned strategy semantics from provider geometry. The first-pass overlays should be:

- tee target corridor
- aggressive tee corridor
- layup candidate zones on par 5s and reachable par 4s
- preferred miss by shot phase
- hazard severity scoring
- recovery severity scoring
- blocked-angle or dead-zone markers

Each derived overlay must include confidence metadata so weak outputs can degrade gracefully rather than masquerade as precise strategic truth.

Alternatives considered:

- Hand-author overlay semantics for all courses
  - Rejected because it does not scale beyond a pilot set.
- Publish raw provider geometry with no overlay derivation
  - Rejected because that leaves too much strategy reasoning to the mobile runtime or the voice model.

### 11. Define a staged overlay derivation pipeline for Course Studio

The first-pass pipeline will be:

1. Ingest provider course payload and snapshot the raw source.
2. Normalize into canonical hole geometry and metadata.
3. Validate core completeness:
   - tees
   - hole length/par
   - centerline
   - green reference
   - playable polygons and hazards
4. Derive candidate overlays:
   - centerline refinements
   - tee-shot corridors
   - carry-risk bands
   - layup candidates
   - preferred miss scores
   - recovery severity
5. Score confidence for each overlay based on source completeness, geometric quality, and internal consistency.
6. Auto-approve high-confidence holes; queue low-confidence holes for review.
7. Publish an immutable course bundle version for mobile and strategy-engine use.

Alternatives considered:

- Single-step ingestion directly to mobile bundle
  - Rejected because there is no clean place for validation, confidence, or review.

Centerline refinement note:

- a future Course Studio derivation step should refine or replace sparse source centerlines with a denser geometric centerline derived from tee position, green target, and fairway corridor geometry
- this refined centerline should be considered part of canonical hole geometry, not a strategy overlay

### 12. Separate base mapping data from TrueCaddie-owned strategy overlays

The canonical course model will have two layers:

- base mapping data from providers
- strategy overlays owned by TrueCaddie

This keeps provider dependency manageable while preserving the product moat in the derived overlay layer.

Alternatives considered:

- Blend provider fields and derived fields into a single undifferentiated schema
  - Rejected because provenance, trust, and vendor portability become unclear.

### 13. Give the strategy engine a stable input contract from Course Studio and player context

The strategy engine should accept one canonical request shape regardless of whether it is running inside the live iOS app or being replayed in a development harness.

Minimum input families:

- course bundle inputs
  - hole geometry
  - strategy overlays
  - confidence metadata
- player inputs
  - club distances
  - dispersion
  - risk posture
- round inputs
  - shot number
  - current ball position
  - lie
  - recent misses
- environment inputs
  - wind
  - elevation context
  - optional weather modifiers

This allows the same scenario to be replayed, tested, and tuned outside the mobile app.

Important note on route selection:

- the strategy engine should treat course data as a set of possible routes and constraints, not as one preordained line
- player-specific strategy happens when the engine ranks those route options against the current player model and live context

Alternatives considered:

- Let the engine read ad hoc view or app state directly
  - Rejected because that makes testing and portability harder.

### 14. Start V1 overlay derivation with five strategy overlays that most improve recommendation quality

The first-pass overlay set inside `TrueCaddie Course Studio` will be:

- `tee_target_corridor`
- `aggressive_tee_corridor`
- `layup_candidates`
- `preferred_miss`
- `hazard_severity`

`recovery_severity` and `blocked_angle_zone` remain important, but they can begin as simpler secondary derivations once the first five overlays are working.

Alternatives considered:

- Derive every conceivable overlay in the first version
  - Rejected because it increases ambiguity and slows validation.
- Start with only raw hazard polygons and leave corridor generation to runtime
  - Rejected because too much strategy would be left to ad hoc reasoning in the app.

### 15. Derive tee_target_corridor from playable width, hazard pressure, and angle value

`tee_target_corridor` is the primary default tee-shot window. Its purpose is to answer:

- where should a stock tee shot finish?
- how wide is the acceptable finish area?
- what line preserves the best combination of safety and next-shot value?

Inputs:

- tee position
- hole centerline
- fairway polygon
- hazard polygons
- OB lines
- tree or obstacle polygons
- green reference and approach direction
- hole length and par

Method:

1. Sample candidate landing distances for the selected tee set, centered on realistic landing bands for the player model.
2. Intersect those landing bands with the fairway polygon and playable corridor.
3. Measure effective fairway width at each candidate depth.
4. Penalize candidates for nearby penalty hazards, OB, severe woods, and blocked next-shot angles.
5. Reward candidates that preserve a clean next-shot line and sufficient playable width.
6. Select the corridor with the best safety-to-advantage balance as the default tee corridor.

Outputs:

- center coordinate
- corridor polygon or centerline segment plus width/depth
- intended landing distance band
- confidence
- supporting reasons such as `avoid right water` or `best angle into green`

Fallback behavior:

- if fairway geometry is weak or absent, corridor defaults to a wider centerline-based playable band with lower confidence
- if hazards are sparse, prioritize fairway width and angle preservation over false precision

### 16. Derive aggressive_tee_corridor as a scored alternative, not a separate invention

`aggressive_tee_corridor` should be derived from the same candidate space as the default corridor, but with a different utility function that accepts more hazard exposure in exchange for measurable reward.

Inputs:

- all `tee_target_corridor` inputs
- player carry and dispersion
- reachable-distance upside
- angle improvement into the green or next layup window

Method:

1. Reuse the tee-shot candidate set from default corridor derivation.
2. Score each candidate twice:
   - conservative utility
   - aggressive utility
3. Aggressive utility can accept narrower width and closer hazard proximity only if it gains one of:
   - shorter approach
   - materially better angle
   - improved chance to reach or threaten the green on the next shot
4. Publish an aggressive corridor only if it is meaningfully distinct from the default and remains above the minimum confidence threshold.

Outputs:

- aggressive corridor geometry
- reward rationale
- additional risk note
- confidence

Fallback behavior:

- if no candidate is meaningfully better than the default, omit the aggressive corridor rather than fabricate one

Strategic interpretation note:

- aggressive and conservative corridors should be understood as route options made available by the hole
- they are not guaranteed recommendations for every player
- the final choice still belongs to the strategy engine after player fit and context are applied

### 17. Derive layup_candidates from downstream shot quality, not distance alone

`layup_candidates` are especially important on par 5s and reachable par 4s. They should represent deliberate landing shelves that improve the next shot rather than generic distance cutoffs.

Inputs:

- tee set and hole length
- centerline and fairway geometry
- hazard polygons
- green geometry and approach direction
- player distance model

Method:

1. Identify plausible layup depth bands based on the remaining shot type desired after the layup:
   - full wedge
   - short iron
   - safe positional leave
2. Remove candidate bands that bring large hazard exposure, severe narrowing, or blocked angle.
3. Score surviving bands by:
   - safety of current shot
   - quality of expected next shot
   - green-entry angle
   - distance comfort for the player archetype
4. Publish the top one to three layup candidates for holes where layup decisions matter.

Outputs:

- layup zone geometry
- expected leave distance band
- shot intent such as `wedge layup` or `positional layup`
- confidence

Fallback behavior:

- if geometry is too weak, publish at most one broad `safe layup band`
- if a hole does not present a meaningful layup decision, omit the overlay entirely

### 18. Derive preferred_miss from hazard severity and recovery expectation by shot phase

`preferred_miss` is the side or zone where a miss is least damaging relative to the player's current shot objective. This should be computed separately for:

- tee shot
- layup shot
- approach shot

Inputs:

- target corridor or layup zone
- hazard severity
- recovery severity
- fairway/rough/woods/water/OB geometry
- green geometry and front/back/side context

Method:

1. For the current shot phase, compare left/right/short/long miss outcomes around the intended target.
2. Estimate which miss directions still preserve a playable next shot with acceptable penalty.
3. Penalize any miss direction that trends toward water, OB, severe woods, or blocked recovery.
4. Select the least damaging miss direction if one is clearly better than the others.

Outputs:

- preferred miss direction
- optional avoid direction
- confidence
- short reason such as `left miss stays dry and open`

Fallback behavior:

- if the geometry does not clearly differentiate miss costs, return `neutral` rather than pretending a side preference exists

### 19. Derive hazard_severity as shot-dependent strategic cost

`hazard_severity` is not just a label like bunker or water. It is the strategic cost of interacting with that hazard from a specific shot context.

Inputs:

- hazard type
- proximity to likely landing bands
- carry requirement
- recovery expectation after entering hazard
- whether the hazard is penalty, obstruction, or angle-reducing only

Method:

1. Start with a base severity by hazard class:
   - OB / penalty water highest
   - severe woods next
   - bunker / rough / non-penalty trouble lower
2. Adjust severity by how directly the hazard conflicts with likely target corridors.
3. Increase severity when the hazard narrows the playable window or forces a shaped miss.
4. Decrease severity when the hazard is present but not strategically relevant for the expected landing band.

Outputs:

- severity class or numeric score
- context relevance
- confidence

Fallback behavior:

- if a hazard exists but the system cannot determine contextual relevance, classify it as visible context with low strategic weight rather than over-penalizing it

### 20. Use explicit confidence gates before overlays become publishable strategy inputs

Each overlay should be scored independently and then combined into a hole-level publishability decision.

Suggested confidence inputs:

- source completeness
- centerline density
- fairway and green polygon quality
- hazard coverage
- OB coverage
- elevation availability
- internal consistency of derived outputs

Suggested publish behavior:

- `high confidence`: available to mobile and strategy engine as precise overlay
- `medium confidence`: available, but voice/runtime should use broader language
- `low confidence`: omit precise overlay and fall back to simpler strategic heuristics

This makes Course Studio a trustworthy publisher instead of a false-precision generator.

### 21. Publish overlays as canonical strategy objects with shared metadata

Every derived overlay should share a common envelope so the strategy engine and mobile app can consume one stable contract.

Shared overlay envelope:

- `overlay_id`
- `overlay_type`
- `course_id`
- `hole_id`
- `tee_set_id` or `applicability`
- `shot_phase`
- `geometry`
- `properties`
- `confidence`
- `rationale`
- `constraints`
- `provenance`
- `derived_at`
- `derivation_version`

Shared semantics:

- `geometry` stores the spatial representation:
  - polygon for corridors or zones
  - point for aim anchors
  - line or segment where needed
- `confidence` contains both a normalized score and coarse band
- `rationale` explains why the overlay exists
- `constraints` describes the conditions where the overlay is valid
- `provenance` records provider source and derivation lineage

This shared envelope keeps downstream logic simple and makes it possible to add new overlays later without inventing a brand-new contract each time.

### 22. Canonical object: tee_target_corridor

Purpose:

- represent the default stock tee-shot landing window

Canonical object:

- `overlay_type`: `tee_target_corridor`
- `shot_phase`: `tee`
- `geometry`:
  - corridor polygon
  - optional center anchor point
- `properties`:
  - `landing_distance_min_m`
  - `landing_distance_max_m`
  - `corridor_width_m`
  - `corridor_depth_m`
  - `play_intent` such as `stock`
  - `angle_value_score`
  - `safety_score`
  - `target_label`
- `rationale`:
  - `primary_reason`
  - `secondary_reason`
- `constraints`:
  - player distance band or archetype
  - wind assumptions if any
- `confidence`
- `provenance`

Example meaning:

- "For white tee players with a standard driver or strong wood band, this is the safest useful landing shelf."

### 23. Canonical object: aggressive_tee_corridor

Purpose:

- represent a higher-reward tee-shot window that remains strategically viable

Canonical object:

- `overlay_type`: `aggressive_tee_corridor`
- `shot_phase`: `tee`
- `geometry`:
  - corridor polygon
  - optional center anchor point
- `properties`:
  - `landing_distance_min_m`
  - `landing_distance_max_m`
  - `corridor_width_m`
  - `corridor_depth_m`
  - `play_intent` set to `aggressive`
  - `reward_type` such as `shorter_approach`, `better_angle`, or `reachable_next`
  - `reward_score`
  - `additional_risk_score`
- `rationale`:
  - `primary_reason`
  - `risk_note`
- `constraints`
- `confidence`
- `provenance`

Important rule:

- this overlay should be absent if no meaningful aggressive alternative exists

### 24. Canonical object: layup_candidate

Purpose:

- represent a deliberate landing shelf chosen for next-shot quality

Canonical object:

- `overlay_type`: `layup_candidate`
- `shot_phase`: `layup`
- `geometry`:
  - layup zone polygon
  - optional aim anchor point
- `properties`:
  - `candidate_rank`
  - `layup_type` such as `wedge_leave`, `short_iron_leave`, or `safe_position`
  - `landing_distance_min_m`
  - `landing_distance_max_m`
  - `expected_leave_min_m`
  - `expected_leave_max_m`
  - `green_entry_angle_score`
  - `safety_score`
  - `next_shot_quality_score`
- `rationale`:
  - `primary_reason`
  - `expected_next_shot`
- `constraints`
- `confidence`
- `provenance`

Important rule:

- multiple layup candidates may exist, but V1 should usually publish at most one to three ranked candidates

### 25. Canonical object: preferred_miss

Purpose:

- express the least damaging miss direction around a target for a given shot phase

Canonical object:

- `overlay_type`: `preferred_miss`
- `shot_phase`: `tee`, `layup`, or `approach`
- `geometry`:
  - optional miss-side polygon or directional sector
  - optional paired target reference
- `properties`:
  - `preferred_direction` such as `left`, `right`, `short`, `long`, or `neutral`
  - `avoid_direction`
  - `miss_tolerance_width_m`
  - `relative_cost_preferred`
  - `relative_cost_avoid`
- `rationale`:
  - `primary_reason`
- `constraints`
- `confidence`
- `provenance`

Important rule:

- `preferred_direction: neutral` is a valid and desirable output when the system cannot clearly distinguish miss costs

### 26. Canonical object: hazard_severity

Purpose:

- represent the strategic cost of a specific hazard relative to likely landing or miss outcomes

Canonical object:

- `overlay_type`: `hazard_severity`
- `shot_phase`: `tee`, `layup`, `approach`, or `all`
- `geometry`:
  - usually the original hazard polygon or line reference
- `properties`:
  - `hazard_ref_id`
  - `hazard_kind`
  - `severity_band` such as `low`, `medium`, `high`, or `critical`
  - `severity_score`
  - `context_relevance_score`
  - `penalty_kind` such as `stroke_penalty`, `recovery_only`, or `angle_loss`
  - `landing_conflict` boolean
  - `blocks_recovery` boolean
- `rationale`:
  - `primary_reason`
- `constraints`
- `confidence`
- `provenance`

Important rule:

- hazard severity is contextual and may differ by shot phase on the same hole

### 27. Use a compact bundle shape with base mapping and strategy overlays split cleanly

Each published hole bundle should be shaped roughly like:

```json
{
  "hole_id": "7",
  "par": 5,
  "base_mapping_data": {
    "tees": {},
    "centerline": {},
    "green": {},
    "features": []
  },
  "strategy_overlays": {
    "tee_target_corridors": [],
    "aggressive_tee_corridors": [],
    "layup_candidates": [],
    "preferred_miss": [],
    "hazard_severity": []
  },
  "quality_confidence": {
    "hole_publish_confidence": "medium"
  },
  "provenance": {}
}
```

This split lets the strategy engine query either:

- raw-ish geometry facts
- or TrueCaddie-owned strategic interpretations

without confusing the two layers.

### 28. Define the strategy engine request and response contract independently of UI concerns

The strategy engine should consume a canonical request and emit a canonical recommendation packet before the voice model speaks. In V1 this request/response happens on-device, but the contract should remain stable enough for replay tools and tests outside the app.

Suggested request shape:

```json
{
  "course_bundle_ref": {
    "course_id": "kungsbacka-nya",
    "hole_id": "7",
    "bundle_version": "2026-05-10.4"
  },
  "player_context": {
    "player_id": "player-123",
    "tee_set_id": "white",
    "club_distances_m": {},
    "dispersion_model": {},
    "risk_profile": "balanced"
  },
  "round_context": {
    "shot_number": 2,
    "ball_position": {
      "lat": 57.4874,
      "lon": 11.9917
    },
    "lie": "fairway",
    "recent_pattern": "short-right"
  },
  "environment_context": {
    "wind_speed_mps": 4.5,
    "wind_bearing_deg": 240,
    "temperature_c": 14
  }
}
```

Suggested response shape:

```json
{
  "strategy_packet_version": "v1",
  "course_id": "kungsbacka-nya",
  "hole_id": "7",
  "tee_set_id": "white",
  "shot_number": 2,
  "recommended_club": "5 iron",
  "recommended_shot_type": "stock",
  "target_type": "layup",
  "aim_point": {
    "label": "left-center layup window",
    "coordinates": [11.9917, 57.4874]
  },
  "target_window_ref": "layup-candidate-1",
  "preferred_miss": "left",
  "risk_level": "medium",
  "confidence": 0.82,
  "primary_reason": "water right starts too early for an aggressive chase",
  "secondary_reason": "this leave preserves a clean wedge angle",
  "conservative_option": {},
  "aggressive_option": {},
  "hazard_summary": []
}
```

This contract is the point where Course Studio ends, on-device strategy begins, and voice remains a downstream rendering layer.

### 29. Define the on-device strategy engine module boundary

Inside the iOS app, the strategy engine should be packaged as a dedicated module with clear dependencies and cached inputs.

Recommended module responsibilities:

- load and index published course bundles
- resolve current hole and tee set
- accept player, round, and environment context
- evaluate candidate shots
- emit a canonical strategy packet

Recommended non-responsibilities:

- direct UI rendering
- microphone or voice session handling
- network session orchestration
- raw provider ingestion

Recommended local inputs and caches:

- cached current-course bundle
- local player profile
- locally stored round state
- current weather snapshot

This keeps the round loop fast and available even with intermittent connectivity.

### 30. Define the on-device strategy request contract

The iOS app should pass a compact request object into the local strategy module rather than letting the module reach arbitrarily into app state.

Suggested on-device request shape:

```json
{
  "bundle_ref": {
    "course_id": "kungsbacka-nya",
    "hole_id": "7",
    "bundle_version": "2026-05-10.4"
  },
  "player_context": {
    "tee_set_id": "white",
    "club_distances_m": {},
    "dispersion_model": {},
    "risk_profile": "balanced"
  },
  "round_context": {
    "shot_number": 2,
    "ball_position": {
      "lat": 57.4874,
      "lon": 11.9917
    },
    "lie": "fairway",
    "recent_pattern": "short-right"
  },
  "environment_context": {
    "wind_speed_mps": 4.5,
    "wind_bearing_deg": 240,
    "temperature_c": 14
  }
}
```

The strategy module should return the canonical strategy packet without requiring the caller to understand internal geometry or overlay logic.

### 31. Define required offline behavior for the on-device strategy module

The on-device strategy engine should remain functional in degraded mode when network access drops.

Required offline-capable inputs:

- published course bundle already downloaded
- persisted player profile
- persisted round state
- last known weather snapshot

Required degraded behavior:

- continue to compute recommendations from local bundle and local state
- preserve last known environment assumptions when live weather is unavailable
- lower confidence or simplify recommendations when missing fresh weather or telemetry

### 32. Define the iOS runtime data flow from bundle load to voice response

The iOS runtime should operate as a clear local pipeline rather than a tangle of UI callbacks.

Recommended runtime stages:

1. `Course Bundle Store`
   - downloads approved bundles from Course Studio ahead of the round
   - keeps the selected course bundle cached locally
   - exposes the active course, hole, and bundle version

2. `Round Session Store`
   - holds current round state:
     - selected tee set
     - current hole
     - shot number
     - last confirmed ball position
     - lie
     - recent miss pattern
     - user overrides

3. `Shot Context Resolver`
   - combines:
     - active hole bundle
     - current GPS position
     - snapped hole position
     - round state
     - player profile
     - current or last-known weather
   - produces the canonical on-device strategy request

4. `On-Device Strategy Engine`
   - consumes the resolved request
   - evaluates candidate shots
   - emits the canonical strategy packet

5. `Presentation Fan-Out`
   - sends the strategy packet to:
     - the voice layer for natural caddie phrasing
     - the glanceable UI for map/card rendering
     - the round state store for continuity

This keeps the runtime deterministic and makes it easier to debug each stage independently.

### 33. Define when the iOS app should invoke the on-device strategy engine

The strategy module should not run continuously without purpose. V1 should trigger recomputation on clear events:

- course or hole selection changes
- tee set changes
- player starts a new shot
- ball position changes meaningfully after a confirmed shot
- lie changes
- user applies an override such as conservative/aggressive or wind correction
- fresh weather arrives with meaningful difference
- user explicitly asks for advice

Recommended V1 behavior:

- precompute a default packet when arriving at a new shot context
- recompute immediately on high-signal context changes
- avoid recomputing on every tiny GPS jitter update

### 34. Define shot-context resolution before strategy evaluation

The iOS app needs a local resolver that turns noisy runtime state into a clean strategy request.

Responsibilities:

- map-match current GPS position into the active hole corridor
- determine likely shot phase:
  - tee
  - layup
  - approach
  - recovery
  - green-side
- infer or accept current lie
- merge user overrides
- choose the applicable overlays for the active tee set and shot phase
- attach the best available weather snapshot

Important design rule:

- the strategy engine should receive already-resolved context, not raw sensor chaos

This keeps golf logic focused on recommendation quality rather than noisy device-state cleanup.

### 35. Define how strategy packets feed both UI and voice

Once the local strategy engine returns a strategy packet, the packet should be treated as the single source of truth for downstream presentation.

UI consumption:

- map view highlights:
  - target corridor
  - aim point
  - preferred miss
  - key hazards
- shot card shows:
  - club
  - target label
  - confidence
  - safe/aggressive toggle if present

Voice consumption:

- voice layer receives the strategy packet plus limited conversational context
- voice must not alter club, line, or risk semantics
- voice may choose:
  - phrasing
  - brevity
  - what to mention first
  - whether to ask a short follow-up

This keeps visual and spoken advice aligned instead of letting them drift.

### 36. Define the minimum local caches required for smooth round play

The iOS app should keep the following local caches ready before a round begins:

- active course bundle
- nearby hole geometry for current round progression
- player profile and club model
- recent round-state snapshots
- last known weather snapshot
- latest strategy packet per active shot context

Using these caches, the app can:

- open the current hole instantly
- recover after temporary suspension or reconnect
- replay the current strategy state into UI and voice without re-fetching the world

### 37. Define runtime fallback behavior by failure point

The runtime should fail gracefully depending on where the pipeline breaks.

If weather is stale:

- keep strategy available
- lower confidence
- mention uncertainty only if materially relevant

If GPS is noisy:

- preserve last confirmed shot context
- avoid unnecessary strategy churn
- allow manual correction

If voice session is unavailable:

- keep the local strategy engine and shot card fully usable
- allow tap-to-hear via local or deferred voice mechanisms if available

If strategy evaluation fails unexpectedly:

- fall back to cached last packet for the same shot context when safe
- otherwise fall back to distance-first guidance with reduced intelligence

The user should lose polish before losing core utility.

### 38. Define the Swift-side module map for TrueCaddie Mobile

The iOS app should be split into focused modules so golf logic, runtime state, and voice orchestration do not collapse into one large feature surface.

Recommended module map:

1. `CourseBundleKit`
   - load, validate, and index published course bundles
   - expose hole geometry and strategy overlays by course, hole, and tee set

2. `PlayerProfileKit`
   - persist club distances, dispersion model, and risk profile
   - expose a normalized player context to the strategy module

3. `RoundSessionKit`
   - hold current round state:
     - selected course
     - tee set
     - hole
     - shot number
     - last confirmed ball position
     - lie
     - overrides
     - recent shot outcomes

4. `EnvironmentKit`
   - fetch and cache weather snapshots
   - normalize wind and temperature inputs for strategy use

5. `ShotContextResolverKit`
   - combine bundle, GPS, player, round, and environment into a canonical strategy request
   - resolve shot phase and applicable overlays

6. `StrategyEngineKit`
   - own the deterministic recommendation logic
   - evaluate candidates and return the canonical strategy packet

7. `VoiceCoordinatorKit`
   - own realtime voice session state
   - translate strategy packets into voice prompts and conversational context
   - handle interruptions and response timing

8. `PresentationStateKit`
   - convert strategy packets into UI-friendly state for map overlays, cards, and controls

9. `TelemetryKit`
   - capture recommendation acceptance, overrides, outcomes, and latency

Recommended dependency direction:

```text
CourseBundleKit
PlayerProfileKit
RoundSessionKit
EnvironmentKit
        │
        ▼
ShotContextResolverKit
        │
        ▼
StrategyEngineKit
        │
        ├─> VoiceCoordinatorKit
        └─> PresentationStateKit
```

Important design rules:

- `StrategyEngineKit` must not depend on SwiftUI
- `VoiceCoordinatorKit` must consume strategy packets, not invent strategy
- `PresentationStateKit` must render the packet faithfully rather than re-deciding golf logic

### 39. Define the concrete published course bundle schema at V1 fidelity

The published bundle should be concrete enough that mobile can load it directly without provider-specific branching.

Top-level bundle shape:

```json
{
  "bundle_version": "2026-05-10.4",
  "course_id": "kungsbacka-nya",
  "course_name": "Kungsbacka Nya",
  "schema_version": "v1",
  "published_at": "2026-05-10T17:00:00Z",
  "provenance": {
    "provider": "igolf",
    "provider_version": "2026-05-08",
    "derivation_version": "course-studio-v1"
  },
  "holes": []
}
```

Per-hole V1 shape:

```json
{
  "hole_id": "7",
  "hole_number": 7,
  "par": 5,
  "default_play_direction": {
    "bearing_deg": 90.94
  },
  "tees": {},
  "base_mapping_data": {
    "centerline": {},
    "green": {},
    "features": [],
    "out_of_bounds_lines": [],
    "context_points": []
  },
  "strategy_overlays": {
    "tee_target_corridors": [],
    "aggressive_tee_corridors": [],
    "layup_candidates": [],
    "preferred_miss": [],
    "hazard_severity": []
  },
  "quality_confidence": {
    "hole_publish_confidence": "medium",
    "hole_publish_score": 0.78,
    "notes": []
  },
  "provenance": {
    "source_file": "kungsbacka-nya-hole-7.json"
  }
}
```

Required V1 sub-objects:

- `tees`
  - tee coordinates and tee length
- `centerline`
  - ordered coordinates and distance metadata if available
- `green`
  - front, center, back references and polygon ref
- `features`
  - canonicalized semantic polygons and lines
- `strategy_overlays`
  - V1 overlay objects defined earlier
- `quality_confidence`
  - publishability and trust metadata

Suggested feature object shape:

```json
{
  "feature_id": "water-1",
  "feature_type": "water",
  "hazard_kind": "water",
  "geometry": {},
  "properties": {
    "area_m2": 1335.272,
    "centerline_along_m": 92.76,
    "centerline_distance_m": 14.05,
    "centerline_side": "left"
  }
}
```

Suggested tee object shape:

```json
{
  "tee_set_id": "white",
  "name": "White",
  "tee_coordinate": [11.9862, 57.4930],
  "tee_length_m": 460,
  "is_default": true
}
```

Suggested quality block:

```json
{
  "hole_publish_confidence": "medium",
  "hole_publish_score": 0.78,
  "overlay_scores": {
    "tee_target_corridor": 0.84,
    "preferred_miss": 0.73,
    "layup_candidates": 0.49
  },
  "notes": [
    "landing-zone placeholders replaced by derived candidate only",
    "green elevation incomplete"
  ]
}
```

This level of concreteness is enough to let the iOS app build loaders, indices, caches, and strategy requests without guessing.

### 40. Define the first-pass single-shot evaluation algorithm

The V1 strategy engine should evaluate one shot using a narrow, staged algorithm rather than a giant opaque process.

Recommended single-shot evaluation flow:

1. `Resolve shot context`
   - identify hole, tee set, shot phase, lie, ball position, and environment assumptions

2. `Load relevant geometry and overlays`
   - active centerline segment
   - current hazards near likely landing or miss zones
   - applicable target corridors or layup candidates
   - preferred miss hints if confidence is sufficient

3. `Generate candidate actions`
   - candidate clubs based on player distance model
   - candidate intents such as:
     - stock
     - conservative
     - aggressive
   - candidate targets based on overlays and centerline geometry

4. `Project candidate outcomes`
   - estimate landing band for each club/intent pair
   - adjust for lie, wind, and confidence modifiers
   - map likely finish zones against hazards and playable areas

5. `Score candidates`
   - safety score
   - next-shot quality score
   - penalty exposure score
   - angle value score
   - fit-to-player score

6. `Apply policy filters`
   - reject candidates that violate hard constraints:
     - excessive penalty exposure
     - clearly blocked recovery
     - unrealistic carry for the player
   - compress noisy differences when confidence is low

7. `Select output set`
   - choose one baseline recommendation
   - choose one conservative alternative when distinct
   - choose one aggressive alternative when viable

8. `Assemble strategy packet`
   - recommended club
   - aim point / target window
   - preferred miss
   - risk level
   - confidence
   - primary and secondary reasons

This gives a deterministic but intelligible path from context to recommendation.

### 41. Define the first-pass candidate scoring model for V1

The V1 scoring model should stay simple enough to tune manually.

Suggested candidate score components:

- `playability_score`
  - how likely the shot finishes in a playable zone
- `penalty_risk_score`
  - how likely the shot creates stroke-penalty or severe trouble
- `recovery_cost_score`
  - how damaging a miss is if it occurs
- `next_shot_value_score`
  - how favorable the resulting next shot is
- `player_fit_score`
  - how well the shot matches the player's distance band and dispersion

Suggested initial selection logic:

```text
total_score =
  playability_score
  + next_shot_value_score
  + player_fit_score
  - penalty_risk_score
  - recovery_cost_score
```

The exact weights should remain configurable in the engine, but V1 should prefer transparent hand-tuned weights over premature model complexity.

### 42. Define how the single-shot algorithm degrades under weak data

When bundle confidence is weak or some overlays are absent, the engine should simplify rather than hallucinate detail.

Examples:

- if `layup_candidates` confidence is low:
  - fall back to distance-and-hazard-based safe layup reasoning
- if `preferred_miss` is absent:
  - omit miss-side guidance from the packet
- if weather is stale:
  - apply reduced-confidence environmental adjustments
- if hazard coverage is sparse:
  - center recommendations more heavily on fairway width and centerline safety

This makes the V1 engine resilient across mixed data quality tiers.

### 43. Define the V1 strategy packet field by field

The V1 strategy packet should be the single authoritative object handed from the on-device strategy engine to both the voice layer and the UI layer.

Design goals:

- compact enough for low-latency on-device use
- explicit enough that voice does not need to infer golf logic
- stable enough for replay, logging, and testing
- flexible enough to degrade when confidence is weak

### 44. Required packet fields for every V1 recommendation

These fields should always be present in the V1 packet.

Identity and context:

- `strategy_packet_version`
- `course_id`
- `hole_id`
- `tee_set_id`
- `shot_number`
- `shot_phase`
- `bundle_version`

Primary recommendation:

- `recommended_club`
- `recommended_shot_type`
- `target_type`
- `aim_point`
- `risk_level`
- `confidence`
- `primary_reason`

Packet control:

- `packet_quality_band`
- `generated_at`

Definitions:

- `recommended_club`
  - the primary club recommendation in human-readable form
- `recommended_shot_type`
  - examples: `stock`, `smooth`, `flighted`, `layup`, `positional`
- `target_type`
  - examples: `tee_corridor`, `aggressive_tee_corridor`, `layup_candidate`, `approach_window`, `center_green_fallback`
- `aim_point`
  - the actual target anchor for rendering and phrasing
- `risk_level`
  - examples: `low`, `medium`, `high`
- `confidence`
  - normalized numeric confidence, usually `0.0 - 1.0`
- `packet_quality_band`
  - coarse summary such as `high`, `medium`, or `degraded`

These fields are the minimum needed for the app to show advice and the voice layer to speak coherently.

### 45. Strongly recommended packet fields when data quality allows

These fields should be included whenever the engine can support them with sufficient confidence.

- `secondary_reason`
- `target_window_ref`
- `target_window_summary`
- `preferred_miss`
- `avoid_direction`
- `distance_to_target_m`
- `expected_landing_distance_m`
- `hazard_summary`
- `conservative_option`
- `aggressive_option`
- `source_overlay_refs`

Definitions:

- `target_window_ref`
  - reference to the overlay object that informed the chosen target
- `target_window_summary`
  - short description like `left-center fairway shelf`
- `preferred_miss`
  - examples: `left`, `right`, `short`, `long`, `neutral`
- `avoid_direction`
  - the miss direction or zone the engine most wants to avoid
- `hazard_summary`
  - short ordered list of the most strategically relevant hazards
- `source_overlay_refs`
  - overlay IDs used in producing the recommendation for debugging and replay

These fields make the packet much more useful operationally, but they should not be fabricated when the underlying data is weak.

### 46. Optional packet fields for richer future behavior

These are useful but should not block V1 if they complicate the first implementation.

- `expected_leave_distance_m`
- `angle_value_score`
- `playability_score`
- `penalty_risk_score`
- `next_shot_value_score`
- `player_fit_score`
- `weather_adjustment_summary`
- `lie_adjustment_summary`
- `notes_for_ui`
- `notes_to_suppress_in_voice`

These can help with analytics, debugging, and future presentation refinement without being essential to the first shipped loop.

### 47. Define the V1 packet object shape

Suggested V1 packet shape:

```json
{
  "strategy_packet_version": "v1",
  "course_id": "kungsbacka-nya",
  "hole_id": "7",
  "tee_set_id": "white",
  "bundle_version": "2026-05-10.4",
  "shot_number": 2,
  "shot_phase": "layup",
  "distance_to_target_m": 214,
  "recommended_club": "5 iron",
  "recommended_shot_type": "stock",
  "target_type": "layup_candidate",
  "aim_point": {
    "label": "left-center layup window",
    "coordinates": [11.9917, 57.4874]
  },
  "target_window_ref": "layup-candidate-1",
  "target_window_summary": "left-center layup shelf",
  "preferred_miss": "left",
  "avoid_direction": "right",
  "risk_level": "medium",
  "confidence": 0.82,
  "packet_quality_band": "high",
  "primary_reason": "water right starts too early for a chase play",
  "secondary_reason": "this leave preserves a clean wedge angle",
  "hazard_summary": [
    "water right in the advance zone",
    "trees tighten both sides near the green"
  ],
  "conservative_option": {
    "club": "6 iron",
    "target_label": "front layup shelf"
  },
  "aggressive_option": {
    "club": "3 wood",
    "target_label": "green-front chase window"
  },
  "source_overlay_refs": [
    "layup-candidate-1",
    "preferred-miss-layup-1",
    "hazard-severity-water-1"
  ],
  "generated_at": "2026-05-10T17:00:00Z"
}
```

This is compact enough for the app, while still giving the voice layer no excuse to invent strategic content.

### 48. Define field provenance for the V1 packet

Each important packet field should have an expected origin so the system remains debuggable.

Suggested provenance map:

- `recommended_club`
  - from candidate scoring using player distance model and context
- `recommended_shot_type`
  - from candidate intent classification
- `target_type`
  - from selected overlay or fallback mode
- `aim_point`
  - from overlay geometry or centerline fallback
- `preferred_miss`
  - from `preferred_miss` overlay when confidence is sufficient, otherwise omitted or `neutral`
- `hazard_summary`
  - from top-ranked `hazard_severity` overlays relevant to the chosen target
- `confidence`
  - from combined recommendation confidence, overlay confidence, and context quality
- `primary_reason`
  - from the strongest scoring rationale behind the selected candidate
- `conservative_option` and `aggressive_option`
  - from adjacent viable candidates after policy filtering

This provenance map matters because it prevents packet fields from becoming unexplained convenience strings.

### 49. Define packet behavior when confidence is weak

When confidence is low, the packet should intentionally become simpler.

Rules:

- keep `recommended_club`, `aim_point`, `risk_level`, `confidence`, and `primary_reason`
- omit `aggressive_option` if upside logic is weak
- omit `preferred_miss` when no clear directional preference exists
- reduce `hazard_summary` to only one or two well-supported items
- use broader `target_type` values such as `centerline_fallback` or `center_green_fallback`
- set `packet_quality_band` to `degraded` when enough fields are missing that voice should become more cautious

Example degraded packet behavior:

- instead of:
  - `left-center fairway shelf with preferred miss left`
- the packet may simply say:
  - `stock tee corridor with avoid-right emphasis`

This is a feature, not a failure. It preserves trust.

### 50. Define what the voice layer may and may not infer from the packet

The packet should be rich enough that the voice layer does not need to re-decide golf strategy.

Voice layer may:

- choose concise wording
- choose which reason to mention first
- soften or tighten phrasing based on confidence
- ask a short clarifying question when the packet presents distinct alternatives

Voice layer may not:

- change the club recommendation
- invent a different target
- reverse preferred miss
- create a new aggressive line not present in the packet
- introduce hazard claims not grounded in `hazard_summary` or packet reasons

This rule protects the deterministic core while still letting the voice experience feel natural.

### 51. Define the actual V1 implementation roadmap across Course Studio, iOS, and pilot validation

V1 should be built as a sequence of vertical slices, not as parallel unfinished subsystems. Each phase should produce a testable artifact and reduce one major risk.

Guiding principle:

- first make the bundle trustworthy
- then make the on-device engine trustworthy
- then make the round loop trustworthy
- then make the voice experience feel premium

### 52. Phase 0: Bundle and pilot-data foundation

Goal:

- prove that `kungsbacka-nya` holes 1-9 can be represented as a stable published bundle

Primary work in `TrueCaddie Course Studio`:

- ingest the existing `kungsbacka-nya` JSON files
- normalize them into the canonical V1 bundle schema
- preserve provenance to the source files
- surface obvious data issues:
  - duplicate landing-zone placeholders
  - sparse OB coverage
  - incomplete elevation
  - duplicate feature naming

Primary work in iOS:

- build bundle-loading and local caching skeleton
- verify the app can load and inspect the pilot bundle without any strategy logic yet

Exit criteria:

- one versioned `kungsbacka-nya` bundle loads locally on device
- holes 1-9 render from the canonical bundle shape
- known data gaps are visible in a structured quality report

### 53. Phase 1: First-pass overlay derivation in Course Studio

Goal:

- produce the minimum strategic overlays needed for useful tee-shot and basic approach advice

Primary work in `TrueCaddie Course Studio`:

- derive `hazard_severity`
- derive `tee_target_corridor`
- derive `preferred_miss`
- derive `aggressive_tee_corridor` when meaningfully distinct
- derive `layup_candidates` on holes 1 and 7 first
- attach confidence scores to all derived overlays

Scope discipline:

- start with white tee as the calibration tee set
- use `kungsbacka-nya` holes 4 or 6 for the first tee-corridor validation
- use holes 1 and 7 for first layup validation

Primary work in iOS:

- build bundle inspection tools for overlay visualization
- verify overlays can be rendered on the hole map and compared against base geometry

Exit criteria:

- pilot bundle includes the five V1 overlay types
- overlay confidence is visible hole by hole
- at least a few pilot holes produce overlays that feel directionally correct in manual review

### 54. Phase 2: On-device strategy engine skeleton

Goal:

- prove the app can turn one local shot context into one deterministic packet

Primary work in iOS:

- implement `ShotContextResolverKit`
- implement `StrategyEngineKit` request and response contract
- implement candidate generation for:
  - baseline tee shot
  - conservative tee shot
  - aggressive tee shot
  - simple layup choice
- implement first-pass scoring model
- emit the V1 strategy packet

Primary work in Course Studio:

- stabilize overlay references and confidence metadata needed by the local engine

Validation method:

- use replayable shot fixtures rather than live rounds first
- run the same scenario multiple times and verify identical packets

Exit criteria:

- the app can compute a strategy packet offline for a fixed scenario
- repeated runs with identical inputs return identical output
- the packet references valid bundle overlays and confidence fields

### 55. Phase 3: Glanceable caddie UI without voice dependency

Goal:

- make the product useful before voice polish is added

Primary work in iOS:

- build shot card presentation from the packet
- render aim point, target corridor, and preferred miss on the hole map
- support overrides:
  - conservative
  - aggressive
  - wind stronger/weaker
  - club up/down
- show confidence and simplified fallback when packet quality is degraded

Validation method:

- walk through the pilot holes in simulator and with local test scenarios
- verify UI state changes correctly as shot context changes

Exit criteria:

- a player can get usable next-shot advice without voice
- UI and packet never diverge on club, target, or risk posture

### 56. Phase 4: Voice layer integration

Goal:

- make the caddie feel conversational without changing the underlying golf decisions

Primary work in iOS:

- integrate `VoiceCoordinatorKit`
- connect the local strategy packet to the realtime voice prompt contract
- handle interruptions and response restarts
- ensure voice requests trigger packet recomputation only when needed

Primary work using the `Voice Agent` prototype:

- reuse session bootstrap and tool-calling patterns where helpful
- adapt prompt design to the caddie packet contract instead of generic assistant behavior

Validation method:

- compare spoken output against the current visible packet
- verify the voice layer never invents a different club, line, or hazard story

Exit criteria:

- the spoken recommendation matches the packet
- interruptions feel natural
- response time is acceptable for on-course use

### 57. Phase 5: Pilot-course field validation

Goal:

- test whether the architecture and recommendation quality hold up in real rounds

Primary work:

- play or simulate real sequences on `kungsbacka-nya` holes 1-9
- compare recommendation quality across:
  - par 3s
  - tighter par 4s
  - par 5 layup decisions
- log:
  - accepted recommendations
  - overrides
  - obvious bad lines
  - confidence mismatches

Review focus:

- are layup candidates useful on holes 1 and 7?
- are preferred misses actually sensible?
- does degraded mode stay honest?
- does the voice layer feel like a caddie rather than a chatbot?

Exit criteria:

- pilot rounds expose a prioritized list of strategy and data defects
- the top failure modes are traceable to bundle quality, overlay derivation, or scoring logic
- the team can decide whether V1 is ready for broader course ingestion

### 58. Phase 6: V1 hardening before expansion

Goal:

- prepare the architecture to support more courses without losing trust

Primary work:

- improve Course Studio review workflow
- improve confidence heuristics
- close the most serious pilot-data gaps
- tune candidate scoring weights
- add operational metrics for:
  - packet latency
  - bundle load time
  - voice response start time
  - override frequency

Exit criteria:

- pilot quality is stable enough that adding a second course is an expansion step, not a reset

### 59. Recommended team execution order

If work is split among a small team, the healthiest sequence is:

1. Course Studio bundle and schema foundation
2. iOS bundle loader and map rendering
3. overlay derivation for the pilot
4. on-device strategy packet generation
5. packet-driven UI
6. packet-driven voice
7. live pilot validation

This ordering keeps dependencies flowing one way and prevents voice integration from masking weak golf logic.

### 60. Recommended definition of V1 done

V1 should be considered done only when all of the following are true:

- `kungsbacka-nya` holes 1-9 are published through Course Studio as a versioned bundle
- the iOS app can run the deterministic strategy engine offline for the pilot course
- the app provides useful next-shot advice on tee shots, simple approaches, and par 5 layups
- spoken advice is derived from the strategy packet rather than freeform reasoning
- degraded-confidence situations simplify gracefully instead of pretending precision
- pilot validation reveals manageable refinement work rather than architectural collapse

## Risks / Trade-offs

- [Course data depth is insufficient for premium recommendations] -> Start with a curated pilot course set and add a manual or semi-manual enrichment workflow.
- [The pilot dataset looks rich but may still omit key caddie concepts] -> Add an explicit gap analysis for `kungsbacka-nya` to identify missing layup, preferred-miss, and target-window semantics before engine work starts.
- [Provider data is rich enough for maps but not rich enough for caddie semantics] -> Derive TrueCaddie-owned overlays automatically in Course Studio and publish them with confidence scores.
- [Overlay derivation produces plausible but wrong precision] -> Require confidence scoring and simpler fallback bundle behavior when overlay confidence is low.
- [Realtime voice latency creeps up when tools are called on demand] -> Precompute round state, cache weather and hole bundles, and keep strategy packet generation lightweight.
- [The LLM over-explains or sounds generic] -> Keep a narrow prompt contract and prefer deterministic short-form response templates where possible.
- [GPS drift causes wrong target recommendations] -> Use corridor-based map matching, hole-aware snapping, and explicit user correction controls.
- [Personalization feels fake early on] -> Be conservative in V1 and only personalize from data the system truly has.
- [Architecture becomes overbuilt before product-market fit] -> Start with a modular monolith, not microservices, and keep course coverage intentionally limited.

## Migration Plan

1. Initialize the repo with architecture and capability specs.
2. Stand up the `TrueCaddie Course Studio` pipeline boundary and canonical bundle contract.
3. Normalize `kungsbacka-nya` holes 1-9 into the canonical hole-intelligence workspace and preserve links back to the original source files.
4. Build first-pass overlay derivation for the pilot:
   - tee corridors
   - layup candidates
   - preferred miss
   - hazard and recovery severity
   - confidence scoring
5. Build a thin vertical slice for the `kungsbacka-nya` pilot:
   - course bundle
   - player profile
   - deterministic recommendation from an on-device strategy engine request/response
   - realtime voice rendering
   - mobile next-shot loop
6. Validate with live rounds on the pilot course and tighten strategy packet quality before expanding scope.
7. Add personalization and broader enrichment only after the baseline loop is trusted.

Rollback strategy for early releases should be simple:

- preserve a touch-first recommendation UI if live voice fails
- preserve a basic distance-and-layup mode if enriched strategy is unavailable
- keep course bundle versions immutable so a bad enrichment can be reverted quickly

## Open Questions

- Is `kungsbacka-nya` holes 1-9 enough as the only V1 pilot, or do we want one contrast course later for validation after the first slice works?
- Which exact iGolf data products should be treated as required inputs for Course Studio V1: simple GPS, 2D GeoData, terrain, enhanced elements, or green heat maps?
- Which overlay derivations are strong enough to auto-publish in V1, and which must remain review-gated?
- Which parts of the strategy module should be implemented for offline-first operation in V1, and which can degrade when live data is stale?
- How much semantic geometry can be sourced externally versus curated in-house?
- Should weather use Apple WeatherKit first, another provider, or a provider abstraction from the start?
- How will shot outcomes be captured with low friction after each shot?
- How aggressive should V1 be about proactive voice versus push-to-talk interaction?
- What level of explainability should be exposed to the player versus kept internal for tuning?
