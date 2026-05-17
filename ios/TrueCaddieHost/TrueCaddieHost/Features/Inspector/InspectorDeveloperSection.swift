import SwiftUI
import TrueCaddieDomain

struct InspectorDeveloperSection: View {
    @ObservedObject var voiceController: HostVoiceSessionController
    @ObservedObject var locationModel: LiveCourseLocationModel
    let bundle: CourseBundle
    @AppStorage("truecaddie.developerToolsEnabled") private var developerToolsEnabled = false
    @State private var typedInput = ""

    var body: some View {
        Section {
            Toggle("Show developer tools", isOn: $developerToolsEnabled)

            if developerToolsEnabled {
                HStack {
                    TextField("Type to the caddie", text: $typedInput)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(true)
                    Button("Send") {
                        let trimmed = typedInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        _ = voiceController.submitTypedUtterance(trimmed)
                        typedInput = ""
                    }
                    .disabled(typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("What do you like?") {
                            _ = voiceController.submitVoiceUtterance("what do you like here")
                        }
                        chip("Sim Voice") {
                            _ = voiceController.submitVoiceUtterance("what do you like here")
                        }
                        chip("Partial") {
                            voiceController.submitPartialVoiceUtterance("what do you")
                        }
                        chip("Sim Result") {
                            _ = voiceController.submitVoiceToolInvocation(
                                VoiceToolInvocation(
                                    actionName: .reportResult,
                                    arguments: .init(lie: .rough, remainingDistanceM: 128)
                                )
                            )
                        }
                        chip("Safe play") {
                            _ = voiceController.submitVoiceUtterance("safe play")
                        }
                        chip("Aggressive") {
                            _ = voiceController.submitVoiceUtterance("aggressive")
                        }
                        chip("Repeat") {
                            _ = voiceController.submitVoiceUtterance("repeat")
                        }
                    }
                }

                stubLocationControls

                Button("Simulate transport failure") {
                    voiceController.simulateTransportFailure("Debug transport drop")
                }
                .foregroundStyle(.red)
            }
        } header: {
            Text("Developer")
        } footer: {
            if !developerToolsEnabled {
                Text("Typed input and simulators are hidden by default.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var stubLocationControls: some View {
        let fixes = stubFixes(for: bundle)

        if !fixes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stub GPS fixes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(fixes, id: \.label) { fix in
                            chip(fix.label) {
                                locationModel.injectStubFix(fix.locationFix)
                            }
                        }
                    }
                }

                if let lastFix = locationModel.lastFix {
                    Text(
                        "Last fix: \(lastFix.coordinate.lon, format: .number.precision(.fractionLength(5))), \(lastFix.coordinate.lat, format: .number.precision(.fractionLength(5))) (±\(Int(lastFix.horizontalAccuracyM.rounded()))m)"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func stubFixes(for bundle: CourseBundle) -> [StubFix] {
        // Build a small canned set from real bundle coordinates so the rest of
        // the system (hole detection, lie inference, distance) exercises the
        // same code paths as on-course play. The accuracy is set inside the
        // capture gate so taps on these chips can complete the full
        // "I'm at my ball" flow without going outside.
        var result: [StubFix] = []

        for hole in bundle.holes.prefix(5) {
            if let tee = hole.tees.first(where: { $0.isDefault == true }) ?? hole.tees.first,
               let coord = GeoCoordinate2D(lonLatPair: tee.teeCoordinate) {
                result.append(StubFix(label: "Hole \(hole.holeNumber) tee", coordinate: coord))
            }
            if let green = GeoCoordinate2D(lonLatPair: hole.baseMappingData.green.center) {
                result.append(StubFix(label: "Hole \(hole.holeNumber) green", coordinate: green))
            }
            if let bunkerCenter = featureCenter(in: hole, type: "bunker") {
                result.append(StubFix(label: "Hole \(hole.holeNumber) bunker", coordinate: bunkerCenter))
            }
        }
        return result
    }

    private func featureCenter(in hole: CourseHole, type: String) -> GeoCoordinate2D? {
        for feature in hole.baseMappingData.features where feature.featureType == type {
            for ring in GolfGeometry.extractOuterRings(from: feature.geometry) where !ring.isEmpty {
                let lonSum = ring.reduce(0.0) { $0 + $1.lon }
                let latSum = ring.reduce(0.0) { $0 + $1.lat }
                return GeoCoordinate2D(lon: lonSum / Double(ring.count), lat: latSum / Double(ring.count))
            }
        }
        return nil
    }
}

private struct StubFix {
    let label: String
    let coordinate: GeoCoordinate2D

    var locationFix: LocationFix {
        // 5 m accuracy puts the fix well inside the 15 m capture gate so the
        // developer chips can drive the full capture path.
        LocationFix(coordinate: coordinate, horizontalAccuracyM: 5.0, timestamp: Date())
    }
}
