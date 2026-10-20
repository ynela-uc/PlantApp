import Foundation

/// Public configuration. The anon key is safe to ship: Row Level Security protects the data.
enum Config {
    static let supabaseURL = URL(string: "https://uspzexcaiwavtpbfskta.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzcHpleGNhaXdhdnRwYmZza3RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc1ODIyNzAsImV4cCI6MjEwMzE1ODI3MH0.RuUATH9_wJTOmFwXus6gC2UMBT8YcC-RwwrCT4Smg9Q"

    /// Password-reset emails open the app through this link.
    static let authScheme = "plantapp"
    static let authHost = "auth-callback"
    static var authRedirectURL: URL { URL(string: "\(authScheme)://\(authHost)")! }
}

/// City codes as stored in the database (English names), in display order.
enum Cities {
    static let codes = ["Baghdad", "Erbil", "Basra", "Mosul", "Najaf", "Sulaymaniyah", "Karbala", "Duhok",
                        "Kirkuk", "Anbar", "Babil", "Diyala", "Wasit", "Maysan", "DhiQar", "Muthanna", "Qadisiyah", "SalahAlDin", "Halabja"]
}
