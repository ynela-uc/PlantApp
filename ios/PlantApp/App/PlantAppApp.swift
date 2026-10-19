import SwiftUI

@main
struct PlantAppApp: App {
    @StateObject private var lang = LanguageStore()
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(lang)
                .environmentObject(app)
                .environment(\.layoutDirection, lang.language.layoutDirection)
                .tint(Theme.green)
                // The app's colours are designed for a light background; without this, dark mode
                // turns the text white on white cards.
                .preferredColorScheme(.light)
                .onOpenURL { app.handleAuthLink($0) }
        }
    }
}
