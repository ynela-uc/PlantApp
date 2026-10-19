import SwiftUI

// Liquid Glass (iOS 26+) with a clean fallback for older iPhones.
//
// The glass APIs only exist in the iOS 26 SDK (Xcode 26, Swift 6.2). `#if compiler(>=6.2)` keeps the
// project compiling on older Xcode versions; `#available` keeps it running on older iOS versions.

extension Theme {
    /// Page-to-page slide used for full-screen pages that open on top of the tabs.
    static let slide = Animation.spring(response: 0.38, dampingFraction: 0.88)
}

/// Soft green gradient with a few blurred colour blobs: gives the glass something to refract.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xE2F3E2), Color(hex: 0xF4FBF4), Color(hex: 0xE8F2E8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                Circle()
                    .fill(Theme.green.opacity(0.20))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 70)
                    .position(x: w * 0.05, y: h * 0.10)
                Circle()
                    .fill(Color(hex: 0x9CCB86).opacity(0.28))
                    .frame(width: w * 0.8, height: w * 0.8)
                    .blur(radius: 70)
                    .position(x: w * 0.95, y: h * 0.55)
                Circle()
                    .fill(Theme.amber.opacity(0.10))
                    .frame(width: w * 0.7, height: w * 0.7)
                    .blur(radius: 70)
                    .position(x: w * 0.2, y: h * 0.95)
            }
        }
        .ignoresSafeArea()
    }
}

/// A rounded surface: Liquid Glass on iOS 26+, a plain filled card before that.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 16
    var tint: Color?
    var interactive = false
    var fallbackFill: Color = .white
    var fallbackStroke: Color? = Theme.border

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(Self.glass(tint: tint, interactive: interactive), in: .rect(cornerRadius: radius))
        } else {
            legacy(content)
        }
        #else
        legacy(content)
        #endif
    }

    private func legacy(_ content: Content) -> some View {
        content
            .background(fallbackFill)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(fallbackStroke ?? Color.clear, lineWidth: 1)
            )
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
    #endif
}

/// Bottom action bar: a floating glass panel on iOS 26+, a white bar with a soft shadow before that.
struct GlassBar: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
        } else {
            content.background(Color.white.shadow(color: .black.opacity(0.08), radius: 6, y: -2))
        }
        #else
        content.background(Color.white.shadow(color: .black.opacity(0.08), radius: 6, y: -2))
        #endif
    }
}

/// Swipe in from the leading screen edge to go back (left edge in English, right edge in Arabic and Kurdish).
private struct EdgeSwipeBack: ViewModifier {
    @Environment(\.layoutDirection) private var direction
    let action: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .global).onEnded { value in
                let width = UIScreen.main.bounds.width
                let rtl = direction == .rightToLeft
                let startsAtEdge = rtl ? value.startLocation.x > width - 28 : value.startLocation.x < 28
                let travel = rtl ? -value.translation.width : value.translation.width
                if startsAtEdge && travel > 70 && abs(value.translation.height) < 90 { action() }
            }
        )
    }
}

extension View {
    func glassCard(radius: CGFloat = 16) -> some View { modifier(GlassSurface(radius: radius)) }
    func glassBar() -> some View { modifier(GlassBar()) }
    func edgeSwipeBack(_ action: @escaping () -> Void) -> some View { modifier(EdgeSwipeBack(action: action)) }

    /// On iOS 26 the tab bar shrinks out of the way while scrolling down.
    @ViewBuilder
    func glassTabBar() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
