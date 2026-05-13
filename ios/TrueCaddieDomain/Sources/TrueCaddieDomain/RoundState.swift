import Foundation

public struct RoundState: Codable, Equatable, Sendable {
    public let courseId: String
    public let holeStates: [HoleRoundState]

    public init(courseId: String, holeStates: [HoleRoundState]) {
        self.courseId = courseId
        self.holeStates = holeStates.sorted { lhs, rhs in
            lhs.holeNumber < rhs.holeNumber
        }
    }

    public func holeState(for holeNumber: Int) -> HoleRoundState? {
        holeStates.first(where: { $0.holeNumber == holeNumber })
    }

    public func startHole(
        _ hole: CourseHole,
        roundContext: RoundContext
    ) -> RoundState {
        updateShotState(
            defaultShotState(for: hole, roundContext: roundContext),
            for: hole.holeNumber
        )
    }

    public func updateShotState(
        _ shotStateContext: ShotStateContext,
        for holeNumber: Int
    ) -> RoundState {
        upserting(
            HoleRoundState(
                holeNumber: holeNumber,
                status: .inProgress,
                shotStateContext: shotStateContext,
                strokesTaken: max(shotStateContext.shotNumber - 1, 0)
            )
        )
    }

    public func advanceShot(
        for holeNumber: Int,
        remainingDistanceM: Double? = nil,
        lie: ShotLie? = nil
    ) -> RoundState {
        guard let holeState = holeState(for: holeNumber),
              let shotStateContext = holeState.shotStateContext else {
            return self
        }

        return updateShotState(
            ShotStateContext(
                shotNumber: shotStateContext.shotNumber + 1,
                remainingDistanceM: remainingDistanceM ?? shotStateContext.remainingDistanceM,
                lie: lie ?? shotStateContext.lie
            ),
            for: holeNumber
        )
    }

    public func finishHole(_ holeNumber: Int, strokesTaken: Int? = nil) -> RoundState {
        let existingHoleState = holeState(for: holeNumber)

        return upserting(
            HoleRoundState(
                holeNumber: holeNumber,
                status: .finished,
                shotStateContext: existingHoleState?.shotStateContext,
                strokesTaken: strokesTaken
                    ?? existingHoleState?.shotStateContext?.shotNumber
                    ?? existingHoleState?.strokesTaken
            )
        )
    }

    public func updateFinishedHoleScore(
        _ strokesTaken: Int,
        for holeNumber: Int
    ) -> RoundState {
        guard let existingHoleState = holeState(for: holeNumber),
              existingHoleState.status == .finished else {
            return self
        }

        return upserting(
            HoleRoundState(
                holeNumber: holeNumber,
                status: .finished,
                shotStateContext: existingHoleState.shotStateContext,
                strokesTaken: strokesTaken
            )
        )
    }

    public func resetHole(_ holeNumber: Int) -> RoundState {
        RoundState(
            courseId: courseId,
            holeStates: holeStates.filter { $0.holeNumber != holeNumber }
        )
    }

    private func upserting(_ holeState: HoleRoundState) -> RoundState {
        RoundState(
            courseId: courseId,
            holeStates: holeStates.filter { $0.holeNumber != holeState.holeNumber } + [holeState]
        )
    }

    private func defaultShotState(
        for hole: CourseHole,
        roundContext: RoundContext
    ) -> ShotStateContext {
        let remainingDistanceM = selectedTee(in: hole, roundContext: roundContext)?.teeLengthM ?? 0

        return ShotStateContext(
            shotNumber: 1,
            remainingDistanceM: remainingDistanceM,
            lie: .tee
        )
    }

    private func selectedTee(in hole: CourseHole, roundContext: RoundContext) -> Tee? {
        if let matchedTee = hole.tees.first(where: { $0.teeSetId == roundContext.teeSetId }) {
            return matchedTee
        }

        if let defaultTee = hole.tees.first(where: { $0.isDefault == true }) {
            return defaultTee
        }

        return hole.tees.first
    }
}

public struct HoleRoundState: Codable, Equatable, Identifiable, Sendable {
    public let holeNumber: Int
    public let status: HoleRoundStatus
    public let shotStateContext: ShotStateContext?
    public let strokesTaken: Int?

    public var id: Int { holeNumber }

    public init(
        holeNumber: Int,
        status: HoleRoundStatus,
        shotStateContext: ShotStateContext?,
        strokesTaken: Int? = nil
    ) {
        self.holeNumber = holeNumber
        self.status = status
        self.shotStateContext = shotStateContext
        self.strokesTaken = strokesTaken
    }
}

public enum HoleRoundStatus: String, Codable, Equatable, Sendable {
    case inProgress
    case finished
}
