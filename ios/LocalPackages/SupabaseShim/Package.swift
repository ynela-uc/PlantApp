// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SupabaseShim",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "Supabase", targets: ["Supabase"])
    ],
    targets: [
        .target(name: "Supabase")
    ]
)
