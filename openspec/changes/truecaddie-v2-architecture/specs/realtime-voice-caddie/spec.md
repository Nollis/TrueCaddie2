## ADDED Requirements

### Requirement: Voice must be a rendering layer over structured strategy

The realtime voice system MUST turn deterministic strategy packets into concise golf-native dialogue without becoming the source of strategy truth.

#### Scenario: Voice responds to a shot question
- **WHEN** the player asks a question such as "What do you think here?"
- **THEN** the voice layer uses the latest structured strategy packet to answer in concise caddie language

### Requirement: Voice sessions must support interruption and low-friction turn taking

The realtime voice system MUST support interruption-friendly conversation so the player can naturally cut in or change the question mid-response.

#### Scenario: Player interrupts mid-answer
- **WHEN** the player speaks while the system is responding
- **THEN** the active response can be interrupted and the next turn can continue with preserved round context

### Requirement: Tool orchestration must stay server-side

The realtime voice system MUST keep deterministic strategy logic and protected business rules on the server side rather than exposing them as client-only prompt logic.

#### Scenario: Realtime session needs fresh strategy
- **WHEN** the voice session needs an updated recommendation
- **THEN** the backend handles the strategy tool interaction and returns structured results to the session without leaking private business logic into the client
