import SwiftUI
import TrueCaddieDomain

struct CaddieRecommendationHero: View {
    let packet: NextShotRecommendationPacket?
    let emptyStateText: String

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
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.25), value: packet?.headline)
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
