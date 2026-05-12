import Foundation

public struct ApproachShotRecommendationPacket: Equatable, Sendable {
    public let courseId: String
    public let holeId: String
    public let holeNumber: Int
    public let shotPhase: String
    public let strategyPreference: String?
    public let approachDistanceM: Double
    public let targetLabel: String
    public let recommendedClub: String?
    public let clubCarryDistanceM: Double?
    public let preferredMissDirection: String?
    public let avoidDirection: String?
    public let riskLevel: String
    public let confidenceBand: String
    public let confidenceScore: Double
    public let primaryReason: String
    public let supportingReason: String?
    public let hazardSummary: [String]
}

public enum ApproachShotRecommendationEngine {
    public static func build(courseId: String, for hole: CourseHole) -> ApproachShotRecommendationPacket? {
        build(courseId: courseId, for: hole, playerContext: nil, roundContext: nil)
    }

    public static func build(
        courseId: String,
        for hole: CourseHole,
        playerContext: PlayerContext?,
        roundContext: RoundContext?
    ) -> ApproachShotRecommendationPacket? {
        guard let tee = selectedTee(in: hole, roundContext: roundContext) else {
            return nil
        }

        let holeLength = tee.teeLengthM
        let teeShot = TeeShotRecommendationEngine.build(
            courseId: courseId,
            for: hole,
            playerContext: playerContext,
            roundContext: roundContext
        )
        let baseApproachDistance: Double
        switch hole.par {
        case 3:
            baseApproachDistance = holeLength
        default:
            guard let teeShot else {
                return nil
            }
            baseApproachDistance = max(55, holeLength - teeShot.targetDistanceM)
        }

        let greensideHazards = greensideHazards(in: hole, holeLength: holeLength)
        let approachRisk = riskLevel(for: greensideHazards.first?.severity ?? 0)
        let target = approachTarget(
            for: hole.baseMappingData.green,
            riskLevel: approachRisk,
            roundContext: roundContext
        )
        let adjustedApproachDistance = max(45, baseApproachDistance + target.distanceAdjustmentM)
        let clubRecommendation = chooseClub(
            approachDistanceM: adjustedApproachDistance,
            playerContext: playerContext,
            roundContext: roundContext
        )
        let missGuidance = missGuidance(for: greensideHazards)
        let confidenceScore = confidenceScore(
            hole: hole,
            teeShot: teeShot,
            greensideHazards: greensideHazards
        )

        return ApproachShotRecommendationPacket(
            courseId: courseId,
            holeId: hole.holeId,
            holeNumber: hole.holeNumber,
            shotPhase: "approach",
            strategyPreference: roundContext?.strategyPreference.rawValue,
            approachDistanceM: adjustedApproachDistance,
            targetLabel: target.label,
            recommendedClub: clubRecommendation?.name,
            clubCarryDistanceM: clubRecommendation?.carryDistanceM,
            preferredMissDirection: missGuidance?.preferredDirection,
            avoidDirection: missGuidance?.avoidDirection,
            riskLevel: approachRisk,
            confidenceBand: confidenceBand(for: confidenceScore),
            confidenceScore: confidenceScore,
            primaryReason: primaryReason(
                targetLabel: target.label,
                greensideHazards: greensideHazards,
                missGuidance: missGuidance
            ),
            supportingReason: supportingReason(
                targetLabel: target.label,
                clubRecommendation: clubRecommendation,
                roundContext: roundContext
            ),
            hazardSummary: Array(greensideHazards.prefix(2).map(\.summary))
        )
    }

    private static func selectedTee(in hole: CourseHole, roundContext: RoundContext?) -> Tee? {
        if let teeSetId = roundContext?.teeSetId,
           let matchedTee = hole.tees.first(where: { $0.teeSetId == teeSetId }) {
            return matchedTee
        }

        if let defaultTee = hole.tees.first(where: { $0.isDefault == true }) {
            return defaultTee
        }

        return hole.tees.first
    }

    private static func greensideHazards(in hole: CourseHole, holeLength: Double) -> [GreensideHazard] {
        hole.baseMappingData.features.compactMap { feature in
            let hazardKind = feature.hazardKind ?? feature.featureType
            guard ["water", "bunker"].contains(hazardKind) else {
                return nil
            }

            guard let alongM = feature.properties["centerline_along_m"]?.numberValue else {
                return nil
            }

            guard alongM >= (holeLength - 40), alongM <= (holeLength + 10) else {
                return nil
            }

            let side = feature.properties["centerline_side"]?.stringValue ?? "center"
            return GreensideHazard(
                kind: hazardKind,
                side: side,
                severity: greensideSeverity(for: hazardKind),
                summary: "\(hazardKind.capitalized) \(side)"
            )
        }
        .sorted { lhs, rhs in
            lhs.severity > rhs.severity
        }
    }

    private static func greensideSeverity(for hazardKind: String) -> Double {
        switch hazardKind {
        case "water":
            return 0.88
        case "bunker":
            return 0.58
        default:
            return 0.35
        }
    }

    private static func approachTarget(
        for green: GreenReference,
        riskLevel: String,
        roundContext: RoundContext?
    ) -> ApproachTarget {
        let wantsSaferTarget =
            riskLevel == "high" ||
            roundContext?.strategyPreference == .conservative

        if wantsSaferTarget, green.frontCenter != nil {
            return ApproachTarget(label: "Front-center green", distanceAdjustmentM: -6)
        }

        return ApproachTarget(label: "Center green", distanceAdjustmentM: 0)
    }

    private static func chooseClub(
        approachDistanceM: Double,
        playerContext: PlayerContext?,
        roundContext: RoundContext?
    ) -> PlayerClub? {
        guard let playerContext else {
            return nil
        }

        let desiredCarry = approachDistanceM + approachCarryBias(roundContext: roundContext)

        return playerContext.clubs.min { lhs, rhs in
            let lhsDelta = abs(lhs.carryDistanceM - desiredCarry)
            let rhsDelta = abs(rhs.carryDistanceM - desiredCarry)
            if lhsDelta == rhsDelta {
                return lhs.carryDistanceM < rhs.carryDistanceM
            }
            return lhsDelta < rhsDelta
        }
    }

    private static func approachCarryBias(roundContext: RoundContext?) -> Double {
        guard let roundContext else {
            return 0
        }

        var bias = 0.0

        switch roundContext.strategyPreference {
        case .conservative:
            bias -= 4
        case .balanced:
            break
        case .aggressive:
            bias += 4
        }

        guard let wind = roundContext.wind else {
            return bias
        }

        switch wind.relativeDirection {
        case .helping:
            bias -= approachWindBias(for: wind.speedMps)
        case .hurting:
            bias += approachWindBias(for: wind.speedMps)
        case .cross:
            break
        }

        return bias
    }

    private static func approachWindBias(for speedMps: Double) -> Double {
        switch speedMps {
        case 6...:
            return 8
        case 3...:
            return 4
        default:
            return 0
        }
    }

    private static func missGuidance(for hazards: [GreensideHazard]) -> MissGuidance? {
        let leftPressure = hazards
            .filter { $0.side == "left" }
            .reduce(0.0) { $0 + $1.severity }
        let rightPressure = hazards
            .filter { $0.side == "right" }
            .reduce(0.0) { $0 + $1.severity }

        let gap = abs(leftPressure - rightPressure)
        guard gap >= 0.2 else {
            return nil
        }

        if leftPressure > rightPressure {
            return MissGuidance(preferredDirection: "right", avoidDirection: "left")
        }

        return MissGuidance(preferredDirection: "left", avoidDirection: "right")
    }

    private static func confidenceScore(
        hole: CourseHole,
        teeShot: TeeShotRecommendationPacket?,
        greensideHazards: [GreensideHazard]
    ) -> Double {
        var score = hole.baseMappingData.green.frontCenter != nil ? 0.76 : 0.72
        if hole.par > 3, teeShot == nil {
            score -= 0.08
        }
        if greensideHazards.isEmpty {
            score -= 0.04
        }
        return max(0.55, score)
    }

    private static func primaryReason(
        targetLabel: String,
        greensideHazards: [GreensideHazard],
        missGuidance: MissGuidance?
    ) -> String {
        if let missGuidance,
           let avoidedHazard = greensideHazards.first(where: { $0.side == missGuidance.avoidDirection }) {
            return "Favor \(missGuidance.preferredDirection). \(avoidedHazard.kind) \(avoidedHazard.side) is the miss to avoid around the green."
        }

        if let topHazard = greensideHazards.first {
            return "\(targetLabel) keeps \(topHazard.kind) \(topHazard.side) in view."
        }

        return "\(targetLabel) is the safest standard approach target."
    }

    private static func supportingReason(
        targetLabel: String,
        clubRecommendation: PlayerClub?,
        roundContext: RoundContext?
    ) -> String? {
        guard let clubRecommendation else {
            return nil
        }

        if let wind = roundContext?.wind {
            return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m fits a \(targetLabel.lowercased()) number with \(windSupportText(wind))."
        }

        return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m fits a \(targetLabel.lowercased()) number."
    }

    private static func riskLevel(for score: Double) -> String {
        switch score {
        case 0.8...:
            return "high"
        case 0.5...:
            return "medium"
        default:
            return "low"
        }
    }

    private static func confidenceBand(for score: Double) -> String {
        switch score {
        case 0.8...:
            return "high"
        case 0.68...:
            return "medium"
        default:
            return "low"
        }
    }

    private static func windSupportText(_ wind: WindContext) -> String {
        let speed = format(number: wind.speedMps)
        switch wind.relativeDirection {
        case .helping:
            return "\(speed)m/s helping wind"
        case .hurting:
            return "\(speed)m/s headwind"
        case .cross:
            return "\(speed)m/s crosswind"
        }
    }
}

private struct GreensideHazard {
    let kind: String
    let side: String
    let severity: Double
    let summary: String
}

private struct ApproachTarget {
    let label: String
    let distanceAdjustmentM: Double
}

private struct MissGuidance {
    let preferredDirection: String
    let avoidDirection: String
}

private func format(number: Double) -> String {
    if number.rounded() == number {
        return String(Int(number))
    }

    return String(format: "%.1f", number)
}
