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
    // Brand colours: teal and sand, with one accent per service (flowers coral, plants green, gifts gold).
    // The names keep "green" for the main brand colour so existing screens pick up the new look unchanged.
    static let green = Color(hex: 0x0E6F73)
    static let greenDark = Color(hex: 0x0B4F52)
    static let greenSoft = Color(hex: 0xDCEEEE)
    static let amber = Color(hex: 0xB7791F)
    static let amberSoft = Color(hex: 0xFFF2DA)
    static let background = Color(hex: 0xF7F5EF)
    static let muted = Color(hex: 0x55706F)
    static let border = Color(hex: 0xE7E1D3)
    static let picture = Color(hex: 0xE8EFEC)
    static let flowerCoral = Color(hex: 0xF26B5B)
    static let flowerCoralSoft = Color(hex: 0xFEE9E5)
    static let leafGreen = Color(hex: 0x3FA56B)
    static let leafGreenSoft = Color(hex: 0xE1F3E8)
    static let giftGold = Color(hex: 0xF2B544)
    static let giftGoldSoft = Color(hex: 0xFFF1D3)

    /// The accent colour of a section (flowers / plants / gifts); the brand teal for anything else.
    static func sectionAccent(_ key: String?) -> Color {
        switch key {
        case "flowers": return flowerCoral
        case "plants": return leafGreen
        case "gifts": return giftGold
        default: return green
        }
    }

    static func sectionAccentSoft(_ key: String?) -> Color {
        switch key {
        case "flowers": return flowerCoralSoft
        case "plants": return leafGreenSoft
        case "gifts": return giftGoldSoft
        default: return greenSoft
        }
    }
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

/// Rounded card used across the app: Liquid Glass on iOS 26+, a white card with a thin border before that.
struct CardStyle: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content.modifier(GlassSurface(radius: radius))
    }
}

extension View {
    func card(radius: CGFloat = 16) -> some View { modifier(CardStyle(radius: radius)) }
}

/// Big rounded call-to-action button: tinted Liquid Glass on iOS 26+, a solid or outlined button before that.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.green
    var filled: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(filled ? Color.white : color)
            .modifier(
                GlassSurface(
                    radius: 16,
                    tint: filled ? color : nil,
                    interactive: true,
                    fallbackFill: filled ? color : Color.clear,
                    fallbackStroke: filled ? nil : color
                )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
                .modifier(
                    GlassSurface(
                        radius: 22,
                        tint: selected ? accent : nil,
                        interactive: true,
                        fallbackFill: selected ? accent : Color.white,
                        fallbackStroke: selected ? accent : Theme.border
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: selected)
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
