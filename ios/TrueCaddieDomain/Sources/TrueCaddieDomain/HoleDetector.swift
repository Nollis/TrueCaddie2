import Foundation

/// Decides which hole a player is on, given a GPS fix and the course bundle.
///
/// Algorithm: polygon containment first (the player is inside `fairway`,
/// `green`, `tee`, or `bunker` of some hole); fall back to the nearest tee
/// within ``GolfGeometry/Constants/holeSwitchOuterRadiusM``. Hysteresis is the
/// caller's responsibility: pass `consecutiveMisses` so the detector can
/// refuse to flip away from `current` until the player has been clearly
/// outside the current hole for several consecutive fixes.
public enum HoleDetector {

    /// Number of consecutive "misses" (fixes outside the current hole and
    /// farther than the switch radius) required before auto-detection is
    /// allowed to flip the active hole.
    public static let missesRequiredToSwitch: Int = 5

    /// Returns the hole number the player is most likely on, or `nil` when
    /// even the fallback finds nothing within range.
    ///
    /// - Parameters:
    ///   - fix: The current GPS coordinate.
    ///   - bundle: The course bundle.
    ///   - current: The currently selected hole, if any.
    ///   - consecutiveMisses: How many consecutive fixes have been outside
    ///     every feature of `current` by more than the switch radius. Ignored
    ///     when `current` is nil. Default 0 means "first read, no hysteresis".
    public static func activeHole(
        fix: GeoCoordinate2D,
        bundle: CourseBundle,
        current: Int?,
        consecutiveMisses: Int = 0
    ) -> Int? {
        let bestGuess = bestGuessHole(fix: fix, bundle: bundle)

        guard let currentHole = current else { return bestGuess }
        if bestGuess == currentHole { return currentHole }
        return consecutiveMisses >= missesRequiredToSwitch ? bestGuess : currentHole
    }

    /// Returns true when the fix is outside every relevant feature of the
    /// hole AND farther than ``GolfGeometry/Constants/holeSwitchOuterRadiusM``
    /// from every feature centroid and every tee of the hole. Callers use
    /// this to increment the streak counter used by ``activeHole(...)``.
    public static func fixIsBeyondSwitchRadius(
        fix: GeoCoordinate2D,
        of hole: CourseHole
    ) -> Bool {
        if pointInRelevantFeature(fix: fix, hole: hole) { return false }

        for tee in hole.tees {
            guard let teeCoord = GeoCoordinate2D(lonLatPair: tee.teeCoordinate) else { continue }
            if GolfGeometry.haversineDistance(fix, teeCoord) <= GolfGeometry.Constants.holeSwitchOuterRadiusM {
                return false
            }
        }

        if let greenCoord = GeoCoordinate2D(lonLatPair: hole.baseMappingData.green.center),
           GolfGeometry.haversineDistance(fix, greenCoord) <= GolfGeometry.Constants.holeSwitchOuterRadiusM {
            return false
        }

        return true
    }

    // MARK: - Private

    /// Considered "relevant" for containment: fairway, green, tee, and bunker.
    /// Water and woods are deliberately excluded — landing in a pond is a
    /// strong signal you're on the right hole, but we already get that signal
    /// from the surrounding fairway polygons; including water would make the
    /// detector cling to a hole when a player wades through a hazard between
    /// holes.
    private static let containmentFeatureTypes: Set<String> = ["fairway", "green", "tee", "bunker"]

    private static func bestGuessHole(fix: GeoCoordinate2D, bundle: CourseBundle) -> Int? {
        var containing: [(holeNumber: Int, greenDistance: Double)] = []

        for hole in bundle.holes where pointInRelevantFeature(fix: fix, hole: hole) {
            let greenDistance: Double
            if let greenCoord = GeoCoordinate2D(lonLatPair: hole.baseMappingData.green.center) {
                greenDistance = GolfGeometry.haversineDistance(fix, greenCoord)
            } else {
                greenDistance = .infinity
            }
            containing.append((hole.holeNumber, greenDistance))
        }

        if !containing.isEmpty {
            // Tiebreaker: the hole whose green is farther from the player is
            // the one they're about to play (not the one they just finished).
            return containing.max(by: { $0.greenDistance < $1.greenDistance })?.holeNumber
        }

        // Fallback: closest tee within the switch radius.
        var closest: (holeNumber: Int, distance: Double)?
        for hole in bundle.holes {
            for tee in hole.tees {
                guard let teeCoord = GeoCoordinate2D(lonLatPair: tee.teeCoordinate) else { continue }
                let distance = GolfGeometry.haversineDistance(fix, teeCoord)
                guard distance <= GolfGeometry.Constants.holeSwitchOuterRadiusM else { continue }
                if closest == nil || distance < closest!.distance {
                    closest = (hole.holeNumber, distance)
                }
            }
        }
        return closest?.holeNumber
    }

    private static func pointInRelevantFeature(fix: GeoCoordinate2D, hole: CourseHole) -> Bool {
        for feature in hole.baseMappingData.features where containmentFeatureTypes.contains(feature.featureType) {
            for ring in GolfGeometry.extractOuterRings(from: feature.geometry) {
                if GolfGeometry.pointInPolygon(fix, ring: ring) {
                    return true
                }
            }
        }
        return false
    }
}
