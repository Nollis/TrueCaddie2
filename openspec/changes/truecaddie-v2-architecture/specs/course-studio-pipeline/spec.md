## ADDED Requirements

### Requirement: Course Studio must separate provider ingestion from mobile runtime consumption

The system MUST process provider course data in an upstream internal system named `TrueCaddie Course Studio` and publish versioned course bundles for downstream mobile use.

#### Scenario: Mobile app needs course data for a round
- **WHEN** the mobile app prepares to load a course
- **THEN** it retrieves a published course bundle from Course Studio rather than depending directly on raw provider payloads

### Requirement: Course Studio must derive TrueCaddie-owned strategy overlays automatically

The system MUST derive strategy overlays from provider geometry so the product can scale without manual hole authoring for every course.

#### Scenario: Provider geometry is available for a supported course
- **WHEN** Course Studio normalizes a course into the canonical schema
- **THEN** it derives overlays such as target corridors, layup candidates, preferred miss, and hazard or recovery severity using automated rules and geometry processing

### Requirement: Course Studio must publish confidence with every derived overlay

The system MUST attach confidence metadata to derived overlays so downstream systems can degrade gracefully when provider data or derivation quality is weak.

#### Scenario: Overlay quality is uncertain
- **WHEN** an overlay is derived from sparse, conflicting, or incomplete provider data
- **THEN** Course Studio includes lower-confidence metadata rather than publishing the overlay as if it were equally trustworthy

### Requirement: Course Studio must support review before publication

The system MUST allow low-confidence or high-importance holes to be reviewed before they are distributed to the mobile app.

#### Scenario: Hole fails auto-approval threshold
- **WHEN** Course Studio determines that a hole or overlay does not meet the confidence threshold for auto-publication
- **THEN** the hole enters a review workflow before an approved course bundle is published

### Requirement: Published overlays must use stable canonical objects

The system MUST publish derived strategy overlays using stable canonical object shapes so downstream strategy and mobile systems can consume them without depending on provider-specific geometry semantics.

#### Scenario: Mobile and strategy runtime load a published bundle
- **WHEN** a course bundle is downloaded from Course Studio
- **THEN** derived overlays such as tee corridors, layup candidates, preferred miss, and hazard severity appear in a consistent canonical structure with geometry, rationale, confidence, and provenance fields
