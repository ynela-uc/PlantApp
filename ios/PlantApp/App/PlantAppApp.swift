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
                .onOpenURL { app.handleAuthLink($0) }
        }
    }
}
