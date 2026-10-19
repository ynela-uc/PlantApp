import SwiftUI

/// The three app languages. Switching is instant (no restart) and flips the layout direction.
enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case kurdish = "ckb" // Central Kurdish (Sorani), Arabic script, right-to-left
    case english = "en"

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .arabic: return "العربية"
        case .kurdish: return "کوردی"
        case .english: return "English"
        }
    }
    var isRTL: Bool { self != .english }
    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
}

@MainActor
final class LanguageStore: ObservableObject {
    private static let key = "plantapp_language"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.key), let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            let device = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if device.hasPrefix("ar") { language = .arabic }
            else if device.hasPrefix("ckb") || device.hasPrefix("ku") { language = .kurdish }
            else { language = .english }
        }
    }

    /// Looks up a UI string; extra arguments fill %1$@ / %1$ld placeholders.
    func t(_ key: String, _ args: CVarArg...) -> String {
        let entry = GeneratedStrings.table[key]
        let text = entry?[language.rawValue] ?? entry?["en"] ?? key
        if args.isEmpty { return text }
        return String(format: text, locale: Locale(identifier: language.rawValue), arguments: args)
    }

    /// Picks the right language from a map of texts (en / ar / ckb); falls back sensibly when one is missing.
    func localized(_ map: [String: String]) -> String {
        if let exact = map[language.rawValue], !exact.isEmpty { return exact }
        if language == .kurdish, let ar = map["ar"], !ar.isEmpty { return ar }
        if let en = map["en"], !en.isEmpty { return en }
        if let ar = map["ar"], !ar.isEmpty { return ar }
        return map.values.first(where: { !$0.isEmpty }) ?? ""
    }

    func cityName(_ code: String) -> String {
        let key = "city_" + code.lowercased()
        return GeneratedStrings.table[key] == nil ? code : t(key)
    }

    func price(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: language.rawValue)
        let number = formatter.string(from: NSNumber(value: amount)) ?? String(amount)
        return t("price_format", number)
    }
}
