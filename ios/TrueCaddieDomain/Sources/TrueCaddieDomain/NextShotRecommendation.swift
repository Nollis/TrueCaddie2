import Foundation

public struct NextShotRecommendationPacket: Equatable, Sendable {
    public let courseId: String
    public let holeId: String
    public let holeNumber: Int
    public let shotPhase: String
    public let recommendationType: String
    public let shotNumber: Int
    public let remainingDistanceM: Double
    public let lie: ShotLie
    public let strategyPreference: String?
    public let targetLabel: String
    public let recommendedClub: String?
    public let clubCarryDistanceM: Double?
    public let shotDistanceM: Double
    public let plannedLeaveDistanceM: Double?
    public let preferredMissDirection: String?
    public let avoidDirection: String?
    public let riskLevel: String
    public let confidenceBand: String
    public let confidenceScore: Double
    public let primaryReason: String
    public let supportingReason: String?
    public let hazardSummary: [String]
    public let headline: String
    public let executionNote: String
    public let missNote: String?
    public let fallbackNote: String?
}

public enum NextShotRecommendationEngine {
    public static func build(courseId: String, for hole: CourseHole) -> NextShotRecommendationPacket? {
        build(
            courseId: courseId,
            for: hole,
            playerContext: nil,
            roundContext: nil,
            shotStateContext: nil
        )
    }

    public static func build(
        courseId: String,
        for hole: CourseHole,
        playerContext: PlayerContext?,
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
    ) -> NextShotRecommendationPacket? {
        let resolvedShotState = resolveShotState(
            for: hole,
            roundContext: roundContext,
            shotStateContext: shotStateContext
        )

        if resolvedShotState.shotNumber == 1,
           resolvedShotState.lie == .tee,
           let teePacket = TeeShotRecommendationEngine.build(
                courseId: courseId,
                for: hole,
                playerContext: playerContext,
                roundContext: roundContext
           ) {
            return buildTeePacket(from: teePacket, shotStateContext: resolvedShotState)
        }

        guard let approachPacket = ApproachShotRecommendationEngine.build(
            courseId: courseId,
            for: hole,
            playerContext: playerContext,
            roundContext: roundContext,
            shotStateContext: resolvedShotState
        ) else {
            return nil
        }

        return buildApproachPacket(from: approachPacket, shotStateContext: resolvedShotState)
    }

    private static func resolveShotState(
        for hole: CourseHole,
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
    ) -> ShotStateContext {
        if let shotStateContext {
            return shotStateContext
        }

        let remainingDistanceM = selectedTee(in: hole, roundContext: roundContext)?.teeLengthM ?? 0
        return ShotStateContext(
            shotNumber: 1,
            remainingDistanceM: remainingDistanceM,
            lie: .tee
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

    private static func buildTeePacket(
        from teePacket: TeeShotRecommendationPacket,
        shotStateContext: ShotStateContext
    ) -> NextShotRecommendationPacket {
        let headline = headline(
            club: teePacket.recommendedClub,
            targetLabel: teePacket.targetLabel
        )
        let executionNote = teePacket.supportingReason ?? teePacket.primaryReason

        return NextShotRecommendationPacket(
            courseId: teePacket.courseId,
            holeId: teePacket.holeId,
            holeNumber: teePacket.holeNumber,
            shotPhase: "tee",
            recommendationType: "tee",
            shotNumber: shotStateContext.shotNumber,
            remainingDistanceM: shotStateContext.remainingDistanceM,
            lie: shotStateContext.lie,
            strategyPreference: teePacket.strategyPreference,
            targetLabel: teePacket.targetLabel,
            recommendedClub: teePacket.recommendedClub,
            clubCarryDistanceM: teePacket.clubCarryDistanceM,
            shotDistanceM: teePacket.targetDistanceM,
            plannedLeaveDistanceM: nil,
            preferredMissDirection: teePacket.preferredMissDirection,
            avoidDirection: teePacket.avoidDirection,
            riskLevel: teePacket.riskLevel,
            confidenceBand: teePacket.confidenceBand,
            confidenceScore: teePacket.confidenceScore,
            primaryReason: teePacket.primaryReason,
            supportingReason: teePacket.supportingReason,
            hazardSummary: teePacket.hazardSummary,
            headline: headline,
            executionNote: executionNote,
            missNote: missNote(
                preferredMissDirection: teePacket.preferredMissDirection,
                avoidDirection: teePacket.avoidDirection
            ),
            fallbackNote: fallbackNote(
                recommendationType: "tee",
                plannedLeaveDistanceM: nil,
                confidenceBand: teePacket.confidenceBand
            )
        )
    }

    private static func buildApproachPacket(
        from approachPacket: ApproachShotRecommendationPacket,
        shotStateContext: ShotStateContext
    ) -> NextShotRecommendationPacket {
        let headline = headline(
            club: approachPacket.recommendedClub,
            targetLabel: approachPacket.targetLabel
        )
        let executionNote = approachPacket.supportingReason ?? approachPacket.primaryReason

        return NextShotRecommendationPacket(
            courseId: approachPacket.courseId,
            holeId: approachPacket.holeId,
            holeNumber: approachPacket.holeNumber,
            shotPhase: approachPacket.recommendationType,
            recommendationType: approachPacket.recommendationType,
            shotNumber: shotStateContext.shotNumber,
            remainingDistanceM: shotStateContext.remainingDistanceM,
            lie: shotStateContext.lie,
            strategyPreference: approachPacket.strategyPreference,
            targetLabel: approachPacket.targetLabel,
            recommendedClub: approachPacket.recommendedClub,
            clubCarryDistanceM: approachPacket.clubCarryDistanceM,
            shotDistanceM: approachPacket.shotDistanceM,
            plannedLeaveDistanceM: approachPacket.plannedLeaveDistanceM,
            preferredMissDirection: approachPacket.preferredMissDirection,
            avoidDirection: approachPacket.avoidDirection,
            riskLevel: approachPacket.riskLevel,
            confidenceBand: approachPacket.confidenceBand,
            confidenceScore: approachPacket.confidenceScore,
            primaryReason: approachPacket.primaryReason,
            supportingReason: approachPacket.supportingReason,
            hazardSummary: approachPacket.hazardSummary,
            headline: headline,
            executionNote: executionNote,
            missNote: missNote(
                preferredMissDirection: approachPacket.preferredMissDirection,
                avoidDirection: approachPacket.avoidDirection
            ),
            fallbackNote: fallbackNote(
                recommendationType: approachPacket.recommendationType,
                plannedLeaveDistanceM: approachPacket.plannedLeaveDistanceM,
                confidenceBand: approachPacket.confidenceBand
            )
        )
    }

    private static func headline(club: String?, targetLabel: String) -> String {
        guard let club else {
            return targetLabel
        }

        return "\(club) to \(targetLabel)"
    }

    private static func missNote(
        preferredMissDirection: String?,
        avoidDirection: String?
    ) -> String? {
        guard let preferredMissDirection, let avoidDirection else {
            return nil
        }

        return "Favor \(preferredMissDirection). Avoid \(avoidDirection)."
    }

    private static func fallbackNote(
        recommendationType: String,
        plannedLeaveDistanceM: Double?,
        confidenceBand: String
    ) -> String? {
        if recommendationType == "layup",
           let plannedLeaveDistanceM {
            return "If the green light is not there, leave yourself about \(format(number: plannedLeaveDistanceM))m in."
        }

        guard confidenceBand == "low" else {
            return nil
        }

        return "If the picture looks different, default to the safer stock target."
    }
}

private func format(number: Double) -> String {
    if number.rounded() == number {
        return String(Int(number))
    }

    return String(format: "%.1f", number)
}
