import Foundation
import XCTest
@testable import TrueCaddieDomain

final class GolfGeometryTests: XCTestCase {

    // Kungsbacka Nya hole 1 reference points (from shared/sample-bundles/kungsbacka-nya.v1.json).
    private let whiteTeeHole1 = GeoCoordinate2D(lon: 11.986226141452791, lat: 57.49302015313067)
    private let greenCenterHole1 = GeoCoordinate2D(lon: 11.992440149, lat: 57.491023724)

    // MARK: - haversineDistance

    func testHaversineDistanceMatchesKnownTeeToGreenLength() {
        let distance = GolfGeometry.haversineDistance(whiteTeeHole1, greenCenterHole1)
        // Straight-line distance from the bundle's published coordinates is ~432.6 m.
        XCTAssertEqual(distance, 432.6, accuracy: 1.0)
    }

    func testHaversineDistanceIsZeroForSamePoint() {
        let distance = GolfGeometry.haversineDistance(whiteTeeHole1, whiteTeeHole1)
        XCTAssertEqual(distance, 0.0, accuracy: 0.001)
    }

    func testHaversineDistanceIsSymmetric() {
        let forward = GolfGeometry.haversineDistance(whiteTeeHole1, greenCenterHole1)
        let backward = GolfGeometry.haversineDistance(greenCenterHole1, whiteTeeHole1)
        XCTAssertEqual(forward, backward, accuracy: 0.001)
    }

    // MARK: - pointInPolygon

    func testPointInPolygonReturnsTrueForInteriorPoint() {
        let square = squareRing(centeredAt: greenCenterHole1, halfSizeDeg: 0.0005)
        XCTAssertTrue(GolfGeometry.pointInPolygon(greenCenterHole1, ring: square))
    }

    func testPointInPolygonReturnsFalseForPointOutsideByASmallMargin() {
        let square = squareRing(centeredAt: greenCenterHole1, halfSizeDeg: 0.0005)
        let outside = GeoCoordinate2D(
            lon: greenCenterHole1.lon + 0.001,
            lat: greenCenterHole1.lat
        )
        XCTAssertFalse(GolfGeometry.pointInPolygon(outside, ring: square))
    }

    func testPointInPolygonReturnsTrueForPointOnVertex() {
        let square = squareRing(centeredAt: greenCenterHole1, halfSizeDeg: 0.0005)
        let vertex = square[0]
        XCTAssertTrue(GolfGeometry.pointInPolygon(vertex, ring: square))
    }

    func testPointInPolygonHandlesEmptyRing() {
        XCTAssertFalse(GolfGeometry.pointInPolygon(greenCenterHole1, ring: []))
    }

    // MARK: - GeoCoordinate2D(lonLatPair:)

    func testGeoCoordinateFromLonLatPair() {
        let coord = GeoCoordinate2D(lonLatPair: [11.986, 57.493])
        XCTAssertEqual(coord?.lon, 11.986)
        XCTAssertEqual(coord?.lat, 57.493)
    }

    func testGeoCoordinateFromLonLatPairReturnsNilForShortInput() {
        XCTAssertNil(GeoCoordinate2D(lonLatPair: []))
        XCTAssertNil(GeoCoordinate2D(lonLatPair: [11.0]))
    }

    func testGeoCoordinateFromLonLatPairAcceptsExtraElements() {
        // GeoJSON allows an optional altitude in position 3; we ignore it.
        let coord = GeoCoordinate2D(lonLatPair: [11.0, 57.0, 12.5])
        XCTAssertEqual(coord?.lon, 11.0)
        XCTAssertEqual(coord?.lat, 57.0)
    }

    // MARK: - extractOuterRings

    func testExtractOuterRingsFromPointReturnsEmpty() throws {
        let geometry = try decodeGeometry(#"""
        {"type":"Point","coordinates":[11.0, 57.0]}
        """#)
        XCTAssertTrue(GolfGeometry.extractOuterRings(from: geometry).isEmpty)
    }

    func testExtractOuterRingsFromPolygonReturnsOneRing() throws {
        let geometry = try decodeGeometry(#"""
        {"type":"Polygon","coordinates":[[[11.0,57.0],[11.001,57.0],[11.001,57.001],[11.0,57.001],[11.0,57.0]]]}
        """#)
        let rings = GolfGeometry.extractOuterRings(from: geometry)
        XCTAssertEqual(rings.count, 1)
        XCTAssertEqual(rings[0].count, 5)
        XCTAssertEqual(rings[0].first?.lon, 11.0)
    }

    func testExtractOuterRingsFromMultiPolygonReturnsOnePerPolygon() throws {
        let geometry = try decodeGeometry(#"""
        {"type":"MultiPolygon","coordinates":[
          [[[11.0,57.0],[11.001,57.0],[11.001,57.001],[11.0,57.001],[11.0,57.0]]],
          [[[12.0,58.0],[12.001,58.0],[12.001,58.001],[12.0,58.001],[12.0,58.0]]]
        ]}
        """#)
        let rings = GolfGeometry.extractOuterRings(from: geometry)
        XCTAssertEqual(rings.count, 2)
    }

    // MARK: - Integration: GeoJSON round-trip + containment

    func testExtractedPolygonContainsItsCentroid() throws {
        let geometry = try decodeGeometry(#"""
        {"type":"Polygon","coordinates":[[
          [11.99670821428299, 57.48901493293537],
          [11.9970079, 57.4884172],
          [11.9974079, 57.4887172],
          [11.9970079, 57.4890172],
          [11.99670821428299, 57.48901493293537]
        ]]}
        """#)
        let rings = GolfGeometry.extractOuterRings(from: geometry)
        XCTAssertEqual(rings.count, 1)
        let centroid = GeoCoordinate2D(lon: 11.9970079, lat: 57.4887172)
        XCTAssertTrue(GolfGeometry.pointInPolygon(centroid, ring: rings[0]))

        let farAway = GeoCoordinate2D(lon: 12.0, lat: 57.50)
        XCTAssertFalse(GolfGeometry.pointInPolygon(farAway, ring: rings[0]))
    }

    // MARK: - Constants

    func testConstantsHaveExpectedValues() {
        XCTAssertEqual(GolfGeometry.Constants.minimumAcceptableAccuracyM, 15.0)
        XCTAssertEqual(GolfGeometry.Constants.holeSwitchOuterRadiusM, 80.0)
    }

    // MARK: - Helpers

    private func squareRing(centeredAt center: GeoCoordinate2D, halfSizeDeg: Double) -> [GeoCoordinate2D] {
        [
            GeoCoordinate2D(lon: center.lon - halfSizeDeg, lat: center.lat - halfSizeDeg),
            GeoCoordinate2D(lon: center.lon + halfSizeDeg, lat: center.lat - halfSizeDeg),
            GeoCoordinate2D(lon: center.lon + halfSizeDeg, lat: center.lat + halfSizeDeg),
            GeoCoordinate2D(lon: center.lon - halfSizeDeg, lat: center.lat + halfSizeDeg),
            GeoCoordinate2D(lon: center.lon - halfSizeDeg, lat: center.lat - halfSizeDeg),
        ]
    }

    private func decodeGeometry(_ json: String) throws -> GeoJSONGeometry {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(GeoJSONGeometry.self, from: data)
    }
}
