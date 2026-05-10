## Context

The architecture work for `truecaddie-v2-architecture` now defines two main product systems:

- `TrueCaddie Course Studio` as desktop/internal software that prepares course bundles
- `TrueCaddie Mobile` as the iOS runtime that consumes those bundles during play

The biggest early risk is not voice quality or advanced strategy. It is whether both systems can successfully share one canonical course bundle contract without drift. The pilot data for `kungsbacka-nya` holes 1-9 already exists and is rich enough to prove this contract, but the repo does not yet have a concrete implementation slice for shared schema, bundle publishing, and iOS bundle loading.

This change intentionally targets that seam first.

## Goals / Non-Goals

**Goals:**

- Define the initial repo layout for `ios/`, `course-studio/`, and `shared/`.
- Define the first concrete canonical course bundle schema in a shared location.
- Produce one published `kungsbacka-nya` pilot bundle with provenance and quality metadata.
- Let the iOS app load the bundle locally and inspect hole-level contents without depending on strategy or voice.
- Create fixtures and examples that future strategy and UI work can build on safely.

**Non-Goals:**

- Full provider ingestion automation from iGolf.
- Full overlay derivation pipeline for all V1 overlays.
- Full on-device strategy engine implementation.
- Realtime voice integration.
- Broad multi-course support.

## Decisions

### 1. Keep the first implementation slice cross-system but narrow

This change should touch all three architectural zones:

- `course-studio/`
- `shared/`
- `ios/`

but only through the narrow concern of bundle production and consumption.

Alternatives considered:

- Start in `ios/` only with hardcoded sample data
  - Rejected because it delays the real contract boundary.
- Start in `course-studio/` only with no mobile consumer
  - Rejected because schema quality is best tested with a real downstream loader.

### 2. Use `kungsbacka-nya` holes 1-9 as the first canonical sample bundle

The pilot course is already rich enough to validate bundle structure, provenance, quality metadata, and hole-level semantic objects.

Alternatives considered:

- Start from a simplified synthetic course
  - Rejected because it would under-test the real schema shape.

### 3. Put the bundle schema in `shared/`

The schema is a producer/consumer contract. It should not live only under Course Studio or only under iOS.

Alternatives considered:

- Put schema only under `course-studio/`
  - Rejected because it weakens shared ownership of the contract.
- Put schema only under `ios/`
  - Rejected because Course Studio is the publisher and needs first-class access too.

### 4. Treat the first bundle as a published artifact, not raw source data

The output of this slice should resemble the future published bundle shape with:

- course metadata
- per-hole canonicalized mapping data
- initial strategy overlay containers
- quality/confidence block
- provenance block

Even if some overlay lists are initially sparse or empty, the shape should match the long-term contract.

Alternatives considered:

- Use raw pilot JSON as the bundle
  - Rejected because the point of this slice is canonical publishing, not direct source reuse.

### 5. Build an iOS hole inspector before building real strategy

The first mobile consumer should be a bundle loader and inspection UI. This is the fastest way to visually validate:

- geometry loading
- tee data
- hazards
- overlays
- quality metadata

Alternatives considered:

- Start directly with strategy evaluation
  - Rejected because poor bundle understanding would make strategy debugging much harder.

## Risks / Trade-offs

- [The bundle schema may still change quickly] -> Accept early schema iteration, but centralize it in `shared/` to reduce drift.
- [The pilot data contains quirks like duplicate landing-zone placeholders] -> Preserve provenance and quality notes in the first bundle rather than hiding data issues.
- [The first bundle publisher becomes too specific to one course] -> Keep the pipeline narrow, but structure the publisher around canonical transforms rather than one-off app code.
- [The first iOS viewer becomes throwaway debug UI] -> Keep the inspection UI intentionally simple and treat it as a validation tool, not polished product UI.

## Migration Plan

1. Create the monorepo skeleton for `ios/`, `course-studio/`, and `shared/`.
2. Define the shared canonical bundle schema and example bundle files.
3. Add the pilot source data or references needed for `kungsbacka-nya`.
4. Publish the first canonical pilot bundle into a shared sample-bundle location.
5. Build the iOS-side loader and hole inspector against the shared sample bundle.
6. Use the resulting bundle and viewer as the base for the next strategy-oriented slice.

## Open Questions

- Should the first bundle publisher read directly from the current `kungsbacka-nya` JSON files or from a copied/snapshotted pilot-data directory inside this repo?
- Should the shared schema be expressed primarily as JSON examples, Swift types plus fixtures, or language-agnostic schema documentation first?
- How much validation should be built into the first publisher versus deferred to later iterations?
