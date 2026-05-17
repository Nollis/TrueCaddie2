import Foundation
import XCTest
@testable import TrueCaddieDomain

final class HoleDetectorTests: XCTestCase {

    // Two synthetic holes with non-overlapping geometry, far enough apart that
    // they don't share fallback radii.
    //   Hole 1: tee polygon around (11.0, 57.0), green at (11.005, 57.005).
    //   Hole 2: tee polygon around (12.0, 58.0), green at (12.005, 58.005).
    // 0.001° ≈ 60–110 m depending on direction at these latitudes — large
    // enough to keep features clearly separated.

    private func makeTwoHoleBundle() throws -> CourseBundle {
        let hole1 = TestBundleBuilders.makeHoleJSON(
            holeNumber: 1,
            teeLonLat: [11.0, 57.0],
            greenLonLat: [11.005, 57.005],
            features: [
                ("tee", TestBundleBuilders.square(centeredAt: [11.0, 57.0], halfSizeDeg: 0.0002)),
                ("fairway", TestBundleBuilders.square(centeredAt: [11.0025, 57.0025], halfSizeDeg: 0.0015)),
                ("green", TestBundleBuilders.square(centeredAt: [11.005, 57.005], halfSizeDeg: 0.0003)),
                ("bunker", TestBundleBuilders.square(centeredAt: [11.0048, 57.0048], halfSizeDeg: 0.00015)),
            ]
        )
        let hole2 = TestBundleBuilders.makeHoleJSON(
            holeNumber: 2,
            teeLonLat: [12.0, 58.0],
            greenLonLat: [12.005, 58.005],
            features: [
                ("tee", TestBundleBuilders.square(centeredAt: [12.0, 58.0], halfSizeDeg: 0.0002)),
                ("fairway", TestBundleBuilders.square(centeredAt: [12.0025, 58.0025], halfSizeDeg: 0.0015)),
                ("green", TestBundleBuilders.square(centeredAt: [12.005, 58.005], halfSizeDeg: 0.0003)),
            ]
        )
        return try TestBundleBuilders.makeBundle(holeJSONFragments: [hole1, hole2])
    }

    // MARK: - Happy paths

    func testTeeCoordinateInsideTeePolygonReturnsThatHole() throws {
        let bundle = try makeTwoHoleBundle()
        let fix = GeoCoordinate2D(lon: 11.0, lat: 57.0)
        XCTAssertEqual(HoleDetector.activeHole(fix: fix, bundle: bundle, current: nil), 1)
    }

    func testGreenCenterReturnsItsOwnHole() throws {
        let bundle = try makeTwoHoleBundle()
        let fix = GeoCoordinate2D(lon: 11.005, lat: 57.005)
        XCTAssertEqual(HoleDetector.activeHole(fix: fix, bundle: bundle, current: nil), 1)
    }

    func testHole2CoordinateReturnsHole2() throws {
        let bundle = try makeTwoHoleBundle()
        let fix = GeoCoordinate2D(lon: 12.0025, lat: 58.0025)
        XCTAssertEqual(HoleDetector.activeHole(fix: fix, bundle: bundle, current: nil), 2)
    }

    // MARK: - Fallback (closest tee within radius)

    func testFixOutsidePolygonsButNearTeeFallsBackToThatHole() throws {
        // Hole-2 tee polygon is at (12.0, 58.0) with half-size 0.0002 ≈ 22m east-west / 22m north-south.
        // A fix at (12.0, 58.0008) is ~89m north of the tee, just outside both the tee polygon
        // and the fairway polygon (which spans lat 58.001-58.004). It's beyond the 80m switch
        // radius from hole-2 tee, so we tighten the offset.
        // Fix at (12.0, 58.0005) is ~56m north — outside tee polygon, outside fairway, within 80m of tee.
        let bundle = try makeTwoHoleBundle()
        let fix = GeoCoordinate2D(lon: 12.0, lat: 58.0005)
        XCTAssertEqual(HoleDetector.activeHole(fix: fix, bundle: bundle, current: nil), 2)
    }

    func testFixFarFromEverythingReturnsNil() throws {
        let bundle = try makeTwoHoleBundle()
        let fix = GeoCoordinate2D(lon: 50.0, lat: 50.0)
        XCTAssertNil(HoleDetector.activeHole(fix: fix, bundle: bundle, current: nil))
    }

    // MARK: - Hysteresis

    func testHysteresisRefusesToFlipBeforeFiveConsecutiveMisses() throws {
        let bundle = try makeTwoHoleBundle()
        // Fix is inside hole 2's fairway, but we're "currently" on hole 1.
        let fix = GeoCoordinate2D(lon: 12.0025, lat: 58.0025)

        let belowThreshold = HoleDetector.activeHole(
            fix: fix,
            bundle: bundle,
            current: 1,
            consecutiveMisses: HoleDetector.missesRequiredToSwitch - 1
        )
        XCTAssertEqual(belowThreshold, 1, "Should stick to current hole until streak reaches threshold")

        let atThreshold = HoleDetector.activeHole(
            fix: fix,
            bundle: bundle,
            current: 1,
            consecutiveMisses: HoleDetector.missesRequiredToSwitch
        )
        XCTAssertEqual(atThreshold, 2, "Once threshold is reached, should switch to detected hole")
    }

    func testHysteresisDoesNotInterfereWhenBestGuessMatchesCurrent() throws {
        let bundle = try makeTwoHoleBundle()
        // Fix on hole 1 with current=1. Even a long streak shouldn't change anything.
        let fix = GeoCoordinate2D(lon: 11.0025, lat: 57.0025)
        let result = HoleDetector.activeHole(fix: fix, bundle: bundle, current: 1, consecutiveMisses: 99)
        XCTAssertEqual(result, 1)
    }

    // MARK: - fixIsBeyondSwitchRadius (streak-counter input)

    func testFixInsideFeaturePolygonIsNotBeyondRadius() throws {
        let bundle = try makeTwoHoleBundle()
        let hole1 = bundle.holes.first { $0.holeNumber == 1 }!
        let fix = GeoCoordinate2D(lon: 11.0025, lat: 57.0025) // inside fairway
        XCTAssertFalse(HoleDetector.fixIsBeyondSwitchRadius(fix: fix, of: hole1))
    }

    func testFixOnFarSideOfCourseIsBeyondRadius() throws {
        let bundle = try makeTwoHoleBundle()
        let hole1 = bundle.holes.first { $0.holeNumber == 1 }!
        let fix = GeoCoordinate2D(lon: 12.0, lat: 58.0) // hole 2 territory, ~150 km from hole 1
        XCTAssertTrue(HoleDetector.fixIsBeyondSwitchRadius(fix: fix, of: hole1))
    }

    // MARK: - Tiebreaker

    func testWhenFixIsInsideTwoHolesTheFartherGreenWins() throws {
        // Build two holes whose fairway polygons overlap. The fix lies in both
        // fairways; tiebreaker says we pick the hole whose green is farther
        // away (the one we're about to play, not the one we just finished).
        let hole1 = TestBundleBuilders.makeHoleJSON(
            holeNumber: 1,
            teeLonLat: [11.0, 57.0],
            greenLonLat: [11.001, 57.0], // close green
            features: [
                ("fairway", TestBundleBuilders.square(centeredAt: [11.0, 57.0], halfSizeDeg: 0.001)),
            ]
        )
        let hole2 = TestBundleBuilders.makeHoleJSON(
            holeNumber: 2,
            teeLonLat: [11.0, 57.0],
            greenLonLat: [11.01, 57.0], // far green (about to play)
            features: [
                ("fairway", TestBundleBuilders.square(centeredAt: [11.0, 57.0], halfSizeDeg: 0.001)),
            ]
        )
        let bundle = try TestBundleBuilders.makeBundle(holeJSONFragments: [hole1, hole2])

        let fix = GeoCoordinate2D(lon: 11.0, lat: 57.0)
        XCTAssertEqual(HoleDetector.activeHole(fix: fix, bundle: bundle, current: nil), 2)
    }
}
