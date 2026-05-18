import SwiftUI
import TrueCaddieDomain

struct CaddieRecommendationHero: View {
    let packet: NextShotRecommendationPacket?
    let emptyStateText: String
    let livePinDistanceM: Double?
    let locationAuthorizationStatus: LocationAuthorizationStatus?
    let liveWind: WindContext?

    init(
        packet: NextShotRecommendationPacket?,
        emptyStateText: String,
        livePinDistanceM: Double? = nil,
        locationAuthorizationStatus: LocationAuthorizationStatus? = nil,
        liveWind: WindContext? = nil
    ) {
        self.packet = packet
        self.emptyStateText = emptyStateText
        self.livePinDistanceM = livePinDistanceM
        self.locationAuthorizationStatus = locationAuthorizationStatus
        self.liveWind = liveWind
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let packet {
                HStack(alignment: .firstTextBaseline) {
                    Text(packet.headline)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    confidenceChip(for: packet.confidenceBand)
                }

                if !packet.executionNote.isEmpty {
                    Text(packet.executionNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(emptyStateText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let livePinDistanceM {
                liveDistanceRow(distanceM: livePinDistanceM)
            } else if let locationAuthorizationStatus, locationAuthorizationStatus == .denied {
                locationDeniedRow
            }

            if let liveWind {
                liveWindRow(wind: liveWind)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.25), value: packet?.headline)
    }

    private func liveDistanceRow(distanceM: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(Int(distanceM.rounded())) m to pin")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityLabel("Live distance to pin: \(Int(distanceM.rounded())) meters")
    }

    private func liveWindRow(wind: WindContext) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wind")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(Int(wind.speedMps.rounded())) m/s \(wind.relativeDirection.rawValue)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityLabel("Live wind: \(Int(wind.speedMps.rounded())) meters per second, \(wind.relativeDirection.rawValue)")
    }

    private var locationDeniedRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.slash.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
            Text("Location permission denied — distances unavailable.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func confidenceChip(for band: String) -> some View {
        switch band {
        case "high":
            Text("High confidence")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green.opacity(0.18)))
                .foregroundStyle(.green)
                .accessibilityLabel("High confidence")
        case "low":
            Text("Best guess")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.18)))
                .foregroundStyle(.orange)
                .accessibilityLabel("Low confidence, best guess")
        default:
            EmptyView()
        }
    }
}
