import Combine
import Foundation
import TrueCaddieDomain

/// Ranks the bundled course catalog by proximity to the player's current GPS
/// fix and publishes the sorted list for the Welcome screen.
///
/// This model owns its own ``LocationProviding`` instance so that GPS is
/// active while the player is on the Welcome screen — before a course bundle
/// has been selected and a ``LiveCourseLocationModel`` can be created.
/// When a round starts, ``ContentView`` stops this model and the in-round
/// ``LiveCourseLocationModel`` (inside ``CaddieHostTabContainer``) takes over.
@MainActor
final class CourseProximityModel: ObservableObject {

    /// Courses sorted by distance from the player's last fix, closest first.
    /// Empty until the first GPS fix arrives.
    @Published private(set) var rankedCourses: [CourseDescriptor] = []

    /// Mirrors the underlying provider's authorization status so the
    /// Welcome screen can display appropriate placeholder states.
    @Published private(set) var authorizationStatus: LocationAuthorizationStatus

    private let provider: any LocationProviding
    private let courses: [CourseDescriptor]

    init(provider: any LocationProviding, courses: [CourseDescriptor]) {
        self.provider = provider
        self.courses = courses
        self.authorizationStatus = provider.authorizationStatus

        provider.onFix = { [weak self] fix in
            self?.handle(fix: fix)
        }
        provider.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
    }

    func start() { provider.start() }
    func stop()  { provider.stop() }

    // MARK: - Private

    private func handle(fix: LocationFix) {
        guard courses.count > 1 else {
            // Skip sorting when there is only one course — still publish so
            // WelcomeView transitions from its "finding location" state.
            rankedCourses = courses
            return
        }

        rankedCourses = courses.sorted { a, b in
            let da = GolfGeometry.haversineDistance(fix.coordinate, a.centerCoordinate)
            let db = GolfGeometry.haversineDistance(fix.coordinate, b.centerCoordinate)
            return da < db
        }
    }
}
