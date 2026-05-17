import Foundation
import TrueCaddieDomain

// Wire-level Codable types used to serialize voice-session traffic across the
// realtime transport. Kept in their own file (as an extension on the
// HostCaddieSession namespace) so the session and controller code stay focused
// on behavior rather than schema.

extension HostCaddieSession {

    struct WireToolArguments: Codable, Equatable {
        let lie: ShotLie?
        let remainingDistanceM: Double?
        let strokesTaken: Int?
        let holeNumber: Int?

        init(
            lie: ShotLie? = nil,
            remainingDistanceM: Double? = nil,
            strokesTaken: Int? = nil,
            holeNumber: Int? = nil
        ) {
            self.lie = lie
            self.remainingDistanceM = remainingDistanceM
            self.strokesTaken = strokesTaken
            self.holeNumber = holeNumber
        }
    }

    struct WireToolCall: Codable, Equatable {
        let name: String
        let arguments: WireToolArguments
    }

    struct WireRoundContextSnapshot: Codable, Equatable {
        let teeSetId: String
        let teeSetName: String
        let strategyPreference: String
        let windRelativeDirection: String?
        let windSpeedMps: Double?
    }

    struct WireSessionStateSnapshot: Codable, Equatable {
        let selectedHoleNumber: Int
        let roundContext: WireRoundContextSnapshot
        let roundState: RoundState
        let availableToolNames: [String]
    }

    struct WireSessionRequest: Codable, Equatable {
        let utterance: String?
        let toolCall: WireToolCall?
    }

    struct WireSessionResponse: Codable, Equatable {
        let actionName: String
        let assistantReply: String
        let state: WireSessionStateSnapshot
        let strategyPreference: String?
    }

    struct WireToolParameterDefinition: Codable, Equatable, Identifiable {
        let name: String
        let type: String
        let required: Bool
        let description: String
        let allowedValues: [String]?

        var id: String { name }
    }

    struct WireToolCatalogEntry: Codable, Equatable, Identifiable {
        let name: String
        let description: String
        let parameters: [WireToolParameterDefinition]
        let sampleUtterances: [String]

        var id: String { name }
    }
}
