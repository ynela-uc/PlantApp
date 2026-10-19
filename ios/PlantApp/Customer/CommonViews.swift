import SwiftUI

/// "← Back" button that points the right way in right-to-left languages.
struct BackButton: View {
    @EnvironmentObject var lang: LanguageStore
    @Environment(\.layoutDirection) private var direction
    var accent: Color = Theme.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(lang.t("back"), systemImage: direction == .rightToLeft ? "arrow.right" : "arrow.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .modifier(GlassSurface(radius: 22, interactive: true, fallbackFill: Color.clear, fallbackStroke: nil))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .zIndex(1)
    }
}

/// Section title used inside forms and detail pages.
struct SectionHeading: View {
    let text: String
    var topPadding: CGFloat = 24

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.greenDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
            .padding(.bottom, 10)
    }
}

/// Small pill showing whether a shop delivers nationwide or only locally.
struct DeliveryBadge: View {
    @EnvironmentObject var lang: LanguageStore
    let shop: SellerInfo?

    var body: some View {
        let nationwide = shop?.isNationwide == true
        Text(lang.t(nationwide ? "delivers_nationwide" : "delivers_local"))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(nationwide ? Theme.greenDark : Theme.amber)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(nationwide ? Theme.greenSoft : Theme.amberSoft)
            .clipShape(Capsule())
    }
}

struct StatusChip: View {
    @EnvironmentObject var lang: LanguageStore
    let status: OrderStatus

    var body: some View {
        let cancelled = status == .cancelled
        Text(lang.t(status.labelKey))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(cancelled ? Theme.error : Theme.greenDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(cancelled ? Theme.errorSoft : Theme.greenSoft)
            .clipShape(Capsule())
    }
}

struct TimelineRow: View {
    let label: String
    let done: Bool
    let current: Bool
    let last: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(done ? Theme.green : Color(hex: 0xD0D8D0))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: current ? 22 : 18, height: current ? 22 : 18)
                if !last {
                    Rectangle()
                        .fill(done ? Theme.green : Color(hex: 0xD0D8D0))
                        .frame(width: 2, height: 22)
                }
            }
            Text(label)
                .font(.system(size: 16, weight: current ? .bold : .regular))
                .foregroundStyle(done ? Theme.greenDark : Theme.muted)
        }
    }
}

/// Label on the left, value on the right.
struct TotalRow: View {
    let label: String
    let value: String
    var bold = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(.system(size: 16, weight: bold ? .bold : .regular))
    }
}

func windowLabelKey(_ window: String) -> String {
    switch window {
    case "morning": return "window_morning"
    case "afternoon": return "window_afternoon"
    case "evening": return "window_evening"
    default: return "window_any"
    }
}
