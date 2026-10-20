// Supabase Edge Function: identify-plant
//
// Input  (POST JSON): { image_base64: string, media_type?: "image/jpeg" | "image/png" | "image/webp" }
// Output (JSON): see PlantSuggestion below. Errors: { error: "<code>" } with a matching HTTP status.
//
// Secrets (Supabase -> Edge Functions -> Secrets): ANTHROPIC_API_KEY (required), AI_MODEL (optional).
// Only signed-in sellers may call it, with a daily limit per user, so a leaked app cannot run up the bill.

import Anthropic from "npm:@anthropic-ai/sdk@0.135.0";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";

const DAILY_LIMIT = 40;
const MAX_IMAGE_BASE64_CHARS = 6_000_000; // ~4.5 MB of image data
const MODEL = Deno.env.get("AI_MODEL") ?? "claude-haiku-5-5";

const PLANT_KEYS = [
  "Monstera", "Snake Plant", "Pothos", "Ficus", "Cactus", "Succulents", "Aloe Vera", "Palm",
  "Rubber Plant", "Peace Lily", "Fern", "Jasmine", "Rose", "Mint", "Basil", "Bonsai", "Orchid",
];

// The marketplace sells flowers, plants (and plant supplies) and gifts. Keys match docs/categories.md.
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

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// A string in each app language.
const tri = {
  type: "object",
  properties: { en: { type: "string" }, ar: { type: "string" }, ckb: { type: "string" } },
  required: ["en", "ar", "ckb"],
  additionalProperties: false,
};

const SCHEMA = {
  type: "object",
  properties: {
    identified: { type: "boolean" },
    confidence: { type: "string", enum: ["high", "medium", "low"] },
    plant_key: { type: "string", enum: [...PLANT_KEYS, "Other"] },
    scientific_name: { type: "string" },
    name: tri,
    description: tri,
    care: {
      type: "object",
      properties: { water: tri, light: tri, fertilizer: tri },
      required: ["water", "light", "fertilizer"],
      additionalProperties: false,
    },
    height_cm: { type: "integer" },
    section: { type: "string", enum: ["flowers", "plants", "gifts"] },
    category: { type: "string", enum: ALL_CATEGORIES },
    occasions: { type: "array", items: { type: "string", enum: OCCASIONS } },
  },
  required: [
    "identified", "confidence", "plant_key", "scientific_name",
    "name", "description", "care", "height_cm", "section", "category", "occasions",
  ],
  additionalProperties: false,
};

const SYSTEM = [
  "You help shop owners in Iraq (flower shops, plant shops and gift and decor shops) create product listings from a photo.",
  "Look at the photo and identify the product: a plant, a flower arrangement, or a gift or decor item (candles, plush toys, cakes, balloons, jewelry, pots, soil, tools, and so on). Write practical details for a customer buying it.",
  "",
  "Rules:",
  "- Give every text in three languages: en (English), ar (Modern Standard Arabic), ckb (Central Kurdish / Sorani, Arabic script).",
  '- "name" is the common name a shopper would search for. "description" is 1-2 friendly sentences. Each care tip is one short sentence with numbers where useful (how often, how much light).',
  '- plant_key: use the closest key from the allowed list, or "Other" if none fits.',
  "- height_cm is your best estimate of the plant's current height from the photo, or 0 if you cannot tell.",
  "- section is flowers, plants or gifts; plant supplies (soil, fertilizer, pots, tools, pest control, seeds, bulbs) belong to plants. category must be a key that belongs to that section: flowers: " + CATEGORIES.flowers.join(", ") + "; plants: " + CATEGORIES.plants.join(", ") + "; gifts: " + CATEGORIES.gifts.join(", ") + ".",
  "- occasions: the occasions this product suits best (0 to 4), from the allowed list.",
  "- For anything that is not a living plant (flowers arrangements, gifts, decor, supplies): plant_key=Other, scientific_name is an empty string, height_cm is 0, and the care texts are empty strings.",
  '- If the photo does not clearly show a plant, flowers or a gift or decor item, set identified=false, confidence="low", plant_key="Other", section="plants", category="indoor", occasions=[], and use empty strings and 0 for the rest.',
  "- Never invent facts you cannot support; if unsure of the species, say so in confidence and give the most likely common name.",
].join("\n");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");

    // 1. Who is calling? Must be a signed-in seller.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: userData } = await userClient.auth.getUser();
    const user = userData?.user;
    if (!user) return json({ error: "unauthorized" }, 401);

    const { data: profile } = await userClient.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (profile?.role !== "seller") return json({ error: "sellers_only" }, 403);

    if (!apiKey) return json({ error: "ai_not_configured" }, 503);

    // 2. Daily limit per seller.
    const admin = createClient(url, service);
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { count } = await admin.from("ai_scans")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id).gte("created_at", since);
    if ((count ?? 0) >= DAILY_LIMIT) return json({ error: "daily_limit" }, 429);

    // 3. Validate the image.
    const body = await req.json();
    const data: string = body?.image_base64 ?? "";
    const mediaType: string = body?.media_type ?? "image/jpeg";
    if (!data || data.length > MAX_IMAGE_BASE64_CHARS) return json({ error: "bad_image" }, 400);
    if (!["image/jpeg", "image/png", "image/webp"].includes(mediaType)) return json({ error: "bad_image" }, 400);

    // 4. Ask Claude. Structured outputs guarantee the reply matches SCHEMA.
    const client = new Anthropic({ apiKey });
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 4000,
      system: SYSTEM,
      output_config: { effort: "low", format: { type: "json_schema", schema: SCHEMA } },
      messages: [{
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: mediaType, data } },
          { type: "text", text: "Identify this product and fill in the listing details." },
        ],
      }],
    });

    if (response.stop_reason === "refusal") return json({ error: "refused" }, 422);
    const textBlock = response.content.find((b) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") return json({ error: "no_result" }, 502);
    const result = JSON.parse(textBlock.text);

    await admin.from("ai_scans").insert({ user_id: user.id });
    return json(result);
  } catch (e) {
    console.error("identify-plant failed", e);
    return json({ error: "server_error" }, 500);
  }
});
