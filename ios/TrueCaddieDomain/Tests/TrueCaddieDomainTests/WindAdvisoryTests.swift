import Foundation
import XCTest
@testable import TrueCaddieDomain

final class WindAdvisoryTests: XCTestCase {

    func testAdvisoryEquatableRoundTrips() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let a = WindAdvisory(directionDegFromNorth: 270, speedMps: 5, fetchedAt: now)
        let b = WindAdvisory(directionDegFromNorth: 270, speedMps: 5, fetchedAt: now)
        XCTAssertEqual(a, b)
    }

    func testAdvisoryDistinguishesDifferentFields() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let baseline = WindAdvisory(directionDegFromNorth: 90, speedMps: 5, fetchedAt: now)
        XCTAssertNotEqual(baseline, WindAdvisory(directionDegFromNorth: 91, speedMps: 5, fetchedAt: now))
        XCTAssertNotEqual(baseline, WindAdvisory(directionDegFromNorth: 90, speedMps: 6, fetchedAt: now))
        XCTAssertNotEqual(baseline, WindAdvisory(directionDegFromNorth: 90, speedMps: 5, fetchedAt: now.addingTimeInterval(1)))
    }

    func testAdvisoryAcceptsDueNorthAndJustUnderNorthValues() {
        // No normalization is performed at construction time — callers feed
        // values already in [0, 360). Verifies the type accepts both extremes
        // without crashing or rejecting.
        let dueNorth = WindAdvisory(directionDegFromNorth: 0, speedMps: 5, fetchedAt: Date())
        XCTAssertEqual(dueNorth.directionDegFromNorth, 0)

        let almostFullCircle = WindAdvisory(directionDegFromNorth: 359.9, speedMps: 5, fetchedAt: Date())
        XCTAssertEqual(almostFullCircle.directionDegFromNorth, 359.9, accuracy: 0.001)
    }

    @MainActor
    func testWindProvidingProtocolIsConformable() {
        // Spot-check that the protocol's surface is usable by writing a
        // trivial in-test conformer. If a missing requirement creeps in, this
        // fails to compile. @MainActor because WindProviding is MainActor-bound.
        final class TestConformer: WindProviding {
            var onAdvisory: ((WindAdvisory) -> Void)?
            var onError: ((WindProvidingError) -> Void)?
            func setLocation(_ coordinate: GeoCoordinate2D) {}
            func refresh() {}
        }

        let conformer = TestConformer()
        XCTAssertNil(conformer.onAdvisory)
        XCTAssertNil(conformer.onError)
    }
}
