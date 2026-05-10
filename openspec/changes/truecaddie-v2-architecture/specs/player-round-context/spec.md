## ADDED Requirements

### Requirement: Player context must combine persistent profile and live round state

The system MUST maintain both long-lived player tendencies and within-round state so strategy can adapt without losing continuity.

#### Scenario: Recommendation uses both profile and current round signals
- **WHEN** the strategy engine evaluates a shot
- **THEN** it can access club distances, dispersion tendencies, risk posture, and current round state such as recent misses, lie, and hole progress

### Requirement: Live round context must be updateable after each shot

The system MUST accept lightweight updates after each shot so recommendations can reflect what is happening today rather than only historical averages.

#### Scenario: Miss pattern changes during a round
- **WHEN** the player repeatedly misses short or right during a round
- **THEN** the round context can record that trend for subsequent recommendation adjustments

### Requirement: Context confidence must reflect known versus inferred data

The system MUST distinguish between directly supplied player data and inferred adjustments so the product does not overstate certainty.

#### Scenario: Limited player history
- **WHEN** the player has little or no historical shot data
- **THEN** the system falls back to baseline assumptions and marks personalization confidence lower than for well-observed players
