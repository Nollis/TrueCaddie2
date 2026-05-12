import Foundation
import TrueCaddieDomain

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
