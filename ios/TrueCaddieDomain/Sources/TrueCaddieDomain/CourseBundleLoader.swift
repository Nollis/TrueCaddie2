import Foundation

public enum CourseBundleLoaderError: Error, Equatable {
    case unsupportedSchema(String)
    case emptyHoleSet
}

public struct CourseBundleLoader: Sendable {
    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load(data: Data) throws -> CourseBundle {
        let bundle = try decoder.decode(CourseBundle.self, from: data)

        guard bundle.schemaVersion == "v1" else {
            throw CourseBundleLoaderError.unsupportedSchema(bundle.schemaVersion)
        }

        guard !bundle.holes.isEmpty else {
            throw CourseBundleLoaderError.emptyHoleSet
        }

        return bundle
    }
}
