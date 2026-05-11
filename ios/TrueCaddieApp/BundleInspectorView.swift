import SwiftUI
import TrueCaddieDomain

struct BundleInspectorView: View {
    let bundle: CourseBundle

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bundle.courseName)
                            .font(.headline)
                        Text(bundle.bundleVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Holes") {
                    ForEach(bundle.holes) { hole in
                        NavigationLink {
                            HoleInspectorDetail(
                                snapshot: HoleInspectionSnapshot(bundle: bundle, hole: hole),
                                hole: hole
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "flag")
                                    .foregroundStyle(.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hole \(hole.holeNumber)")
                                        .fontWeight(.medium)
                                    Text(hole.qualityConfidence.holePublishConfidence.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("Par \(hole.par)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(bundle.courseId)
        }
    }
}

private struct HoleInspectorDetail: View {
    let snapshot: HoleInspectionSnapshot
    let hole: CourseHole

    private var hazardSeverityOverlays: [HazardSeveritySummary] {
        hole.strategyOverlays.hazardSeverity
            .compactMap(HazardSeveritySummary.init)
            .sorted { lhs, rhs in
                if lhs.severityScore == rhs.severityScore {
                    return lhs.hazardKind < rhs.hazardKind
                }

                return lhs.severityScore > rhs.severityScore
            }
    }

    var body: some View {
        List {
            Section("Hole Sketch") {
                HoleSketchView(hole: hole)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Bundle") {
                LabeledContent("Course", value: snapshot.courseId)
                LabeledContent("Version", value: snapshot.bundleVersion)
                LabeledContent("Quality", value: qualityLabel)
                LabeledContent("Published", value: hole.provenance.derivationVersion)
            }

            Section("Hole") {
                LabeledContent("Hole", value: "\(snapshot.holeNumber)")
                LabeledContent("Par", value: "\(snapshot.par)")
                LabeledContent("Tees", value: "\(snapshot.teeCount)")
                LabeledContent("Features", value: "\(snapshot.featureCount)")
                if let bearing = defaultBearingText {
                    LabeledContent("Direction", value: bearing)
                }
            }

            Section("Green") {
                LabeledContent("Center", value: coordinateText(hole.baseMappingData.green.center))

                if let frontCenter = hole.baseMappingData.green.frontCenter {
                    LabeledContent("Front", value: coordinateText(frontCenter))
                }

                if let backCenter = hole.baseMappingData.green.backCenter {
                    LabeledContent("Back", value: coordinateText(backCenter))
                }
            }

            Section("Tees") {
                ForEach(hole.tees) { tee in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tee.name)
                            if tee.isDefault == true {
                                Spacer()
                                Text("Default")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("\(Int(tee.teeLengthM)) m")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(coordinateText(tee.teeCoordinate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Hazard Severity") {
                if hazardSeverityOverlays.isEmpty {
                    Text("No derived hazard overlays yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hazardSeverityOverlays) { hazard in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(hazard.hazardKind.capitalized, systemImage: hazard.iconName)
                                    .font(.headline)

                                Spacer()

                                Text(hazard.severityLabel)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(hazard.bandColor.opacity(0.18), in: Capsule())
                                    .foregroundStyle(hazard.bandColor)
                            }

                            Text(hazard.primaryReason)
                                .font(.subheadline)

                            HStack(spacing: 12) {
                                Text("Score \(hazard.scoreText)")
                                Text(hazard.penaltyKind.replacingOccurrences(of: "_", with: " "))
                                if hazard.landingConflict {
                                    Text("Landing conflict")
                                }
                                if hazard.blocksRecovery {
                                    Text("Recovery blocker")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Feature Types") {
                ForEach(featureTypeCounts, id: \.name) { item in
                    LabeledContent(item.name, value: "\(item.count)")
                }
            }

            Section("Feature Highlights") {
                ForEach(featureHighlights, id: \.id) { feature in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .fontWeight(.medium)
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Overlay Containers") {
                LabeledContent("Tee Corridors", value: "\(hole.strategyOverlays.teeTargetCorridors.count)")
                LabeledContent("Aggressive Corridors", value: "\(hole.strategyOverlays.aggressiveTeeCorridors.count)")
                LabeledContent("Layup Candidates", value: "\(hole.strategyOverlays.layupCandidates.count)")
                LabeledContent("Preferred Miss", value: "\(hole.strategyOverlays.preferredMiss.count)")
                LabeledContent("Hazard Severity", value: "\(hole.strategyOverlays.hazardSeverity.count)")
            }

            Section("Quality Notes") {
                if snapshot.qualityNotes.isEmpty {
                    Text("No quality notes")
                } else {
                    ForEach(snapshot.qualityNotes, id: \.self) { note in
                        Text(note)
                    }
                }
            }

            Section("Provenance") {
                if let sourceFile = hole.provenance.sourceFile {
                    LabeledContent("Source File", value: sourceFile)
                }

                if let updatedAt = hole.provenance.sourceUpdatedAt {
                    LabeledContent("Updated", value: updatedAt)
                }
            }
        }
        .navigationTitle("Hole \(snapshot.holeNumber)")
    }

    private var featureTypeCounts: [(name: String, count: Int)] {
        Dictionary(grouping: hole.baseMappingData.features, by: \.featureType)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    private var featureHighlights: [FeatureHighlight] {
        hole.baseMappingData.features
            .prefix(8)
            .map { feature in
                let alongText = numericText(feature.properties["centerline_along_m"])
                let sideText = stringText(feature.properties["centerline_side"])
                let hazardText = feature.hazardKind ?? feature.featureType

                return FeatureHighlight(
                    id: feature.id,
                    title: feature.properties["name"]?.stringValue ?? feature.featureType.capitalized,
                    detail: "\(hazardText) • along \(alongText ?? "n/a") m • \(sideText ?? "unknown side")"
                )
            }
    }

    private var qualityLabel: String {
        let score = String(format: "%.2f", hole.qualityConfidence.holePublishScore)
        return "\(snapshot.qualityBand.capitalized) (\(score))"
    }

    private var defaultBearingText: String? {
        guard let bearing = hole.defaultPlayDirection?["bearingDeg"]?.numberValue else {
            return nil
        }

        return "\(format(number: bearing)) deg"
    }

    private func coordinateText(_ coordinate: [Double]) -> String {
        guard coordinate.count == 2 else {
            return "n/a"
        }

        return String(format: "%.5f, %.5f", coordinate[1], coordinate[0])
    }

    private func numericText(_ value: JSONValue?) -> String? {
        guard let number = value?.numberValue else {
            return nil
        }

        return format(number: number)
    }

    private func stringText(_ value: JSONValue?) -> String? {
        value?.stringValue
    }

    private func format(number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.2f", number)
    }
}

private struct HoleSketchView: View {
    let hole: CourseHole

    var body: some View {
        GeometryReader { proxy in
            let layout = HoleSketchLayout(hole: hole, size: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.95, blue: 0.91))

                Canvas { context, size in
                    for polygon in layout.polygons(for: "rough") {
                        context.fill(polygon, with: .color(Color(red: 0.85, green: 0.88, blue: 0.80)))
                    }

                    for polygon in layout.polygons(for: "woods") {
                        context.fill(polygon, with: .color(Color(red: 0.32, green: 0.45, blue: 0.30).opacity(0.34)))
                    }

                    for polygon in layout.polygons(for: "water") {
                        context.fill(polygon, with: .color(Color(red: 0.45, green: 0.66, blue: 0.87).opacity(0.8)))
                    }

                    for polygon in layout.polygons(for: "fairway") {
                        context.fill(polygon, with: .color(Color(red: 0.58, green: 0.78, blue: 0.49)))
                    }

                    for polygon in layout.polygons(for: "green") {
                        context.fill(polygon, with: .color(Color(red: 0.71, green: 0.87, blue: 0.52)))
                    }

                    for polygon in layout.polygons(for: "tee") {
                        context.fill(polygon, with: .color(Color(red: 0.77, green: 0.70, blue: 0.56)))
                    }

                    for polygon in layout.polygons(for: "bunker") {
                        context.fill(polygon, with: .color(Color(red: 0.89, green: 0.80, blue: 0.61)))
                    }

                    for line in layout.outOfBounds {
                        context.stroke(
                            Path { path in
                                path.addLines(line)
                            },
                            with: .color(.red),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                    }

                    if !layout.centerline.isEmpty {
                        context.stroke(
                            Path { path in
                                path.addLines(layout.centerline)
                            },
                            with: .color(.white.opacity(0.92)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                    }

                    for teePoint in layout.teePoints {
                        let rect = CGRect(x: teePoint.x - 4, y: teePoint.y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.8)))
                    }

                    if let greenCenter = layout.greenCenter {
                        let rect = CGRect(x: greenCenter.x - 5, y: greenCenter.y - 5, width: 10, height: 10)
                        context.fill(Path(ellipseIn: rect), with: .color(.white))
                        context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.25)), lineWidth: 1)
                    }
                }
                .padding(10)
            }
        }
        .frame(height: 240)
        .accessibilityLabel("Simplified hole sketch")
    }
}

private struct HazardSeveritySummary: Identifiable {
    let id: String
    let hazardKind: String
    let severityBand: String
    let severityScore: Double
    let penaltyKind: String
    let landingConflict: Bool
    let blocksRecovery: Bool
    let primaryReason: String

    init?(jsonValue: JSONValue) {
        guard
            let overlay = jsonValue.objectValue,
            let id = overlay["overlay_id"]?.stringValue,
            let properties = overlay["properties"]?.objectValue,
            let rationale = overlay["rationale"]?.objectValue,
            let hazardKind = properties["hazard_kind"]?.stringValue,
            let severityBand = properties["severity_band"]?.stringValue,
            let severityScore = properties["severity_score"]?.numberValue,
            let penaltyKind = properties["penalty_kind"]?.stringValue,
            let primaryReason = rationale["primary_reason"]?.stringValue
        else {
            return nil
        }

        self.id = id
        self.hazardKind = hazardKind
        self.severityBand = severityBand
        self.severityScore = severityScore
        self.penaltyKind = penaltyKind
        self.landingConflict = properties["landing_conflict"]?.boolValue ?? false
        self.blocksRecovery = properties["blocks_recovery"]?.boolValue ?? false
        self.primaryReason = primaryReason
    }

    var severityLabel: String {
        "\(severityBand.capitalized) \(scoreText)"
    }

    var scoreText: String {
        String(format: "%.2f", severityScore)
    }

    var bandColor: Color {
        switch severityBand {
        case "critical":
            return .red
        case "high":
            return .orange
        case "medium":
            return .yellow
        default:
            return .secondary
        }
    }

    var iconName: String {
        switch hazardKind {
        case "water":
            return "drop.fill"
        case "bunker":
            return "oval.bottomhalf.filled"
        case "woods":
            return "tree.fill"
        case "rough":
            return "leaf.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
}

private struct HoleSketchLayout {
    private let featuresByType: [String: [CourseFeature]]
    let centerline: [CGPoint]
    let outOfBounds: [[CGPoint]]
    let teePoints: [CGPoint]
    let greenCenter: CGPoint?
    private let bounds: CGRect
    private let drawingSize: CGSize

    init(hole: CourseHole, size: CGSize) {
        self.featuresByType = Dictionary(grouping: hole.baseMappingData.features, by: \.featureType)
        self.drawingSize = CGSize(width: max(size.width - 20, 1), height: max(size.height - 20, 1))

        var allCoordinates = [[Double]]()
        allCoordinates.append(contentsOf: Self.collectCoordinates(from: hole.baseMappingData.centerline))
        for feature in hole.baseMappingData.features {
            allCoordinates.append(contentsOf: Self.collectCoordinates(from: feature.geometry))
        }
        for line in hole.baseMappingData.outOfBoundsLines {
            if let geometry = line.geometry {
                allCoordinates.append(contentsOf: Self.collectCoordinates(from: geometry))
            }
        }
        allCoordinates.append(contentsOf: hole.tees.map(\.teeCoordinate))
        allCoordinates.append(hole.baseMappingData.green.center)
        if let point = hole.baseMappingData.green.frontCenter {
            allCoordinates.append(point)
        }
        if let point = hole.baseMappingData.green.backCenter {
            allCoordinates.append(point)
        }

        self.bounds = Self.makeBounds(from: allCoordinates, size: size)
        self.centerline = Self.linePoints(from: hole.baseMappingData.centerline, in: bounds, size: drawingSize)
        self.outOfBounds = hole.baseMappingData.outOfBoundsLines.compactMap { line in
            guard let geometry = line.geometry else {
                return nil
            }

            let points = Self.linePoints(from: geometry, in: bounds, size: drawingSize)
            return points.isEmpty ? nil : points
        }
        self.teePoints = hole.tees.map { Self.project($0.teeCoordinate, in: bounds, size: drawingSize) }
        self.greenCenter = Self.projectOptional(hole.baseMappingData.green.center, in: bounds, size: drawingSize)
    }

    func polygons(for featureType: String) -> [Path] {
        (featuresByType[featureType] ?? [])
            .flatMap { Self.polygonPaths(from: $0.geometry, in: bounds, size: drawingSize) }
    }

    private static func makeBounds(from coordinates: [[Double]], size: CGSize) -> CGRect {
        let valid = coordinates.filter { $0.count == 2 }
        let fallback = CGRect(x: 0, y: 0, width: max(size.width, 1), height: max(size.height, 1))

        guard
            let minLon = valid.map({ $0[0] }).min(),
            let maxLon = valid.map({ $0[0] }).max(),
            let minLat = valid.map({ $0[1] }).min(),
            let maxLat = valid.map({ $0[1] }).max()
        else {
            return fallback
        }

        let lonPadding = max((maxLon - minLon) * 0.12, 0.00012)
        let latPadding = max((maxLat - minLat) * 0.12, 0.00012)

        return CGRect(
            x: minLon - lonPadding,
            y: minLat - latPadding,
            width: max((maxLon - minLon) + lonPadding * 2, 0.0002),
            height: max((maxLat - minLat) + latPadding * 2, 0.0002)
        )
    }

    private static func collectCoordinates(from geometry: GeoJSONGeometry) -> [[Double]] {
        switch geometry.type {
        case "LineString":
            return coordinatePairs(from: geometry.coordinates)
        case "Polygon":
            return polygonRings(from: geometry.coordinates).flatMap { $0 }
        case "MultiPolygon":
            return multiPolygonRings(from: geometry.coordinates).flatMap { $0 }.flatMap { $0 }
        case "Point":
            return coordinatePairs(from: .array([geometry.coordinates])).flatMap { [$0] }
        default:
            return []
        }
    }

    private static func polygonPaths(from geometry: GeoJSONGeometry, in bounds: CGRect, size: CGSize) -> [Path] {
        switch geometry.type {
        case "Polygon":
            return polygonRings(from: geometry.coordinates).compactMap { ring in
                path(for: ring, in: bounds, size: size)
            }
        case "MultiPolygon":
            return multiPolygonRings(from: geometry.coordinates)
                .flatMap { polygon in
                    polygon.compactMap { ring in
                        path(for: ring, in: bounds, size: size)
                    }
                }
        default:
            return []
        }
    }

    private static func linePoints(from geometry: GeoJSONGeometry, in bounds: CGRect, size: CGSize) -> [CGPoint] {
        guard geometry.type == "LineString" else {
            return []
        }

        return coordinatePairs(from: geometry.coordinates).map { project($0, in: bounds, size: size) }
    }

    private static func path(for ring: [[Double]], in bounds: CGRect, size: CGSize) -> Path? {
        let points = ring
            .filter { $0.count == 2 }
            .map { project($0, in: bounds, size: size) }

        guard points.count >= 3 else {
            return nil
        }

        return Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }

    private static func coordinatePairs(from value: JSONValue) -> [[Double]] {
        value.arrayValue?.compactMap { point in
            guard
                let values = point.arrayValue?.compactMap(\.numberValue),
                values.count == 2
            else {
                return nil
            }

            return values
        } ?? []
    }

    private static func polygonRings(from value: JSONValue) -> [[[Double]]] {
        value.arrayValue?.compactMap { ringValue in
            let points = coordinatePairs(from: ringValue)
            return points.isEmpty ? nil : points
        } ?? []
    }

    private static func multiPolygonRings(from value: JSONValue) -> [[[[Double]]]] {
        value.arrayValue?.compactMap { polygonValue in
            let rings = polygonRings(from: polygonValue)
            return rings.isEmpty ? nil : rings
        } ?? []
    }

    private static func projectOptional(_ coordinate: [Double]?, in bounds: CGRect, size: CGSize) -> CGPoint? {
        guard let coordinate else {
            return nil
        }

        return project(coordinate, in: bounds, size: size)
    }

    private static func project(_ coordinate: [Double], in bounds: CGRect, size: CGSize) -> CGPoint {
        guard coordinate.count == 2 else {
            return .zero
        }

        let x = (coordinate[0] - bounds.minX) / bounds.width
        let y = 1 - (coordinate[1] - bounds.minY) / bounds.height

        return CGPoint(x: x * size.width, y: y * size.height)
    }
}

private struct FeatureHighlight: Identifiable {
    let id: String
    let title: String
    let detail: String
}
