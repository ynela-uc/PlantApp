# Sections, categories and occasions

The app is a marketplace for **flower shops, plant shops and gift & decor shops** (the same scope as
ÇiçekSepeti). A shop declares its types (`sellers.shop_types`), but every **product** carries its own
`section` and `category`, so a flower shop can sell gifts and a plant shop can sell soil and tools.

These keys are stored in the database (`listings.section`, `listings.category`, `listings.occasions`).
Names live in the string files (`sec_<key>`, `cat_<key>`, `occ_<key>`) in Arabic, Kurdish (Sorani) and English.
The same lists are in `android/.../data/Catalog.kt` and `ios/PlantApp/Data/Catalog.swift`; keep all three in sync.
Adding a category = add the key here, the three string files, `Catalog.kt`, `Catalog.swift`, and the AI list in
`supabase/functions/identify-plant/index.ts`.

| Section (`section`) | Categories (`category`) |
|---|---|
| `flowers` 🌸 | `bouquets`, `roses`, `flower_boxes`, `baskets`, `weddings_events` (bridal bouquets, wedding decor), `wreaths` (wreaths and stands for sympathy or openings), `dried_preserved`, `artificial_flowers` |
| `plants` 🪴 | `indoor`, `outdoor`, `succulents_cacti`, `flowering`, `trees_palms`, `herbs`, `bonsai` (orchids go under `flowering`), and plant supplies: `soil`, `fertilizer` (includes pest control), `pots`, `tools`, `seeds_bulbs` |
| `gifts` 🎁 | `gift_sets`, `chocolate_sweets`, `personalised`, `home_decor`, `candles_fragrance`, `cards_wrapping`, `plush_toys`, `accessories_jewelry`, `balloons_party` |

Occasions (`occasions`, any number per product): `birthday`, `anniversary`, `love`, `new_baby`, `get_well`,
`congratulations`, `new_home`, `graduation`, `wedding`, `condolence`, `mothers_day`, `eid`, `thank_you`.

Plant-only product fields (`plant_key`, `scientific_name`, `care`, `height_cm`) stay empty for other sections.

Rules for the list: a category is a *kind of product*, an occasion is a *reason to buy*, so nothing is both (sympathy is an
occasion; wreaths are a category). Categories do not overlap, so a seller always knows where a product goes. Fresh food
(cakes, bakery) is deliberately not sold: it needs same-day baking, food licences and cold delivery, which the app does not handle.
Names follow how Iraqi shops write them (checked against hazalgifts.com and tookiegifts.com).
