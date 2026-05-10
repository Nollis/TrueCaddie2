## ADDED Requirements

### Requirement: The round experience must be mobile-first and minimal-friction

The product MUST support a next-shot interaction loop that minimizes taps and avoids chat-style UI overhead during live play.

#### Scenario: Player moves through a hole
- **WHEN** the player advances from tee shot to approach to recovery shot
- **THEN** the app keeps the current shot context visible and ready without requiring repeated deep navigation

### Requirement: Quick overrides must be available without breaking flow

The product MUST provide lightweight controls for correcting or steering recommendations when the player wants a different posture than the default.

#### Scenario: Player wants a safer plan
- **WHEN** the player chooses a conservative option or signals a stronger wind or different miss tendency
- **THEN** the app can apply that override quickly and request an updated recommendation

### Requirement: Core round utility must survive temporary offline conditions

The product MUST continue to provide at least cached hole context, core distance awareness, and baseline recommendation support during temporary connectivity loss.

#### Scenario: Network drops during a round
- **WHEN** the player loses network access on course
- **THEN** the app retains enough local state and cached course data to continue supporting the round in a degraded mode
