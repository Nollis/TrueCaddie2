## ADDED Requirements

### Requirement: Course Studio must publish a canonical pilot bundle artifact

The system MUST produce a published course bundle artifact for the pilot course rather than only holding transient normalized data.

#### Scenario: Pilot course is prepared for mobile use
- **WHEN** Course Studio finishes transforming the pilot source data
- **THEN** it emits a canonical published bundle artifact that the iOS app can load directly

### Requirement: The first publisher must preserve source lineage

The system MUST preserve the source lineage of the pilot-course data so the team can trace canonical fields back to source files.

#### Scenario: Canonical hole data is inspected
- **WHEN** a developer inspects a hole in the published pilot bundle
- **THEN** the hole's provenance metadata can identify its source file or source snapshot

### Requirement: The first publisher must tolerate incomplete overlay maturity

The system MUST be able to publish the pilot bundle even when derived overlays are incomplete, as long as the bundle shape remains canonical and quality metadata makes that clear.

#### Scenario: Overlay derivation is not fully implemented yet
- **WHEN** the first pilot bundle is published before all strategy overlays are mature
- **THEN** the bundle still publishes using canonical overlay containers plus structured quality notes
