## ADDED Requirements

### Requirement: The iOS app must load the canonical pilot bundle locally

The system MUST load the canonical pilot course bundle from local storage so the runtime can inspect and use it without depending on raw source files.

#### Scenario: App starts with the pilot bundle available
- **WHEN** the iOS app opens the pilot course locally
- **THEN** it can parse and access the canonical bundle structure without custom parsing of raw source data

### Requirement: The first iOS consumer must support hole-level inspection

The system MUST provide a simple hole-level inspection path for the pilot bundle so developers can verify tees, features, overlays, and quality metadata on device.

#### Scenario: Developer inspects a pilot hole
- **WHEN** a developer opens a hole in the first iOS inspection view
- **THEN** the app can display the hole's canonical data, including geometry-derived content and metadata relevant to debugging

### Requirement: The iOS loader must surface bundle-version identity

The system MUST expose the loaded bundle's course identity and version metadata so later strategy and telemetry logic can depend on stable bundle references.

#### Scenario: App loads a published pilot bundle
- **WHEN** the iOS loader finishes loading the bundle
- **THEN** the runtime can identify the active `course_id`, `bundle_version`, and hole set from the canonical bundle metadata
