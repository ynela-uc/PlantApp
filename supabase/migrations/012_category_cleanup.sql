-- 012: tidy the category list (see docs/categories.md).
--   condolence  -> wreaths        (a category is a kind of product; sympathy stays an occasion)
--   bonsai_orchids -> bonsai      (orchids move to flowering)
--   pest_care   -> fertilizer     (one supplies category: fertilizer and pest control)
--   cakes       -> chocolate_sweets (fresh food is not sold in the app)

update listings set category = 'wreaths' where category = 'condolence';
update listings set category = 'flowering' where category = 'bonsai_orchids' and plant_key = 'Orchid';
update listings set category = 'bonsai' where category = 'bonsai_orchids';
update listings set category = 'fertilizer' where category = 'pest_care';
update listings set category = 'chocolate_sweets' where category = 'cakes';
