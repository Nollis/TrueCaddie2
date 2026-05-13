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

### Requirement: Swift-first pilot sessions must keep golf logic out of the view layer

The realtime voice system MUST support a Swift-first iOS pilot architecture where session transport and audio coordination can live in-app, while deterministic strategy and round-state mutations stay inside a dedicated caddie session layer rather than in SwiftUI views or prompt-only logic.

#### Scenario: Realtime session needs fresh strategy
- **WHEN** the voice session needs an updated recommendation
- **THEN** the app routes the request through the dedicated caddie session layer and returns structured results without moving recommendation logic into the view or prompt text

### Requirement: Pilot direct auth must stay replaceable

The realtime voice system MUST allow a pilot direct-app authentication mode while isolating credential and session bootstrap logic behind replaceable abstractions for later hardening.

#### Scenario: Pilot build uses embedded credential
- **WHEN** the iOS pilot connects directly to the realtime service
- **THEN** credential retrieval and realtime session bootstrap are owned by dedicated abstractions and can later be replaced without rewriting the golf/session logic
