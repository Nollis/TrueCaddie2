import Foundation

/// Infers a ``ShotLie`` from a GPS fix and a course hole's feature polygons.
///
/// Precedence (highest wins): `bunker` → `water` → `green` → `fairway` → rough.
///
/// The existing ``ShotLie`` enum has no `.green` case, so green polygons map
/// to `.fairway` — landing on the green is treated as an approach lie for the
/// recommendation engine. Tee lies are intentionally never returned here; the
/// caller forces ``ShotLie/tee`` on the first shot of a hole.
public enum LieInference {

    public static func lie(at coord: GeoCoordinate2D, in hole: CourseHole) -> ShotLie {
        var hits: Set<String> = []
        for feature in hole.baseMappingData.features {
            for ring in GolfGeometry.extractOuterRings(from: feature.geometry) {
                if GolfGeometry.pointInPolygon(coord, ring: ring) {
                    hits.insert(feature.featureType)
                    break
                }
            }
        }

        if hits.contains("bunker") { return .bunker }
        if hits.contains("water") { return .recovery }
        if hits.contains("green") { return .fairway }
        if hits.contains("fairway") { return .fairway }
        return .rough
    }
}
