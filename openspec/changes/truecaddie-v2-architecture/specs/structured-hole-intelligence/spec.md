## ADDED Requirements

### Requirement: Canonical hole intelligence must be semantic and spatial

The system MUST represent each playable hole as structured spatial data rather than relying on raw imagery or freeform text descriptions.

#### Scenario: Canonical hole bundle for strategy use
- **WHEN** a course is prepared for TrueCaddie use
- **THEN** each hole is stored with a canonical geometry bundle that includes a centerline, playable corridor, tee information, green target information, and semantic course features needed for strategy evaluation

### Requirement: Existing geometry seeds must remain reusable

The system MUST be able to ingest previously created centerline and corridor assets as seed geometry for the canonical hole model.

#### Scenario: Importing legacy hole geometry
- **WHEN** an operator imports existing centerline or corridor GIS assets
- **THEN** the system preserves those assets as reusable routing and map-matching inputs instead of requiring a full rebuild from scratch

### Requirement: Course intelligence must be deliverable offline

The system MUST support compact per-course or per-round hole bundles that can be cached on the mobile device for offline play.

#### Scenario: Starting a round with weak connectivity
- **WHEN** a player begins a round and connectivity is limited or lost
- **THEN** the app can load the current course's hole intelligence from locally cached structured bundles
