// Supabase Edge Function: notify
//
// Sends a push notification (Firebase Cloud Messaging) about an order event. Called only by the database
// (see migration 015) with a shared secret; never by the apps.
//
// Input  (POST JSON, header x-notify-secret): { event: string, order_id: string }
// Events: new_order, order_reminder, photo_approved, photo_change (to the shop);
//         photo_ready, out_for_delivery, order_cancelled (to the customer).
//
// Secrets (Supabase -> Edge Functions -> Secrets):
//   NOTIFY_SECRET        same value as internal_config.notify_secret in the database
//   FCM_SERVICE_ACCOUNT  the whole JSON of the Firebase service-account key (Project settings -> Service accounts)
// Turn "Verify JWT" OFF for this function (the shared secret is the check).

import { createClient } from "npm:@supabase/supabase-js@2.115.0";

type Lang = "ar" | "ckb" | "en";
type Text = { title: string; body: string };

// {name} = the customer's name (for shops), {shop} = the shop's name (for customers).
const TEXTS: Record<string, Record<Lang, Text>> = {
  new_order: {
    ar: { title: "طلب جديد", body: "وصلك طلب جديد من {name}" },
    ckb: { title: "داواکارییەکی نوێ", body: "داواکارییەکی نوێت بۆ هاتووە لە {name}" },
    en: { title: "New order", body: "You have a new order from {name}" },
  },
  order_reminder: {
    ar: { title: "طلب ينتظرك", body: "طلب {name} ما زال ينتظر قبولك" },
    ckb: { title: "داواکارییەک چاوەڕێتە", body: "داواکارییەکەی {name} هێشتا چاوەڕێی قبوڵکردنتە" },
    en: { title: "An order is waiting", body: "{name}'s order is still waiting for you" },
  },
  photo_approved: {
    ar: { title: "وافق الزبون على الصورة", body: "يمكنك الآن إرسال طلب {name} للتوصيل" },
    ckb: { title: "کڕیار وێنەکەی پەسەند کرد", body: "ئێستا دەتوانیت داواکارییەکەی {name} بنێریت بۆ گەیاندن" },
    en: { title: "The customer approved the photo", body: "You can now send {name}'s order out for delivery" },
  },
  photo_change: {
    ar: { title: "الزبون طلب تعديلًا", body: "افتح طلب {name} لقراءة التعديل المطلوب" },
    ckb: { title: "کڕیار گۆڕانکارییەکی داوا کرد", body: "داواکارییەکەی {name} بکەرەوە بۆ خوێندنەوەی گۆڕانکارییەکە" },
    en: { title: "The customer asked for a change", body: "Open {name}'s order to read what to change" },
  },
  photo_ready: {
    ar: { title: "صورة طلبك جاهزة", body: "افتح الطلب لتوافق على الصورة قبل التوصيل" },
    ckb: { title: "وێنەی داواکارییەکەت ئامادەیە", body: "داواکارییەکە بکەرەوە و پێش گەیاندن وێنەکە پەسەند بکە" },
    en: { title: "Your order photo is ready", body: "Open the order to approve the photo before delivery" },
  },
  out_for_delivery: {
    ar: { title: "طلبك في الطريق", body: "{shop} أرسل طلبك للتوصيل" },
    ckb: { title: "داواکارییەکەت لە ڕێگایە", body: "{shop} داواکارییەکەتی نارد بۆ گەیاندن" },
    en: { title: "Your order is on its way", body: "{shop} sent your order out for delivery" },
  },
  order_cancelled: {
    ar: { title: "تعذّر تنفيذ طلبك", body: "اعتذر {shop} عن تنفيذ طلبك" },
    ckb: { title: "داواکارییەکەت جێبەجێ نەکرا", body: "{shop} ببورە لە جێبەجێکردنی داواکارییەکەت" },
    en: { title: "Your order could not be fulfilled", body: "{shop} had to cancel your order" },
  },
};

const FOR_SHOP = new Set(["new_order", "order_reminder", "photo_approved", "photo_change"]);

const NOTIFY_SECRET = Deno.env.get("NOTIFY_SECRET");
const SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT");

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
const textBase64url = (text: string) => base64url(new TextEncoder().encode(text));

/** Google OAuth access token for the Firebase service account (signed JWT exchange). */
async function accessToken(account: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = textBase64url(JSON.stringify({ alg: "RS256", typ: "JWT" })) + "." + textBase64url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = account.private_key.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: unsigned + "." + base64url(signature),
    }),
  });
  const data = await response.json();
  if (!data.access_token) throw new Error("no access token");
  return data.access_token;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method" }, 405);
  if (!NOTIFY_SECRET || request.headers.get("x-notify-secret") !== NOTIFY_SECRET) return json({ error: "unauthorized" }, 401);
  if (!SERVICE_ACCOUNT) return json({ error: "fcm_not_configured" }, 503);

  let payload: { event?: string; order_id?: string };
  try { payload = await request.json(); } catch { return json({ error: "bad_request" }, 400); }
  const event = payload.event ?? "";
  const texts = TEXTS[event];
  if (!texts || !payload.order_id) return json({ error: "bad_request" }, 400);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: order } = await db
    .from("orders")
    .select("id, buyer_id, buyer_name, seller_name, sellers(owner_id)")
    .eq("id", payload.order_id)
    .maybeSingle();
  if (!order) return json({ error: "order_not_found" }, 404);

  // deno-lint-ignore no-explicit-any
  const ownerId = (order as any).sellers?.owner_id as string | null;
  const recipient = FOR_SHOP.has(event) ? ownerId : order.buyer_id;
  if (!recipient) return json({ sent: 0, reason: "no_recipient" });

  const { data: devices } = await db.from("device_tokens").select("token, platform, language").eq("user_id", recipient);
  if (!devices || devices.length === 0) return json({ sent: 0, reason: "no_devices" });

  const account = JSON.parse(SERVICE_ACCOUNT);
  const token = await accessToken(account);
  const channel = FOR_SHOP.has(event) ? "new_orders" : "order_updates";
  let sent = 0;

  for (const device of devices) {
    const lang: Lang = (["ar", "ckb", "en"].includes(device.language) ? device.language : "ar") as Lang;
    const text = texts[lang];
    const fill = (s: string) => s.replace("{name}", order.buyer_name || "").replace("{shop}", order.seller_name || "");
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: { title: fill(text.title), body: fill(text.body) },
          data: { event, order_id: order.id },
          android: { priority: "HIGH", notification: { channel_id: channel, sound: "default" } },
          apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
        },
      }),
    });
    if (response.ok) {
      sent++;
    } else {
      const error = await response.json().catch(() => ({}));
      const status = error?.error?.status;
      // A token that is no longer valid (app removed, reinstalled): forget it.
      if (status === "NOT_FOUND" || status === "UNREGISTERED") {
        await db.from("device_tokens").delete().eq("token", device.token);
      }
    }
  }
  return json({ sent, devices: devices.length });
});
