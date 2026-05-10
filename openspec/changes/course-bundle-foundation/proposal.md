## Why

TrueCaddie now has a fairly complete architecture, but the first implementation step needs to prove the producer/consumer contract between `TrueCaddie Course Studio` and the iOS app before strategy and voice are layered on top. The highest-value first slice is a shared bundle foundation that lets Course Studio publish one canonical pilot-course bundle and lets the iOS app load and inspect it locally.

## What Changes

- Establish the initial monorepo structure for `ios/`, `course-studio/`, and `shared/`.
- Define the first concrete V1 course bundle schema in a shared location that both systems can use.
- Normalize the `kungsbacka-nya` pilot data into one canonical published bundle artifact.
- Build the first Course Studio publishing path that outputs the pilot bundle without requiring full provider ingestion automation.
- Build the first iOS bundle-loading path and a simple hole-inspection surface for validating bundle contents on device.
- Add sample bundle fixtures and provenance/quality metadata to support replay, inspection, and future strategy work.
- Avoid full voice integration and full strategy implementation in this slice; the goal is contract validation, not a complete product loop.

## Capabilities

### New Capabilities

- `shared-course-bundle-foundation`: Shared canonical bundle schema, fixtures, and validation rules used by both Course Studio and the iOS app.
- `course-studio-bundle-publisher`: First-pass Course Studio flow for transforming pilot-course source data into a published course bundle artifact.
- `ios-bundle-runtime-loader`: On-device bundle loading, caching, and inspection for the published pilot bundle.

### Modified Capabilities

- None.

## Impact

- Creates the first real implementation seam between `TrueCaddie Course Studio` and `TrueCaddie Mobile`.
- Establishes the first shared data contract that future overlay derivation, strategy evaluation, and voice presentation will depend on.
- Uses `kungsbacka-nya` holes 1-9 as the pilot dataset and creates the first sample published bundle for downstream iOS consumption.
