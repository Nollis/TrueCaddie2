import CoreGraphics
import Foundation
import XCTest
@testable import TrueCaddieDomain

final class HoleSketchLayoutTests: XCTestCase {
    private let size = CGSize(width: 220, height: 240)

    func testEmptyCenterlineProducesNoLinePoints() throws {
        let hole = try makeHole(centerlineJSON: lineStringJSON([]))

        let layout = HoleSketchLayout(hole: hole, size: size)

        XCTAssertTrue(layout.centerline.isEmpty)
    }

    func testCenterlineProjectsToDrawingSpace() throws {
        let hole = try makeHole(
            centerlineJSON: lineStringJSON([[11.0, 57.0], [11.2, 57.2]])
        )

        let layout = HoleSketchLayout(hole: hole, size: size)

        XCTAssertEqual(layout.centerline.count, 2)

        let drawingWidth = size.width - 20
        let drawingHeight = size.height - 20

        let xValues = layout.centerline.map(\.x)
        let yValues = layout.centerline.map(\.y)
        let xSpread = (xValues.max() ?? 0) - (xValues.min() ?? 0)
        let ySpread = (yValues.max() ?? 0) - (yValues.min() ?? 0)

        XCTAssertGreaterThan(xSpread, 0)
        XCTAssertLessThanOrEqual(xSpread, drawingWidth)
        XCTAssertGreaterThan(ySpread, 0)
        XCTAssertLessThanOrEqual(ySpread, drawingHeight)
    }

    func testNorthernCoordinateMapsToSmallerYThanSouthernCoordinate() throws {
        let south: [Double] = [11.1, 57.0]
        let north: [Double] = [11.1, 57.2]
        let hole = try makeHole(centerlineJSON: lineStringJSON([south, north]))

        let layout = HoleSketchLayout(hole: hole, size: size)

        let southPoint = layout.centerline[0]
        let northPoint = layout.centerline[1]

        XCTAssertLessThan(northPoint.y, southPoint.y)
    }

    func testDegenerateBoundsStillProducesFinitePoints() throws {
        let coordinate: [Double] = [11.1, 57.1]
        let hole = try makeHole(
            centerlineJSON: lineStringJSON([coordinate, coordinate]),
            greenCenter: coordinate
        )

        let layout = HoleSketchLayout(hole: hole, size: size)

        XCTAssertEqual(layout.centerline.count, 2)
        for point in layout.centerline {
            XCTAssertTrue(point.x.isFinite)
            XCTAssertTrue(point.y.isFinite)
        }

        let greenCenter = try XCTUnwrap(layout.greenCenter)
        XCTAssertTrue(greenCenter.x.isFinite)
        XCTAssertTrue(greenCenter.y.isFinite)
    }

    func testPolygonRingsAreProjectedAndPreservePointCount() throws {
        let ring: [[Double]] = [
            [11.0, 57.0],
            [11.1, 57.0],
            [11.1, 57.1],
            [11.0, 57.1],
            [11.0, 57.0]
        ]
        let feature = featureJSON(
            id: "fairway-1",
            type: "fairway",
            geometry: polygonJSON([ring])
        )
        let hole = try makeHole(
            centerlineJSON: lineStringJSON([[11.0, 57.0], [11.1, 57.1]]),
            featureJSONs: [feature]
        )

        let layout = HoleSketchLayout(hole: hole, size: size)
        let rings = layout.polygonRings(for: "fairway")

        XCTAssertEqual(rings.count, 1)
        XCTAssertEqual(rings[0].count, 5)
    }

    func testMultiPolygonProducesMultipleRings() throws {
        let ringA: [[Double]] = [
            [11.0, 57.0], [11.01, 57.0], [11.01, 57.01], [11.0, 57.01], [11.0, 57.0]
        ]
        let ringB: [[Double]] = [
            [11.05, 57.05], [11.06, 57.05], [11.06, 57.06], [11.05, 57.06], [11.05, 57.05]
        ]
        let feature = featureJSON(
            id: "bunker-multi",
            type: "bunker",
            geometry: multiPolygonJSON([[ringA], [ringB]])
        )
        let hole = try makeHole(
            centerlineJSON: lineStringJSON([[11.0, 57.0], [11.06, 57.06]]),
            featureJSONs: [feature]
        )

        let layout = HoleSketchLayout(hole: hole, size: size)
        let rings = layout.polygonRings(for: "bunker")

        XCTAssertEqual(rings.count, 2)
    }

    func testUnknownFeatureTypeProducesNoRings() throws {
        let feature = featureJSON(
            id: "fairway-1",
            type: "fairway",
            geometry: polygonJSON([[
                [11.0, 57.0], [11.1, 57.0], [11.1, 57.1], [11.0, 57.0]
            ]])
        )
        let hole = try makeHole(
            centerlineJSON: lineStringJSON([[11.0, 57.0], [11.1, 57.1]]),
            featureJSONs: [feature]
        )

        let layout = HoleSketchLayout(hole: hole, size: size)

        XCTAssertTrue(layout.polygonRings(for: "water").isEmpty)
    }

    func testOutOfBoundsLineWithoutGeometryIsSkipped() throws {
        let validLine = obFeatureJSON(
            id: "ob-1",
            geometryJSON: lineStringJSON([[11.0, 57.0], [11.1, 57.1]])
        )
        let invalidLine = obFeatureJSON(id: "ob-2", geometryJSON: nil)

        let hole = try makeHole(
            centerlineJSON: lineStringJSON([[11.0, 57.0], [11.1, 57.1]]),
            outOfBoundsJSONs: [validLine, invalidLine]
        )

        let layout = HoleSketchLayout(hole: hole, size: size)

        XCTAssertEqual(layout.outOfBounds.count, 1)
        XCTAssertEqual(layout.outOfBounds[0].count, 2)
    }
}

private func lineStringJSON(_ coordinates: [[Double]]) -> String {
    """
    {
      "type": "LineString",
      "coordinates": \(coordinatesJSON(coordinates))
    }
    """
}

private func polygonJSON(_ rings: [[[Double]]]) -> String {
    """
    {
      "type": "Polygon",
      "coordinates": \(ringsJSON(rings))
    }
    """
}

private func multiPolygonJSON(_ polygons: [[[[Double]]]]) -> String {
    let body = polygons
        .map { ringsJSON($0) }
        .joined(separator: ",")

    return """
    {
      "type": "MultiPolygon",
      "coordinates": [\(body)]
    }
    """
}

private func coordinatesJSON(_ coordinates: [[Double]]) -> String {
    let items = coordinates
        .map { coordinate in
            "[" + coordinate.map { String(format: "%.10f", $0) }.joined(separator: ",") + "]"
        }
        .joined(separator: ",")

    return "[\(items)]"
}

private func ringsJSON(_ rings: [[[Double]]]) -> String {
    let items = rings
        .map { coordinatesJSON($0) }
        .joined(separator: ",")

    return "[\(items)]"
}

private func featureJSON(id: String, type: String, geometry: String) -> String {
    """
    {
      "feature_id": "\(id)",
      "feature_type": "\(type)",
      "hazard_kind": null,
      "geometry": \(geometry),
      "properties": {}
    }
    """
}

private func obFeatureJSON(id: String, geometryJSON: String?) -> String {
    let geometryField = geometryJSON ?? "null"
    return """
    {
      "type": "Feature",
      "id": "\(id)",
      "geometry": \(geometryField),
      "properties": null
    }
    """
}

private func makeHole(
    centerlineJSON: String,
    featureJSONs: [String] = [],
    outOfBoundsJSONs: [String] = [],
    greenCenter: [Double] = [11.1, 57.1]
) throws -> CourseHole {
    let features = featureJSONs.joined(separator: ",")
    let outOfBounds = outOfBoundsJSONs.joined(separator: ",")
    let green = "[" + greenCenter.map { String(format: "%.10f", $0) }.joined(separator: ",") + "]"

    let json = """
    {
      "hole_id": "1",
      "hole_number": 1,
      "par": 4,
      "tees": [],
      "base_mapping_data": {
        "centerline": \(centerlineJSON),
        "green": {
          "center": \(green),
          "front_center": null,
          "back_center": null,
          "center_elevation_m": null,
          "front_elevation_m": null,
          "back_elevation_m": null,
          "polygon_feature_id": null
        },
        "features": [\(features)],
        "out_of_bounds_lines": [\(outOfBounds)],
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
    """

    return try JSONDecoder().decode(CourseHole.self, from: Data(json.utf8))
}
