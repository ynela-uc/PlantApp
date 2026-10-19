# PlantApp

A plant marketplace app for Iraq, built twice: natively for Android and for iPhone (SwiftUI). Same Supabase backend, same three languages (Arabic, Kurdish Sorani, English) with right-to-left layout, same string source of truth.

## Layout

| Folder | What is in it |
|---|---|
| `ios/` | The SwiftUI iPhone app. See [ios/README.md](ios/README.md). |
| `android/` | The native Android app. *(Not yet added to this repo — see below.)* |

## Why one repo

The iOS app's strings are generated *from* the Android app's `strings.xml` (`ios/tools/generate_strings.py`), so the two need to stay next to each other for that script to work, and so changes on either side are visible to whoever (or whichever AI session) is working on the other.

## Status

- `ios/`: builds and runs in the iOS Simulator. See `ios/project.yml` for notes on local-only build workarounds (a stand-in Supabase package, lowered deployment target) needed on the Mac this was set up on — restore the commented-out real values on a Mac with Xcode 16+.
- `android/`: empty placeholder. Whoever has the Android project should add it here (as `android/`) and push, so both sides of the app live in one place.
