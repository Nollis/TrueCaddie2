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

        let bundle = try CourseBundleLoader().load(data: Data(json.utf8))

        XCTAssertEqual(bundle.courseId, "test-course")
        XCTAssertEqual(bundle.bundleVersion, "test-bundle")
        XCTAssertEqual(bundle.holes.first?.holeId, "1")
    }
}
