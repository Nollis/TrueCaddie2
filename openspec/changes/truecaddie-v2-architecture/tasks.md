## 1. Product And Architecture Foundation

- [ ] 1.1 Confirm the V1 product boundary around a deterministic conversational caddie for a curated course set.
- [ ] 1.2 Lock `kungsbacka-nya` holes 1-9 as the initial pilot course and document what geometry and metadata already exist in the current JSON dataset.
- [ ] 1.3 Name and define `TrueCaddie Course Studio` as the upstream internal system responsible for course ingestion, derivation, review, and publishing.
- [ ] 1.4 Decide the canonical V1 client platform and round-session ownership model.

## 2. Course Studio Foundation

- [ ] 2.1 Inventory `kungsbacka-nya` hole 1-9 JSON plus the older GIS assets and map them into the canonical hole-intelligence schema.
- [ ] 2.2 Define the storage model for centerlines, corridors, semantic features, out-of-bounds lines, context points, and course bundle versioning.
- [ ] 2.3 Define the base mapping layer versus the TrueCaddie-owned strategy overlay layer in the canonical schema.
- [ ] 2.4 Design the enrichment workflow for adding missing layup zones, preferred-miss regions, target windows, and confidence metadata to the pilot course.
- [ ] 2.5 Define the future Course Studio refinement step that derives denser geometric centerlines from tee anchors, green anchors, and fairway corridor geometry.
- [ ] 2.6 Define route-option semantics so Course Studio publishes possible corridors and candidate routes without pretending one static strategic line fits every player.

## 3. Overlay Derivation Pipeline

- [ ] 3.1 Define the first-pass automatically derived overlays for V1: tee corridors, layup candidates, preferred miss, hazard severity, and recovery severity.
- [ ] 3.2 Define the derivation inputs each overlay needs from provider geometry and metadata.
- [ ] 3.3 Define the tee-target-corridor derivation algorithm and its fallback behavior when geometry quality is weak.
- [ ] 3.4 Define the aggressive-tee-corridor derivation as a scored alternative rather than a separately authored target.
- [ ] 3.5 Define the layup-candidate derivation algorithm for par 5s and reachable par 4s.
- [ ] 3.6 Define the preferred-miss derivation rules by shot phase.
- [ ] 3.7 Define hazard-severity scoring and how it changes by shot context.
- [ ] 3.8 Define the canonical published object shape for each V1 overlay and its shared metadata envelope.
- [ ] 3.9 Define confidence scoring rules and the auto-approval threshold for course publication.
- [ ] 3.10 Define the review workflow for low-confidence holes before mobile distribution.

## 4. Player And Round Context

- [ ] 4.1 Define the baseline player profile fields required for V1 recommendations.
- [ ] 4.2 Define the minimum live round-state fields that must update between shots.
- [ ] 4.3 Define how inferred adjustments are separated from user-supplied truths in the data model.

## 5. Deterministic Strategy Engine

- [ ] 5.1 Specify the V1 recommendation packet contract consumed by the voice and mobile layers.
- [ ] 5.2 Define the on-device strategy-module request contract independent of SwiftUI and ad hoc app-state coupling.
- [ ] 5.3 Define the on-device bundle-loading and caching assumptions required for offline-capable evaluation.
- [ ] 5.4 Define the candidate-shot evaluation flow, including conservative and aggressive option handling.
- [ ] 5.5 Define the first-pass expected-outcome model for wind, lie, hazard exposure, and player dispersion.

## 6. Realtime Voice Architecture

- [ ] 6.1 Adapt the current `Voice Agent` prototype pattern into a production session architecture with server-side sideband control.
- [ ] 6.2 Define the prompt contract so the voice layer stays concise and never invents strategic reasoning.
- [ ] 6.3 Define failure and fallback behavior for interruption, reconnection, and degraded network conditions.

## 7. Mobile Round Companion

- [ ] 7.1 Design the next-shot mobile state machine from tee to green.
- [ ] 7.2 Define the quick override interactions for risk posture, conditions, and shot corrections.
- [ ] 7.3 Define the offline cache contents needed for a playable degraded round mode.
- [ ] 7.4 Define the shot-context resolver that turns GPS, lie, player state, and overrides into a clean on-device strategy request.
- [ ] 7.5 Define when the app recomputes strategy versus when it ignores low-signal changes like GPS jitter.
- [ ] 7.6 Define how the returned strategy packet feeds both the glanceable UI and the voice layer without divergence.

## 8. iOS Runtime Module Design

- [ ] 8.1 Define the Swift-side module map for bundle loading, player context, round state, environment, context resolution, strategy, voice, and presentation.
- [ ] 8.2 Define the dependency direction between runtime modules so strategy and voice remain decoupled from SwiftUI views.
- [ ] 8.3 Define the minimum per-round local caches required for fast resume and degraded offline play.

## 9. Bundle Schema And Evaluation Flow

- [ ] 9.1 Define the concrete published course bundle schema at V1 fidelity, including hole, tee, feature, overlay, confidence, and provenance objects.
- [ ] 9.2 Define the first-pass single-shot evaluation flow from request resolution to strategy packet assembly.
- [ ] 9.3 Define the first-pass candidate scoring model and weak-data fallback behavior.

## 10. Strategy Packet Contract

- [ ] 10.1 Define the required fields of the V1 strategy packet for UI and voice consumption.
- [ ] 10.2 Define the strongly recommended and optional packet fields, along with their provenance.
- [ ] 10.3 Define degraded packet behavior when overlay or context confidence is weak.
- [ ] 10.4 Define the presentation contract that limits what the voice layer may and may not infer from the packet.

## 11. Validation And Roadmap

- [ ] 11.1 Define how `kungsbacka-nya` pilot recommendations will be validated with real golfers before broadening scope.
- [ ] 11.2 Split the roadmap into V1, V2, and V3 milestones with clear exit criteria for each phase.
- [ ] 11.3 Identify the highest-risk unknowns that need research spikes before implementation starts.

## 12. V1 Execution Sequencing

- [ ] 12.1 Define the vertical-slice implementation order across Course Studio, bundle loading, strategy evaluation, UI, and voice.
- [ ] 12.2 Define phase exit criteria so each V1 stage is testable before the next layer is built.
- [ ] 12.3 Define the V1 "done" bar for the `kungsbacka-nya` pilot before expansion to additional courses.
