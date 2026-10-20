// Supabase Edge Function: plant-assistant (the "Smart Guide" inside the app)
//
// A helper for everyone (customers and sellers) in a marketplace for flowers, plants and gifts: identify a plant
// or flower from a photo, say whether it looks healthy, give care advice, suggest gift ideas for an occasion and
// budget, name the plant in all three app languages so the app can find shops that sell it, and say which part of
// the marketplace to browse (section, category, occasion).
//
// Input  (POST JSON):
//   { language: "en" | "ar" | "ckb",
//     messages: [ { role: "user" | "assistant", text: string }, ... ],   // last one must be "user"
//     image_base64?: string, media_type?: "image/jpeg" | "image/png" | "image/webp" }  // belongs to the last user message
// Output (JSON): see SCHEMA below. Errors: { error: "<code>" } with a matching HTTP status:
//   unauthorized 401, ai_not_configured 503, daily_limit 429 (messages), photo_limit 429 (photos),
//   bad_request 400, bad_image 400, refused 422, server_error 500.
//
// Secrets (Supabase -> Edge Functions -> Secrets): ANTHROPIC_API_KEY (required), AI_MODEL (optional).
// Any signed-in user may call it, with daily limits per user so a leaked app cannot run up the bill.

import Anthropic from "npm:@anthropic-ai/sdk@0.135.0";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";

const DAILY_MESSAGE_LIMIT = 40; // all calls in 24 h
const DAILY_PHOTO_LIMIT = 12; // calls with a photo in 24 h
const MAX_MESSAGES = 12;
const MAX_TEXT_CHARS = 1000;
const MAX_IMAGE_BASE64_CHARS = 6_000_000; // ~4.5 MB of image data
const MODEL = Deno.env.get("AI_MODEL") ?? "claude-haiku-5-5";

// Keys of the marketplace catalog (see docs/categories.md).
const CATEGORIES = {
  flowers: ["bouquets", "roses", "flower_boxes", "baskets", "weddings_events", "condolence", "dried_preserved", "artificial_flowers"],
  plants: ["indoor", "outdoor", "succulents_cacti", "flowering", "trees_palms", "herbs", "bonsai_orchids", "soil", "fertilizer", "pots", "tools", "pest_care", "seeds_bulbs"],
  gifts: ["gift_sets", "chocolate_sweets", "cakes", "personalised", "home_decor", "candles_fragrance", "cards_wrapping", "plush_toys", "accessories_jewelry", "balloons_party"],
};
const ALL_CATEGORIES = [...CATEGORIES.flowers, ...CATEGORIES.plants, ...CATEGORIES.gifts];
const OCCASIONS = [
  "birthday", "anniversary", "love", "new_baby", "get_well", "congratulations", "new_home",
  "graduation", "wedding", "condolence", "mothers_day", "eid", "nowruz", "thank_you",
];

const PLANT_KEYS = [
  "Monstera", "Snake Plant", "Pothos", "Ficus", "Cactus", "Succulents", "Aloe Vera", "Palm",
  "Rubber Plant", "Peace Lily", "Fern", "Jasmine", "Rose", "Mint", "Basil", "Bonsai", "Orchid",
];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const tri = {
  type: "object",
  properties: { en: { type: "string" }, ar: { type: "string" }, ckb: { type: "string" } },
  required: ["en", "ar", "ckb"],
  additionalProperties: false,
};

const SCHEMA = {
  type: "object",
  properties: {
    // The plant being discussed (from the photo or from the conversation). identified=false when unknown.
    identified: { type: "boolean" },
    confidence: { type: "string", enum: ["high", "medium", "low"] },
    plant_key: { type: "string", enum: [...PLANT_KEYS, "Other"] },
    scientific_name: { type: "string" },
    names: tri,
    // Health of the plant in the photo: unknown when there is no photo or no plant in it.
    health: { type: "string", enum: ["healthy", "needs_attention", "unhealthy", "unknown"] },
    // The reply to show, in the user's language, plain text.
    answer: { type: "string" },
    // Up to three short questions the user may want to ask next, in the user's language.
    follow_ups: { type: "array", items: { type: "string" } },
    // What to show in the shop: the part of the marketplace that best matches the question ("" when nothing fits).
    browse_section: { type: "string", enum: ["", "flowers", "plants", "gifts"] },
    browse_category: { type: "string", enum: ["", ...ALL_CATEGORIES] },
    browse_occasion: { type: "string", enum: ["", ...OCCASIONS] },
  },
  required: [
    "identified", "confidence", "plant_key", "scientific_name", "names", "health", "answer", "follow_ups",
    "browse_section", "browse_category", "browse_occasion",
  ],
  additionalProperties: false,
};

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  ar: "Modern Standard Arabic",
  ckb: "Central Kurdish (Sorani, Arabic script)",
};

const SYSTEM = [
  "You are the Smart Guide inside a marketplace app for flowers, plants and gifts in Iraq (hot dry summers, strong sun, hard tap water, cool winters in the north).",
  "People use you to: identify a plant or flower from a photo, learn how to care for it or what is wrong with it, get gift ideas for an occasion, a person or a budget, and find what to buy.",
  "",
  "Rules:",
  "- Write the answer and follow_ups in the language requested in the user's message. names must have all three languages (en, ar, ckb).",
  "- Arabic (ar) must read naturally to Iraqi shoppers: warm, simple, friendly Modern Standard Arabic like a good shopping app, with short sentences; never stiff, literal or machine-translated. Use everyday words such as بيت and عرس where natural.",
  "- Keep the answer short and practical: at most about 120 words, plain text, no markdown, no bullet symbols; use short sentences or numbered steps written as 1) 2) 3).",
  "- When a photo shows a plant or flower, identify it (identified=true). When it also shows problems (yellow or brown leaves, spots, wilting, pests, rot, dry soil), say what is most likely wrong and what to do now, and set health to needs_attention or unhealthy. Otherwise set health to healthy.",
  '- With no photo, or when the question is not about one specific plant, set identified=false and health to "unknown" and plant_key=Other with empty strings; do not ask for a photo unless a photo would really help. If the conversation already established a plant, keep describing that plant in identified/plant_key/scientific_name/names.',
  "- If a photo was sent but you cannot tell which plant it is, set identified=false and say so kindly in the answer; ask for a clearer photo of the leaves or the whole plant.",
  "- plant_key: the closest key from the allowed list, or Other. Never invent facts; say when you are unsure and what you would check.",
  "- Gift and shopping questions (a gift for someone, an occasion, a budget, what to buy): suggest 2 to 4 concrete ideas in the answer, matched to the person, the occasion and the budget in Iraqi dinar (IQD). Do not name shops, brands or prices of specific products; the app shows real products itself.",
  "- browse_section, browse_category and browse_occasion: the part of the marketplace that best matches the question so the app can show matching products. Use an empty string for each one that does not clearly apply. A category must belong to its section. Sections and categories: flowers: " + CATEGORIES.flowers.join(", ") + "; plants (including supplies like soil, fertilizer, pots, tools): " + CATEGORIES.plants.join(", ") + "; gifts and decor: " + CATEGORIES.gifts.join(", ") + ". Occasions: " + OCCASIONS.join(", ") + ".",
  "- Mention if a plant is toxic to cats, dogs or children when that matters. For serious or spreading plant problems, suggest showing the plant to a local nursery.",
  "- Only help with plants, flowers, gardening, plant care, gifts, decor and choosing what to buy in this app. Politely decline anything else in one sentence.",
].join("\n");

type Msg = { role: "user" | "assistant"; text: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");

    // 1. Who is calling? Any signed-in user.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: userData } = await userClient.auth.getUser();
    const user = userData?.user;
    if (!user) return json({ error: "unauthorized" }, 401);

    if (!apiKey) return json({ error: "ai_not_configured" }, 503);

    // 2. Validate the request.
    const body = await req.json();
    const language: string = LANGUAGE_NAMES[body?.language] ? body.language : "en";
    const rawMessages: unknown = body?.messages;
    if (!Array.isArray(rawMessages) || rawMessages.length === 0) return json({ error: "bad_request" }, 400);
    const messages: Msg[] = rawMessages.slice(-MAX_MESSAGES).map((m: any) => ({
      role: m?.role === "assistant" ? "assistant" : "user",
      text: String(m?.text ?? "").slice(0, MAX_TEXT_CHARS),
    }));
    // The conversation must start with a user message and end with one.
    while (messages.length > 0 && messages[0].role !== "user") messages.shift();
    if (messages.length === 0 || messages[messages.length - 1].role !== "user") return json({ error: "bad_request" }, 400);

    const imageData: string = body?.image_base64 ?? "";
    const mediaType: string = body?.media_type ?? "image/jpeg";
    const hasImage = imageData.length > 0;
    if (hasImage) {
      if (imageData.length > MAX_IMAGE_BASE64_CHARS) return json({ error: "bad_image" }, 400);
      if (!["image/jpeg", "image/png", "image/webp"].includes(mediaType)) return json({ error: "bad_image" }, 400);
    } else if (messages[messages.length - 1].text.trim().length === 0) {
      return json({ error: "bad_request" }, 400);
    }

    // 3. Daily limits per user.
    const admin = createClient(url, service);
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { count: total } = await admin.from("ai_assistant_calls")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id).gte("created_at", since);
    if ((total ?? 0) >= DAILY_MESSAGE_LIMIT) return json({ error: "daily_limit" }, 429);
    if (hasImage) {
      const { count: photos } = await admin.from("ai_assistant_calls")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id).eq("has_image", true).gte("created_at", since);
      if ((photos ?? 0) >= DAILY_PHOTO_LIMIT) return json({ error: "photo_limit" }, 429);
    }

    // 4. Build the conversation. The photo (if any) goes with the last user message.
    const last = messages.length - 1;
    const apiMessages = messages.map((m, i) => {
      const isLast = i === last;
      const text = isLast ? "Reply in " + LANGUAGE_NAMES[language] + ".\n\n" + (m.text.trim() || "What plant is this and how do I care for it?") : m.text;
      if (isLast && hasImage) {
        return {
          role: m.role,
          content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: imageData } },
            { type: "text", text },
          ],
        };
      }
      return { role: m.role, content: text.length > 0 ? text : "(photo)" };
    });

    // 5. Ask Claude. Structured outputs guarantee the reply matches SCHEMA.
    const client = new Anthropic({ apiKey });
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 8000, // thinking tokens count against this; a too-small cap truncated the JSON reply
      system: SYSTEM,
      output_config: { effort: hasImage ? "medium" : "low", format: { type: "json_schema", schema: SCHEMA } },
      messages: apiMessages,
    });

    if (response.stop_reason === "refusal") return json({ error: "refused" }, 422);
    if (response.stop_reason === "max_tokens") return json({ error: "too_long" }, 502);
    const textBlock = response.content.find((b) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") return json({ error: "no_result" }, 502);
    const result = JSON.parse(textBlock.text);

    await admin.from("ai_assistant_calls").insert({ user_id: user.id, has_image: hasImage });
    return json(result);
  } catch (e) {
    console.error("plant-assistant failed", e);
    return json({ error: "server_error" }, 500);
  }
});
