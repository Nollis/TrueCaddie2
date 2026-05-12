import Foundation

public struct ApproachShotRecommendationPacket: Equatable, Sendable {
    public let courseId: String
    public let holeId: String
    public let holeNumber: Int
    public let shotPhase: String
    public let recommendationType: String
    public let strategyPreference: String?
    public let shotDistanceM: Double
    public let plannedLeaveDistanceM: Double?
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
        roundContext: RoundContext?
    ) -> ApproachShotRecommendationPacket? {
        build(
            courseId: courseId,
            for: hole,
            playerContext: playerContext,
            roundContext: roundContext,
            shotStateContext: nil
        )
    }

    public static func build(
        courseId: String,
        for hole: CourseHole,
        playerContext: PlayerContext?,
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
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
        if let shotStateContext {
            baseApproachDistance = max(35, shotStateContext.remainingDistanceM)
        } else {
            switch hole.par {
            case 3:
                baseApproachDistance = holeLength
            default:
                guard let teeShot else {
                    return nil
                }
                baseApproachDistance = max(55, holeLength - teeShot.targetDistanceM)
            }
        }

        let greensideHazards = greensideHazards(in: hole, holeLength: holeLength)
        let approachRisk = riskLevel(
            for: max(
                greensideHazards.first?.severity ?? 0,
                lieRiskFloor(for: shotStateContext?.lie)
            )
        )
        let target = approachTarget(
            for: hole.baseMappingData.green,
            riskLevel: approachRisk,
            roundContext: roundContext,
            shotStateContext: shotStateContext
        )
        let adjustedApproachDistance = max(45, baseApproachDistance + target.distanceAdjustmentM)
        let shotPlan = shotPlan(
            hole: hole,
            holeLength: holeLength,
            targetLabel: target.label,
            remainingDistanceM: baseApproachDistance,
            approachDistanceM: adjustedApproachDistance,
            greensideHazards: greensideHazards,
            playerContext: playerContext,
            roundContext: roundContext,
            shotStateContext: shotStateContext
        )
        let missGuidance = missGuidance(for: greensideHazards)
        let confidenceScore = confidenceScore(
            hole: hole,
            teeShot: teeShot,
            greensideHazards: greensideHazards,
            shotStateContext: shotStateContext
        )

        return ApproachShotRecommendationPacket(
            courseId: courseId,
            holeId: hole.holeId,
            holeNumber: hole.holeNumber,
            shotPhase: shotPlan.recommendationType,
            recommendationType: shotPlan.recommendationType,
            strategyPreference: roundContext?.strategyPreference.rawValue,
            shotDistanceM: shotPlan.shotDistanceM,
            plannedLeaveDistanceM: shotPlan.plannedLeaveDistanceM,
            targetLabel: shotPlan.targetLabel,
            recommendedClub: shotPlan.clubRecommendation?.name,
            clubCarryDistanceM: shotPlan.clubRecommendation?.carryDistanceM,
            preferredMissDirection: missGuidance?.preferredDirection,
            avoidDirection: missGuidance?.avoidDirection,
            riskLevel: approachRisk,
            confidenceBand: confidenceBand(for: confidenceScore),
            confidenceScore: confidenceScore,
            primaryReason: primaryReason(
                targetLabel: shotPlan.targetLabel,
                recommendationType: shotPlan.recommendationType,
                plannedLeaveDistanceM: shotPlan.plannedLeaveDistanceM,
                greensideHazards: greensideHazards,
                missGuidance: missGuidance
            ),
            supportingReason: supportingReason(
                recommendationType: shotPlan.recommendationType,
                targetLabel: shotPlan.targetLabel,
                shotDistanceM: shotPlan.shotDistanceM,
                plannedLeaveDistanceM: shotPlan.plannedLeaveDistanceM,
                clubRecommendation: shotPlan.clubRecommendation,
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
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
    ) -> ApproachTarget {
        let wantsSaferTarget =
            riskLevel == "high" ||
            roundContext?.strategyPreference == .conservative ||
            requiresSaferApproachTarget(for: shotStateContext?.lie)

        if wantsSaferTarget, green.frontCenter != nil {
            return ApproachTarget(label: "Front-center green", distanceAdjustmentM: -6)
        }

        return ApproachTarget(label: "Center green", distanceAdjustmentM: 0)
    }

    private static func chooseClub(
        shotDistanceM: Double,
        playerContext: PlayerContext?,
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
    ) -> PlayerClub? {
        guard let playerContext else {
            return nil
        }

        let desiredCarry =
            shotDistanceM +
            approachCarryBias(roundContext: roundContext) +
            lieCarryBias(for: shotStateContext?.lie)

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
        greensideHazards: [GreensideHazard],
        shotStateContext: ShotStateContext?
    ) -> Double {
        var score = hole.baseMappingData.green.frontCenter != nil ? 0.76 : 0.72
        if hole.par > 3, teeShot == nil {
            score -= 0.08
        }
        if greensideHazards.isEmpty {
            score -= 0.04
        }
        score -= lieConfidencePenalty(for: shotStateContext?.lie)
        return max(0.55, score)
    }

    private static func primaryReason(
        targetLabel: String,
        recommendationType: String,
        plannedLeaveDistanceM: Double?,
        greensideHazards: [GreensideHazard],
        missGuidance: MissGuidance?
    ) -> String {
        if recommendationType == "layup",
           let plannedLeaveDistanceM {
            return "Lay up to leave about \(format(number: plannedLeaveDistanceM))m in. Reaching the green cleanly is not a strong percentage play from here."
        }

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
        recommendationType: String,
        targetLabel: String,
        shotDistanceM: Double,
        plannedLeaveDistanceM: Double?,
        clubRecommendation: PlayerClub?,
        roundContext: RoundContext?
    ) -> String? {
        guard let clubRecommendation else {
            return nil
        }

        if recommendationType == "layup",
           let plannedLeaveDistanceM {
            if let wind = roundContext?.wind {
                return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m leaves about \(format(number: plannedLeaveDistanceM))m with \(windSupportText(wind))."
            }

            return "\(clubRecommendation.name) carry \(format(number: clubRecommendation.carryDistanceM))m leaves about \(format(number: plannedLeaveDistanceM))m in."
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

    private static func shotPlan(
        hole: CourseHole,
        holeLength: Double,
        targetLabel: String,
        remainingDistanceM: Double,
        approachDistanceM: Double,
        greensideHazards: [GreensideHazard],
        playerContext: PlayerContext?,
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
    ) -> ShotPlan {
        let longestCarry = playerContext?.clubs.first?.carryDistanceM ?? 0
        let reachableThreshold = max(
            155,
            longestCarry - 20 +
            reachableWindAdjustment(roundContext: roundContext) -
            lieReachPenalty(for: shotStateContext?.lie)
        )

        if hole.par == 5,
           shouldLayUpOnParFive(
                approachDistanceM: remainingDistanceM,
                reachableThreshold: reachableThreshold,
                greensideHazards: greensideHazards,
                playerContext: playerContext,
                roundContext: roundContext
           ) {
            if let layupCandidate = selectLayupCandidate(
                in: hole,
                holeLength: holeLength,
                remainingDistanceM: remainingDistanceM,
                roundContext: roundContext,
                shotStateContext: shotStateContext
            ) {
                let currentAlongDistance = max(0, holeLength - remainingDistanceM)
                let layupDistance = max(70, layupCandidate.properties.targetDistanceM - currentAlongDistance)
                let layupClub = chooseClub(
                    shotDistanceM: layupDistance,
                    playerContext: playerContext,
                    roundContext: roundContext,
                    shotStateContext: shotStateContext
                )

                return ShotPlan(
                    recommendationType: "layup",
                    targetLabel: layupCandidate.properties.targetLabel,
                    shotDistanceM: layupDistance,
                    plannedLeaveDistanceM: layupCandidate.properties.plannedLeaveDistanceM,
                    clubRecommendation: layupClub
                )
            }

            let preferredLeave = preferredLeaveDistance(roundContext: roundContext)
            let layupDistance = max(70, remainingDistanceM - preferredLeave)
            let layupClub = chooseClub(
                shotDistanceM: layupDistance,
                playerContext: playerContext,
                roundContext: roundContext,
                shotStateContext: shotStateContext
            )

            return ShotPlan(
                recommendationType: "layup",
                targetLabel: "Lay up for wedge number",
                shotDistanceM: layupDistance,
                plannedLeaveDistanceM: max(55, approachDistanceM - (layupClub?.carryDistanceM ?? layupDistance)),
                clubRecommendation: layupClub
            )
        }

        return ShotPlan(
            recommendationType: "approach",
            targetLabel: targetLabel,
            shotDistanceM: approachDistanceM,
            plannedLeaveDistanceM: nil,
            clubRecommendation: chooseClub(
                shotDistanceM: approachDistanceM,
                playerContext: playerContext,
                roundContext: roundContext,
                shotStateContext: shotStateContext
            )
        )
    }

    private static func selectLayupCandidate(
        in hole: CourseHole,
        holeLength: Double,
        remainingDistanceM: Double,
        roundContext: RoundContext?,
        shotStateContext: ShotStateContext?
    ) -> LayupCandidateOverlay? {
        guard shotStateContext?.shotNumber != 1 else {
            return nil
        }

        let currentAlongDistance = max(0, holeLength - remainingDistanceM)
        let minimumAdvanceDistance = max(70, remainingDistanceM * 0.25)
        let preferredLeave = preferredLeaveDistance(roundContext: roundContext)

        return hole.strategyOverlays.layupCandidates
            .filter { candidate in
                let layupDistance = candidate.properties.targetDistanceM - currentAlongDistance
                return layupDistance >= minimumAdvanceDistance &&
                    candidate.properties.plannedLeaveDistanceM <= max(140, remainingDistanceM - 45)
            }
            .sorted { lhs, rhs in
                let lhsLeaveDelta = abs(lhs.properties.plannedLeaveDistanceM - preferredLeave)
                let rhsLeaveDelta = abs(rhs.properties.plannedLeaveDistanceM - preferredLeave)
                if lhsLeaveDelta == rhsLeaveDelta {
                    return lhs.confidence.score > rhs.confidence.score
                }
                return lhsLeaveDelta < rhsLeaveDelta
            }
            .first
    }

    private static func requiresSaferApproachTarget(for lie: ShotLie?) -> Bool {
        switch lie {
        case .rough, .bunker, .recovery:
            return true
        default:
            return false
        }
    }

    private static func lieRiskFloor(for lie: ShotLie?) -> Double {
        switch lie {
        case .rough:
            return 0.52
        case .bunker, .recovery:
            return 0.82
        default:
            return 0
        }
    }

    private static func lieCarryBias(for lie: ShotLie?) -> Double {
        switch lie {
        case .rough:
            return 5
        case .bunker:
            return 8
        case .recovery:
            return 12
        default:
            return 0
        }
    }

    private static func lieReachPenalty(for lie: ShotLie?) -> Double {
        switch lie {
        case .rough:
            return 8
        case .bunker:
            return 15
        case .recovery:
            return 20
        default:
            return 0
        }
    }

    private static func lieConfidencePenalty(for lie: ShotLie?) -> Double {
        switch lie {
        case .rough:
            return 0.04
        case .bunker:
            return 0.08
        case .recovery:
            return 0.10
        default:
            return 0
        }
    }

    private static func preferredLeaveDistance(roundContext: RoundContext?) -> Double {
        switch roundContext?.strategyPreference {
        case .conservative:
            return 110
        case .aggressive:
            return 85
        default:
            return 100
        }
    }

    private static func reachableWindAdjustment(roundContext: RoundContext?) -> Double {
        guard let wind = roundContext?.wind else {
            return 0
        }

        switch wind.relativeDirection {
        case .helping:
            return 5
        case .hurting:
            return -10
        case .cross:
            return 0
        }
    }

    private static func shouldLayUpOnParFive(
        approachDistanceM: Double,
        reachableThreshold: Double,
        greensideHazards: [GreensideHazard],
        playerContext: PlayerContext?,
        roundContext: RoundContext?
    ) -> Bool {
        if approachDistanceM > reachableThreshold {
            return true
        }

        let greensideSeverity = greensideHazards.first?.severity ?? 0
        guard greensideSeverity >= 0.55 else {
            return false
        }

        let aggressionAllowance = parFiveAggressionAllowance(
            playerContext: playerContext,
            roundContext: roundContext
        )

        return approachDistanceM > (reachableThreshold - aggressionAllowance)
    }

    private static func parFiveAggressionAllowance(
        playerContext: PlayerContext?,
        roundContext: RoundContext?
    ) -> Double {
        var allowance = 0.0

        if let playerContext {
            switch playerContext.riskTolerance {
            case .conservative:
                allowance -= 10
            case .balanced:
                break
            case .aggressive:
                allowance += 10
            }

            if let handicapIndex = playerContext.handicapIndex {
                switch handicapIndex {
                case ..<8:
                    allowance += 10
                case 18...:
                    allowance -= 10
                default:
                    break
                }
            }
        }

        if let roundContext {
            switch roundContext.strategyPreference {
            case .conservative:
                allowance -= 10
            case .balanced:
                break
            case .aggressive:
                allowance += 10
            }
        }

        return allowance
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

private struct ShotPlan {
    let recommendationType: String
    let targetLabel: String
    let shotDistanceM: Double
    let plannedLeaveDistanceM: Double?
    let clubRecommendation: PlayerClub?
}

private func format(number: Double) -> String {
    if number.rounded() == number {
        return String(Int(number))
    }

    return String(format: "%.1f", number)
}
