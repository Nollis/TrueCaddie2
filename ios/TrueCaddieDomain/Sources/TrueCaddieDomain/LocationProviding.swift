import Foundation

/// Authorization state for a ``LocationProviding`` source.
///
/// Mirrors `CLAuthorizationStatus` but lives in the platform-free domain
/// module so business logic and UI can reason about authorization without
/// importing CoreLocation.
public enum LocationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorizedWhenInUse
    case authorizedAlways
    case denied
    case restricted
}

/// Abstract location source. The host module supplies a CoreLocation-backed
/// concrete implementation; tests and the simulator developer panel supply a
/// stub. Callbacks are deliberately closure-shaped to match the existing
/// transport-layer pattern (`OpenAIRealtimeConnectioning` etc.).
@MainActor
public protocol LocationProviding: AnyObject {
    var authorizationStatus: LocationAuthorizationStatus { get }

    var onFix: ((LocationFix) -> Void)? { get set }
    var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)? { get set }

    /// Begin emitting fixes. Idempotent — calling multiple times must not
    /// produce duplicate subscriptions. If authorization is `notDetermined`,
    /// the implementation should prompt for permission.
    func start()

    /// Stop emitting fixes. Idempotent.
    func stop()
}
