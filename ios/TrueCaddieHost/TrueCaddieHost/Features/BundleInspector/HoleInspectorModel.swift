import Foundation
import TrueCaddieDomain

struct HoleInspectorModel {
    static func makeShotStateScenarios(
        for hole: CourseHole,
        courseId: String,
        playerContext: PlayerContext,
        roundContext: RoundContext
    ) -> [ShotStateScenario] {
        guard let tee = selectedTee(in: hole, roundContext: roundContext) else {
            return []
        }

        if hole.par == 3 {
            return [
                ShotStateScenario(
                    id: "tee",
                    name: "Tee shot",
                    detail: "Standard par-3 tee ball",
                    shotStateContext: ShotStateContext(
                        shotNumber: 1,
                        remainingDistanceM: tee.teeLengthM,
                        lie: .tee
                    )
                ),
                ShotStateScenario(
                    id: "rough",
                    name: "Missed rough",
                    detail: "Light rough approach after a loose swing",
                    shotStateContext: ShotStateContext(
                        shotNumber: 2,
                        remainingDistanceM: max(45, tee.teeLengthM - 8),
                        lie: .rough
                    )
                )
            ]
        }

        guard let teeShotRecommendation = TeeShotRecommendationEngine.build(
            courseId: courseId,
            for: hole,
            playerContext: playerContext,
            roundContext: roundContext
        ) else {
            return []
        }

        let baseRemainingDistance = max(55, tee.teeLengthM - teeShotRecommendation.targetDistanceM)
        var scenarios = [
            ShotStateScenario(
                id: "default",
                name: "Fairway result",
                detail: "Stock tee ball in the short grass",
                shotStateContext: ShotStateContext(
                    shotNumber: 2,
                    remainingDistanceM: baseRemainingDistance,
                    lie: .fairway
                )
            ),
            ShotStateScenario(
                id: "rough",
                name: "Missed right rough",
                detail: "Same line, tougher contact from light rough",
                shotStateContext: ShotStateContext(
                    shotNumber: 2,
                    remainingDistanceM: baseRemainingDistance + 12,
                    lie: .rough
                )
            ),
            ShotStateScenario(
                id: "recovery",
                name: "Recovery miss",
                detail: "Blocked or awkward stance after a bigger miss",
                shotStateContext: ShotStateContext(
                    shotNumber: 2,
                    remainingDistanceM: baseRemainingDistance + 22,
                    lie: .recovery
                )
            )
        ]

        if hole.par == 5 {
            scenarios.append(
                ShotStateScenario(
                    id: "layup",
                    name: "Layup leave",
                    detail: "Third shot from a comfortable wedge number",
                    shotStateContext: ShotStateContext(
                        shotNumber: 3,
                        remainingDistanceM: preferredLeaveDistanceM(for: roundContext),
                        lie: .fairway
                    )
                )
            )
        }

        return scenarios
    }

    static func nextShotRecommendation(
        for hole: CourseHole,
        courseId: String,
        playerContext: PlayerContext,
        roundContext: RoundContext,
        selectedScenarioId: String
    ) -> NextShotRecommendationPacket? {
        let scenarios = makeShotStateScenarios(
            for: hole,
            courseId: courseId,
            playerContext: playerContext,
            roundContext: roundContext
        )
        let selectedScenario = scenarios.first(where: { $0.id == selectedScenarioId }) ?? scenarios.first

        return NextShotRecommendationEngine.build(
            courseId: courseId,
            for: hole,
            playerContext: playerContext,
            roundContext: roundContext,
            shotStateContext: selectedScenario?.shotStateContext
        )
    }

    static func selectedTee(in hole: CourseHole, roundContext: RoundContext) -> Tee? {
        if let matchedTee = hole.tees.first(where: { $0.teeSetId == roundContext.teeSetId }) {
            return matchedTee
        }

        if let defaultTee = hole.tees.first(where: { $0.isDefault == true }) {
            return defaultTee
        }

        return hole.tees.first
    }

    static func preferredLeaveDistanceM(for roundContext: RoundContext) -> Double {
        switch roundContext.strategyPreference {
        case .conservative:
            return 110
        case .aggressive:
            return 85
        case .balanced:
            return 100
        }
    }
}

struct ShotStateScenario: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let shotStateContext: ShotStateContext
}
