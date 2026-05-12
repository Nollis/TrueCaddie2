import Foundation
import XCTest
@testable import TrueCaddieDomain

final class CourseBundleLoaderTests: XCTestCase {
    func testLoadsCanonicalBundleIdentity() throws {
        let json = """
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
                  "front_center": null,
                  "back_center": null,
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
                      "primary_reason": "right side carries more risk: water on the right at 180m along with 18m from centerline"
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
                      "hazard_ref_id": "feature-1",
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
        """

        let bundle = try CourseBundleLoader().load(data: Data(json.utf8))

        XCTAssertEqual(bundle.courseId, "test-course")
        XCTAssertEqual(bundle.bundleVersion, "test-bundle")
        XCTAssertEqual(bundle.holes.first?.holeId, "1")
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.teeTargetCorridors.count, 1)
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.teeTargetCorridors.first?.teeSetId, "all")
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.teeTargetCorridors.first?.properties.targetLabel, "Primary stock corridor")
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.preferredMiss.count, 1)
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.preferredMiss.first?.properties.preferredDirection, "left")
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.preferredMiss.first?.properties.avoidDirection, "right")
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.hazardSeverity.count, 1)
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.hazardSeverity.first?.properties.hazardKind, "water")
        XCTAssertEqual(bundle.holes.first?.strategyOverlays.hazardSeverity.first?.rationale.primaryReason, "water right is the main problem")
    }

    func testRejectsUnsupportedSchema() throws {
        let json = """
        {
          "schema_version": "v2",
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
              "tees": [],
              "base_mapping_data": {
                "centerline": {
                  "type": "LineString",
                  "coordinates": [[11.0, 57.0], [11.1, 57.1]]
                },
                "green": {
                  "center": [11.1, 57.1],
                  "front_center": null,
                  "back_center": null,
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

        XCTAssertThrowsError(try CourseBundleLoader().load(data: Data(json.utf8))) { error in
            XCTAssertEqual(error as? CourseBundleLoaderError, .unsupportedSchema("v2"))
        }
    }

    func testRejectsEmptyHoleSet() throws {
        let json = """
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
          "holes": []
        }
        """

        XCTAssertThrowsError(try CourseBundleLoader().load(data: Data(json.utf8))) { error in
            XCTAssertEqual(error as? CourseBundleLoaderError, .emptyHoleSet)
        }
    }

    func testHazardOverlayDecodeFailsWhenRequiredPropertyIsMissing() {
        let json = """
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
              "tees": [],
              "base_mapping_data": {
                "centerline": {
                  "type": "LineString",
                  "coordinates": [[11.0, 57.0], [11.1, 57.1]]
                },
                "green": {
                  "center": [11.1, 57.1],
                  "front_center": null,
                  "back_center": null,
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
                      "hazard_ref_id": "feature-1",
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
        """

        XCTAssertThrowsError(try CourseBundleLoader().load(data: Data(json.utf8)))
    }
}
