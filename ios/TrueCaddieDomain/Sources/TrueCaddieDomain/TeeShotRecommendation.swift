import Foundation

public struct TeeShotRecommendationPacket: Equatable, Sendable {
    public let courseId: String
    public let holeId: String
    public let holeNumber: Int
    public let shotPhase: String
    public let strategyMode: String
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
        let supportingReason = supportingReason(
            corridor: corridor,
            preferredMiss: preferredMiss
        )

        return TeeShotRecommendationPacket(
            courseId: courseId,
            holeId: hole.holeId,
            holeNumber: hole.holeNumber,
            shotPhase: "tee",
            strategyMode: corridor.properties.strategyMode,
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
        preferredMiss: PreferredMissOverlay?
    ) -> String? {
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
