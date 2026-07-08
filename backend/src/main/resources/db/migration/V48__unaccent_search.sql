-- Enables accent-insensitive name search (e.g. "a" matches "á", "ă") for
-- foods, recipes, and user email search — see FoodRepository, RecipeRepository,
-- UserRepository native @Query methods using unaccent().
CREATE EXTENSION IF NOT EXISTS unaccent;
