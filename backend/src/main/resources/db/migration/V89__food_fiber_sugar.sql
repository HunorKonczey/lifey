-- LIF-145: optional dietary fibre and sugars per 100 g on a food, next to carbs and fat. Nullable like those: "not
-- known" is not zero (OpenFoodFacts often has no fibre figure). No backfill - existing foods simply have none.
alter table foods add column fiber_per_100g double precision;
alter table foods add column sugar_per_100g double precision;
