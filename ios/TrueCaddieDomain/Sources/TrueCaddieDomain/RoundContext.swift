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

    /// Map an absolute compass wind direction (degrees the wind is coming
    /// FROM, clockwise from north) and the current shot bearing (degrees
    /// clockwise from north) to one of the three relative directions.
    ///
    /// The "relative" angle is the bearing of the shot minus the direction
    /// the wind is coming from, normalized to `[0, 360)`:
    /// - ~0° (or ~360°): wind is hitting the shot head-on → `.hurting`.
    /// - ~180°: wind is from behind the shot → `.helping`.
    /// - ~90° / ~270°: perpendicular → `.cross`.
    ///
    /// The band half-width comes from
    /// ``GolfGeometry/Constants/windHelpingHurtingBandDeg`` (45°), so wind
    /// up to 45° off the shot axis still counts as hurting / helping.
    public static func from(windFromDeg: Double, shotBearingDeg: Double) -> WindRelativeDirection {
        let band = GolfGeometry.Constants.windHelpingHurtingBandDeg
        let raw = (shotBearingDeg - windFromDeg).truncatingRemainder(dividingBy: 360)
        let relative = raw < 0 ? raw + 360 : raw

        if relative <= band || relative >= (360 - band) {
            return .hurting
        }
        if relative >= (180 - band) && relative <= (180 + band) {
            return .helping
        }
        return .cross
    }
}

public extension RoundContext {
    static let pilotSample = RoundContext(
        teeSetId: "white",
        teeSetName: "White",
        strategyPreference: .balanced,
        wind: WindContext(relativeDirection: .helping, speedMps: 5.0)
    )
}
