# Map pin setup (Google Maps for Android)

"Use my current location" works without any setup (it only needs the GPS permission). The full-screen "Choose on the map"
screen needs a Google Maps key. Without a key the app still builds and runs; the map button is greyed out with a note.
The iPhone app uses Apple Maps, which needs no key and no account.

## One-time steps (Android)

1. **Google Cloud project.** https://console.cloud.google.com -> sign in -> create a project ("PlantApp").
2. **Billing.** Billing -> link a billing account (a card is required by Google, even for free use).
   Then set a budget alert (Billing -> Budgets & alerts), for example 5 USD, so you are told about any cost.
3. **Turn on the API.** APIs & Services -> Library -> "Maps SDK for Android" -> Enable.
4. **Create the key.** APIs & Services -> Credentials -> Create credentials -> API key.
5. **Restrict the key** (important: it ends up inside the app):
   - Application restrictions: Android apps -> Add: package name `com.plantapp.iraq`, SHA-1 fingerprint
     `9F:8A:86:6F:D3:3D:33:53:F5:D5:E6:9A:63:B1:FB:36:0F:D5:F5:DC` (this is the debug certificate on this PC).
     The release/Play Store certificate gets added later as a second row.
   - API restrictions: Restrict key -> only "Maps SDK for Android".
6. **Give the key to the build.** Create (or edit) `android/local.properties` and add one line:

       MAPS_API_KEY=your_key_here

   The file is ignored by git (it stays on this PC). Then rebuild the app.

## Cost

Google lists the mobile Maps SDK as free for any number of map loads. The paid products are things this app does not use
(address search, geocoding, directions). Navigation to the shop or customer opens the phone's own maps app.

## Before publishing

Add the SHA-1 of the Play Store signing certificate to the key's Android restriction, otherwise the map is blank in the
store version.
