import Foundation
@testable import TrueCaddieDomain

/// Shared test helpers for building synthetic `CourseBundle` values with just
/// enough field coverage to satisfy the strict `Decodable` requirements.
/// Geometry-bearing fields (tee coordinates, green centers, feature polygons)
/// are parameterized so each test can shape its own course.
enum TestBundleBuilders {

    /// Build a `CourseBundle` from one or more synthetic `CourseHole` JSON
    /// snippets. The JSON wraps the bundle envelope around the supplied holes.
    static func makeBundle(holeJSONFragments: [String]) throws -> CourseBundle {
        let json = """
        {
          "schema_version": "v1",
          "bundle_version": "test",
          "course_id": "test",
          "course_name": "Test",
          "published_at": "2026-05-10T00:00:00Z",
          "provenance": { "source_system": "test", "derivation_version": "test" },
          "holes": [\(holeJSONFragments.joined(separator: ","))]
        }
        """
        return try CourseBundleLoader().load(data: Data(json.utf8))
    }

    /// Builds the JSON for one `CourseHole`. `features` are pairs of
    /// `(featureType, polygonRing)` where the ring is a closed loop of
    /// `[lon, lat]` pairs.
    static func makeHoleJSON(
        holeNumber: Int,
        teeLonLat: [Double],
        teeLengthM: Double = 350,
        greenLonLat: [Double],
        features: [(type: String, polygon: [[Double]])] = []
    ) -> String {
        let teeCoordString = "[\(teeLonLat[0]), \(teeLonLat[1])]"
        let greenCenterString = "[\(greenLonLat[0]), \(greenLonLat[1])]"

        let featuresJSON = features.enumerated().map { index, feature in
            """
            {
              "feature_id": "\(feature.type)-\(holeNumber)-\(index)",
              "feature_type": "\(feature.type)",
              "geometry": { "type": "Polygon", "coordinates": [\(ringJSON(feature.polygon))] },
              "properties": {}
            }
            """
        }.joined(separator: ",")

        return """
        {
          "hole_id": "\(holeNumber)",
          "hole_number": \(holeNumber),
          "par": 4,
          "tees": [
            {
              "tee_set_id": "white",
              "name": "White",
              "tee_coordinate": \(teeCoordString),
              "tee_length_m": \(teeLengthM),
              "is_default": true
            }
          ],
          "base_mapping_data": {
            "centerline": { "type": "LineString", "coordinates": [\(teeCoordString), \(greenCenterString)] },
            "green": {
              "center": \(greenCenterString),
              "front_center": null, "back_center": null,
              "center_elevation_m": null, "front_elevation_m": null, "back_elevation_m": null,
              "polygon_feature_id": null
            },
            "features": [\(featuresJSON)],
            "out_of_bounds_lines": [],
            "context_points": []
          },
          "strategy_overlays": {
            "tee_target_corridors": [], "aggressive_tee_corridors": [],
            "layup_candidates": [], "preferred_miss": [], "hazard_severity": []
          },
          "quality_confidence": {
            "hole_publish_confidence": "medium", "hole_publish_score": 0.7,
            "overlay_scores": {}, "notes": []
          },
          "provenance": { "source_system": "test", "source_file": "test.json", "derivation_version": "test" }
        }
        """
    }

    private static func ringJSON(_ ring: [[Double]]) -> String {
        let points = ring.map { "[\($0[0]), \($0[1])]" }.joined(separator: ",")
        return "[\(points)]"
    }

    /// Build a small closed square ring centered on the given coordinate.
    /// `halfSizeDeg` is in raw degrees and applied symmetrically in lon/lat —
    /// roughly square at golf-hole scale.
    static func square(centeredAt center: [Double], halfSizeDeg: Double) -> [[Double]] {
        let lon = center[0], lat = center[1]
        return [
            [lon - halfSizeDeg, lat - halfSizeDeg],
            [lon + halfSizeDeg, lat - halfSizeDeg],
            [lon + halfSizeDeg, lat + halfSizeDeg],
            [lon - halfSizeDeg, lat + halfSizeDeg],
            [lon - halfSizeDeg, lat - halfSizeDeg],
        ]
    }
}
