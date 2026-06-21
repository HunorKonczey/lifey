# V12 Plan — Language Selector (HU / EN)

## Goal

The user can switch the app's UI language between **Hungarian** and **English**.
The default is the **phone's language** (if the device is set to neither HU nor
EN, fall back to English). The choice is persisted in the existing per-user
settings and **synced to the backend** like `theme`/`unitSystem`, so it follows
the user across devices.

Only **UI chrome** is translated (labels, buttons, headings, validation
messages, snackbars). **User/DB data is never translated** — food, exercise,
recipe, water-source names etc. are shown exactly as stored.

## Architecture decisions

1. **Standard Flutter localization (`flutter_localizations` + `gen_l10n`).**
   - Translations live in ARB files bundled in the app (`lib/l10n/app_en.arb`,
     `lib/l10n/app_hu.arb`); the `AppLocalizations` class is **generated**
     (never hand-edited, same rule as `*.g.dart`).
   - `intl` is already a dependency, which `gen_l10n` builds on.
   - No runtime string fetching — strings ship with the binary, so language
     works fully offline.

2. **`language` is a synced setting, mirroring `theme` exactly.**
   - Backend: `LanguagePreference { SYSTEM, ENGLISH, HUNGARIAN }` enum + a
     `language` column on `user_settings` (default `SYSTEM`), added to
     `SettingsRequest` / `SettingsResponse` / `SettingsMapper`.
   - Mobile: a `language` column on the drift `user_settings` table + the
     `UserSettings` domain model, written into the outbox `toJson` payload and
     read back in `PullEngine._pullSettings`.
   - `SYSTEM` is the default and means "follow the device locale".

3. **`SYSTEM` resolves to the device locale at the `MaterialApp` level.**
   - `SYSTEM` → `locale: null` (Flutter picks the best match from
     `supportedLocales`, i.e. the phone language, falling back to `en`).
   - `ENGLISH` → `Locale('en')`, `HUNGARIAN` → `Locale('hu')`.
   - Driven from `settingsControllerProvider` in `app.dart`, exactly like
     `themeMode` already is.

## Flow

```
SettingsScreen language selector (System / English / Magyar)
  → SettingsRepository.save  (offline-first: local write + outbox 'update')
  → app.dart reads settings.language → MaterialApp.locale
      SYSTEM   → null   → device locale (HU or EN, else EN)
      ENGLISH  → en
      HUNGARIAN→ hu
  → every screen reads text via AppLocalizations.of(context)
  → DB-sourced names (foods/exercises/…) rendered as-is, untouched
```

## Dependency order

```
A1 → A2            (backend: sync the preference, testable on its own)
        ↓
B1 → B2 → B3 → B4  (B3 needs B1's delegates + B2's setting; B4 expands coverage)
                ↓
               C1
```

Recommendation: do the backend (A) first so the `/settings` contract already
carries `language`, then build the mobile localization infrastructure (B1),
wire persistence (B2) and switching (B3), and finally sweep the strings (B4).

---

## Phase A — Backend (sync the preference)

### A1. `language` field on settings + Flyway migration (`V11`)
Add a `LanguagePreference { SYSTEM, ENGLISH, HUNGARIAN }` enum next to
`ThemePreference`. Add a non-null `language` column (default `SYSTEM`) to the
`UserSettings` entity and a `V11__user_settings_language.sql` migration. Thread
`language` through `SettingsRequest` (`@NotNull`), `SettingsResponse` and
`SettingsMapper`, mirroring how `theme` is handled.

### A2. Backend tests
There are currently no tests under `com.lifey.settings`. Add a focused test for
the settings flow that asserts `language` round-trips (default `SYSTEM` on lazy
create; a `PUT` with `HUNGARIAN` persists and is returned), following the
existing test conventions (MockMvc slice / service unit test) used elsewhere in
the backend.

---

## Phase B — Mobile (Flutter)

### B1. Localization infrastructure
Add `flutter_localizations` (SDK) + `flutter: generate: true` + an `l10n.yaml`.
Create `lib/l10n/app_en.arb` and `lib/l10n/app_hu.arb` seeded with an initial
key set (at least the strings needed by `SettingsScreen` and the language
selector). Wire `MaterialApp.router` in `app.dart` with
`AppLocalizations.localizationsDelegates` + `supportedLocales` (`en`, `hu`).
Run the generator. At this point the app already honours the **device** locale
for the seeded keys.

### B2. Thread `language` through the mobile settings layer
Add a `language` column to the drift `user_settings` table (schema bump +
migration), a `LanguagePreference { system, english, hungarian }` enum + field
on the `UserSettings` domain model, and wire it through
`SettingsRepository` (`_toDomain` / `save` companion / `toJson`) and
`PullEngine._pullSettings`. Run `build_runner`.

### B3. Locale override + settings selector
In `app.dart`, drive `MaterialApp.locale` from `settings.language`
(`SYSTEM`→null, `ENGLISH`→`Locale('en')`, `HUNGARIAN`→`Locale('hu')`), the same
way `themeMode` is driven today. Add a "Language" `SegmentedButton` to
`SettingsScreen` (System / English / Magyar), matching the existing Theme
selector. After this, switching language live re-renders the app.

### B4. Migrate UI strings to `AppLocalizations`
Replace every hardcoded UI string across `lib/features/**/presentation/**` and
`lib/shared/widgets/**` with `AppLocalizations.of(context)` keys, adding the
matching `en` + `hu` entries to the ARB files. **Do not** localize names that
come from domain/DB data (food/exercise/recipe/water-source names, server error
messages already handled by `friendlyError`). This step is large and may be
split feature-by-feature (auth, nutrition, workouts, recipes, water, weight,
statistics, settings, shared) across several passes.

---

## Phase C — Wrap-up

### C1. Documentation
Document the localization approach in the docs: how to add a new string (ARB +
regenerate), how a new language would be added (new ARB + `supportedLocales`),
and the `language` field on the `/settings` contract
(`SYSTEM` | `ENGLISH` | `HUNGARIAN`, default `SYSTEM`).

---

## Open considerations

- **Plural / interpolation**: a few strings have counts or embedded values
  ("Deleted {name}", "{n} sets"). Use ICU placeholders/plurals in the ARB so
  Hungarian grammar stays correct rather than string concatenation.
- **`intl` date/number formatting**: `DateFormat`/`NumberFormat` should use the
  active locale so dates and decimal separators localize too (HU uses `,`).
- **Scope of B4**: large surface area; safe to ship incrementally — untranslated
  keys simply fall back to the template (English) language.
- **No new languages now**: enum + ARB structure leaves room, but only HU/EN
  are in scope.
