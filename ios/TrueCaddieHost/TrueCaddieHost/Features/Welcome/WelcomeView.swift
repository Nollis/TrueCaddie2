import SwiftUI
import TrueCaddieDomain

/// Pre-round landing screen.  Shows the GPS-closest course (or the full
/// catalog when location is unavailable) and lets the player tap
/// **Start Round** to begin.
struct WelcomeView: View {

    @ObservedObject var proximityModel: CourseProximityModel
    /// Called with the loaded bundle when the player confirms Start Round.
    let onStartRound: (CourseBundle) -> Void

    @State private var selectedDescriptor: CourseDescriptor?
    @State private var showSettings = false
    @State private var loadError: String?
    @State private var showLoadError = false

    // MARK: - Derived state

    /// Courses to display, taking GPS state into account.
    private var displayedCourses: [CourseDescriptor] {
        switch proximityModel.authorizationStatus {
        case .denied, .restricted:
            // No GPS — show the full catalog alphabetically.
            return HostCourseBundleStore.availableCourses.sorted { $0.name < $1.name }
        default:
            // Authorized (ranked) or not-yet-determined — show ranked list
            // (empty until the first fix).
            return proximityModel.rankedCourses
        }
    }

    private var locationDenied: Bool {
        proximityModel.authorizationStatus == .denied
            || proximityModel.authorizationStatus == .restricted
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    Divider()
                    courseSection
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Could Not Load Course", isPresented: $showLoadError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(loadError ?? "An unknown error occurred.")
            }
            .onReceive(proximityModel.$rankedCourses) { ranked in
                // Auto-select the closest course only when nothing is
                // selected yet — never override a manual pick.
                if selectedDescriptor == nil, let first = ranked.first {
                    selectedDescriptor = first
                }
            }
            .onAppear {
                // Same guard as onReceive: seed only if not yet set.
                if selectedDescriptor == nil, let first = displayedCourses.first {
                    selectedDescriptor = first
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.golf")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .padding(.top, 40)
            Text("TrueCaddie")
                .font(.largeTitle.weight(.bold))
            Text("Your AI caddie on the course")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            courseList
            startButton
        }
        .padding(20)
    }

    @ViewBuilder
    private var sectionHeader: some View {
        if locationDenied {
            Label("Location unavailable — showing all courses", systemImage: "location.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if proximityModel.authorizationStatus == .notDetermined {
            Label("Requesting location…", systemImage: "location")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if displayedCourses.isEmpty {
            Label("Finding nearest course…", systemImage: "location.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(displayedCourses.count == 1 ? "Nearest course" : "Nearby courses")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var courseList: some View {
        if displayedCourses.isEmpty {
            // Spinner while waiting for first GPS fix.
            HStack {
                ProgressView()
                    .padding(.trailing, 4)
                Text("Searching…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                ForEach(displayedCourses) { descriptor in
                    courseRow(descriptor)
                }
            }
        }
    }

    private func courseRow(_ descriptor: CourseDescriptor) -> some View {
        let isSelected = selectedDescriptor?.id == descriptor.id
        let isClosest = displayedCourses.first?.id == descriptor.id && !locationDenied

        return Button {
            selectedDescriptor = descriptor
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(descriptor.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if isClosest {
                            Text("Closest")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text("9 holes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? Color.green.opacity(0.08)
                          : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            startRound()
        } label: {
            Label("Start Round", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedDescriptor != nil ? Color.green : Color.gray.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(selectedDescriptor != nil ? .white : .secondary)
        }
        .disabled(selectedDescriptor == nil)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func startRound() {
        guard let descriptor = selectedDescriptor else { return }
        do {
            let bundle = try HostCourseBundleStore.load(descriptor)
            onStartRound(bundle)
        } catch {
            loadError = error.localizedDescription
            showLoadError = true
        }
    }
}

#Preview {
    WelcomeView(
        proximityModel: CourseProximityModel(
            provider: StubLocationProvider(),
            courses: HostCourseBundleStore.availableCourses
        ),
        onStartRound: { _ in }
    )
}
