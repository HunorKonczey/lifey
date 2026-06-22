# Localization guide

Reference for the HU/EN localization built in `docs/12-language-plan.md`.

## Adding a new string

1. Add the key to **both** ARB files, with a `@key` description in the English one:

   ```
   mobile/lib/l10n/app_en.arb
   mobile/lib/l10n/app_hu.arb
   ```

   ```json
   "saveButton": "Save",
   "@saveButton": {"description": "Label for the save button on the settings form"},
   ```

   For strings with embedded values, use ICU placeholders rather than string
   concatenation (keeps Hungarian grammar/word order correct):

   ```json
   "deletedFoodMessage": "Deleted {name}",
   "@deletedFoodMessage": {"description": "...", "placeholders": {"name": {"type": "String"}}}
   ```

   For counts, use ICU plurals:

   ```json
   "setsCountLabel": "{count, plural, =1{1 set} other{{count} sets}}",
   "@setsCountLabel": {"description": "...", "placeholders": {"count": {"type": "int"}}}
   ```

2. Regenerate (only needed for IDE autocomplete — `flutter run`/`build`/`pub get`
   do this automatically because `generate: true` is set in `pubspec.yaml`):

   ```bash
   flutter gen-l10n
   ```

3. Use it in a widget:

   ```dart
   import '../../../l10n/app_localizations.dart';

   final l10n = AppLocalizations.of(context)!;
   Text(l10n.saveButton)
   Text(l10n.deletedFoodMessage(food.name))
   ```

   `AppLocalizations.of(context)` is typed nullable by the generator; the `!`
   is safe because `app.dart` always installs `AppLocalizations.delegate`.

4. **Never** hand-edit `lib/l10n/app_localizations*.dart` — generated, and
   gitignored (mirrors the `*.g.dart` convention: regenerate, don't commit).

5. Don't localize: names from domain/DB data (food, exercise, recipe,
   water-source names — anything user/server-supplied), or server error
   messages already routed through `friendlyError`.

## Adding a new language

1. Add `lib/l10n/app_<code>.arb` (e.g. `app_de.arb`) with `"@@locale": "de"`
   and every key from `app_en.arb` translated. `AppLocalizations.supportedLocales`
   is derived from the ARB files present — no extra config needed for the
   device-locale (`SYSTEM`) path to pick it up automatically.

2. To let the user *explicitly* pick it in Settings (rather than only via
   `SYSTEM` following the device locale), add a case to **both**:

   - Backend: `LanguagePreference` enum (`backend/src/main/java/com/lifey/settings/LanguagePreference.java`)
   - Mobile: `LanguagePreference` enum (`mobile/lib/features/settings/domain/user_settings.dart`)

   and a new `ButtonSegment` in the Settings screen's Language selector
   (`mobile/lib/features/settings/presentation/settings_screen.dart`), plus
   a case in `LifeyApp._locale()` (`mobile/lib/app.dart`) mapping the new enum
   value to its `Locale`.

3. No backend migration is needed beyond the enum change — `language` is
   stored as `varchar(20)`, not a DB-level enum constraint.

## The `/settings` `language` field

Mirrors `theme` exactly — a synced, per-user preference, not a device-only
setting.

- **Values:** `SYSTEM` | `ENGLISH` | `HUNGARIAN`, default `SYSTEM`.
- **Backend:** `language` column on `user_settings` (Flyway `V11`), threaded
  through `SettingsRequest`/`SettingsResponse`/`SettingsMapper`.
- **Mobile:** `language` column on the drift `user_settings` table (schema
  v3), `LanguagePreference` field on the `UserSettings` domain model, written
  into the outbox payload on save and read back by `PullEngine._pullSettings`.
- **Resolution:** `SYSTEM` → `Locale` `null` (Flutter picks the best match
  from `supportedLocales`, i.e. the phone's language, falling back to `en`);
  `ENGLISH` → `Locale('en')`; `HUNGARIAN` → `Locale('hu')`. Driven from
  `settingsControllerProvider` in `app.dart`, the same way `themeMode` is.
