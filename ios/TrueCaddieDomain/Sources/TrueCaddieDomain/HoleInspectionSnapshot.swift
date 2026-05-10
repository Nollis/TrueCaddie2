import Foundation

public struct HoleInspectionSnapshot: Equatable, Sendable {
    public let courseId: String
    public let bundleVersion: String
    public let holeId: String
    public let holeNumber: Int
    public let par: Int
    public let teeCount: Int
    public let featureCount: Int
    public let qualityBand: String
    public let qualityNotes: [String]

    public init(bundle: CourseBundle, hole: CourseHole) {
        courseId = bundle.courseId
        bundleVersion = bundle.bundleVersion
        holeId = hole.holeId
        holeNumber = hole.holeNumber
        par = hole.par
        teeCount = hole.tees.count
        featureCount = hole.baseMappingData.features.count
        qualityBand = hole.qualityConfidence.holePublishConfidence
        qualityNotes = hole.qualityConfidence.notes
    }
}
