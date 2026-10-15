-- Which recipe a meal entry came from (docs/88 §2.1, LIF-167). Nullable: entries from foods, macros and photo estimates
-- have none, and the column is only ever set by a client that knows the recipe. `on delete set null`: recipes are
-- soft-deleted in practice (recipes.deleted_at), so this only fires on a hard delete, where null is the honest value.
alter table meal_entries
    add column recipe_id bigint references recipes (id) on delete set null;

-- Postgres does not index foreign-key columns by itself.
create index meal_entries_recipe_id_idx on meal_entries (recipe_id);

-- Backfill (docs/88 §2.6): until now a recipe logged as a meal of its own is told apart only by the meal's name, so tag
-- the entries of every live meal named exactly like ONE live recipe of the same user (case and surrounding spaces
-- ignored). A name that matches two live recipes, a deleted recipe, or no recipe at all is left untagged on purpose -
-- a wrong tag would count a use of the wrong recipe, a missing one only a use not counted.
--
-- Raw SQL does not fire the @PreUpdate of Meal, and the mobile and web clients read meals through the delta feed ordered
-- by meals.updated_at: so the touched meals' updated_at is bumped here, or no client would ever receive the tags.
with unique_recipes as (
    select user_id, lower(btrim(name)) as recipe_name, min(id) as recipe_id
      from recipes
     where deleted_at is null
     group by user_id, lower(btrim(name))
    having count(*) = 1
), tagged as (
    update meal_entries e
       set recipe_id = r.recipe_id
      from meals m
      join unique_recipes r on r.user_id = m.user_id and r.recipe_name = lower(btrim(m.name))
     where e.meal_id = m.id
       and m.deleted_at is null
       and m.name is not null
    returning e.meal_id
)
update meals
   set updated_at = now()
 where id in (select meal_id from tagged);
