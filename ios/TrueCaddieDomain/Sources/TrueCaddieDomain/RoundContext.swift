import Foundation

public struct RoundContext: Equatable, Sendable {
    public let teeSetId: String
    public let teeSetName: String
    public let strategyPreference: StrategyPreference
    public let wind: WindContext?

    public init(
        teeSetId: String,
        teeSetName: String,
        strategyPreference: StrategyPreference,
        wind: WindContext?
    ) {
        self.teeSetId = teeSetId
        self.teeSetName = teeSetName
        self.strategyPreference = strategyPreference
        self.wind = wind
    }
}

public struct WindContext: Equatable, Sendable {
    public let relativeDirection: WindRelativeDirection
    public let speedMps: Double

    public init(relativeDirection: WindRelativeDirection, speedMps: Double) {
        self.relativeDirection = relativeDirection
        self.speedMps = speedMps
    }
}

public enum StrategyPreference: String, Equatable, Sendable {
    case conservative
    case balanced
    case aggressive
}

public enum WindRelativeDirection: String, Equatable, Sendable {
    case helping
    case hurting
    case cross
}

public extension RoundContext {
    static let pilotSample = RoundContext(
        teeSetId: "white",
        teeSetName: "White",
        strategyPreference: .balanced,
        wind: WindContext(relativeDirection: .helping, speedMps: 5.0)
    )
}
