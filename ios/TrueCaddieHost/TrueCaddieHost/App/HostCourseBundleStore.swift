import Foundation
import TrueCaddieDomain

// MARK: - Course Descriptor

/// Lightweight catalog entry for a bundled course.  Contains only the
/// metadata needed to display a course picker and rank courses by GPS
/// proximity — the full `CourseBundle` is loaded lazily when the player
/// taps **Start Round**.
struct CourseDescriptor: Identifiable, Equatable {
    /// Matches `CourseBundle.courseId` so the two can be correlated.
    let id: String
    let name: String
    /// Name of the JSON resource in the app bundle (without extension).
    let bundleResourceName: String
    /// Representative coordinate used for GPS proximity ranking.
    /// Hard-coded at authoring time from the default tee on hole 1.
    /// GeoJSON coordinate order: longitude first, then latitude.
    let centerCoordinate: GeoCoordinate2D
}

// MARK: - Store

/// Loads bundled course resources and exposes the multi-course registry.
enum HostCourseBundleStore {

    // MARK: Registry

    /// All courses available in this build.  Extend this array to add more
    /// bundled courses; no other code change is required.
    static let availableCourses: [CourseDescriptor] = [
        CourseDescriptor(
            id: "kungsbacka-nya",
            name: "Kungsbacka Nya",
            bundleResourceName: "kungsbacka-nya.v1",
            // Default (white) tee on hole 1 — lon/lat, WGS-84.
            centerCoordinate: GeoCoordinate2D(lon: 11.986226141452791, lat: 57.49302015313067)
        )
    ]

    // MARK: Loading

    /// Load the `CourseBundle` identified by `descriptor`.
    static func load(_ descriptor: CourseDescriptor, bundle: Bundle = .main) throws -> CourseBundle {
        guard let url = bundle.url(forResource: descriptor.bundleResourceName, withExtension: "json") else {
            throw HostCourseBundleStoreError.missingBundledCourse("\(descriptor.bundleResourceName).json")
        }
        let data = try Data(contentsOf: url)
        return try CourseBundleLoader().load(data: data)
    }

    /// Convenience shim kept for source compatibility during migration.
    /// Prefer ``load(_:bundle:)`` with an entry from ``availableCourses``.
    static func loadKungsbackaNya(bundle: Bundle = .main) throws -> CourseBundle {
        guard let descriptor = availableCourses.first(where: { $0.id == "kungsbacka-nya" }) else {
            throw HostCourseBundleStoreError.missingBundledCourse("kungsbacka-nya.v1.json")
        }
        return try load(descriptor, bundle: bundle)
    }
}

enum HostCourseBundleStoreError: Error, Equatable {
    case missingBundledCourse(String)
}
