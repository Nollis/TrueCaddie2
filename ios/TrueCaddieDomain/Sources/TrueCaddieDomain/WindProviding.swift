import Foundation

/// A single live-wind observation, expressed in the meteorological convention
/// the recommendation engine ultimately cares about: an absolute compass
/// direction the wind is *coming from* (degrees clockwise from north), and a
/// speed in meters per second.
///
/// Conversion from this absolute observation to the shot-relative
/// ``WindRelativeDirection`` happens at the host layer, where the current
/// hole's tee→green bearing is known. Keeping that mapping out of the domain
/// value type means the same advisory can be reinterpreted on hole change
/// without re-fetching.
public struct WindAdvisory: Equatable, Sendable {
    /// Direction the wind is coming from, degrees clockwise from north,
    /// normalized to `[0, 360)`.
    public let directionDegFromNorth: Double

    /// Wind speed in meters per second.
    public let speedMps: Double

    /// When this observation was fetched. Used by UI for "stale" indicators.
    public let fetchedAt: Date

    public init(directionDegFromNorth: Double, speedMps: Double, fetchedAt: Date) {
        self.directionDegFromNorth = directionDegFromNorth
        self.speedMps = speedMps
        self.fetchedAt = fetchedAt
    }
}

/// Failure modes a ``WindProviding`` source can surface. Categories are
/// deliberately coarse — UI displays a short message and otherwise treats all
/// errors as "wind unavailable, keep the last good value".
public enum WindProvidingError: Equatable, Sendable {
    case notAuthorized
    case network(String)
    case unknown(String)
}

/// Abstract wind source. The host module supplies a WeatherKit-backed
/// concrete implementation; tests and the simulator developer panel supply a
/// stub. Refresh is explicit (the model drives cadence) so the protocol stays
/// free of timer/lifecycle concerns.
@MainActor
public protocol WindProviding: AnyObject {
    var onAdvisory: ((WindAdvisory) -> Void)? { get set }
    var onError: ((WindProvidingError) -> Void)? { get set }

    /// Store the coordinate to fetch wind at. The next ``refresh()`` will
    /// query this location. Setting the location without calling refresh is
    /// allowed — the caller decides when to fetch.
    func setLocation(_ coordinate: GeoCoordinate2D)

    /// Trigger a wind fetch for the most recently set location. No-op when no
    /// location has been set yet — a successful first GPS fix will trigger
    /// the call from the caller side.
    func refresh()
}
