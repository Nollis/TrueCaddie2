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
    private let debugLog = AppDebugLogStore.shared

    /// The hole the player is currently committed to playing (per the round
    /// state, not GPS). Used as the anchor for hysteresis: the model refuses
    /// to flip away from this hole until the player has been clearly
    /// outside its features for several consecutive fixes. ContentView keeps
    /// this in sync with its `selectedHoleNumber` state.
    var currentHoleNumber: Int? {
        didSet {
            if oldValue != currentHoleNumber {
                consecutiveMisses = 0
            }
        }
    }

    private var consecutiveMisses: Int = 0

    init(
        provider: any LocationProviding,
        bundle: CourseBundle,
        currentHoleNumber: Int? = nil
    ) {
        self.provider = provider
        self.bundle = bundle
        self.currentHoleNumber = currentHoleNumber
        self.authorizationStatus = provider.authorizationStatus

        provider.onFix = { [weak self] fix in
            self?.handle(fix: fix)
        }
        provider.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
            self?.debugLog.record(
                "Location authorization changed",
                category: .location,
                metadata: ["status": Self.authorizationLabel(status)]
            )
        }
    }

    func start() { provider.start() }
    func stop() { provider.stop() }

    /// Inject a fix as if it had arrived from the underlying provider.
    /// Used by the Inspector's developer section to drive the full
    /// pipeline (hole detection, distance, lie, capture) on the iOS
    /// Simulator, where real CoreLocation never delivers fixes.
    func injectStubFix(_ fix: LocationFix) {
        handle(fix: fix)
    }

    // MARK: - Private

    private func handle(fix: LocationFix) {
        let previousDetectedHole = detectedHoleNumber
        let previousLie = inferredLie
        lastFix = fix

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

        if previousDetectedHole != detectedHoleNumber || previousLie != inferredLie {
            debugLog.record(
                "Processed live fix",
                category: .location,
                metadata: [
                    "accuracyM": Self.metric(fix.horizontalAccuracyM),
                    "currentHole": currentHoleNumber.map(String.init) ?? "nil",
                    "detectedHole": detectedHoleNumber.map(String.init) ?? "nil",
                    "lie": inferredLie?.rawValue ?? "nil",
                    "misses": String(consecutiveMisses)
                ]
            )
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

    nonisolated private static func authorizationLabel(_ status: LocationAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "not_determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorized_always"
        case .authorizedWhenInUse:
            return "authorized_when_in_use"
        }
    }

    nonisolated private static func metric(_ number: Double) -> String {
        if number.rounded() == number {
            return String(Int(number))
        }

        return String(format: "%.1f", number)
    }
}
