import SwiftUI
import TrueCaddieDomain

struct CaddieStatusPill: View {
    let holeNumber: Int
    let par: Int
    let remainingDistanceM: Double
    let lie: ShotLie
    let roundScoreVsPar: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("Hole \(holeNumber)")
                separator
                Text("Par \(par)")
                separator
                Text("\(Int(remainingDistanceM)) m")
                separator
                Text(lieLabel)
                separator
                Text(scoreLabel)
                    .monospacedDigit()
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Hole \(holeNumber), par \(par), \(Int(remainingDistanceM)) meters remaining, \(lieLabel), round \(scoreLabel). Tap to open Inspector."
        )
    }

    private var separator: some View {
        Text("·").foregroundStyle(.tertiary)
    }

    private var lieLabel: String { lie.rawValue.capitalized }

    private var scoreLabel: String {
        switch roundScoreVsPar {
        case ..<0: return "\(roundScoreVsPar)"
        case 0: return "E"
        default: return "+\(roundScoreVsPar)"
        }
    }
}
