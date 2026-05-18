import Foundation
import Testing
import TrueCaddieDomain
@testable import TrueCaddieHost

@MainActor
struct LiveWindModelTests {

    // Reference bearings for the Kungsbacka bundle (White tees):
    //   Hole 6 -> ~92° (nearly due east)
    //   Hole 3 -> ~255° (nearly due west)
    // Same absolute wind direction maps to opposite categories on these
    // two holes, which is what makes them useful for the "change hole
    // recomputes windContext" tests below.

    @Test func windFromAheadOnEastFacingHoleIsHurting() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole6 = try #require(bundle.holes.first(where: { $0.holeNumber == 6 }))
        model.setCurrentHole(hole6, teeSetId: "white")

        // Wind from 90° = wind coming from due east, blowing west. Hole 6's
        // shot points roughly east — that's a headwind.
        provider.emit(directionDegFromNorth: 90, speedMps: 5)

        let context = try #require(model.windContext)
        #expect(context.relativeDirection == .hurting)
        #expect(context.speedMps == 5)
    }

    @Test func sameWindOnWestFacingHoleIsHelping() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole3 = try #require(bundle.holes.first(where: { $0.holeNumber == 3 }))
        model.setCurrentHole(hole3, teeSetId: "white")

        // Same 90° wind on a shot pointing west — that's a tailwind.
        provider.emit(directionDegFromNorth: 90, speedMps: 5)

        let context = try #require(model.windContext)
        #expect(context.relativeDirection == .helping)
        #expect(context.speedMps == 5)
    }

    @Test func changingHoleRecomputesWindContextWithoutRefetch() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole6 = try #require(bundle.holes.first(where: { $0.holeNumber == 6 }))
        let hole3 = try #require(bundle.holes.first(where: { $0.holeNumber == 3 }))

        model.setCurrentHole(hole6, teeSetId: "white")
        provider.emit(directionDegFromNorth: 90, speedMps: 5)
        #expect(model.windContext?.relativeDirection == .hurting)

        // Switch holes — no fresh emit. Same advisory should reinterpret
        // against hole-3 bearing.
        model.setCurrentHole(hole3, teeSetId: "white")
        #expect(model.windContext?.relativeDirection == .helping)
    }

    @Test func holeChangeWithNoAdvisoryYetLeavesContextNil() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole = try #require(bundle.holes.first)
        model.setCurrentHole(hole, teeSetId: "white")

        #expect(model.windContext == nil)
        #expect(model.advisory == nil)
    }

    @Test func errorAfterGoodFetchPreservesLastKnownWind() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 6 }))
        model.setCurrentHole(hole, teeSetId: "white")
        provider.emit(directionDegFromNorth: 90, speedMps: 5)

        let goodAdvisory = try #require(model.advisory)
        let goodContext = try #require(model.windContext)

        provider.emitError(.network("offline"))

        #expect(model.advisory == goodAdvisory, "Last good advisory should persist across errors")
        #expect(model.windContext == goodContext)
        #expect(model.lastFetchError == .network("offline"))
    }

    @Test func successfulFetchClearsPriorError() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 6 }))
        model.setCurrentHole(hole, teeSetId: "white")

        provider.emitError(.network("offline"))
        #expect(model.lastFetchError == .network("offline"))

        provider.emit(directionDegFromNorth: 90, speedMps: 5)
        #expect(model.lastFetchError == nil)
    }

    @Test func identicalAdvisoryDoesNotChurnPublisher() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 6 }))
        model.setCurrentHole(hole, teeSetId: "white")

        provider.emit(directionDegFromNorth: 90, speedMps: 5)
        let firstFetchTimestamp = try #require(model.advisory?.fetchedAt)

        // Emit the same wind values (different timestamp). The model should
        // skip republishing, so `advisory.fetchedAt` stays at the original.
        provider.emit(directionDegFromNorth: 90, speedMps: 5, at: firstFetchTimestamp.addingTimeInterval(10))
        #expect(model.advisory?.fetchedAt == firstFetchTimestamp)
    }

    @Test func setLocationForwardsToProviderAndTriggersRefresh() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let coord = GeoCoordinate2D(lon: 11.986226141452791, lat: 57.49302015313067)
        model.setLocation(coord)

        #expect(provider.currentLocation == coord)
    }

    @Test func teeSelectionFallsBackToDefaultThenFirstTee() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let provider = StubWindProvider()
        let model = LiveWindModel(provider: provider, bundle: bundle)

        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 6 }))
        // Pass a tee set ID that doesn't exist on this hole — fallback to
        // default then first.
        model.setCurrentHole(hole, teeSetId: "nonexistent-tee-set")
        provider.emit(directionDegFromNorth: 90, speedMps: 5)

        // The exact category isn't the point — just that we got A category,
        // i.e. the fallback actually found a tee coordinate.
        #expect(model.windContext != nil)
    }
}
