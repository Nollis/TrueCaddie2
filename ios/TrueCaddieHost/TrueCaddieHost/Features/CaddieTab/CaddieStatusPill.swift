import SwiftUI
import TrueCaddieDomain

struct CaddieStatusPill: View {
    let holeNumber: Int
    let par: Int
    let remainingDistanceM: Double
    let lie: ShotLie
    let roundScoreVsPar: Int
    /// When non-nil the pill renders as a tappable button with a disclosure
    /// chevron.  Pass `nil` when the Inspector tab is hidden.
    let onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                pillContent(showChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Hole \(holeNumber), par \(par), \(Int(remainingDistanceM)) meters remaining, \(lieLabel), round \(scoreLabel). Tap to open Inspector."
            )
        } else {
            pillContent(showChevron: false)
                .accessibilityLabel(
                    "Hole \(holeNumber), par \(par), \(Int(remainingDistanceM)) meters remaining, \(lieLabel), round \(scoreLabel)."
                )
        }
    }

    private func pillContent(showChevron: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Hole \(holeNumber)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    scoreBadge
                }

                HStack(spacing: 6) {
                    metricChip("Par \(par)")
                    metricChip("\(Int(remainingDistanceM.rounded())) m")
                    metricChip(lieLabel)
                }
            }

            Spacer(minLength: 0)

            if showChevron {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func metricChip(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
    }

    private var scoreBadge: some View {
        Text(scoreLabel)
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(scoreColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(scoreColor.opacity(0.14))
            )
    }

    private var lieLabel: String { lie.rawValue.capitalized }

    private var scoreLabel: String {
        switch roundScoreVsPar {
        case ..<0: return "\(roundScoreVsPar)"
        case 0: return "E"
        default: return "+\(roundScoreVsPar)"
        }
    }

    private var scoreColor: Color {
        switch roundScoreVsPar {
        case ..<0:
            return .green
        case 0:
            return .secondary
        default:
            return .orange
        }
    }
}
