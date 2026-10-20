-- 009: the app is a marketplace for flower shops, plant shops and gift/decor shops (like ÇiçekSepeti).
-- Every product (listing) now belongs to a section and a category, and a shop declares what kinds of
-- shop it is. Category and occasion keys are defined in the apps (see docs/categories.md); the database
-- only guards the three sections.

alter table sellers add column if not exists shop_types text[] not null default '{plants}';

alter table listings add column if not exists section text not null default 'plants';
alter table listings add column if not exists category text;

do $$
begin
  alter table listings
    add constraint listings_section_check check (section in ('flowers', 'plants', 'gifts'));
exception when duplicate_object then null;
end $$;

-- Everything that exists today is a plant: file it under a plant category from its plant type.
update listings
set category = case plant_key
  when 'Cactus' then 'succulents_cacti'
  when 'Succulents' then 'succulents_cacti'
  when 'Aloe Vera' then 'succulents_cacti'
  when 'Palm' then 'trees_palms'
  when 'Rose' then 'flowering'
  when 'Jasmine' then 'flowering'
  when 'Mint' then 'herbs'
  when 'Basil' then 'herbs'
  when 'Bonsai' then 'bonsai_orchids'
  when 'Orchid' then 'bonsai_orchids'
  else 'indoor'
end
where category is null;

create index if not exists listings_section_category_idx on listings (section, category);
