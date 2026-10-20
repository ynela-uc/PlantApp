# Push notifications: setup

What is built: when an order changes, the database calls the `notify` edge function, which sends a push through Firebase
Cloud Messaging to the right phone.

| Event | Who gets it | Android sound |
|---|---|---|
| New order | the shop | loud, vibrating channel |
| Order still waiting after 10 minutes (one reminder) | the shop | loud, vibrating channel |
| Customer approved the photo / asked for a change | the shop | loud, vibrating channel |
| Photo ready to approve, on its way, could not be fulfilled | the customer | normal |

Nothing is sent until the steps below are done. The apps still build and run without them.

## 1. Firebase (once, about 10 minutes, free)
1. Go to https://console.firebase.google.com, **Add project**, name it, turn Google Analytics off, **Create**.
2. **Add app -> Android**. Package name: `com.plantapp.iraq` (change it here too if the app id ever changes). Register.
3. Download `google-services.json` and put it in `android/app/` (next to `build.gradle.kts`). It is safe to commit.
4. **Project settings -> Service accounts -> Generate new private key**. A JSON file downloads. This is a secret:
   never commit it and do not paste it in chat.

## 2. Supabase
1. **Edge Functions -> Secrets**, add:
   - `FCM_SERVICE_ACCOUNT`: paste the whole content of the JSON file from step 1.4.
   - `NOTIFY_SECRET`: any long random text (the same value is stored in the database, see 3).
2. Deploy `supabase/functions/notify/index.ts` as a function named `notify`, with **Verify JWT turned OFF**
   (the shared secret is the check).
3. Run `supabase/migrations/015_push_notifications.sql`, then once, with your own secret value:
   `insert into internal_config (key, value) values ('notify_secret', '<same value as NOTIFY_SECRET>');`

## 3. Test
Sign in as a shop on a phone (allow notifications), place an order as a customer from another account: the shop phone should ring.
Leave an order unopened for 10 minutes: a reminder arrives. The function's Logs tab shows every call.

## iPhone
Push on iPhone needs a paid Apple Developer account ($99 per year): an APNs key uploaded to Firebase, a signed app with the
Push Notifications capability, and the Firebase iOS SDK. A free account and Sideloadly cannot do it. Until then iPhone shops
rely on the in-app alert while the app is open.
