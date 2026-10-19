-- 005: plant listings (what shops sell) + demo data for the five seeded shops
-- Run once in Supabase Dashboard -> SQL Editor.
--
-- Text fields are jsonb maps keyed by language code: {"en": "...", "ar": "...", "ckb": "..."}.
-- The apps show the user's language and fall back to another one if a language is missing.

create table if not exists listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references sellers(id) on delete cascade,
  plant_key text,
  name jsonb not null default '{}',
  scientific_name text,
  description jsonb not null default '{}',
  care jsonb not null default '{}',          -- {"water": {"en":..}, "light": {...}, "fertilizer": {...}}
  height_cm integer,
  pot_size_cm integer,
  price_iqd integer not null check (price_iqd >= 0),
  image_path text,
  in_stock boolean not null default true,
  ai_generated boolean not null default false,
  occasions text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists listings_seller_idx on listings (seller_id);

alter table listings enable row level security;

create policy "Anyone can view listings" on listings
  for select using (true);

create policy "Shop owners can add listings" on listings
  for insert with check (
    exists (select 1 from sellers where sellers.id = listings.seller_id and sellers.owner_id = auth.uid())
  );

create policy "Shop owners can edit their listings" on listings
  for update using (
    exists (select 1 from sellers where sellers.id = listings.seller_id and sellers.owner_id = auth.uid())
  );

create policy "Shop owners can delete their listings" on listings
  for delete using (
    exists (select 1 from sellers where sellers.id = listings.seller_id and sellers.owner_id = auth.uid())
  );

-- Demo data: one listing per plant each seeded shop (owner_id is null) already offers.
-- Prices vary a little per shop. Kurdish names/text need review by a native speaker.
with dict(key, name_en, name_ar, name_ckb, sci, price, height, desc_en, desc_ar, water_en, water_ar, light_en, light_ar, fert_en, fert_ar) as (
  values
  ('Monstera','Monstera','مونستيرا','مۆنستێرا','Monstera deliciosa',35000,50,
   'Bold split-leaf tropical plant that thrives indoors.','نبتة استوائية ذات أوراق مشقوقة جميلة تنمو داخل المنزل.',
   'Water when the top 3 cm of soil is dry (about weekly).','اسقِها عندما تجف أول 3 سم من التربة (تقريبًا أسبوعيًا).',
   'Bright indirect light.','ضوء غير مباشر ساطع.','Monthly in spring and summer.','شهريًا في الربيع والصيف.'),
  ('Snake Plant','Snake Plant','نبتة الثعبان','ڕووەکی مار','Dracaena trifasciata',15000,40,
   'Tough, almost unkillable air-purifying plant.','نبتة قوية تكاد لا تموت وتنقّي الهواء.',
   'Every 2-3 weeks; let the soil dry out.','كل 2-3 أسابيع، دع التربة تجف.',
   'Low to bright light.','إضاءة منخفضة إلى ساطعة.','Twice a year.','مرتين في السنة.'),
  ('Pothos','Pothos','بوتس','پۆتۆس','Epipremnum aureum',8000,30,
   'Fast-growing trailing vine, great for shelves.','نبتة متدلية سريعة النمو مناسبة للرفوف.',
   'Weekly, when the top soil is dry.','أسبوعيًا عندما تجف التربة السطحية.',
   'Low to medium indirect light.','ضوء غير مباشر منخفض إلى متوسط.','Every 6 weeks in the growing season.','كل 6 أسابيع في موسم النمو.'),
  ('Ficus','Ficus','فيكس','فیکس','Ficus lyrata',30000,80,
   'Elegant indoor tree with glossy leaves.','شجرة داخلية أنيقة بأوراق لامعة.',
   'When the top 2-3 cm is dry.','عندما تجف أول 2-3 سم من التربة.',
   'Bright indirect light; avoid moving it often.','ضوء غير مباشر ساطع، وتجنب نقلها كثيرًا.','Monthly in spring and summer.','شهريًا في الربيع والصيف.'),
  ('Cactus','Cactus','صبار','کاکتۆس','Cactaceae',5000,20,
   'Low-maintenance desert plant.','نبتة صحراوية قليلة الاحتياج للعناية.',
   'Every 2-3 weeks, less in winter.','كل 2-3 أسابيع وأقل في الشتاء.',
   'Full sun.','شمس مباشرة.','Once in spring.','مرة واحدة في الربيع.'),
  ('Succulents','Succulents','نباتات عصارية','ڕووەکی شیرەدار','Crassulaceae',4000,10,
   'Small water-storing plants, ideal for sunny windowsills.','نباتات صغيرة تخزّن الماء مناسبة للنوافذ المشمسة.',
   'Every 2 weeks; let the soil dry fully.','كل أسبوعين، دع التربة تجف تمامًا.',
   'Bright light with some direct sun.','ضوء ساطع مع بعض الشمس المباشرة.','Diluted, once a month in summer.','مخففًا مرة شهريًا في الصيف.'),
  ('Aloe Vera','Aloe Vera','ألوفيرا','ئەلۆڤێرا','Aloe vera',7000,30,
   'Soothing gel plant, easy to grow.','نبتة مفيدة للبشرة وسهلة النمو.',
   'Every 2-3 weeks.','كل 2-3 أسابيع.',
   'Bright light with some direct sun.','ضوء ساطع مع بعض الشمس المباشرة.','Twice a year.','مرتين في السنة.'),
  ('Palm','Palm','نخيل','دارخورما','Arecaceae',45000,90,
   'Tropical palm that adds height and a fresh feel.','نخلة استوائية تضيف ارتفاعًا وأجواءً منعشة.',
   'Keep the soil lightly moist.','حافظ على رطوبة خفيفة للتربة.',
   'Bright indirect light.','ضوء غير مباشر ساطع.','Monthly in spring and summer.','شهريًا في الربيع والصيف.'),
  ('Rubber Plant','Rubber Plant','شجرة المطاط','ڕووەکی لاستیک','Ficus elastica',25000,60,
   'Bold, glossy leaves; very easy indoors.','أوراق لامعة كبيرة وسهلة العناية داخل المنزل.',
   'When the top 3 cm is dry.','عندما تجف أول 3 سم.',
   'Bright indirect light.','ضوء غير مباشر ساطع.','Monthly in spring and summer.','شهريًا في الربيع والصيف.'),
  ('Peace Lily','Peace Lily','زنبق السلام','سۆسنی ئاشتی','Spathiphyllum',18000,45,
   'Elegant white blooms; it droops when thirsty.','أزهار بيضاء أنيقة وتتدلى أوراقها عند العطش.',
   'Weekly; it droops when thirsty.','أسبوعيًا، وتتدلى أوراقها عند العطش.',
   'Low to medium light.','إضاءة منخفضة إلى متوسطة.','Every 2 months.','كل شهرين.'),
  ('Fern','Fern','سرخس','سەرخس','Nephrolepis exaltata',10000,35,
   'Soft feathery fronds that love humidity.','سعف ناعم يحب الرطوبة.',
   'Keep the soil evenly moist.','حافظ على رطوبة التربة باستمرار.',
   'Indirect light.','ضوء غير مباشر.','Monthly in summer.','شهريًا في الصيف.'),
  ('Jasmine','Jasmine','ياسمين','یاسەمەن','Jasminum officinale',12000,50,
   'Fragrant white flowers; loves sun.','أزهار بيضاء عطرة تحب الشمس.',
   'Keep the soil moist, not soggy.','حافظ على رطوبة التربة دون إغراق.',
   'Full sun to part shade.','شمس كاملة إلى ظل جزئي.','Every 2-3 weeks while blooming.','كل 2-3 أسابيع أثناء الإزهار.'),
  ('Rose','Rose','ورد','گوڵەباخ','Rosa',8000,40,
   'Classic flowering shrub.','شجيرة مزهرة كلاسيكية.',
   'Deeply, 2-3 times a week in summer.','بعمق 2-3 مرات أسبوعيًا في الصيف.',
   'Full sun (6+ hours).','شمس كاملة (6 ساعات أو أكثر).','Every 2 weeks in the growing season.','كل أسبوعين في موسم النمو.'),
  ('Mint','Mint','نعناع','نەعنا','Mentha',3000,25,
   'Fresh aromatic herb for tea and cooking.','عشبة عطرية طازجة للشاي والطبخ.',
   'Keep the soil moist.','حافظ على رطوبة التربة.',
   'Sun to part shade.','شمس إلى ظل جزئي.','Monthly.','شهريًا.'),
  ('Basil','Basil','ريحان','ڕەیحان','Ocimum basilicum',3000,25,
   'Sweet aromatic herb that loves warmth.','عشبة عطرية حلوة تحب الدفء.',
   'Keep the soil moist; water in the morning.','حافظ على رطوبة التربة واسقِها صباحًا.',
   'Full sun.','شمس كاملة.','Every 2 weeks.','كل أسبوعين.'),
  ('Bonsai','Bonsai','بونساي','بۆنسای','Ficus microcarpa',60000,35,
   'Miniature tree that rewards patient care.','شجرة مصغّرة تكافئ العناية والصبر.',
   'Check daily; water when the top soil is dry.','افحصها يوميًا واسقِها عند جفاف التربة.',
   'Bright light with some direct sun.','ضوء ساطع مع بعض الشمس المباشرة.','Every 2 weeks in the growing season.','كل أسبوعين في موسم النمو.'),
  ('Orchid','Orchid','أوركيد','ئۆرکید','Phalaenopsis',40000,40,
   'Long-lasting elegant blooms.','أزهار أنيقة تدوم طويلًا.',
   'Once a week; let the roots dry in between.','مرة أسبوعيًا مع ترك الجذور تجف بين الريات.',
   'Bright indirect light.','ضوء غير مباشر ساطع.','Orchid fertilizer every 2 weeks.','سماد الأوركيد كل أسبوعين.')
)
insert into listings (seller_id, plant_key, name, scientific_name, description, care, height_cm, price_iqd)
select
  s.id,
  d.key,
  jsonb_build_object('en', d.name_en, 'ar', d.name_ar, 'ckb', d.name_ckb),
  d.sci,
  jsonb_build_object('en', d.desc_en, 'ar', d.desc_ar),
  jsonb_build_object(
    'water',      jsonb_build_object('en', d.water_en, 'ar', d.water_ar),
    'light',      jsonb_build_object('en', d.light_en, 'ar', d.light_ar),
    'fertilizer', jsonb_build_object('en', d.fert_en,  'ar', d.fert_ar)
  ),
  d.height,
  (round(d.price * (0.90 + (abs(hashtext(s.id::text || d.key)) % 21) / 100.0) / 500.0) * 500)::integer
from sellers s
cross join lateral unnest(s.plants_offered) as p(key)
join dict d on d.key = p.key
where s.owner_id is null
  and not exists (select 1 from listings l where l.seller_id = s.id and l.plant_key = d.key);
