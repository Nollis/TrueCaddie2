import CoreLocation
import Foundation
import TrueCaddieDomain
import WeatherKit

/// WeatherKit-backed implementation of ``WindProviding``.
///
/// Async-fetches the current weather at the most recently set location and
/// turns the absolute compass wind into a ``WindAdvisory``. Lifecycle
/// concerns — refresh cadence, debouncing, retry — live in
/// ``LiveWindModel``; this class is single-purpose.
///
/// Setup: requires the `com.apple.developer.weatherkit` entitlement and the
/// bundle ID registered for WeatherKit in the Apple Developer portal.
/// Without those, fetches fail with the system error surface and the app
/// falls back to "no wind available" UX. The stub provider keeps the
/// simulator usable while setup is being completed.
final class WeatherKitWindProvider: WindProviding {

    var onAdvisory: ((WindAdvisory) -> Void)?
    var onError: ((WindProvidingError) -> Void)?

    private var currentLocation: GeoCoordinate2D?
    private var inFlightTask: Task<Void, Never>?

    func setLocation(_ coordinate: GeoCoordinate2D) {
        currentLocation = coordinate
    }

    func refresh() {
        guard let coordinate = currentLocation else { return }

        // Cancel any prior in-flight fetch so rapid setLocation/refresh
        // sequences don't pile up redundant queries.
        inFlightTask?.cancel()
        inFlightTask = Task { [weak self] in
            await self?.fetch(at: coordinate)
        }
    }

    private func fetch(at coordinate: GeoCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.lat, longitude: coordinate.lon)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            guard !Task.isCancelled else { return }

            let wind = weather.currentWeather.wind
            let speedMps = wind.speed.converted(to: .metersPerSecond).value
            let directionDeg = wind.direction.converted(to: .degrees).value

            let advisory = WindAdvisory(
                directionDegFromNorth: Self.normalizeDegrees(directionDeg),
                speedMps: speedMps,
                fetchedAt: Date()
            )
            onAdvisory?(advisory)
        } catch {
            guard !Task.isCancelled else { return }
            onError?(Self.classify(error))
        }
    }

    nonisolated private static func normalizeDegrees(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    nonisolated private static func classify(_ error: Error) -> WindProvidingError {
        let nsError = error as NSError
        // WeatherKit surfaces a wide variety of errors. Map by NSURLErrorDomain
        // codes where they're meaningful; everything else falls into the
        // catch-all bucket. UI doesn't differentiate beyond this.
        if nsError.domain == NSURLErrorDomain {
            return .network(nsError.localizedDescription)
        }
        return .unknown(nsError.localizedDescription)
    }
}
