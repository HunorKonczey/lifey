# AI Nutrition Plan — Calorie Estimation (Phase 1) + Recipe Generation (Phase 2)

Two roadmap-V3 features on a shared AI foundation (`01-product-vision.md`, `07-roadmap.md`):

- **Phase 1 — AI calorie estimation:** take a photo of a meal, send it to the backend, get back a
  list of recognized food items with estimated grams + calories/macros, let the user edit the
  values, then save through the normal offline-first meal flow.
- **Phase 2 — AI recipe generation:** a multi-step wizard (diet type, meal type, calorie band,
  meat type, free-text extras) generates a recipe whose ingredients **reuse the user's existing
  foods by ID** instead of duplicating them; new foods are created only for genuinely new
  ingredients. See "Phase 2" section below.

Both share the `com.lifey.ai` client/config and the `AiFeatureGate` seam. **Neither has a user
limit for now** — the gate is permissive until the subscription model lands.

Related docs: `07-roadmap.md` (V2 OpenFoodFacts notes — same proxy pattern), `18-macros-tab-plan.md`.

---

## Guiding decisions

1. **The mobile app never calls Anthropic directly** — same rule as OpenFoodFacts. The backend
   proxies the call, holds the API key, normalizes the output. Key never ships in the app.
2. **Online-only, nothing persisted.** Like the barcode lookup: the estimate endpoint reads an
   image, returns JSON, stores nothing, touches no sync/outbox code. Saving the result happens
   client-side through the existing local-write + outbox flow.
3. **No schema change.** A confirmed estimate is saved as an ad-hoc `Food` (per-100g macros
   computed from the estimate) + a `MealEntry` with the estimated grams — the existing model fits.
   No Flyway migration needed for the MVP.
4. **No usage limit for now, but gate-ready.** A single `AiFeatureGate` seam is called at the top
   of the endpoint. Today it always allows; when the subscription model lands, one implementation
   swap turns this into a paid-tier feature (see "Subscription gating" below).

---

## API access & costs (important)

**A claude.ai subscription (Pro/Max) cannot be used for API calls.** Subscriptions cover the
claude.ai apps and Claude Code, but a product backend needs an **API key from the Anthropic
Console** (platform.claude.com) with its own pay-as-you-go credits. For testing, a small credit
top-up ($5) covers hundreds of estimates.

Per-estimate cost (image resized to 1024px ≈ ~1,300–1,600 input tokens, plus prompt; ~300 output
tokens):

| Model | Input $/MTok | Output $/MTok | ~cost / estimate |
|---|---|---|---|
| `claude-opus-4-8` (default) | $5.00 | $25.00 | ~$0.02 |
| `claude-sonnet-5` | $3.00 ($2.00 intro) | $15.00 ($10.00 intro) | ~$0.01 |
| `claude-haiku-4-5` | $1.00 | $5.00 | ~$0.004 |

Default to `claude-opus-4-8`; the model is a config property (`lifey.ai.model`) so it can be
swapped to Haiku/Sonnet after comparing estimate quality on real meal photos — worth an A/B during
testing since this is a bounded vision+extraction task where the smaller models may be sufficient.

Config (all via env vars, following `OpenFoodFactsProperties` precedent):

```properties
lifey.ai.api-key=${ANTHROPIC_API_KEY}
lifey.ai.model=${LIFEY_AI_MODEL:claude-opus-4-8}
lifey.ai.timeout-seconds=${LIFEY_AI_TIMEOUT:60}
```

---

## Backend

### Packages

- `com.lifey.ai` — shared AI plumbing, reusable by the V3 "AI recipe generation" feature later:
  - `AiProperties` (config-properties class above)
  - `AiClientConfig` — builds the Anthropic Java SDK client bean
  - `AiFeatureGate` (interface) + `PermissiveAiFeatureGate` (current impl: always allow)
- `com.lifey.nutrition.estimation` — the feature itself (feature-based packaging):
  - `MealEstimationController`
  - `service/MealEstimationService` + `MealEstimationServiceImpl`
  - `dto/MealEstimateResponse`, `dto/EstimatedItem`

### Dependency

Official Anthropic Java SDK (justified new dependency: typed client + structured outputs instead of
hand-rolled HTTP):

```xml
<dependency>
    <groupId>com.anthropic</groupId>
    <artifactId>anthropic-java</artifactId>
    <version>2.34.0</version>
</dependency>
```

### Endpoint

```
POST /api/v1/meals/estimate        (authenticated, multipart)
  part "image": JPEG/PNG photo
→ 200 {
    "items": [
      {
        "name": "Grilled chicken breast",
        "estimatedGrams": 150,
        "calories": 248,
        "proteinGrams": 46.5,
        "carbsGrams": 0,
        "fatGrams": 5.4,
        "confidence": "HIGH" | "MEDIUM" | "LOW"
      }, ...
    ],
    "notes": "optional free-text caveat from the model"
  }
→ 200 with empty items[] if no food is visible (client shows a friendly message)
→ 400 invalid/unreadable image (existing InvalidImageException path)
→ 403 feature not available (future — subscription gate; not returned today)
→ 502 upstream AI error / timeout (mapped in GlobalExceptionHandler)
```

`calories`/macros are **for the estimated portion**, not per-100g — that's what the user sees and
edits. Per-100g conversion happens client-side at save time.

### Service flow

1. `AiFeatureGate.checkMealEstimation(userId)` — no-op today.
2. Decode + downscale via the existing `ImageReencoder` (`resizedJpeg(source, 1024)`) — bounds
   token cost and rejects garbage input with the existing `InvalidImageException`.
3. Base64-encode, call the Messages API with the image block + prompt, using **structured
   outputs** so the response is schema-guaranteed JSON. The Java SDK's typed
   `outputConfig(Class)` path fits:

```java
record EstimatedItem(String name, double estimatedGrams, double calories,
                     double proteinGrams, double carbsGrams, double fatGrams,
                     Confidence confidence) {}
record MealEstimate(List<EstimatedItem> items, String notes) {}

StructuredMessageCreateParams<MealEstimate> params = MessageCreateParams.builder()
    .model(properties.model())
    .maxTokens(2048L)
    .system(SYSTEM_PROMPT)
    .outputConfig(MealEstimate.class)
    .addUserMessageOfBlockParams(List.of(
        ContentBlockParam.ofImage(/* base64 JPEG block */),
        ContentBlockParam.ofText(TextBlockParam.builder()
            .text("Estimate the foods in this photo.").build())))
    .build();
```

   (Exact image-block builder names to be verified against the SDK at implementation time.)
4. Map to `MealEstimateResponse`. Clamp obviously broken values (negative numbers, grams > 3000)
   defensively before returning.

### Prompt (v1 draft, iterate on real photos)

System prompt essentials:
- "You estimate nutrition from a single meal photo. Identify each distinct food item."
- Per item: name (short, English — localization later), estimated portion in grams, calories and
  protein/carbs/fat **for that portion**, confidence.
- "If portion size is ambiguous, estimate conservatively and lower the confidence."
- "If the image contains no food, return an empty items list and explain in notes."
- "Use the plate/cutlery for scale when visible."

### Error mapping

- `RateLimitException` / `InternalServerException` / timeout → 502 with a stable error code
  (`AI_UNAVAILABLE`) so the app can show "try again later".
- Never bubble raw Anthropic error messages to the client.

### Tests

- `MealEstimationServiceImpl` unit test with a mocked SDK client (verify prompt assembly, mapping,
  clamping, empty-items path).
- `@WebMvcTest` for the controller: auth required, multipart validation, error mapping.
- No live API calls in CI. Optionally one `@Disabled` manual smoke test hitting the real API.

---

## Subscription gating (later, designed now)

```java
public interface AiFeatureGate {
    // both throw AiFeatureNotAvailableException → 403
    void checkMealEstimation(Long userId);
    void checkRecipeGeneration(Long userId);
}
```

- Today: `PermissiveAiFeatureGate` — always passes. **No rate limit, no quota.**
- Later: a subscription-aware implementation checks the user's plan (and possibly a daily quota)
  and throws; the 403 body carries error code `AI_FEATURE_REQUIRES_SUBSCRIPTION`.
- Mobile handles 403 from day one by hiding/upselling the feature — so shipping the paid gate
  later is backend-only work plus a paywall screen.

---

## Mobile (Flutter)

Mirror the barcode-lookup feature structure under `mobile/lib/features/nutrition/`:

- `domain/meal_estimate.dart` — `MealEstimate`, `EstimatedItem` models.
- `data/meal_estimation_repository.dart` — dio multipart POST to `/api/v1/meals/estimate`,
  online-only, no Drift/outbox involvement (same as `barcode_lookup_repository.dart`).
- `application/meal_estimation_controller.dart` — Riverpod controller: idle → capturing →
  estimating → result/error states.
- `presentation/`:
  - Entry point: a camera icon next to the barcode scanner action in the meal/food add flow.
  - Capture via the existing image-picker dependency (already used for recipe photos); compress
    client-side to ≤1024px before upload to keep requests small on mobile data.
  - `EstimateResultSheet`: list of items, each row editable (name, grams, kcal, macros);
    per-item delete; confidence shown as a subtle badge; a notes line if present.
  - Confirm → for each item create an ad-hoc `Food` (per-100g values derived from
    portion values ÷ grams × 100) + `MealEntry(quantityInGrams: estimatedGrams)` through the
    existing offline-first save path. The AI round-trip is online, but saving still works the
    normal local-first way.
- Error states: no-food-found (friendly empty state), `AI_UNAVAILABLE` (retry), 403 (hide/upsell,
  future), offline (button disabled with tooltip, like barcode scan).
- l10n: all new strings through the existing localization flow (`13-localization-guide.md`).

---

## Phase 2 — AI Recipe Generation

The user walks through a short wizard describing what they want, the backend asks the model to
design a recipe, and the proposal comes back with ingredients that **reference the user's existing
foods by ID wherever one fits** — new `Food` rows are created only for ingredients the user
doesn't have yet. The user reviews/edits the proposal, then saves it as a normal `Recipe` through
the existing offline-first flow.

### Food deduplication — the core design decision

`Food` is a **per-user catalog** (`foods.user_id NOT NULL`), and `RecipeIngredient` references
`Food`. So dedup means: don't create a second "Chicken breast" in *this user's* catalog when they
already have one. Strategy (two layers):

1. **Model-side matching (primary).** The generation request includes a compact snapshot of the
   user's visible foods — `id | name | kcal/100g` per line (hidden foods excluded). The prompt
   instructs: *"When an ingredient matches one of these foods (same food, minor naming differences
   included), reference it by `existingFoodId` and use its nutrition values. Only propose a
   `newFood` when nothing in the list is the same food."* A personal catalog is typically well
   under a few hundred rows, so this costs only a few thousand input tokens.
2. **Backend validation + name safety net (secondary).** After the model responds, the service
   (a) verifies every `existingFoodId` actually belongs to the current user and is not hidden
   (reject/strip otherwise — never trust model-emitted IDs blindly), and (b) for each proposed
   `newFood`, runs a case-insensitive exact-name check against the user's foods; on a hit, the
   proposal is silently converted to an `existingFoodId` reference. No fuzzy matching in v1 —
   the model already handles the fuzzy part, this is just a guard.

The response keeps both shapes explicit so the client can render "already in your foods" vs
"will be added" badges in the preview.

### Endpoint

```
POST /api/v1/recipes/generate        (authenticated, JSON)
{
  "dietType":    "VEGETARIAN" | "VEGAN" | "MEAT" | "FISH" | "ANYTHING",
  "mealType":    "BREAKFAST" | "LUNCH" | "DINNER" | "SNACK",
  "calorieBand": "UNDER_300" | "FROM_300_TO_500" | "FROM_500_TO_700" | "OVER_700",   // per serving
  "meatType":    "CHICKEN" | "BEEF" | "PORK" | "TURKEY" | "FISH" | "ANY" | null,     // only when dietType allows meat
  "extraRequest": "free text, optional, max ~500 chars"
}
→ 200 {
    "name": "…",
    "description": "step-by-step instructions",        // must fit recipes.description (2000 chars) — prompt-enforced
    "servings": 2,
    "ingredients": [
      { "existingFoodId": 42, "name": "Chicken breast", "quantityInGrams": 300 },
      { "newFood": { "name": "Smoked paprika", "caloriesPer100g": 282,
                     "proteinPer100g": 14.1, "carbsPer100g": 54, "fatPer100g": 13 },
        "quantityInGrams": 5 }
    ],
    "perServing": { "calories": 460, "proteinGrams": 42, "carbsGrams": 30, "fatGrams": 18 }
  }
→ 400 invalid combination (e.g. meatType with VEGAN) / bad input
→ 502 AI_UNAVAILABLE (same mapping as Phase 1)
```

Implementation: `com.lifey.nutrition.recipe.generation` package (`RecipeGenerationController`,
`service/RecipeGenerationService(Impl)`, `dto/`), reusing the `com.lifey.ai` client bean and
structured outputs (typed schema like Phase 1, one ingredient union: exactly one of
`existingFoodId` / `newFood` must be set — validated server-side since JSON schema `oneOf`
support is limited). `AiFeatureGate.checkRecipeGeneration(userId)` at the top — **permissive now,
no user limit**, same swap-in point as Phase 1 for the future subscription gate.

Prompt essentials: honor the wizard constraints strictly (diet type is a hard rule, calorie band
is per serving), prefer common ingredients, keep instructions inside 2000 chars, realistic gram
quantities, and the dedup instruction from above. Generation is text-only (no image), so output is
the dominant cost — still ~1–3 cents per recipe on Opus 4.8, and `maxTokens` should be ~4096.

### Mobile — multi-step wizard

New flow under `mobile/lib/features/recipes/` (`generation/` subfolder mirroring the feature
split: domain / data / application / presentation). Entry point: a "✨ Generate with AI" action on
the recipes screen. The wizard is a paged bottom sheet / dialog, **one choice per step**, with
back navigation and a progress indicator:

1. **Diet type** — chips: Vegetarian, Vegan, Meat, Fish, Anything.
2. **Meal type** — Breakfast, Lunch, Dinner, Snack.
3. **Calorie band (per serving)** — <300, 300–500, 500–700, 700+.
4. **Meat type** — Chicken, Beef, Pork, Turkey, Fish, Surprise me. *(Skipped automatically for
   Vegetarian/Vegan — the wizard jumps from step 3 to step 5.)*
5. **Extras** — free-text field ("no mushrooms", "high protein", "Asian style", …), optional,
   plus the Generate button.

These are creative *setting-level* controls — the enums can grow later (cuisine style, prep-time
cap) without API changes by adding optional fields. The whole wizard state is client-side; only
the final Generate press calls the backend (online-only, like Phase 1 — button disabled offline).

**Preview screen** (after generation): recipe name, per-serving macros, instructions, and the
ingredient list where each row shows an "in your foods" badge (existingFoodId) or a "new" badge
(newFood). Everything editable; a Regenerate button re-runs with the same wizard input. On
**Save**: create the `newFood` items as local Foods, then the Recipe + ingredients — all through
the existing offline-first local-write + outbox path (the referenced existing-food IDs are already
in the local Drift DB thanks to delta sync). The AI round-trip is the only online part.

### Phase 2 tests

- Service unit tests: catalog snapshot assembly, model-ID validation (foreign/hidden IDs
  stripped), exact-name dedup conversion, VEGAN+meatType rejection.
- Controller `@WebMvcTest`: auth, enum validation, error mapping.
- Prompt iteration manually with a few real user catalogs (empty catalog must also work — then
  everything is `newFood`).

---

## Implementation order

**Phase 1 — calorie estimation:**

1. Backend: `com.lifey.ai` config + SDK dependency + `AiFeatureGate` (permissive).
2. Backend: `nutrition/estimation` service + controller + error mapping + tests.
3. Manual smoke test with real photos; iterate prompt; compare Opus vs Haiku quality/cost.
4. Mobile: repository + controller + capture entry point.
5. Mobile: result sheet + save-as-meal flow + error/empty states + l10n.

**Phase 2 — recipe generation (builds on 1–3):**

6. Backend: `nutrition/recipe/generation` service + controller + dedup validation + tests.
7. Prompt iteration with real catalogs (dedup quality is the thing to verify).
8. Mobile: wizard steps + generation repository/controller.
9. Mobile: preview screen + save flow (new foods + recipe via outbox) + l10n.

**Later (separate effort):** subscription-aware `AiFeatureGate` + paywall UI for both features;
optional daily quota.

## Out of scope for the MVP

- Persisting estimates, generated-but-unsaved recipes, or photos server-side (meal photos would
  push storage toward object storage — see the option C note in `22-profile-picture-plan.md`).
- Matching photo-estimated items against the local `foods` catalog or OpenFoodFacts (Phase 2's
  dedup applies to recipe generation only).
- Fuzzy/semantic food matching beyond the model-side matching + exact-name guard.
- Rate limiting / quotas (arrives with the subscription model).
- Multi-photo or barcode+photo combined flows; generating recipe photos.
