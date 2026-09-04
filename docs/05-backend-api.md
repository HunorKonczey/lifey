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

## Billing & entitlements

Full design: [docs/landing_page/64-billing-backend-plan.md](landing_page/64-billing-backend-plan.md).
Everything here is behind `lifey.billing.enabled` (default **false**, which resolves an open
entitlement for everyone and passes every seat check — that is what makes the feature deployable
before any client understands it).

GET /api/v1/me/entitlements
* The one endpoint every client reads to decide what a user may do (`64` §3): tier, source, the
  free-tier limits (`historyDays`, `aiCreditsRemaining`), `adsEnabled`, an optional `trainer`
  block, and `graceUntil` for the offline ladder. `Cache-Control: max-age=60, private`.
* Resolution order is server-side and fixed (`63` §3): own paid → trainer-sponsored → trainer
  trial. Clients gate on the *fields*, never on `tier`/`source`, which exist for copy only.

POST /api/v1/billing/checkout-session
* `ROLE_TRAINER` only. Body `{plan, interval}` → a Stripe Checkout URL. Sets
  `client_reference_id` to the trainer's user id (how the webhook finds them back), turns on
  Stripe Tax and promotion codes, and collects the EU 14-day withdrawal waiver as a real consent
  checkbox (`63` §5).

POST /api/v1/billing/portal-session
* `ROLE_TRAINER` only. → a Stripe billing-portal URL. 404 if the trainer has no linked customer
  yet (nothing writes that column before the first webhook).

POST /api/v1/billing/store-purchase
* The mobile purchase path (`64` §6). Body `{platform, productId, purchaseToken}`; verifies the
  receipt with Apple/Google and returns the freshly resolved `EntitlementResponse`. The client
  only calls the store's own `completePurchase` **after** this answers 200 — a 409/422 is
  terminal and completes anyway, anything else leaves the transaction pending for redelivery.

POST /api/v1/webhooks/stripe · /api/v1/webhooks/app-store · /api/v1/webhooks/play
* Unauthenticated by design — each verifies its provider's own signature instead (Stripe's
  `Webhook.constructEvent` over the raw body, Apple's JWS chain, Google's Pub/Sub OIDC token),
  and all three fail closed with no secret configured. Idempotent: `processed_billing_event`
  makes a replayed event a no-op (`64` Prompt 5).
* These are the **source of truth** for subscription state (D-B5). The browser redirect after
  Checkout is a UI convenience and never writes anything.

## Technical Requirements

* OpenAPI documentation
* Validation
* Global exception handling
* Flyway migrations
* Unit tests
* Integration tests
* Docker support
