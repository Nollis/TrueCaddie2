import Combine
import Foundation
import TrueCaddieDomain

/// Bridges a ``LocationProviding`` source into SwiftUI-observable derived
/// state: which hole the player is on, how far to the green, what lie they're
/// likely sitting on, and the most recent raw fix for accuracy-gating UI.
///
/// The model holds the hysteresis streak counter so the ``HoleDetector`` can
/// refuse to flip the active hole mid-shot when the player drifts past the
/// edge of one fairway and into another.
@MainActor
final class LiveCourseLocationModel: ObservableObject {

    @Published private(set) var lastFix: LocationFix?
    @Published private(set) var detectedHoleNumber: Int?
    @Published private(set) var distanceToPinM: Double?
    @Published private(set) var inferredLie: ShotLie?
    @Published private(set) var authorizationStatus: LocationAuthorizationStatus

    private let provider: any LocationProviding
    private let bundle: CourseBundle

    /// Caller-supplied getter so the model can read the currently selected
    /// hole without owning it (ContentView is the source of truth).
    private let currentHole: () -> Int?

    private var consecutiveMisses: Int = 0

    init(
        provider: any LocationProviding,
        bundle: CourseBundle,
        currentHole: @escaping () -> Int?
    ) {
        self.provider = provider
        self.bundle = bundle
        self.currentHole = currentHole
        self.authorizationStatus = provider.authorizationStatus

        provider.onFix = { [weak self] fix in
            self?.handle(fix: fix)
        }
        provider.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
    }

    func start() { provider.start() }
    func stop() { provider.stop() }

    // MARK: - Private

    private func handle(fix: LocationFix) {
        lastFix = fix

        let currentHoleNumber = currentHole()
        updateMissStreak(for: fix, currentHoleNumber: currentHoleNumber)

        let detected = HoleDetector.activeHole(
            fix: fix.coordinate,
            bundle: bundle,
            current: currentHoleNumber,
            consecutiveMisses: consecutiveMisses
        )
        detectedHoleNumber = detected

        // Derive distance and lie against the *detected* hole — if the user
        // has not started any hole yet, we still want to show "you're on
        // hole 3, 150 m to the green".
        if let detected, let hole = bundle.holes.first(where: { $0.holeNumber == detected }) {
            if let green = GeoCoordinate2D(lonLatPair: hole.baseMappingData.green.center) {
                distanceToPinM = GolfGeometry.haversineDistance(fix.coordinate, green)
            } else {
                distanceToPinM = nil
            }
            inferredLie = LieInference.lie(at: fix.coordinate, in: hole)
        } else {
            distanceToPinM = nil
            inferredLie = nil
        }
    }

    private func updateMissStreak(for fix: LocationFix, currentHoleNumber: Int?) {
        guard
            let currentHoleNumber,
            let current = bundle.holes.first(where: { $0.holeNumber == currentHoleNumber })
        else {
            consecutiveMisses = 0
            return
        }
        if HoleDetector.fixIsBeyondSwitchRadius(fix: fix.coordinate, of: current) {
            consecutiveMisses += 1
        } else {
            consecutiveMisses = 0
        }
    }
}
