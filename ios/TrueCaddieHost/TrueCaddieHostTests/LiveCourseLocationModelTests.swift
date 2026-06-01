import Foundation
import Testing
import TrueCaddieDomain
@testable import TrueCaddieHost

@MainActor
struct LiveCourseLocationModelTests {

    @Test func emittingFixOnTeeReportsThatHoleAndDistanceToGreen() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: nil)
        model.start()

        // Hole 1 White tee coordinate from the bundle.
        let teeCoord = GeoCoordinate2D(lon: 11.986226141452791, lat: 57.49302015313067)
        provider.emit(coordinate: teeCoord)

        #expect(model.detectedHoleNumber == 1)
        // Straight-line tee to green center is ~432.6 m for hole 1 White.
        let distance = try #require(model.distanceToPinM)
        #expect(abs(distance - 432.6) < 2.0)
    }

    @Test func fixOnGreenInfersFairwayLie() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: nil)

        // Hole 1 green center.
        let greenCoord = GeoCoordinate2D(lon: 11.992440149, lat: 57.491023724)
        provider.emit(coordinate: greenCoord)

        #expect(model.detectedHoleNumber == 1)
        // No .green case in ShotLie; green polygons map to .fairway.
        #expect(model.inferredLie == .fairway)
    }

    @Test func authorizationChangesPropagate() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: nil)

        #expect(model.authorizationStatus == .authorizedWhenInUse)

        provider.setAuthorization(.denied)
        #expect(model.authorizationStatus == .denied)

        provider.setAuthorization(.authorizedWhenInUse)
        #expect(model.authorizationStatus == .authorizedWhenInUse)
    }

    @Test func lastFixIsPublishedEvenWhenAccuracyIsPoor() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: nil)

        // The model does not gate fixes by accuracy itself — that gate lives
        // at the capture seam. So a poor-accuracy fix should still surface
        // in lastFix so UI can render "GPS warming up".
        let coord = GeoCoordinate2D(lon: 11.986226141452791, lat: 57.49302015313067)
        provider.emit(coordinate: coord, accuracy: 50.0)

        let fix = try #require(model.lastFix)
        #expect(fix.horizontalAccuracyM == 50.0)
    }

    @Test func hysteresisRefusesToFlipBeforeFiveConsecutiveMisses() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        // "Currently on hole 1" — model uses this to track misses.
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: 1)

        // A coordinate clearly inside hole 2's footprint (and well outside hole 1's).
        let hole2Green = GeoCoordinate2D(lon: 11.997032761573793, lat: 57.488330174334116)

        // Four consecutive fixes outside hole 1 — should stick to hole 1.
        for _ in 1...4 {
            provider.emit(coordinate: hole2Green)
            #expect(model.detectedHoleNumber == 1, "Should stick to current hole before streak threshold")
        }

        // Fifth consecutive miss crosses the threshold — should flip.
        provider.emit(coordinate: hole2Green)
        #expect(model.detectedHoleNumber == 2)
    }

    @Test func returningToCurrentHoleResetsTheMissStreak() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: 1)

        let hole2Green = GeoCoordinate2D(lon: 11.997032761573793, lat: 57.488330174334116)
        let hole1Green = GeoCoordinate2D(lon: 11.992440149, lat: 57.491023724)

        // Build up 4 misses, then re-enter hole 1, then 4 more misses — must
        // not flip because the streak was reset.
        for _ in 1...4 { provider.emit(coordinate: hole2Green) }
        provider.emit(coordinate: hole1Green)
        #expect(model.detectedHoleNumber == 1)
        for _ in 1...4 { provider.emit(coordinate: hole2Green) }
        #expect(model.detectedHoleNumber == 1, "Streak reset by intervening hole-1 fix should prevent flip")
    }

    @Test func inProgressHoleLocksDetectionToCurrentHoleEvenNearAnotherHole() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: 1)
        model.automaticHoleSwitchingEnabled = false

        let hole9Green = GeoCoordinate2D(lon: 12.000505438540564, lat: 57.492985279137305)

        for _ in 1...8 {
            provider.emit(coordinate: hole9Green)
        }

        #expect(model.detectedHoleNumber == 1)
        let distance = try #require(model.distanceToPinM)
        #expect(distance > 300, "Distance should still be anchored to hole 1 rather than flipping to hole 9")
    }

    @Test func betweenHolesDetectionCanStillAdvanceAutomatically() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubLocationProvider()
        let model = LiveCourseLocationModel(provider: provider, bundle: bundle, currentHoleNumber: 1)
        model.automaticHoleSwitchingEnabled = true

        let hole2Green = GeoCoordinate2D(lon: 11.997032761573793, lat: 57.488330174334116)

        for _ in 1...HoleDetector.missesRequiredToSwitch {
            provider.emit(coordinate: hole2Green)
        }

        #expect(model.detectedHoleNumber == 2)
    }
}
