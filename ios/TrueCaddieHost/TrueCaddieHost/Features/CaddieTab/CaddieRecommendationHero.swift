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
        VStack(alignment: .leading, spacing: 18) {
            if let packet {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let livePinDistanceM {
                            distanceHero(distanceM: livePinDistanceM)
                        }

                        if let clubLabel = clubLabel(from: packet.headline) {
                            Text(clubLabel)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.12))
                                )
                        }

                        Text(targetHeadline(from: packet.headline))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !packet.executionNote.isEmpty {
                            Text(packet.executionNote)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                    confidenceChip(for: packet.confidenceBand)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ready for the next shot")
                        .font(.title2.weight(.bold))
                    Text(emptyStateText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if packet == nil, let livePinDistanceM {
                liveDistanceRow(distanceM: livePinDistanceM)
            } else if let locationAuthorizationStatus, locationAuthorizationStatus == .denied {
                locationDeniedRow
            }

            HStack(spacing: 10) {
                if let liveWind {
                    liveWindRow(wind: liveWind)
                }
                if packet != nil, let livePinDistanceM {
                    liveDistanceRow(distanceM: livePinDistanceM)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .secondarySystemBackground),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .accessibilityLabel("Live wind: \(Int(wind.speedMps.rounded())) meters per second, \(wind.relativeDirection.rawValue)")
    }

    private func distanceHero(distanceM: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(distanceM.rounded()))")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("m")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("to pin")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(distanceM.rounded())) meters to pin")
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.16)))
                .foregroundStyle(.green)
                .accessibilityLabel("High confidence")
        case "low":
            Text("Best guess")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(0.16)))
                .foregroundStyle(.orange)
                .accessibilityLabel("Low confidence, best guess")
        default:
            EmptyView()
        }
    }

    private func clubLabel(from headline: String) -> String? {
        if let range = headline.range(of: " toward ") {
            return String(headline[..<range.lowerBound])
        }
        if let range = headline.range(of: " to ") {
            return String(headline[..<range.lowerBound])
        }
        return nil
    }

    private func targetHeadline(from headline: String) -> String {
        if let range = headline.range(of: " toward ") {
            return String(headline[range.upperBound...])
        }
        if let range = headline.range(of: " to ") {
            return String(headline[range.upperBound...])
        }
        return headline
    }
}
