import SwiftUI

struct InspectorDeveloperSection: View {
    @ObservedObject var voiceController: HostVoiceSessionController
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

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}
