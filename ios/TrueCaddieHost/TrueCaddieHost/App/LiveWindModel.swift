import Combine
import Foundation
import TrueCaddieDomain

/// Bridges a ``WindProviding`` source into SwiftUI-observable state: the
/// last successful raw advisory, the shot-relative `WindContext` derived
/// from the current hole's tee→green bearing, and a non-fatal fetch-error
/// surface for UI to show "wind unavailable" without dropping the last
/// known good value.
///
/// Owns the periodic refresh loop. The provider stays single-purpose —
/// fetch on demand — and the model decides when to call it: on location
/// change, on hole change, and on a coarse 600 s cadence by default.
@MainActor
final class LiveWindModel: ObservableObject {

    @Published private(set) var advisory: WindAdvisory?
    @Published private(set) var windContext: WindContext?
    @Published private(set) var lastFetchError: WindProvidingError?

    private let provider: any WindProviding
    private let bundle: CourseBundle
    private let periodicRefreshSeconds: TimeInterval

    /// The hole the player is currently committed to. Used to compute the
    /// shot-relative wind direction. ContentView keeps this in sync with
    /// its `selectedHoleNumber` state.
    private(set) var currentHole: CourseHole?

    /// The selected tee for the current hole. The tee→green bearing is
    /// invariant to tee selection at hole scale, so this is mostly cosmetic
    /// — but using the configured tee keeps things consistent if the bundle
    /// ever introduces per-tee centerlines.
    private(set) var currentTeeSetId: String?

    private var refreshTask: Task<Void, Never>?

    init(
        provider: any WindProviding,
        bundle: CourseBundle,
        periodicRefreshSeconds: TimeInterval = 600
    ) {
        self.provider = provider
        self.bundle = bundle
        self.periodicRefreshSeconds = periodicRefreshSeconds

        provider.onAdvisory = { [weak self] advisory in
            self?.handle(advisory: advisory)
        }
        provider.onError = { [weak self] error in
            self?.handle(error: error)
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Forward a new player coordinate to the provider and trigger a fresh
    /// fetch. Called by ContentView whenever a new GPS fix arrives.
    func setLocation(_ coordinate: GeoCoordinate2D) {
        provider.setLocation(coordinate)
        provider.refresh()
    }

    /// Set the current hole + selected tee. Recomputes `windContext` from
    /// the existing advisory (no fetch) and also kicks off a fresh fetch in
    /// case the player has walked far enough that nearby wind has changed.
    func setCurrentHole(_ hole: CourseHole?, teeSetId: String?) {
        currentHole = hole
        currentTeeSetId = teeSetId
        recomputeWindContext()
        provider.refresh()
    }

    /// Start the periodic refresh loop. Idempotent — call once after the
    /// owning view has rendered.
    func startRefreshLoop() {
        guard refreshTask == nil else { return }
        let period = periodicRefreshSeconds
        let provider = self.provider
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(period * 1_000_000_000))
                } catch {
                    return
                }
                guard self != nil, !Task.isCancelled else { return }
                provider.refresh()
            }
        }
    }

    /// Inject an advisory as if it had arrived from the underlying provider.
    /// Used by the Inspector's developer section to drive the pipeline on
    /// the simulator and by tests that don't want to spin up a stub provider.
    func injectStubAdvisory(_ advisory: WindAdvisory) {
        handle(advisory: advisory)
    }

    /// Inject an error as if the provider had reported it.
    func injectStubError(_ error: WindProvidingError) {
        handle(error: error)
    }

    // MARK: - Private

    private func handle(advisory: WindAdvisory) {
        // Avoid churn: only republish when the advisory's wind data changes.
        // Timestamps alone don't matter for downstream observers.
        if let existing = self.advisory,
           existing.directionDegFromNorth == advisory.directionDegFromNorth,
           existing.speedMps == advisory.speedMps {
            return
        }
        self.advisory = advisory
        lastFetchError = nil
        recomputeWindContext()
    }

    private func handle(error: WindProvidingError) {
        lastFetchError = error
        // Keep `advisory` and `windContext` intact — UI shows last known
        // wind plus an error indicator rather than collapsing to nil.
    }

    private func recomputeWindContext() {
        guard
            let advisory,
            let hole = currentHole,
            let teeCoord = selectedTeeCoordinate(in: hole),
            let greenCoord = GeoCoordinate2D(lonLatPair: hole.baseMappingData.green.center)
        else {
            windContext = nil
            return
        }
        let shotBearing = GolfGeometry.bearingDeg(from: teeCoord, to: greenCoord)
        let relative = WindRelativeDirection.from(
            windFromDeg: advisory.directionDegFromNorth,
            shotBearingDeg: shotBearing
        )
        windContext = WindContext(relativeDirection: relative, speedMps: advisory.speedMps)
    }

    private func selectedTeeCoordinate(in hole: CourseHole) -> GeoCoordinate2D? {
        let tee = hole.tees.first(where: { $0.teeSetId == currentTeeSetId })
            ?? hole.tees.first(where: { $0.isDefault == true })
            ?? hole.tees.first
        return tee.flatMap { GeoCoordinate2D(lonLatPair: $0.teeCoordinate) }
    }
}
