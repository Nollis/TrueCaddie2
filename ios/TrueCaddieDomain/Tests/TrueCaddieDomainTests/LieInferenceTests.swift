import Foundation
import XCTest
@testable import TrueCaddieDomain

final class LieInferenceTests: XCTestCase {

    // A single synthetic hole with overlapping features so precedence is
    // exercised: fairway covers the whole lower hole, green sits inside the
    // fairway, bunker sits near the green inside the fairway, water sits in
    // its own corner.
    private func makeHoleWithAllFeatures() throws -> CourseHole {
        let json = TestBundleBuilders.makeHoleJSON(
            holeNumber: 1,
            teeLonLat: [11.0, 57.0],
            greenLonLat: [11.005, 57.005],
            features: [
                ("fairway", TestBundleBuilders.square(centeredAt: [11.0025, 57.0025], halfSizeDeg: 0.003)),
                ("green", TestBundleBuilders.square(centeredAt: [11.005, 57.005], halfSizeDeg: 0.0005)),
                ("bunker", TestBundleBuilders.square(centeredAt: [11.0048, 57.0048], halfSizeDeg: 0.0002)),
                ("water", TestBundleBuilders.square(centeredAt: [11.001, 57.0005], halfSizeDeg: 0.0005)),
                ("woods", TestBundleBuilders.square(centeredAt: [10.998, 57.0], halfSizeDeg: 0.0005)),
            ]
        )
        let bundle = try TestBundleBuilders.makeBundle(holeJSONFragments: [json])
        return bundle.holes.first!
    }

    func testCoordinateInBunkerReturnsBunkerEvenWhenAlsoInsideFairway() throws {
        let hole = try makeHoleWithAllFeatures()
        let fix = GeoCoordinate2D(lon: 11.0048, lat: 57.0048)
        XCTAssertEqual(LieInference.lie(at: fix, in: hole), .bunker)
    }

    func testCoordinateInWaterReturnsRecovery() throws {
        let hole = try makeHoleWithAllFeatures()
        let fix = GeoCoordinate2D(lon: 11.001, lat: 57.0005)
        XCTAssertEqual(LieInference.lie(at: fix, in: hole), .recovery)
    }

    func testCoordinateOnGreenReturnsFairway() throws {
        // No .green case exists in ShotLie; green maps to .fairway.
        let hole = try makeHoleWithAllFeatures()
        let fix = GeoCoordinate2D(lon: 11.005, lat: 57.005)
        XCTAssertEqual(LieInference.lie(at: fix, in: hole), .fairway)
    }

    func testCoordinateInFairwayReturnsFairway() throws {
        let hole = try makeHoleWithAllFeatures()
        // Inside fairway, not inside green/bunker/water (offset away from those).
        let fix = GeoCoordinate2D(lon: 11.003, lat: 57.003)
        XCTAssertEqual(LieInference.lie(at: fix, in: hole), .fairway)
    }

    func testCoordinateOutsideAllFeaturesReturnsRough() throws {
        let hole = try makeHoleWithAllFeatures()
        // Far outside any feature.
        let fix = GeoCoordinate2D(lon: 11.05, lat: 57.05)
        XCTAssertEqual(LieInference.lie(at: fix, in: hole), .rough)
    }

    func testCoordinateInWoodsButNotInFairwayReturnsRough() throws {
        // Woods is not in the precedence table; coordinate inside only the woods polygon
        // falls through to the default rough.
        let hole = try makeHoleWithAllFeatures()
        let fix = GeoCoordinate2D(lon: 10.998, lat: 57.0)
        XCTAssertEqual(LieInference.lie(at: fix, in: hole), .rough)
    }

    func testHoleWithNoFeaturesReturnsRough() throws {
        let json = TestBundleBuilders.makeHoleJSON(
            holeNumber: 1,
            teeLonLat: [11.0, 57.0],
            greenLonLat: [11.005, 57.005],
            features: []
        )
        let bundle = try TestBundleBuilders.makeBundle(holeJSONFragments: [json])
        let fix = GeoCoordinate2D(lon: 11.0, lat: 57.0)
        XCTAssertEqual(LieInference.lie(at: fix, in: bundle.holes.first!), .rough)
    }
}
