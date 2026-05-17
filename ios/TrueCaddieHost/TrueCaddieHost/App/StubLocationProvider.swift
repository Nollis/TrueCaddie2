import Foundation
import TrueCaddieDomain

/// Stub `LocationProviding` for the iOS Simulator and unit tests.
///
/// The Simulator has no real microphone but does have a real CLLocationManager
/// stack — however, no real GPS fixes arrive. This stub lets the developer
/// section in the Inspector emit canned fixes so the whole pipeline
/// (LiveCourseLocationModel → Caddie tab → voice capture) can be exercised on
/// the simulator without a device.
final class StubLocationProvider: LocationProviding {

    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)?

    private(set) var authorizationStatus: LocationAuthorizationStatus = .authorizedWhenInUse

    func start() { /* no-op */ }
    func stop() { /* no-op */ }

    /// Emit a single canned fix. Tests and the Inspector developer section
    /// call this to drive the rest of the system.
    func emit(_ fix: LocationFix) {
        onFix?(fix)
    }

    /// Convenience: emit a fix at a coordinate with a default 5 m accuracy
    /// (well inside the capture threshold).
    func emit(coordinate: GeoCoordinate2D, accuracy: Double = 5.0, at date: Date = Date()) {
        emit(LocationFix(coordinate: coordinate, horizontalAccuracyM: accuracy, timestamp: date))
    }

    /// Test-only handle to change authorization on the fly.
    func setAuthorization(_ status: LocationAuthorizationStatus) {
        authorizationStatus = status
        onAuthorizationChange?(status)
    }
}
