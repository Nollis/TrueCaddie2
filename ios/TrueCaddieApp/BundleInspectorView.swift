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

    private var hazardSeverityOverlays: [HazardSeverityOverlay] {
        hole.strategyOverlays.hazardSeverity
            .sorted { lhs, rhs in
                if lhs.properties.severityScore == rhs.properties.severityScore {
                    return lhs.properties.hazardKind < rhs.properties.hazardKind
                }

                return lhs.properties.severityScore > rhs.properties.severityScore
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
                                Label(
                                    hazard.properties.hazardKind.capitalized,
                                    systemImage: iconName(for: hazard.properties.hazardKind)
                                )
                                    .font(.headline)

                                Spacer()

                                Text(severityLabel(for: hazard))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(bandColor(for: hazard).opacity(0.18), in: Capsule())
                                    .foregroundStyle(bandColor(for: hazard))
                            }

                            Text(hazard.rationale.primaryReason)
                                .font(.subheadline)

                            HStack(spacing: 12) {
                                Text("Score \(format(number: hazard.properties.severityScore))")
                                Text(hazard.properties.penaltyKind.replacingOccurrences(of: "_", with: " "))
                                if hazard.properties.landingConflict {
                                    Text("Landing conflict")
                                }
                                if hazard.properties.blocksRecovery {
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

    private func severityLabel(for hazard: HazardSeverityOverlay) -> String {
        "\(hazard.properties.severityBand.capitalized) \(format(number: hazard.properties.severityScore))"
    }

    private func bandColor(for hazard: HazardSeverityOverlay) -> Color {
        switch hazard.properties.severityBand {
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

    private func iconName(for hazardKind: String) -> String {
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

private extension HoleSketchLayout {
    func polygons(for featureType: String) -> [Path] {
        polygonRings(for: featureType).map { ring in
            Path { path in
                path.addLines(ring)
                path.closeSubpath()
            }
        }
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

private struct FeatureHighlight: Identifiable {
    let id: String
    let title: String
    let detail: String
}
