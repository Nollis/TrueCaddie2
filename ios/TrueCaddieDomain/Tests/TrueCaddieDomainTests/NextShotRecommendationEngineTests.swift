import Foundation
import XCTest
@testable import TrueCaddieDomain

final class NextShotRecommendationEngineTests: XCTestCase {
    func testResolvesTeePacketForOpeningShot() throws {
        let bundle = try loadBundle(from: makeBundleJSON(
            par: 4,
            teeLengthM: 350,
            featuresJSON: """
            [
              {
                "feature_id": "water-right",
                "feature_type": "water",
                "hazard_kind": "water",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "name": "water-1",
                  "centerline_along_m": 200,
                  "centerline_distance_m": 18,
                  "centerline_side": "right"
                }
              }
            ]
            """,
            teeTargetCorridorsJSON: """
            [
              {
                "overlay_id": "tee-corridor-1",
                "overlay_type": "tee_target_corridor",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "tee",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "target_distance_m": 210,
                  "corridor_width_m": 24,
                  "corridor_depth_m": 30,
                  "target_label": "Primary stock corridor",
                  "fairway_feature_id": "fairway-1",
                  "strategy_mode": "stock"
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.74
                },
                "rationale": {
                  "primary_reason": "corridor follows the broadest stock landing area"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """,
            preferredMissJSON: """
            [
              {
                "overlay_id": "preferred-miss-1",
                "overlay_type": "preferred_miss",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "tee",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "preferred_direction": "left",
                  "avoid_direction": "right",
                  "preferred_risk_score": 0.18,
                  "avoid_risk_score": 0.62,
                  "risk_gap_score": 0.44
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.73
                },
                "rationale": {
                  "primary_reason": "right side carries more risk: water on the right at 200m along with 18m from centerline"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """,
            hazardSeverityJSON: """
            [
              {
                "overlay_id": "hazard-1",
                "overlay_type": "hazard_severity",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "all",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "hazard_ref_id": "water-right",
                  "hazard_kind": "water",
                  "severity_band": "critical",
                  "severity_score": 0.91,
                  "context_relevance_score": 0.83,
                  "penalty_kind": "stroke_penalty",
                  "landing_conflict": true,
                  "blocks_recovery": false
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.72
                },
                "rationale": {
                  "primary_reason": "water right is the main problem"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """
        ))

        let packet = NextShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .balanced,
                wind: nil
            ),
            shotStateContext: ShotStateContext(
                shotNumber: 1,
                remainingDistanceM: 350,
                lie: .tee
            )
        )

        XCTAssertEqual(packet?.shotPhase, "tee")
        XCTAssertEqual(packet?.recommendationType, "tee")
        XCTAssertEqual(packet?.shotNumber, 1)
        XCTAssertEqual(packet?.remainingDistanceM, 350)
        XCTAssertEqual(packet?.lie, .tee)
        XCTAssertEqual(packet?.recommendedClub, "5 Wood")
        XCTAssertEqual(packet?.targetLabel, "Primary stock corridor")
        XCTAssertEqual(packet?.headline, "5 Wood to Primary stock corridor")
        XCTAssertEqual(packet?.executionNote, "5 Wood carry 200m matches the stock landing window.")
        XCTAssertEqual(packet?.missNote, "Favor left. Avoid right.")
        XCTAssertNil(packet?.fallbackNote)
    }

    func testResolvesApproachPacketFromFairwayShot() throws {
        let bundle = try loadBundle(from: makeBundleJSON(
            par: 4,
            teeLengthM: 360,
            featuresJSON: "[]"
        ))

        let packet = NextShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .balanced,
                wind: nil
            ),
            shotStateContext: ShotStateContext(
                shotNumber: 2,
                remainingDistanceM: 142,
                lie: .fairway
            )
        )

        XCTAssertEqual(packet?.shotPhase, "approach")
        XCTAssertEqual(packet?.recommendationType, "approach")
        XCTAssertEqual(packet?.shotNumber, 2)
        XCTAssertEqual(packet?.remainingDistanceM, 142)
        XCTAssertEqual(packet?.lie, .fairway)
        XCTAssertEqual(packet?.shotDistanceM, 142)
        XCTAssertEqual(packet?.recommendedClub, "8 Iron")
        XCTAssertEqual(packet?.headline, "8 Iron to Center green")
        XCTAssertEqual(packet?.executionNote, "8 Iron carry 144m fits a center green number.")
        XCTAssertNil(packet?.missNote)
        XCTAssertNil(packet?.fallbackNote)
    }

    func testResolvesSaferApproachPacketFromRoughShot() throws {
        let bundle = try loadBundle(from: makeBundleJSON(
            par: 4,
            teeLengthM: 360,
            featuresJSON: "[]"
        ))

        let packet = NextShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .balanced,
                wind: nil
            ),
            shotStateContext: ShotStateContext(
                shotNumber: 2,
                remainingDistanceM: 128,
                lie: .rough
            )
        )

        XCTAssertEqual(packet?.shotPhase, "approach")
        XCTAssertEqual(packet?.recommendationType, "approach")
        XCTAssertEqual(packet?.shotNumber, 2)
        XCTAssertEqual(packet?.remainingDistanceM, 128)
        XCTAssertEqual(packet?.lie, .rough)
        XCTAssertEqual(packet?.targetLabel, "Front-center green")
        XCTAssertEqual(packet?.shotDistanceM, 122)
        XCTAssertEqual(packet?.recommendedClub, "9 Iron")
        XCTAssertEqual(packet?.headline, "9 Iron to Front-center green")
        XCTAssertEqual(packet?.executionNote, "9 Iron carry 132m fits a front-center green number.")
        XCTAssertNil(packet?.missNote)
        XCTAssertNil(packet?.fallbackNote)
    }

    func testResolvesLayupPacketForSecondShotShelf() throws {
        let bundle = try loadBundle(from: makeBundleJSON(
            par: 5,
            teeLengthM: 460,
            featuresJSON: """
            [
              {
                "feature_id": "bunker-left",
                "feature_type": "bunker",
                "hazard_kind": "bunker",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "name": "bunker-left",
                  "centerline_along_m": 417,
                  "centerline_distance_m": 3,
                  "centerline_side": "left"
                }
              }
            ]
            """,
            teeTargetCorridorsJSON: """
            [
              {
                "overlay_id": "tee-corridor-7",
                "overlay_type": "tee_target_corridor",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "tee",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "target_distance_m": 239.2,
                  "corridor_width_m": 24,
                  "corridor_depth_m": 30,
                  "target_label": "Primary stock corridor",
                  "fairway_feature_id": "fairway-1",
                  "strategy_mode": "stock"
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.78
                },
                "rationale": {
                  "primary_reason": "corridor avoids the nearest fairway bunker pressure"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """,
            layupCandidatesJSON: """
            [
              {
                "overlay_id": "layup-7-stock",
                "overlay_type": "layup_candidate",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "layup",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "target_distance_m": 358,
                  "planned_leave_distance_m": 102,
                  "target_label": "Left-center layup shelf",
                  "strategy_mode": "stock"
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.76
                },
                "rationale": {
                  "primary_reason": "shelf stays short of the greenside bunker while preserving a full wedge look"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """,
            preferredMissJSON: """
            [
              {
                "overlay_id": "preferred-miss-1",
                "overlay_type": "preferred_miss",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "tee",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "preferred_direction": "right",
                  "avoid_direction": "left",
                  "preferred_risk_score": 0.14,
                  "avoid_risk_score": 0.39,
                  "risk_gap_score": 0.25
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.73
                },
                "rationale": {
                  "primary_reason": "left side carries more risk: bunker on the left at 240m along adds recovery cost"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """,
            hazardSeverityJSON: """
            [
              {
                "overlay_id": "hazard-1",
                "overlay_type": "hazard_severity",
                "course_id": "test-course",
                "hole_id": "1",
                "tee_set_id": "all",
                "shot_phase": "all",
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                },
                "properties": {
                  "hazard_ref_id": "bunker-left",
                  "hazard_kind": "bunker",
                  "severity_band": "high",
                  "severity_score": 0.74,
                  "context_relevance_score": 0.97,
                  "penalty_kind": "recovery_only",
                  "landing_conflict": true,
                  "blocks_recovery": false
                },
                "confidence": {
                  "band": "medium",
                  "score": 0.72
                },
                "rationale": {
                  "primary_reason": "bunker on the left at 417m along adds recovery cost"
                },
                "constraints": {
                  "derived_from": "test"
                },
                "provenance": {
                  "source_file": "test.json",
                  "derivation_version": "test"
                }
              }
            ]
            """
        ))

        let packet = NextShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .aggressive,
                wind: nil
            ),
            shotStateContext: ShotStateContext(
                shotNumber: 2,
                remainingDistanceM: 220,
                lie: .fairway
            )
        )

        XCTAssertEqual(packet?.shotPhase, "layup")
        XCTAssertEqual(packet?.recommendationType, "layup")
        XCTAssertEqual(packet?.shotNumber, 2)
        XCTAssertEqual(packet?.remainingDistanceM, 220)
        XCTAssertEqual(packet?.lie, .fairway)
        XCTAssertEqual(packet?.targetLabel, "Left-center layup shelf")
        XCTAssertEqual(packet?.shotDistanceM, 118)
        XCTAssertEqual(packet?.plannedLeaveDistanceM, 102)
        XCTAssertEqual(packet?.recommendedClub, "PW")
        XCTAssertEqual(packet?.headline, "PW to Left-center layup shelf")
        XCTAssertEqual(packet?.executionNote, "PW carry 118m leaves about 102m in.")
        XCTAssertEqual(packet?.fallbackNote, "If the green light is not there, leave yourself about 102m in.")
    }

    private func loadBundle(from json: String) throws -> CourseBundle {
        try CourseBundleLoader().load(data: Data(json.utf8))
    }

    private func makeBundleJSON(
        par: Int,
        teeLengthM: Double,
        featuresJSON: String,
        teeTargetCorridorsJSON: String = "[]",
        layupCandidatesJSON: String = "[]",
        preferredMissJSON: String = "[]",
        hazardSeverityJSON: String = "[]"
    ) -> String {
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
              "par": \(par),
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
                "features": \(featuresJSON),
                "out_of_bounds_lines": [],
                "context_points": []
              },
              "strategy_overlays": {
                "tee_target_corridors": \(teeTargetCorridorsJSON),
                "aggressive_tee_corridors": [],
                "layup_candidates": \(layupCandidatesJSON),
                "preferred_miss": \(preferredMissJSON),
                "hazard_severity": \(hazardSeverityJSON)
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
