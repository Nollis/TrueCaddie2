import Foundation

public struct ShotStateContext: Codable, Equatable, Sendable {
    public let shotNumber: Int
    public let remainingDistanceM: Double
    public let lie: ShotLie

    public init(
        shotNumber: Int,
        remainingDistanceM: Double,
        lie: ShotLie
    ) {
        self.shotNumber = shotNumber
        self.remainingDistanceM = remainingDistanceM
        self.lie = lie
    }
}

public enum ShotLie: String, Codable, Equatable, Sendable {
    case tee
    case fairway
    case rough
    case bunker
    case recovery
}
