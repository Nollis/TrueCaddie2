import Foundation

/// A WGS84 coordinate stored as decimal-degree longitude and latitude.
///
/// Course bundle JSON stores coordinates as `[lon, lat]` arrays (GeoJSON
/// convention). The `init(lonLatPair:)` factory is the only sanctioned way to
/// turn one of those arrays into a coordinate — it prevents accidental lat/lng
/// swaps in math code that operates on this type.
public struct GeoCoordinate2D: Equatable, Hashable, Sendable {
    public let lon: Double
    public let lat: Double

    public init(lon: Double, lat: Double) {
        self.lon = lon
        self.lat = lat
    }

    public init?(lonLatPair pair: [Double]) {
        guard pair.count >= 2 else { return nil }
        self.lon = pair[0]
        self.lat = pair[1]
    }
}

/// A position fix from a location provider. Platform-free so the domain can
/// reason about fixes without importing CoreLocation.
public struct LocationFix: Equatable, Sendable {
    public let coordinate: GeoCoordinate2D
    public let horizontalAccuracyM: Double
    public let timestamp: Date

    public init(coordinate: GeoCoordinate2D, horizontalAccuracyM: Double, timestamp: Date) {
        self.coordinate = coordinate
        self.horizontalAccuracyM = horizontalAccuracyM
        self.timestamp = timestamp
    }
}

/// Pure geometry utilities for golf-hole-scale work: great-circle distance,
/// point-in-polygon containment, and GeoJSON polygon extraction. No platform
/// imports, no I/O — safe to use from any module.
public enum GolfGeometry {

    public enum Constants {
        /// Maximum acceptable horizontal accuracy (in meters) for a GPS fix to
        /// be used to close out a shot. Fixes worse than this are still
        /// surfaced to UI (so the player sees "GPS warming up"), but capture
        /// refuses to mutate round state.
        public static let minimumAcceptableAccuracyM: Double = 15.0

        /// Distance (in meters) the player must be from any feature of their
        /// current hole before auto-hole-detection is even considered.
        /// Combined with the consecutive-miss streak in `HoleDetector`, this
        /// produces a conservative hysteresis that avoids mid-shot flips.
        public static let holeSwitchOuterRadiusM: Double = 80.0

        /// Half-width (in degrees) of the helping and hurting bands when
        /// mapping continuous wind direction onto the three
        /// ``WindRelativeDirection`` categories. With 45° bands, a wind
        /// 0–45° off the shot axis counts as hurting (or helping), and
        /// anything beyond is `.cross`.
        public static let windHelpingHurtingBandDeg: Double = 45.0
    }

    /// Earth radius used by the haversine formula. WGS84 mean radius.
    private static let earthRadiusM: Double = 6_371_000.0

    /// Great-circle distance in meters between two points. Accurate to a few
    /// centimeters at golf-hole scale.
    public static func haversineDistance(_ a: GeoCoordinate2D, _ b: GeoCoordinate2D) -> Double {
        let lat1 = a.lat.radians
        let lat2 = b.lat.radians
        let dLat = (b.lat - a.lat).radians
        let dLon = (b.lon - a.lon).radians

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusM * asin(min(1.0, sqrt(h)))
    }

    /// Initial great-circle bearing in degrees clockwise from north
    /// (0 = due north, 90 = due east), normalized to `[0, 360)`. Returns 0
    /// when `from` and `to` coincide. Accurate at hole scale and immune to
    /// any pole / antimeridian concerns since golf courses don't span them.
    public static func bearingDeg(from a: GeoCoordinate2D, to b: GeoCoordinate2D) -> Double {
        let lat1 = a.lat.radians
        let lat2 = b.lat.radians
        let dLon = (b.lon - a.lon).radians

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        // atan2 returns radians in (-π, π]; convert and wrap into [0, 360).
        let degrees = atan2(y, x) * 180.0 / .pi
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }

    /// Returns true if `coord` lies inside (or exactly on an edge of) the
    /// closed polygon described by `ring`. Uses ray casting on a local
    /// equirectangular projection — accurate at hole scale and immune to
    /// antimeridian / pole concerns since golf courses don't span them.
    ///
    /// `ring` is expected to be a closed loop (first point equal to last);
    /// open rings work too because the algorithm wraps automatically.
    public static func pointInPolygon(_ coord: GeoCoordinate2D, ring: [GeoCoordinate2D]) -> Bool {
        guard ring.count >= 3 else { return false }

        // Project into local meters using the ring's reference latitude. This
        // collapses degree-distance asymmetry (lon-degrees shrink with
        // latitude) into a flat plane where ray casting is straightforward.
        let referenceLatRad = ring[0].lat.radians
        let cosRef = cos(referenceLatRad)

        func project(_ c: GeoCoordinate2D) -> (x: Double, y: Double) {
            ((c.lon - ring[0].lon) * cosRef, c.lat - ring[0].lat)
        }

        let target = project(coord)
        let projected = ring.map(project)

        var inside = false
        let count = projected.count
        var j = count - 1
        for i in 0..<count {
            let xi = projected[i].x, yi = projected[i].y
            let xj = projected[j].x, yj = projected[j].y

            // Treat a coordinate that coincides with a vertex as inside.
            if xi == target.x && yi == target.y {
                return true
            }

            // Standard ray-cast on the projected plane.
            let intersects = ((yi > target.y) != (yj > target.y))
                && (target.x < (xj - xi) * (target.y - yi) / (yj - yi) + xi)
            if intersects {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Returns the outer rings of a GeoJSON geometry. Supports `Polygon` and
    /// `MultiPolygon`; returns an empty array for any other type. Inner rings
    /// (holes) are intentionally ignored — golf-course features rarely have
    /// them and the dispersion-foundation pass does not need polygon-with-hole
    /// support.
    public static func extractOuterRings(from geometry: GeoJSONGeometry) -> [[GeoCoordinate2D]] {
        switch geometry.type {
        case "Polygon":
            // Coordinates: [ring0, ring1, ...] where ring0 is the outer ring.
            guard let rings = geometry.coordinates.arrayValue,
                  let outer = rings.first else { return [] }
            return [ring(from: outer)].compactMap { $0 }

        case "MultiPolygon":
            // Coordinates: [polygon0, polygon1, ...] where each polygon is
            // [outerRing, hole0, hole1, ...].
            guard let polygons = geometry.coordinates.arrayValue else { return [] }
            return polygons.compactMap { polygonValue in
                polygonValue.arrayValue?.first.flatMap(ring(from:))
            }

        default:
            return []
        }
    }

    // MARK: - Private

    private static func ring(from value: JSONValue) -> [GeoCoordinate2D]? {
        guard let coords = value.arrayValue else { return nil }
        let points: [GeoCoordinate2D] = coords.compactMap { point in
            guard let pair = point.arrayValue else { return nil }
            let numbers = pair.compactMap { $0.numberValue }
            return GeoCoordinate2D(lonLatPair: numbers)
        }
        return points.isEmpty ? nil : points
    }
}

private extension Double {
    var radians: Double { self * .pi / 180.0 }
}
