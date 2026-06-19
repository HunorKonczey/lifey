-- Foods could previously be created with a name that already existed (e.g. "Rice"
-- added twice), making them indistinguishable in the meal/recipe food pickers.
-- Merge any such duplicates into the lowest id, repointing references, then
-- enforce uniqueness (case-insensitive, trimmed) going forward.

update meal_entries me
    set food_id = d.canonical_id
    from (
        select id, min(id) over (partition by lower(trim(name))) as canonical_id
        from foods
    ) d
    where me.food_id = d.id and d.id <> d.canonical_id;

update recipe_ingredients ri
    set food_id = d.canonical_id
    from (
        select id, min(id) over (partition by lower(trim(name))) as canonical_id
        from foods
    ) d
    where ri.food_id = d.id and d.id <> d.canonical_id;

delete from foods f
    using (
        select id, min(id) over (partition by lower(trim(name))) as canonical_id
        from foods
    ) d
    where f.id = d.id and d.id <> d.canonical_id;

create unique index foods_name_unique_idx on foods (lower(trim(name)));
