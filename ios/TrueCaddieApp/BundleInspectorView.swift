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

    var body: some View {
        List {
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
                    title: feature.properties["name"].flatMap(stringText) ?? feature.featureType.capitalized,
                    detail: "\(hazardText) • along \(alongText ?? "n/a") m • \(sideText ?? "unknown side")"
                )
            }
    }

    private var qualityLabel: String {
        let score = String(format: "%.2f", hole.qualityConfidence.holePublishScore)
        return "\(snapshot.qualityBand.capitalized) (\(score))"
    }

    private var defaultBearingText: String? {
        guard let bearing = hole.defaultPlayDirection?["bearingDeg"].flatMap(numericText) else {
            return nil
        }

        return "\(bearing) deg"
    }

    private func coordinateText(_ coordinate: [Double]) -> String {
        guard coordinate.count == 2 else {
            return "n/a"
        }

        return String(format: "%.5f, %.5f", coordinate[1], coordinate[0])
    }

    private func numericText(_ value: JSONValue?) -> String? {
        guard case let .number(number) = value else {
            return nil
        }

        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.2f", number)
    }

    private func stringText(_ value: JSONValue?) -> String? {
        guard case let .string(text) = value else {
            return nil
        }

        return text
    }
}

private struct FeatureHighlight: Identifiable {
    let id: String
    let title: String
    let detail: String
}
