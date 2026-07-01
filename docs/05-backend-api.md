# Backend API Requirements

## Nutrition

GET /api/v1/foods
* Unpaged, backward-compatible contract: returns the full (non-hidden) catalog
  as a JSON array. Used by any caller that doesn't pass a `page` param.

GET /api/v1/foods?page=&size=&sort=&search=
* Paged + optionally searched variant, routed via the same path (Spring
  `@GetMapping(params = "page")` — presence of `page` is the switch). Params:
  `page` (0-based), `size` (default 200), `sort` (Spring Data sort expr,
  defaults to `name,asc` then `id,asc` for a deterministic tiebreak), `search`
  (optional, case-insensitive `name` contains-match; omitted = no filter).
  Response is a Spring Data `Page<FoodResponse>` serialized as-is:
  `{ content: [...], totalElements, totalPages, number, size, last, ... }`.
* Two consumers use this with different `size`: the web foods table
  (~25–50, driven by `search`) and the mobile sync pull (~200–500, no
  `search` — it always wants the full catalog, just chunked).
* Pattern to reuse for other long lists (recipes, exercises, ...): same
  path, `params = "page"` vs `params = "!page"` on two controller methods,
  a `findBy<Field>(Pageable)` / `findBy<Field>And<SearchField>ContainingIgnoreCase(String, Pageable)`
  pair on the repository, and the service returning `Page<T>` untouched via
  `.map(Mapper::toResponse)`.

GET /api/v1/foods/{id}

POST /api/v1/foods

PUT /api/v1/foods/{id}

DELETE /api/v1/foods/{id}

## Recipes

GET /api/v1/recipes

GET /api/v1/recipes/{id}

POST /api/v1/recipes

PUT /api/v1/recipes/{id}

DELETE /api/v1/recipes/{id}

## Meals

GET /api/v1/meals

POST /api/v1/meals

PUT /api/v1/meals/{id}

DELETE /api/v1/meals/{id}

## Workouts

GET /api/v1/workout-templates

POST /api/v1/workout-templates

GET /api/v1/workout-sessions

POST /api/v1/workout-sessions

## Weight Tracking

GET /api/v1/weights

POST /api/v1/weights

DELETE /api/v1/weights/{id}

## Statistics

GET /api/v1/statistics/daily

GET /api/v1/statistics/weekly

GET /api/v1/statistics/monthly

## Technical Requirements

* OpenAPI documentation
* Validation
* Global exception handling
* Flyway migrations
* Unit tests
* Integration tests
* Docker support
