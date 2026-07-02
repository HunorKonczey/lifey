# Onboarding "Step Zero" + user_details Plan

After registration (email/password **or** social login — first login with an empty profile), the user goes through a short onboarding wizard before reaching the dashboard. Collected data lands in a new `user_details` table and powers personalized defaults (calorie/macro goals).

Related docs: `08-auth-module.md` (auth), `19-password-email-plan.md`, `20-social-login-plan.md` (social users also pass through this), `18-macros-tab-plan.md` (consumes the calorie goals).

---

## What we collect and why

| Field | Why it's relevant | Required? |
|---|---|---|
| Gender | BMR formula input (Mifflin-St Jeor differs by sex) | yes (with "prefer not to say") |
| Birth date | Age is a BMR input; also enables age-based defaults later | yes |
| Height | BMR input; BMI display on the weight screen | yes |
| Current weight | BMR input; **seeds the first `weight_entries` row** — it is NOT stored in `user_details`, the weight feature already owns weight history | yes |
| Activity level | Converts BMR → TDEE (sedentary ×1.2 … very active ×1.9) | yes |
| Primary goal | Lose / maintain / gain — adjusts the suggested calorie target (−15% / ±0 / +10%) and can drive dashboard emphasis later | yes |
| Target weight | Progress display on the weight screen ("3.2 kg to go") | optional |

Deliberately **not** collected here (already owned elsewhere or too much friction at step zero): unit system, language, theme, step goal (all in `user_settings`); medical conditions (out of scope); body measurements (future feature).

### Derived output: suggested daily goals

At the end of the wizard the backend computes and the client shows **suggested** daily calorie, macro, and water goals, which the user can accept (writes into the existing `user_settings.daily_*` / `daily_water_goal_liters` columns) or skip. This suggestion is the first number the app ever shows a new user — get it wrong and every downstream feature (macros tab, dashboard rings) looks broken, so the formulas below are deliberately conservative and cross-checked against published methodology rather than invented.

**1. BMR — Mifflin-St Jeor equation.**
Chosen over Harris-Benedict because the systematic comparison against measured resting energy expenditure (Frankenfield, Roth-Yousey & Compher, *J Am Diet Assoc* 2005) found Mifflin-St Jeor the most accurate predictor for both normal-weight and obese adults, with Harris-Benedict tending to overestimate. It's also what most modern consumer nutrition apps (MyFitnessPal, Cronometer) use as their default.

- Men: `10w + 6.25h − 5a + 5`
- Women: `10w + 6.25h − 5a − 161`
- Unspecified: average of the two, i.e. `10w + 6.25h − 5a − 78`

(`w` = weight in kg, `h` = height in cm, `a` = age in years, computed from `birthDate` as of today.)

We deliberately do **not** offer Katch-McArdle (which uses lean body mass) at this step — body-fat % isn't collected in onboarding and asking for it here would add friction for a formula that's only more accurate when body-fat is measured, not guessed.

**2. TDEE — activity multiplier.**
Standard Katch activity factors, same set used across the mainstream apps above:

| Activity level | Multiplier | Description |
|---|---|---|
| Sedentary | ×1.2 | little/no exercise |
| Light | ×1.375 | light exercise 1–3 days/week |
| Moderate | ×1.55 | moderate exercise 3–5 days/week |
| Active | ×1.725 | hard exercise 6–7 days/week |
| Very active | ×1.9 | very hard exercise + physical job |

`TDEE = BMR × multiplier`

**3. Calorie target — goal adjustment with safety clamps.**
A flat percentage without bounds can produce dangerous numbers for small/large users, so the percentage is clamped in absolute kcal *and* floored against a minimum safe intake:

- Lose weight: TDEE × 0.85 (−15%, ≈0.5–0.75 kg/week for most users — inside the generally-cited safe range of ~0.5–1% bodyweight/week), but the deficit is capped at **1000 kcal/day** even if 15% of TDEE would exceed that.
- Maintain: TDEE × 1.0.
- Gain muscle: TDEE × 1.10 (+10%, a lean-gain surplus per the ISSN position stand on muscle gain — large surpluses mostly add fat, not muscle), capped at **+500 kcal/day**.
- Absolute floor regardless of goal: **1500 kcal** for men, **1200 kcal** for women, **1350 kcal** for unspecified (WHO/NHS-cited minimums below which micronutrient adequacy becomes hard to sustain). The suggestion never goes below this floor even if the deficit math would.
- Result rounded to the nearest 10 kcal.

**4. Protein — grams per kg bodyweight, not a fixed % of calories.**
A fixed macro percentage (e.g. "30% of calories") is a poor protein estimator because it scales with total calories instead of the thing protein need actually tracks: bodyweight and training/deficit status. Using g/kg ranges from the ISSN position stand (Jäger et al., *J Int Soc Sports Nutr* 2017) and Helms et al. (2014, protein needs during caloric restriction) instead:

- Lose weight: **2.2 g/kg** — high end of the 1.6–2.4 g/kg range shown to preserve lean mass during a deficit.
- Maintain: **1.6 g/kg** — lower end of the general athletic recommendation, adequate for a non-dieting, non-bulking adult.
- Gain muscle: **2.0 g/kg** — within the 1.6–2.2 g/kg range shown to maximize hypertrophy; more than this shows no added benefit in the literature.
- `proteinGrams = round(gPerKg × weightKg)`, `proteinKcal = proteinGrams × 4`.

**5. Fat — percentage of calories with a hormonal-health floor.**
`fatGrams = max(round(0.25 × calories / 9), round(0.6 × weightKg))` — 25% of total calories is mid-range of the commonly-cited 20–35% healthy-fat window, and the 0.6 g/kg floor guards against very-low-fat diets at low calorie targets, which is associated with hormonal disruption. `fatKcal = fatGrams × 9`.

**6. Carbs — remainder.**
`carbsGrams = round(max(0, calories − proteinKcal − fatKcal) / 4)`. Because protein and fat are now needs-based rather than percentage-based, carbs simply fill what's left — this is standard "protein/fat first, carbs fill the rest" macro construction, and avoids the old plan's problem of a fixed 40% carb share pushing protein too low for someone lifting weights.

**7. Water — bodyweight formula + activity adjustment, cross-checked against clinical adequate-intake guidance.**
`waterMl = round50(weightKg × 35 + activityBonusMl)`, converted to liters (1 decimal).

- Baseline 35 mL/kg sits in the commonly used 30–40 mL/kg clinical range (used e.g. by the ESPEN nutrition guidelines) for healthy adults.
- Activity bonus accounts for sweat losses: Sedentary +0 mL, Light +150 mL, Moderate +300 mL, Active +500 mL, Very active +750 mL.
- Sanity check against EFSA/IOM adequate total-water intake (≈3.7 L/day men, ≈2.7 L/day women, includes food-derived water) confirms a 70 kg sedentary adult lands at ≈2.45 L from this formula, i.e. plausibly under the "total water" figure once food water is added back — the formula is deliberately about *drinking* water, not total water, matching what the water-tracking feature actually measures.
- This is a starting suggestion, not a hard cap; the existing water feature lets the user edit `daily_water_goal_liters` freely afterward.

Calculation lives in the **backend** (single source of truth, returned by the API) — clients never duplicate the formula. `POST /api/v1/user-details/suggest-goals` returns `bmr`, `tdee`, `calories`, `proteinGrams`, `carbsGrams`, `fatGrams`, and `waterLiters` so the UI can show its work ("suggested from your BMR of Xkcal") if desired.

---

## Data model

Flyway `V38__user_details.sql` (V36/V37 are reserved by docs 19/20 — renumber if those haven't shipped first):

```sql
-- Biometric/profile data collected at onboarding. One row per user,
-- created when the user completes (or partially completes) onboarding.
-- Weight is NOT here: weight history lives in weight_entries.
create table user_details (
    id                      bigint generated by default as identity primary key,
    user_id                 bigint      not null unique references users (id) on delete cascade,
    gender                  varchar(20) not null,  -- MALE | FEMALE | UNSPECIFIED
    birth_date              date        not null,
    height_cm               numeric(5,1) not null, -- metric canonical, imperial converted client-side
    activity_level          varchar(20) not null,  -- SEDENTARY | LIGHT | MODERATE | ACTIVE | VERY_ACTIVE
    primary_goal            varchar(20) not null,  -- LOSE_WEIGHT | MAINTAIN | GAIN_MUSCLE
    target_weight_kg        numeric(5,2),
    onboarding_completed_at timestamptz not null default now(),
    updated_at              timestamptz not null default now()
);
```

Canonical units are **metric** (cm, kg) like the rest of the DB; imperial input is converted by the client per `user_settings.unit_system`, same as the existing weight feature.

### API

All endpoints live under the existing `/api/v1` prefix (matching every other controller in the backend — `/api/v1/weights`, `/api/v1/settings`, etc.; earlier drafts of this doc said `/api/user-details`, which was wrong):

```http
GET  /api/v1/user-details                → 200 body | 404 if not yet onboarded
PUT  /api/v1/user-details                → upsert (onboarding submit AND later edits from settings)
POST /api/v1/user-details/suggest-goals  → { bmr, tdee, calories, proteinGrams, carbsGrams, fatGrams, waterLiters }
       body: { gender, birthDate, heightCm, weightKg, activityLevel, primaryGoal }
```

- `suggest-goals` is stateless (computes from the request body) so the wizard can show live suggestions before anything is saved.
- Onboarding submit = client calls `PUT /api/v1/user-details`, then (if provided) `POST /api/v1/weights` for the initial weight through the **existing** weight endpoint, then optionally `PUT /api/v1/settings` with the accepted goals (including `dailyWaterGoalLiters`, which already exists on `user_settings`). No new "combo" endpoint — reuse what exists; the wizard orchestrates.
- "Has the user onboarded?" signal: the backend currently has **no** `/me` or login-response user payload to extend (login returns only the access/refresh token pair — see `AuthResponse`). Rather than inventing a new endpoint for this doc, clients rely on `GET /api/v1/user-details` returning 404 as the onboarding signal — call it once after login/register and route to onboarding on 404. If a `/me` endpoint gets built for other reasons later, `hasUserDetails` can be added to it then, but that's out of scope here.

### Skippability

The wizard is **skippable** ("I'll do this later") — data-entry friction right after registration is the #1 drop-off point. Skip = no `user_details` row; clients re-offer onboarding via a dismissible dashboard banner, and everything is editable later under Settings → Profile. No feature is hard-blocked on missing details; the macros tab just shows generic defaults until then.

---

## Wizard UX (both clients, same steps)

1. **Welcome** — one screen, "let's personalize" + Skip link (subtle, top corner).
2. **About you** — gender (3 large select cards) + birth date picker.
3. **Body** — height + current weight, unit-aware inputs (respect `user_settings.unit_system`).
4. **Lifestyle & goal** — activity level (5 options with one-line descriptions) + primary goal (3 cards) + optional target weight (shown only when goal ≠ maintain).
5. **Suggested plan** — final step. Shows the computed calories, protein/carbs/fat, and water goal ("You can change this anytime in Settings"), with two buttons:
   - **Apply these goals** — writes `user_details` (+ initial weight entry) *and* the suggested goals into `user_settings`, then finishes onboarding.
   - **Not now** — writes `user_details` (+ initial weight entry) only, skips the `user_settings` write, then finishes onboarding just the same. Declining the suggestion never blocks or discards the biometric data already collected in steps 2–4.

   Both buttons are always full data-saves for what was entered so far; the only thing "Not now" skips is the goals write. This is distinct from the top-level wizard Skip (which abandons onboarding entirely, before any data is collected).

Progress dots, back navigation, all strings localized EN+HU.

---

## Phase 1 — Backend

**Prompt:**

> In the Lifey backend (Spring Boot 4, Java 24, feature-based packaging), implement the `user_details` feature per `docs/21-onboarding-user-details-plan.md`.
>
> - New package `com.lifey.userdetails` (entity, repository, service, controller, dto, enums `Gender`, `ActivityLevel`, `PrimaryGoal`).
> - Flyway `V38__user_details.sql` exactly as in the plan (check the actual next free version number at implementation time).
> - `GET /api/v1/user-details` (404 with standard error body when absent), `PUT /api/v1/user-details` (upsert, bean-validation: birth date in the past and age between 13 and 120, height 80–250 cm, target weight 30–300 kg when present; `updated_at` refreshed on update).
> - `POST /api/v1/user-details/suggest-goals`: stateless Mifflin-St Jeor BMR → TDEE → clamped goal-adjusted calories → g/kg-based protein → % + floor-based fat → remainder carbs → bodyweight + activity water formula, exactly as specified in the "Derived output" section of the plan doc (not the old flat 30/40/30 split). Round calories to nearest 10, macro grams to whole numbers, water to nearest 50 mL / 0.1 L. Unit-test the formula against known reference values (both sexes, UNSPECIFIED = average, each activity level, each goal including the safety clamps).
> - Current user always from security context. There is no existing `/me` or login-response payload to extend for a `hasUserDetails` flag (login returns only tokens) — don't invent one; clients use the `GET /api/v1/user-details` 404 as the onboarding signal, per the API section above.
> - Tests: Mockito-based service unit tests + `@WebMvcTest` controller tests (matching the existing `weight`/`settings` feature test style — this repo does not use Testcontainers), covering 404 before any row exists, upsert roundtrip, validation failures (age bounds, height bounds, target weight bounds), and suggest-goals reference values.

---

## Phase 2 — Web wizard

**Prompt:**

> In the Lifey web app (Next.js 16 App Router, react-hook-form + zod, TanStack Query, next-intl, zustand — follow `docs/web/04-frontend-architecture.md`), implement onboarding per `docs/21-onboarding-user-details-plan.md`.
>
> - New route `(app)/onboarding` with the 5-step wizard (single page, client-side step state; progress dots; back nav; Skip link on every step).
> - After successful registration redirect to `/onboarding` instead of the dashboard; on any later login, if `hasUserDetails === false`, show a dismissible dashboard banner linking to `/onboarding` (dismissal persisted in localStorage).
> - Unit-aware height/weight inputs based on the user's `unit_system` setting (convert to metric before sending, mirroring the existing weight-entry form).
> - Step 5 calls `POST /api/user-details/suggest-goals` and renders the suggestion; Accept → `PUT /api/user-details` + `POST /api/weights` (initial weight) + `PUT /api/settings` (goals); Not now → same without the settings call.
> - Settings: add a "Profile" section rendering the same field components for later edits (`GET` + `PUT /api/user-details`).
> - Zod schemas mirror backend validation; all strings in `messages/en.json` + `messages/hu.json`; match the design system (selection cards like existing option pickers).

---

## Phase 3 — Mobile wizard

**Prompt:**

> In the Lifey Flutter app (Riverpod, go_router, dio, feature packaging per `mobile/CLAUDE.md`), implement onboarding per `docs/21-onboarding-user-details-plan.md`.
>
> - New feature `lib/features/onboarding/` (domain/data/application/presentation). Repository calls the three endpoints directly (onboarding happens right after registration, i.e. online — no outbox/drift involvement; the initial weight POST goes through the existing weight repository so it lands in the local DB + sync flow properly).
> - `PageView`-based 5-step wizard matching the steps in the plan; Skip on every page; progress dots; respects `unit_system` for height/weight inputs.
> - Routing: after successful registration navigate to onboarding; on login, if `hasUserDetails == false` (from the login/me response), show a dismissible banner on the dashboard (dismissal in shared_preferences).
> - Settings screen: "Profile" tile → edit screen reusing the same form widgets with data from `GET /api/user-details`.
> - l10n EN+HU ARB entries; existing form validation + `app_snackbar.dart` error patterns; buttons disabled while submitting.

---

## Phase 4 — Verification checklist

- [ ] Register (email + social) on both clients → wizard appears; Skip → dashboard reachable, banner shows.
- [ ] Full wizard on both clients → `user_details` row, first `weight_entries` row, goals in `user_settings` (when accepted).
- [ ] Imperial user: inputs shown in lb/ft-in, DB stores metric, suggestion is correct.
- [ ] Suggest-goals reference values verified, e.g. male, 30y, 180 cm, 80 kg, moderate activity, lose weight:
      BMR = 10×80 + 6.25×180 − 5×30 + 5 = 1780; TDEE = 1780×1.55 = 2759; calories = 2759×0.85 ≈ 2345 (rounded to 2350, deficit 409 kcal, under the 1000 kcal cap, above the 1500 kcal floor);
      protein = 2.2×80 = 176 g (704 kcal); fat = max(2350×0.25/9, 0.6×80) = max(65.3, 48) → 65 g (587 kcal); carbs = (2350−704−587)/4 ≈ 265 g;
      water = 80×35 + 300 (moderate bonus) = 3100 mL → 3.1 L.
- [ ] Edit from Settings → Profile updates the row; `updated_at` changes; no second row.
- [ ] Under-13 birth date rejected on both clients and backend.
- [ ] Existing users (pre-migration) log in normally, see banner, nothing crashes on 404.
