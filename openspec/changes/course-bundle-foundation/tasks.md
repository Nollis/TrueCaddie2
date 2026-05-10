## 1. Repo Foundation

- [x] 1.1 Define the initial monorepo layout for `ios/`, `course-studio/`, and `shared/`.
- [x] 1.2 Decide where pilot source data, shared schema files, and published sample bundles should live inside the repo.
- [x] 1.3 Define the first shared ownership boundary for the bundle contract so future changes remain centralized.

## 2. Shared Bundle Contract

- [x] 2.1 Define the first concrete canonical course bundle schema in `shared/`.
- [x] 2.2 Define the required bundle-level and hole-level provenance fields.
- [x] 2.3 Define the required quality/confidence fields for the first published pilot bundle.

## 3. Course Studio Publisher

- [x] 3.1 Define the first transform path from `kungsbacka-nya` source JSON into the canonical bundle shape.
- [x] 3.2 Define how the first publisher preserves source lineage and known data-quality notes.
- [x] 3.3 Define the first published pilot-bundle artifact location and versioning convention.

## 4. iOS Bundle Consumer

- [x] 4.1 Define the first local bundle-loading path in the iOS app for the canonical pilot bundle.
- [x] 4.2 Define the hole-inspection surface that exposes tees, features, overlays, and quality metadata.
- [x] 4.3 Define how the iOS runtime identifies the active bundle version and course identity.

## 5. Validation

- [x] 5.1 Define the acceptance checks that prove the pilot bundle shape is valid across publisher and consumer.
- [x] 5.2 Define how the team will verify that hole 1-9 data from `kungsbacka-nya` survives canonicalization correctly.
- [x] 5.3 Define the exit criteria for closing this slice and starting the next strategy-oriented slice.
