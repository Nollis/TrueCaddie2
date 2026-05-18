import Foundation
import TrueCaddieDomain

/// Stub ``WindProviding`` for the iOS Simulator and unit tests.
///
/// Real WeatherKit requires the entitlement and is unreliable in the
/// simulator. This stub lets the Inspector's developer section emit canned
/// advisories — and lets tests drive the full pipeline (model + chips +
/// recommendation engine) without network reach.
final class StubWindProvider: WindProviding {

    var onAdvisory: ((WindAdvisory) -> Void)?
    var onError: ((WindProvidingError) -> Void)?

    private(set) var currentLocation: GeoCoordinate2D?

    func setLocation(_ coordinate: GeoCoordinate2D) {
        currentLocation = coordinate
    }

    /// No-op for the stub. Tests/UI drive emission explicitly through
    /// ``emit(_:)`` / ``emitError(_:)``.
    func refresh() { /* no-op */ }

    /// Emit a canned advisory.
    func emit(_ advisory: WindAdvisory) {
        onAdvisory?(advisory)
    }

    /// Convenience: emit a fully specified advisory with `Date()` as the
    /// fetch timestamp.
    func emit(directionDegFromNorth: Double, speedMps: Double, at date: Date = Date()) {
        emit(WindAdvisory(directionDegFromNorth: directionDegFromNorth, speedMps: speedMps, fetchedAt: date))
    }

    /// Emit a canned error.
    func emitError(_ error: WindProvidingError) {
        onError?(error)
    }
}
