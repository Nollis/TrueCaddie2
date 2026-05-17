import Foundation
import TrueCaddieDomain

/// Loads the bundled pilot course (currently Kungsbacka Nya) from the app
/// bundle. The realtime/voice runtime and the GPS layer treat this as the
/// canonical source of course geometry.
enum HostCourseBundleStore {
    static func loadKungsbackaNya(bundle: Bundle = .main) throws -> CourseBundle {
        guard let url = bundle.url(forResource: "kungsbacka-nya.v1", withExtension: "json") else {
            throw HostCourseBundleStoreError.missingBundledCourse("kungsbacka-nya.v1.json")
        }

        let data = try Data(contentsOf: url)
        return try CourseBundleLoader().load(data: data)
    }
}

enum HostCourseBundleStoreError: Error, Equatable {
    case missingBundledCourse(String)
}
