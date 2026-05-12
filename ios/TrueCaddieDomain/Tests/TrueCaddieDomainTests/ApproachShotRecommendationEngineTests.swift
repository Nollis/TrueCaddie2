import Foundation
import XCTest
@testable import TrueCaddieDomain

final class ApproachShotRecommendationEngineTests: XCTestCase {
    func testBuildsApproachRecommendationFromStandardPar4Context() throws {
        let bundle = try loadBundle(from: """
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
                  "tee_length_m": 350,
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
                "features": [
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
                      "centerline_along_m": 338,
                      "centerline_distance_m": 8,
                      "centerline_side": "left"
                    }
                  },
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
                ],
                "out_of_bounds_lines": [],
                "context_points": []
              },
              "strategy_overlays": {
                "tee_target_corridors": [
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
                ],
                "aggressive_tee_corridors": [],
                "layup_candidates": [],
                "preferred_miss": [
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
                ],
                "hazard_severity": [
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
        """)

        let packet = ApproachShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .balanced,
                wind: nil
            )
        )

        XCTAssertEqual(packet?.courseId, "test-course")
        XCTAssertEqual(packet?.holeId, "1")
        XCTAssertEqual(packet?.recommendationType, "approach")
        XCTAssertEqual(packet?.targetLabel, "Center green")
        XCTAssertEqual(packet?.shotDistanceM, 140)
        XCTAssertNil(packet?.plannedLeaveDistanceM)
        XCTAssertEqual(packet?.recommendedClub, "8 Iron")
        XCTAssertEqual(packet?.clubCarryDistanceM, 144)
        XCTAssertEqual(packet?.preferredMissDirection, "right")
        XCTAssertEqual(packet?.avoidDirection, "left")
        XCTAssertEqual(packet?.riskLevel, "medium")
        XCTAssertEqual(packet?.confidenceBand, "medium")
        XCTAssertEqual(packet?.primaryReason, "Favor right. bunker left is the miss to avoid around the green.")
        XCTAssertEqual(packet?.supportingReason, "8 Iron carry 144m fits a center green number.")
        XCTAssertEqual(packet?.hazardSummary, ["Bunker left"])
    }

    func testPar3CanStillProduceApproachPacketWithoutTeeShotContext() throws {
        let bundle = try loadBundle(from: """
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
              "hole_id": "2",
              "hole_number": 2,
              "par": 3,
              "tees": [
                {
                  "tee_set_id": "white",
                  "name": "White",
                  "tee_coordinate": [11.0, 57.0],
                  "tee_length_m": 155,
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
                  "back_center": null,
                  "center_elevation_m": null,
                  "front_elevation_m": null,
                  "back_elevation_m": null,
                  "polygon_feature_id": null
                },
                "features": [
                  {
                    "feature_id": "water-right",
                    "feature_type": "water",
                    "hazard_kind": "water",
                    "geometry": {
                      "type": "Polygon",
                      "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                    },
                    "properties": {
                      "name": "water-right",
                      "centerline_along_m": 150,
                      "centerline_distance_m": 8,
                      "centerline_side": "right"
                    }
                  }
                ],
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
        """)

        let packet = ApproachShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .conservative,
                wind: nil
            )
        )

        XCTAssertEqual(packet?.recommendationType, "approach")
        XCTAssertEqual(packet?.targetLabel, "Front-center green")
        XCTAssertEqual(packet?.shotDistanceM, 149)
        XCTAssertEqual(packet?.recommendedClub, "8 Iron")
        XCTAssertEqual(packet?.preferredMissDirection, "left")
        XCTAssertEqual(packet?.avoidDirection, "right")
        XCTAssertEqual(packet?.hazardSummary, ["Water right"])
    }

    func testLongPar5FallsBackToLayupRecommendation() throws {
        let bundle = try loadBundle(from: """
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
              "hole_id": "7",
              "hole_number": 7,
              "par": 5,
              "tees": [
                {
                  "tee_set_id": "white",
                  "name": "White",
                  "tee_coordinate": [11.0, 57.0],
                  "tee_length_m": 525,
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
                "features": [
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
                      "centerline_along_m": 506,
                      "centerline_distance_m": 8,
                      "centerline_side": "left"
                    }
                  },
                  {
                    "feature_id": "bunker-right",
                    "feature_type": "bunker",
                    "hazard_kind": "bunker",
                    "geometry": {
                      "type": "Polygon",
                      "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                    },
                    "properties": {
                      "name": "bunker-right",
                      "centerline_along_m": 507,
                      "centerline_distance_m": 7,
                      "centerline_side": "right"
                    }
                  }
                ],
                "out_of_bounds_lines": [],
                "context_points": []
              },
              "strategy_overlays": {
                "tee_target_corridors": [
                  {
                    "overlay_id": "tee-corridor-7",
                    "overlay_type": "tee_target_corridor",
                    "course_id": "test-course",
                    "hole_id": "7",
                    "tee_set_id": "all",
                    "shot_phase": "tee",
                    "geometry": {
                      "type": "Polygon",
                      "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                    },
                    "properties": {
                      "target_distance_m": 273,
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
                      "primary_reason": "corridor favors the side with less tree pressure around the stock landing"
                    },
                    "constraints": {
                      "derived_from": "test"
                    },
                    "provenance": {
                      "source_file": "test.json",
                      "derivation_version": "test"
                    }
                  }
                ],
                "aggressive_tee_corridors": [],
                "layup_candidates": [],
                "preferred_miss": [
                  {
                    "overlay_id": "preferred-miss-7",
                    "overlay_type": "preferred_miss",
                    "course_id": "test-course",
                    "hole_id": "7",
                    "tee_set_id": "all",
                    "shot_phase": "tee",
                    "geometry": {
                      "type": "Polygon",
                      "coordinates": [[[11.0, 57.0], [11.02, 57.0], [11.02, 57.01], [11.0, 57.01], [11.0, 57.0]]]
                    },
                    "properties": {
                      "preferred_direction": "left",
                      "avoid_direction": "right",
                      "preferred_risk_score": 0.27,
                      "avoid_risk_score": 0.40,
                      "risk_gap_score": 0.13
                    },
                    "confidence": {
                      "band": "medium",
                      "score": 0.69
                    },
                    "rationale": {
                      "primary_reason": "right side carries more risk: woods on the right at 293.37m along can turn a miss into recovery golf"
                    },
                    "constraints": {
                      "derived_from": "test"
                    },
                    "provenance": {
                      "source_file": "test.json",
                      "derivation_version": "test"
                    }
                  }
                ],
                "hazard_severity": [
                  {
                    "overlay_id": "hazard-1",
                    "overlay_type": "hazard_severity",
                    "course_id": "test-course",
                    "hole_id": "7",
                    "tee_set_id": "all",
                    "shot_phase": "all",
                    "geometry": {
                      "type": "Polygon",
                      "coordinates": [[[11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.0]]]
                    },
                    "properties": {
                      "hazard_ref_id": "woods-right",
                      "hazard_kind": "woods",
                      "severity_band": "critical",
                      "severity_score": 0.87,
                      "context_relevance_score": 0.91,
                      "penalty_kind": "recovery_only",
                      "landing_conflict": true,
                      "blocks_recovery": true
                    },
                    "confidence": {
                      "band": "medium",
                      "score": 0.72
                    },
                    "rationale": {
                      "primary_reason": "woods on the right at 401.34m along can turn a miss into recovery golf"
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
        """)

        let packet = ApproachShotRecommendationEngine.build(
            courseId: bundle.courseId,
            for: try XCTUnwrap(bundle.holes.first),
            playerContext: .pilotSample,
            roundContext: RoundContext(
                teeSetId: "white",
                teeSetName: "White",
                strategyPreference: .balanced,
                wind: WindContext(relativeDirection: .helping, speedMps: 5.0)
            )
        )

        XCTAssertEqual(packet?.recommendationType, "layup")
        XCTAssertEqual(packet?.targetLabel, "Lay up for wedge number")
        XCTAssertEqual(packet?.shotDistanceM, 148)
        XCTAssertEqual(packet?.plannedLeaveDistanceM, 108)
        XCTAssertEqual(packet?.recommendedClub, "8 Iron")
        XCTAssertEqual(packet?.clubCarryDistanceM, 144)
        XCTAssertEqual(packet?.primaryReason, "Lay up to leave about 108m in. Reaching the green cleanly is not a strong percentage play from here.")
        XCTAssertEqual(packet?.supportingReason, "8 Iron carry 144m leaves about 108m with 5m/s helping wind.")
    }

    private func loadBundle(from json: String) throws -> CourseBundle {
        try CourseBundleLoader().load(data: Data(json.utf8))
    }
}
