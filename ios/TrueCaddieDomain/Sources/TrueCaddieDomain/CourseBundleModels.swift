import Foundation

public struct CourseBundle: Decodable, Sendable {
    public let schemaVersion: String
    public let bundleVersion: String
    public let courseId: String
    public let courseName: String
    public let publishedAt: Date
    public let provenance: Provenance
    public let holes: [CourseHole]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case bundleVersion = "bundle_version"
        case courseId = "course_id"
        case courseName = "course_name"
        case publishedAt = "published_at"
        case provenance
        case holes
    }
}

public struct CourseHole: Decodable, Identifiable, Sendable {
    public let holeId: String
    public let holeNumber: Int
    public let par: Int
    public let defaultPlayDirection: [String: JSONValue]?
    public let tees: [Tee]
    public let baseMappingData: BaseMappingData
    public let strategyOverlays: StrategyOverlays
    public let qualityConfidence: QualityConfidence
    public let provenance: Provenance

    public var id: String { holeId }

    private enum CodingKeys: String, CodingKey {
        case holeId = "hole_id"
        case holeNumber = "hole_number"
        case par
        case defaultPlayDirection = "default_play_direction"
        case tees
        case baseMappingData = "base_mapping_data"
        case strategyOverlays = "strategy_overlays"
        case qualityConfidence = "quality_confidence"
        case provenance
    }
}

public struct Tee: Decodable, Identifiable, Sendable {
    public let teeSetId: String
    public let name: String
    public let teeCoordinate: [Double]
    public let teeLengthM: Double
    public let isDefault: Bool?

    public var id: String { teeSetId }

    private enum CodingKeys: String, CodingKey {
        case teeSetId = "tee_set_id"
        case name
        case teeCoordinate = "tee_coordinate"
        case teeLengthM = "tee_length_m"
        case isDefault = "is_default"
    }
}

public struct BaseMappingData: Decodable, Sendable {
    public let centerline: GeoJSONGeometry
    public let green: GreenReference
    public let features: [CourseFeature]
    public let outOfBoundsLines: [GeoJSONFeature]
    public let contextPoints: [GeoJSONFeature]

    private enum CodingKeys: String, CodingKey {
        case centerline
        case green
        case features
        case outOfBoundsLines = "out_of_bounds_lines"
        case contextPoints = "context_points"
    }
}

public struct GreenReference: Decodable, Sendable {
    public let center: [Double]
    public let frontCenter: [Double]?
    public let backCenter: [Double]?
    public let centerElevationM: Double?
    public let frontElevationM: Double?
    public let backElevationM: Double?
    public let polygonFeatureId: String?

    private enum CodingKeys: String, CodingKey {
        case center
        case frontCenter = "front_center"
        case backCenter = "back_center"
        case centerElevationM = "center_elevation_m"
        case frontElevationM = "front_elevation_m"
        case backElevationM = "back_elevation_m"
        case polygonFeatureId = "polygon_feature_id"
    }
}

public struct CourseFeature: Decodable, Identifiable, Sendable {
    public let featureId: String
    public let featureType: String
    public let hazardKind: String?
    public let geometry: GeoJSONGeometry
    public let properties: [String: JSONValue]

    public var id: String { featureId }

    private enum CodingKeys: String, CodingKey {
        case featureId = "feature_id"
        case featureType = "feature_type"
        case hazardKind = "hazard_kind"
        case geometry
        case properties
    }
}

public struct StrategyOverlays: Decodable, Sendable {
    public let teeTargetCorridors: [JSONValue]
    public let aggressiveTeeCorridors: [JSONValue]
    public let layupCandidates: [JSONValue]
    public let preferredMiss: [JSONValue]
    public let hazardSeverity: [JSONValue]

    private enum CodingKeys: String, CodingKey {
        case teeTargetCorridors = "tee_target_corridors"
        case aggressiveTeeCorridors = "aggressive_tee_corridors"
        case layupCandidates = "layup_candidates"
        case preferredMiss = "preferred_miss"
        case hazardSeverity = "hazard_severity"
    }
}

public struct QualityConfidence: Decodable, Sendable {
    public let holePublishConfidence: String
    public let holePublishScore: Double
    public let overlayScores: [String: Double]?
    public let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case holePublishConfidence = "hole_publish_confidence"
        case holePublishScore = "hole_publish_score"
        case overlayScores = "overlay_scores"
        case notes
    }
}

public struct Provenance: Decodable, Sendable {
    public let sourceSystem: String
    public let sourcePath: String?
    public let sourceFile: String?
    public let sourceUpdatedAt: String?
    public let derivationVersion: String

    private enum CodingKeys: String, CodingKey {
        case sourceSystem = "source_system"
        case sourcePath = "source_path"
        case sourceFile = "source_file"
        case sourceUpdatedAt = "source_updated_at"
        case derivationVersion = "derivation_version"
    }
}

public struct GeoJSONFeature: Decodable, Sendable {
    public let type: String
    public let id: String?
    public let geometry: GeoJSONGeometry?
    public let properties: [String: JSONValue]?
}

public struct GeoJSONGeometry: Decodable, Sendable {
    public let type: String
    public let coordinates: JSONValue
}

public enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}

public extension JSONValue {
    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }

        return value
    }

    var numberValue: Double? {
        guard case let .number(value) = self else {
            return nil
        }

        return value
    }

    var boolValue: Bool? {
        guard case let .bool(value) = self else {
            return nil
        }

        return value
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else {
            return nil
        }

        return value
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else {
            return nil
        }

        return value
    }
}
