# PlantApp for iPhone (SwiftUI)

Same app as the Android one, same Supabase backend, same three languages (Arabic, Kurdish Sorani, English) with right-to-left layout.

## Build it on the Mac (first time)

1. Install Xcode from the App Store (16 or newer) and open it once so it finishes installing components.
2. Open Terminal and install XcodeGen (it turns `project.yml` into the Xcode project):
   ```
   brew install xcodegen
   ```
   (No Homebrew? Install it first from https://brew.sh)
3. In Terminal, go into this `ios` folder and generate the project:
   ```
   cd path/to/ios
   xcodegen generate
   open PlantApp.xcodeproj
   ```
4. In Xcode: click the **PlantApp** project (top of the left list) -> target **PlantApp** -> **Signing & Capabilities** -> tick *Automatically manage signing* -> **Team**: pick your Apple ID (Xcode > Settings > Accounts > add your Apple ID if it is not listed).
   If Xcode says the bundle id is taken, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (for example `com.plantapp.iraq.yourname`) and run `xcodegen generate` again.
5. Plug in the iPhone, unlock it, trust the Mac. Pick the iPhone in the device list at the top of Xcode and press **Run** (the play button).
6. First run on a personal Apple ID: on the iPhone go to Settings > General > VPN & Device Management > your Apple ID > Trust. Also turn on Developer Mode (Settings > Privacy & Security > Developer Mode) if iOS asks.
   Apps signed with a free Apple ID expire after 7 days; press Run again to renew.

The first build downloads the Supabase Swift package, so it needs internet.

## Layout

| Folder | What is in it |
|---|---|
| `PlantApp/App` | App entry, root switch, sign-in/session logic (`AppModel`) |
| `PlantApp/Core` | Config (Supabase URL + public key), theme, language store, generated strings, shared components, photo helpers |
| `PlantApp/Data` | Models (match the database) and services (auth, listings, orders, seller, AI) |
| `PlantApp/Auth` | Welcome (Customer / Seller choice + language picker), sign in / create account, password reset |
| `PlantApp/Customer` | Browse, plant page, cart, checkout, orders, photo approval, profile |
| `PlantApp/Seller` | Orders (accept, photo of prepared order, delivery), my plants with the AI camera editor, shop settings |

## Strings

All texts come from the Android string files, so both apps stay identical. After changing
`android/app/src/main/res/values*/strings.xml`, regenerate the Swift table:

```
python3 tools/generate_strings.py
```

## Password reset

The reset email opens `plantapp://auth-callback`. The URL scheme is registered in `project.yml`
(the link has to be opened on the iPhone itself, from the Mail app).
