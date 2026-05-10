## ADDED Requirements

### Requirement: Strategy recommendations must be produced deterministically

The system MUST produce club, target, and risk recommendations from structured inputs using deterministic engine logic rather than freeform LLM reasoning.

#### Scenario: Same inputs produce the same recommendation packet
- **WHEN** the same hole geometry, player context, weather, lie, and round state are evaluated multiple times
- **THEN** the strategy engine returns the same recommendation packet unless an input changes

### Requirement: The strategy engine must be consumable through a stable compute contract

The system MUST expose the strategy engine through a stable input/output contract so it can run as a dedicated on-device module independently of iOS UI-layer code.

#### Scenario: Strategy is evaluated outside the mobile runtime
- **WHEN** engineers or internal tools replay a golf situation using the same course bundle, player context, and environment context
- **THEN** the strategy engine can compute the same recommendation packet without depending on SwiftUI views or ad hoc app-state coupling

### Requirement: The strategy engine must support offline-capable on-device evaluation

The system MUST be able to evaluate recommendations on-device from locally cached course bundles and player context during degraded connectivity.

#### Scenario: Network degrades during a round
- **WHEN** the player loses network access after the course bundle and player profile have already been loaded
- **THEN** the strategy engine can still compute a recommendation packet using local bundle data, local round state, and the last known environment snapshot

### Requirement: Recommendations must include explainable strategy packets

The system MUST emit a structured packet that the voice layer can render without inventing golf logic.

#### Scenario: Voice layer requests next-shot advice
- **WHEN** a voice response is needed for a player's current shot
- **THEN** the strategy engine provides club, aim intent, risk level, confidence, primary reason, and alternative options in a structured output

### Requirement: The strategy engine must support conservative and aggressive framing

The system MUST be able to evaluate at least a baseline recommendation and a more aggressive or more conservative alternative where the situation allows.

#### Scenario: Player asks how aggressive to be
- **WHEN** the player explicitly asks for the aggressive versus safe play
- **THEN** the engine can compare viable options using the same deterministic context instead of generating separate ad hoc reasoning
