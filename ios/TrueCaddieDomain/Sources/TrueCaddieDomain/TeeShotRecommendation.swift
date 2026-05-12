import Foundation

public struct TeeShotRecommendationPacket: Equatable, Sendable {
    public let courseId: String
    public let holeId: String
    public let holeNumber: Int
    public let shotPhase: String
    public let strategyMode: String
    public let strategyPreference: String?
    public let recommendedClub: String?
    public let clubCarryDistanceM: Double?
    public let targetLabel: String
    public let targetDistanceM: Double
    public let targetWidthM: Double
    public let targetDepthM: Double
    public let preferredMissDirection: String?
    public let avoidDirection: String?
    public let riskLevel: String
    public let confidenceBand: String
    public let confidenceScore: Double
    public let primaryReason: String
    public let supportingReason: String?
    public let hazardSummary: [String]
}

public enum TeeShotRecommendationEngine {
    public static func build(courseId: String, for hole: CourseHole) -> TeeShotRecommendationPacket? {
        build(courseId: courseId, for: hole, playerContext: nil, roundContext: nil)
    }

    public static func build(
        courseId: String,
        for hole: CourseHole,
        playerContext: PlayerContext?
    ) -> TeeShotRecommendationPacket? {
        build(courseId: courseId, for: hole, playerContext: playerContext, roundContext: nil)
    }

    public static func build(
        courseId: String,
        for hole: CourseHole,
        playerContext: PlayerContext?,
        roundContext: RoundContext?
    ) -> TeeShotRecommendationPacket? {
        guard
            hole.par > 3,
            let corridor = hole.strategyOverlays.teeTargetCorridors.first
        else {
            return nil
        }

        let preferredMiss = hole.strategyOverlays.preferredMiss.max { lhs, rhs in
            lhs.properties.riskGapScore < rhs.properties.riskGapScore
        }

        let relevantHazards = hazardsRelevantToLanding(in: hole, targetDistanceM: corridor.properties.targetDistanceM)
        let riskReference = max(
            preferredMiss?.properties.avoidRiskScore ?? 0,
            relevantHazards.first?.overlay.properties.severityScore ?? 0
        )
        let confidenceScore = blendedConfidence(
            corridorScore: corridor.confidence.score,
            preferredMissScore: preferredMiss?.confidence.score
        )
        let primaryReason = primaryReason(
            corridor: corridor,
            preferredMiss: preferredMiss,
            relevantHazards: relevantHazards
        )
        let clubRecommendation = chooseClub(
            for: corridor,
            playerContext: playerContext,
            roundContext: roundContext,
            riskLevel: riskLevel(for: riskReference)
        )
        let supportingReason = supportingReason(
            corridor: corridor,
            preferredMiss: preferredMiss,
            clubRecommendation: clubRecommendation,
            roundContext: roundContext
        )

        return TeeShotRecommendationPacket(
            courseId: courseId,
            holeId: hole.holeId,
            holeNumber: hole.holeNumber,
            shotPhase: "tee",
            strategyMode: corridor.properties.strategyMode,
            strategyPreference: roundContext?.strategyPreference.rawValue,
            recommendedClub: clubRecommendation?.name,
            clubCarryDistanceM: clubRecommendation?.carryDistanceM,
            targetLabel: corridor.properties.targetLabel,
            targetDistanceM: corridor.properties.targetDistanceM,
            targetWidthM: corridor.properties.corridorWidthM,
            targetDepthM: corridor.properties.corridorDepthM,
            preferredMissDirection: preferredMiss?.properties.preferredDirection,
            avoidDirection: preferredMiss?.properties.avoidDirection,
            riskLevel: riskLevel(for: riskReference),
            confidenceBand: confidenceBand(for: confidenceScore),
            confidenceScore: confidenceScore,
            primaryReason: primaryReason,
            supportingReason: supportingReason,
            hazardSummary: Array(relevantHazards.prefix(2).map(\.summary))
        )
    }

    private static func chooseClub(
        for corridor: TeeTargetCorridorOverlay,
        playerContext: PlayerContext?,
        roundContext: RoundContext?,
        riskLevel: String
    ) -> PlayerClub? {
        guard let playerContext else {
            return nil
        }

        var carryBias: Double
        switch (playerContext.riskTolerance, riskLevel) {
        case (.conservative, _), (_, "high"):
            carryBias = -10
        case (.aggressive, "low"), (.aggressive, "medium"):
            carryBias = 5
        default:
            carryBias = 0
        }

        if let roundContext {
            carryBias += carryBiasForRoundContext(roundContext)
        }

        let desiredCarry = corridor.properties.targetDistanceM + carryBias

        return playerContext.clubs.min { lhs, rhs in
            let lhsDelta = abs(lhs.carryDistanceM - desiredCarry)
            let rhsDelta = abs(rhs.carryDistanceM - desiredCarry)
            if lhsDelta == rhsDelta {
                return lhs.carryDistanceM < rhs.carryDistanceM
            }
            return lhsDelta < rhsDelta
        }
    }

    private static func hazardsRelevantToLanding(
        in hole: CourseHole,
        targetDistanceM: Double
    ) -> [RelevantHazard] {
        let featureById = Dictionary(uniqueKeysWithValues: hole.baseMappingData.features.map { ($0.featureId, $0) })

        return hole.strategyOverlays.hazardSeverity.compactMap { overlay in
            guard
                let feature = featureById[overlay.properties.hazardRefId],
                let alongM = feature.properties["centerline_along_m"]?.numberValue,
                abs(alongM - targetDistanceM) <= 70
            else {
                return nil
            }

            let side = feature.properties["centerline_side"]?.stringValue ?? "center"
            return RelevantHazard(
                overlay: overlay,
                side: side,
                summary: "\(overlay.properties.hazardKind.capitalized) \(side)"
            )
        }
        .sorted { lhs, rhs in
            lhs.overlay.properties.severityScore > rhs.overlay.properties.severityScore
        }
    }

    private static func blendedConfidence(corridorScore: Double, preferredMissScore: Double?) -> Double {
        let total = corridorScore + (preferredMissScore ?? corridorScore)
        return (total / 2.0).rounded(toPlaces: 2)
    }

    private static func primaryReason(
        corridor: TeeTargetCorridorOverlay,
        preferredMiss: PreferredMissOverlay?,
        relevantHazards: [RelevantHazard]
    ) -> String {
        if let preferredMiss {
            return "Favor \(preferredMiss.properties.preferredDirection). \(preferredMiss.rationale.primaryReason)"
        }

        if let topHazard = relevantHazards.first {
            return "\(topHazard.overlay.properties.hazardKind.capitalized) is the main issue around the stock landing area."
        }

        return corridor.rationale.primaryReason
    }

    private static func supportingReason(
        corridor: TeeTargetCorridorOverlay,
        preferredMiss: PreferredMissOverlay?,
        clubRecommendation: PlayerClub?,
        roundContext: RoundContext?
    ) -> String? {
        if let clubRecommendation {
            let windText = windSupportText(roundContext?.wind)
            if let windText {
                return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m matches the stock landing window with \(windText)."
            }

            if let roundContext, roundContext.strategyPreference != .balanced {
                return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m fits today's \(roundContext.strategyPreference.rawValue) plan."
            }

            return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m matches the stock landing window."
        }

        if let preferredMiss, preferredMiss.rationale.primaryReason != corridor.rationale.primaryReason {
            return corridor.rationale.primaryReason
        }

        return nil
    }

    private static func riskLevel(for score: Double) -> String {
        switch score {
        case 0.75...:
            return "high"
        case 0.45...:
            return "medium"
        default:
            return "low"
        }
    }

    private static func confidenceBand(for score: Double) -> String {
        switch score {
        case 0.8...:
            return "high"
        case 0.65...:
            return "medium"
        default:
            return "low"
        }
    }

    private static func carryBiasForRoundContext(_ roundContext: RoundContext) -> Double {
        var bias = 0.0

        switch roundContext.strategyPreference {
        case .conservative:
            bias -= 10
        case .balanced:
            break
        case .aggressive:
            bias += 10
        }

        guard let wind = roundContext.wind else {
            return bias
        }

        switch wind.relativeDirection {
        case .helping:
            bias -= windBias(for: wind.speedMps)
        case .hurting:
            bias += windBias(for: wind.speedMps)
        case .cross:
            break
        }

        return bias
    }

    private static func windBias(for speedMps: Double) -> Double {
        switch speedMps {
        case 6...:
            return 10
        case 3...:
            return 5
        default:
            return 0
        }
    }

    private static func windSupportText(_ wind: WindContext?) -> String? {
        guard let wind else {
            return nil
        }

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

private struct RelevantHazard {
    let overlay: HazardSeverityOverlay
    let side: String
    let summary: String
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private func format(number: Double) -> String {
    if number.rounded() == number {
        return String(Int(number))
    }

    return String(format: "%.1f", number)
}
