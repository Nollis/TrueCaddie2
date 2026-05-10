## ADDED Requirements

### Requirement: The canonical course bundle schema must be shared between Course Studio and iOS

The system MUST define the canonical bundle contract in a shared location that both the publisher and the mobile consumer use.

#### Scenario: Publisher and mobile app evolve together
- **WHEN** Course Studio publishes a new pilot bundle and the iOS app loads it
- **THEN** both systems rely on the same shared bundle shape rather than separate, diverging interpretations

### Requirement: The first shared bundle must support the pilot course

The system MUST represent `kungsbacka-nya` holes 1-9 in the canonical bundle format with hole data, tees, features, quality metadata, and provenance.

#### Scenario: Pilot bundle is produced
- **WHEN** the first canonical pilot bundle is generated
- **THEN** it contains the full pilot course in the shared bundle structure without requiring raw source files at runtime

### Requirement: Shared bundles must include quality and provenance metadata

The system MUST preserve bundle-level and hole-level provenance and quality metadata so downstream systems can inspect source lineage and known weaknesses.

#### Scenario: Hole has known data issues
- **WHEN** a hole contains quirks such as duplicate placeholder landing zones or incomplete elevation
- **THEN** the canonical bundle can surface those issues in structured metadata rather than silently dropping them
