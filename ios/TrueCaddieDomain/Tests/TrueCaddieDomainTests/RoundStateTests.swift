import XCTest
@testable import TrueCaddieDomain

final class RoundStateTests: XCTestCase {
    func testStartHoleSeedsOpeningTeeState() throws {
        let bundle = try loadBundle(from: makeBundleJSON(teeLengthM: 352))
        let hole = try XCTUnwrap(bundle.holes.first)

        let roundState = RoundState(courseId: bundle.courseId, holeStates: [])
            .startHole(hole, roundContext: .pilotSample)
        let holeState = try XCTUnwrap(roundState.holeState(for: 1))

        XCTAssertEqual(holeState.status, .inProgress)
        XCTAssertEqual(holeState.shotStateContext?.shotNumber, 1)
        XCTAssertEqual(holeState.shotStateContext?.remainingDistanceM, 352)
        XCTAssertEqual(holeState.shotStateContext?.lie, .tee)
        XCTAssertEqual(holeState.strokesTaken, 0)
    }

    func testAdvanceShotIncrementsShotNumberAndAppliesOverrides() {
        let roundState = RoundState(courseId: "course", holeStates: [
            HoleRoundState(
                holeNumber: 1,
                status: .inProgress,
                shotStateContext: ShotStateContext(
                    shotNumber: 2,
                    remainingDistanceM: 165,
                    lie: .fairway
                )
            )
        ])

        let advancedState = roundState.advanceShot(
            for: 1,
            remainingDistanceM: 118,
            lie: .rough
        )

        XCTAssertEqual(advancedState.holeState(for: 1)?.status, .inProgress)
        XCTAssertEqual(advancedState.holeState(for: 1)?.shotStateContext?.shotNumber, 3)
        XCTAssertEqual(advancedState.holeState(for: 1)?.shotStateContext?.remainingDistanceM, 118)
        XCTAssertEqual(advancedState.holeState(for: 1)?.shotStateContext?.lie, .rough)
        XCTAssertEqual(advancedState.holeState(for: 1)?.strokesTaken, 2)
    }

    func testFinishAndResetHoleUpdateStoredStatus() {
        let roundState = RoundState(courseId: "course", holeStates: [
            HoleRoundState(
                holeNumber: 1,
                status: .inProgress,
                shotStateContext: ShotStateContext(
                    shotNumber: 3,
                    remainingDistanceM: 94,
                    lie: .fairway
                )
            )
        ])

        let finishedState = roundState.finishHole(1)
        XCTAssertEqual(finishedState.holeState(for: 1)?.status, .finished)
        XCTAssertEqual(finishedState.holeState(for: 1)?.shotStateContext?.remainingDistanceM, 94)
        XCTAssertEqual(finishedState.holeState(for: 1)?.strokesTaken, 3)

        let resetState = finishedState.resetHole(1)
        XCTAssertNil(resetState.holeState(for: 1))
    }

    func testFinishHoleUsesConfirmedStrokeTotalWhenProvided() {
        let roundState = RoundState(courseId: "course", holeStates: [
            HoleRoundState(
                holeNumber: 1,
                status: .inProgress,
                shotStateContext: ShotStateContext(
                    shotNumber: 4,
                    remainingDistanceM: 3,
                    lie: .fairway
                ),
                strokesTaken: 3
            )
        ])

        let finishedState = roundState.finishHole(1, strokesTaken: 5)

        XCTAssertEqual(finishedState.holeState(for: 1)?.status, .finished)
        XCTAssertEqual(finishedState.holeState(for: 1)?.strokesTaken, 5)
    }

    func testRoundStateCodableRoundTripPreservesHoleProgress() throws {
        let roundState = RoundState(courseId: "course", holeStates: [
            HoleRoundState(
                holeNumber: 1,
                status: .finished,
                shotStateContext: ShotStateContext(
                    shotNumber: 4,
                    remainingDistanceM: 0,
                    lie: .fairway
                )
            ),
            HoleRoundState(
                holeNumber: 2,
                status: .inProgress,
                shotStateContext: ShotStateContext(
                    shotNumber: 2,
                    remainingDistanceM: 158,
                    lie: .rough
                )
            )
        ])

        let encoded = try JSONEncoder().encode(roundState)
        let decoded = try JSONDecoder().decode(RoundState.self, from: encoded)

        XCTAssertEqual(decoded, roundState)
    }

    private func loadBundle(from json: String) throws -> CourseBundle {
        try CourseBundleLoader().load(data: Data(json.utf8))
    }

    private func makeBundleJSON(teeLengthM: Double) -> String {
        """
        {
          "schema_version": "v1",
          "bundle_version": "test-bundle",
          "course_id": "test-course",
          "course_name": "Test Course",
          "published_at": "2026-05-10T00:00:00Z",
          "provenance": {
            "source_system": "test",
            "derivation_version": "test"
          },
          "holes": [
            {
              "hole_id": "1",
              "hole_number": 1,
              "par": 4,
              "tees": [
                {
                  "tee_set_id": "white",
                  "name": "White",
                  "tee_coordinate": [11.0, 57.0],
                  "tee_length_m": \(teeLengthM),
                  "is_default": true
                }
              ],
              "base_mapping_data": {
                "centerline": {
                  "type": "LineString",
                  "coordinates": [[11.0, 57.0], [11.1, 57.1]]
                },
                "green": {
                  "center": [11.1, 57.1],
                  "front_center": [11.09, 57.09],
                  "back_center": [11.11, 57.11],
                  "center_elevation_m": null,
                  "front_elevation_m": null,
                  "back_elevation_m": null,
                  "polygon_feature_id": null
                },
                "features": [],
                "out_of_bounds_lines": [],
                "context_points": []
              },
              "strategy_overlays": {
                "tee_target_corridors": [],
                "aggressive_tee_corridors": [],
                "layup_candidates": [],
                "preferred_miss": [],
                "hazard_severity": []
              },
              "quality_confidence": {
                "hole_publish_confidence": "medium",
                "hole_publish_score": 0.7,
                "overlay_scores": {},
                "notes": []
              },
              "provenance": {
                "source_system": "test",
                "source_file": "test.json",
                "derivation_version": "test"
              }
            }
          ]
        }
        """
    }
}
