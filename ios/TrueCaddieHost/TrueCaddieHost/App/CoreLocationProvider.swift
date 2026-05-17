import CoreLocation
import Foundation
import TrueCaddieDomain

/// CoreLocation-backed implementation of ``LocationProviding``.
///
/// Foreground-only ("When In Use" authorization). Filters out fixes with
/// `horizontalAccuracy <= 0` (Apple's "invalid fix" sentinel) and fixes worse
/// than 2× the capture-accuracy threshold so the rest of the app never sees
/// obviously useless reads. The capture gate (15 m) lives in
/// ``GolfGeometry/Constants/minimumAcceptableAccuracyM`` and is enforced at
/// the moment of shot capture, not here — UI still wants to display "GPS
/// warming up" while accuracy is between the two thresholds.
final class CoreLocationProvider: NSObject, LocationProviding {

    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)?

    private(set) var authorizationStatus: LocationAuthorizationStatus

    private let manager: CLLocationManager
    private var isStarted = false

    override init() {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2.0
        self.manager = manager
        self.authorizationStatus = Self.mapStatus(manager.authorizationStatus)
        super.init()
        manager.delegate = self
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            // Surface the state via the callback; do not request again — the
            // user must change it in Settings.
            onAuthorizationChange?(authorizationStatus)
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        manager.stopUpdatingLocation()
    }

    private static func mapStatus(_ status: CLAuthorizationStatus) -> LocationAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedAlways: return .authorizedAlways
        case .authorizedWhenInUse: return .authorizedWhenInUse
        @unknown default: return .denied
        }
    }

    /// Filter fixes that are obviously useless before we publish them.
    /// Apple uses negative `horizontalAccuracy` to signal "no fix"; we also
    /// drop anything outside 2× the capture-accuracy threshold so noisy
    /// readings don't churn the UI distance number.
    private static func shouldKeep(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > 0 else { return false }
        return location.horizontalAccuracy <= GolfGeometry.Constants.minimumAcceptableAccuracyM * 2
    }
}

extension CoreLocationProvider: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.mapStatus(manager.authorizationStatus)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            self.onAuthorizationChange?(status)
            if self.isStarted, status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, Self.shouldKeep(latest) else { return }
        let fix = LocationFix(
            coordinate: GeoCoordinate2D(lon: latest.coordinate.longitude, lat: latest.coordinate.latitude),
            horizontalAccuracyM: latest.horizontalAccuracy,
            timestamp: latest.timestamp
        )
        Task { @MainActor [weak self] in
            self?.onFix?(fix)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // CoreLocation errors during a round are usually transient (lost
        // signal, etc.). Don't propagate — the UI will simply see the lastFix
        // grow stale, which is the right visual signal.
    }
}
