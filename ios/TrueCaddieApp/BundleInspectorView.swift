import SwiftUI
import TrueCaddieDomain

struct BundleInspectorView: View {
    let bundle: CourseBundle
    @State private var selectedHoleId: String?

    private var selectedHole: CourseHole? {
        let selectedId = selectedHoleId ?? bundle.holes.first?.holeId
        return bundle.holes.first { $0.holeId == selectedId }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedHoleId) {
                Section(bundle.courseName) {
                    ForEach(bundle.holes) { hole in
                        Label("Hole \(hole.holeNumber)", systemImage: "flag")
                            .badge("Par \(hole.par)")
                            .tag(hole.holeId)
                    }
                }
            }
            .navigationTitle(bundle.courseId)
        } detail: {
            if let selectedHole {
                HoleInspectorDetail(
                    snapshot: HoleInspectionSnapshot(bundle: bundle, hole: selectedHole),
                    hole: selectedHole
                )
            } else {
                ContentUnavailableView("No Hole", systemImage: "flag.slash")
            }
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
                LabeledContent("Quality", value: snapshot.qualityBand)
            }

            Section("Hole") {
                LabeledContent("Hole", value: "\(snapshot.holeNumber)")
                LabeledContent("Par", value: "\(snapshot.par)")
                LabeledContent("Tees", value: "\(snapshot.teeCount)")
                LabeledContent("Features", value: "\(snapshot.featureCount)")
            }

            Section("Tees") {
                ForEach(hole.tees) { tee in
                    LabeledContent(tee.name, value: "\(Int(tee.teeLengthM)) m")
                }
            }

            Section("Feature Types") {
                ForEach(featureTypeCounts, id: \.name) { item in
                    LabeledContent(item.name, value: "\(item.count)")
                }
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
        }
        .navigationTitle("Hole \(snapshot.holeNumber)")
    }

    private var featureTypeCounts: [(name: String, count: Int)] {
        Dictionary(grouping: hole.baseMappingData.features, by: \.featureType)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }
}
