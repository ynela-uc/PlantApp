import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let green = Color(hex: 0x2E7D32)
    static let greenDark = Color(hex: 0x1B5E20)
    static let greenSoft = Color(hex: 0xE3F2E3)
    static let amber = Color(hex: 0xB8860B)
    static let amberSoft = Color(hex: 0xFFF3E0)
    static let background = Color(hex: 0xF4FBF4)
    static let muted = Color(hex: 0x4E6E4F)
    static let border = Color(hex: 0xE0ECE0)
    static let picture = Color(hex: 0xE8F5E9)
    static let error = Color(hex: 0xC62828)
    static let errorSoft = Color(hex: 0xFFEBEE)
}

/// Emoji shown as the picture until a shop uploads a real photo.
func plantEmoji(_ key: String?) -> String {
    switch key {
    case "Cactus": return "🌵"
    case "Palm": return "🌴"
    case "Rose": return "🌹"
    case "Orchid": return "🌸"
    case "Jasmine": return "🌼"
    case "Bonsai": return "🌳"
    case "Mint", "Basil", "Fern": return "🌿"
    default: return "🪴"
    }
}

/// White rounded card with a thin border, used across the app.
struct CardStyle: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 1))
    }
}

extension View {
    func card(radius: CGFloat = 16) -> some View { modifier(CardStyle(radius: radius)) }
}

/// Big rounded call-to-action button.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.green
    var filled: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(filled ? Color.white : color)
            .background(filled ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? Color.clear : color, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

/// Small selectable pill (city, plant type, time window, ...).
struct Pill: View {
    let label: String
    let selected: Bool
    var accent: Color = Theme.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? Color.white : Color(hex: 0x333333))
                .background(selected ? accent : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping layout for pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
