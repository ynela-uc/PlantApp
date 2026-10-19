# PlantApp

A plant marketplace app for Iraq, built twice: natively for Android and for iPhone (SwiftUI). Same Supabase backend, same three languages (Arabic, Kurdish Sorani, English) with right-to-left layout, same string source of truth.

## Layout

| Folder | What is in it |
|---|---|
| `ios/` | The SwiftUI iPhone app. See [ios/README.md](ios/README.md). |
| `android/` | The native Android app (Kotlin/Jetpack Compose). |
| `supabase/` | The shared backend: edge functions and SQL migrations. |

## Why one repo

The iOS app's strings are generated *from* the Android app's `strings.xml` (`ios/tools/generate_strings.py`), so the two need to stay next to each other for that script to work, and so changes on either side are visible to whoever (or whichever AI session) is working on the other.

## Status

- `ios/`: builds and runs in the iOS Simulator, verified against the real Supabase backend (live sign-in/data calls, not mocked). On the Mac this was set up on (Xcode 14.2, macOS 12 Monterey, too old for the official `supabase-swift` package), `ios/project.yml` points at a hand-written Supabase REST client in `ios/LocalPackages/SupabaseShim` instead — see the comments there. Works on any Xcode version.
- `android/`: builds clean (`gradlew assembleDebug`).
