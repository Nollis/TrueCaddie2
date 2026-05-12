import Foundation

public struct PlayerContext: Equatable, Sendable {
    public let displayName: String
    public let handicapIndex: Double?
    public let riskTolerance: RiskTolerance
    public let clubs: [PlayerClub]

    public init(
        displayName: String,
        handicapIndex: Double?,
        riskTolerance: RiskTolerance,
        clubs: [PlayerClub]
    ) {
        self.displayName = displayName
        self.handicapIndex = handicapIndex
        self.riskTolerance = riskTolerance
        self.clubs = clubs.sorted { lhs, rhs in
            lhs.carryDistanceM > rhs.carryDistanceM
        }
    }
}

public struct PlayerClub: Equatable, Identifiable, Sendable {
    public let name: String
    public let carryDistanceM: Double

    public var id: String { name }

    public init(name: String, carryDistanceM: Double) {
        self.name = name
        self.carryDistanceM = carryDistanceM
    }
}

public enum RiskTolerance: String, Equatable, Sendable {
    case conservative
    case balanced
    case aggressive
}

public extension PlayerContext {
    static let pilotSample = PlayerContext(
        displayName: "Pilot Player",
        handicapIndex: 14.8,
        riskTolerance: .balanced,
        clubs: [
            PlayerClub(name: "Driver", carryDistanceM: 235),
            PlayerClub(name: "3 Wood", carryDistanceM: 215),
            PlayerClub(name: "5 Wood", carryDistanceM: 200),
            PlayerClub(name: "4 Hybrid", carryDistanceM: 188),
            PlayerClub(name: "5 Iron", carryDistanceM: 178),
            PlayerClub(name: "6 Iron", carryDistanceM: 168),
            PlayerClub(name: "7 Iron", carryDistanceM: 156),
            PlayerClub(name: "8 Iron", carryDistanceM: 144),
            PlayerClub(name: "9 Iron", carryDistanceM: 132),
            PlayerClub(name: "PW", carryDistanceM: 118)
        ]
    )
}
