---
name: localization
description: Add, change, rename or delete user-facing strings in the Flutter app's ARB files (mobile/lib/l10n/app_en.arb and app_hu.arb). Use whenever mobile UI text is written or edited — including as one step of a larger feature — and whenever a string literal would otherwise be hardcoded in a widget. Covers key naming, ICU placeholders and plurals, Hungarian translation rules, and verifying the two ARB files stay in sync. Not for backend messages, and not for names that come from user or server data.
---

# Localization (HU/EN)

`docs/13-localization-guide.md` is the canonical reference for *how* the setup
works (ARB syntax, adding a new language, the synced `language` setting). Read it
when something below is unclear. This skill is the *procedure* for touching
strings, plus the checks that catch the mistakes this repo actually hits.

## Non-negotiables

- Every user-facing string in `mobile/` goes through the ARB files. No literal
  UI text in a widget, ever — not even for a "temporary" screen.
- **Both** files get the key, in the **same order**: `app_en.arb` and `app_hu.arb`.
  A key in EN but not HU compiles fine and then shows English to Hungarian users.
- `@key` description blocks live **only in `app_en.arb`** (the template file).
  `app_hu.arb` holds `"key": "value"` pairs and nothing else.
- Never hand-edit `lib/l10n/app_localizations*.dart` — generated and gitignored.

## Procedure

### 1. Look for an existing key first

984 keys already exist. Before inventing one:

```bash
grep -n '"[a-zA-Z]*Save' mobile/lib/l10n/app_en.arb    # by name
grep -in '": "Save' mobile/lib/l10n/app_en.arb          # by English text
```

Reuse only when the meaning is identical in both languages — sharing a key
across two contexts that happen to be the same word in English is how you get
an untranslatable Hungarian string later.

### 2. Name the key

camelCase, `<what><Role>`, matching the established suffixes:

| Suffix | Count in use | For |
|---|---|---|
| `Label` | 282 | field labels, section headings, inline text |
| `Title` | 139 | screen / dialog / sheet titles |
| `Message` | 121 | snackbars, empty states, confirmations |
| `Button` | 59 | button captions |
| `Subtitle` | 28 | secondary line under a title |
| `Tooltip` / `Hint` / `Error` / `Action` | 22 / 20 / 16 / 16 | as named |

Prefix with the feature or screen when the bare name would be ambiguous:
`workoutSuccessPrTitle`, `copyDaySheetMealsKcal`, `waterSourcesDescription`.

### 3. Write the English entry

Append near the related keys if a clear feature block exists; otherwise append
at the end of the file. Keep the HU file in the same order.

```json
"editWeatherDialogTitle": "Weather at start",
"@editWeatherDialogTitle": {
  "description": "Title of the bottom sheet that sets a hike's weather snapshot on the summary screen (docs/cardio/60 C8.6)"
},
```

Write the description for a translator who cannot see the screen: say where the
string appears and what it does. This repo's convention is to cite the plan doc
or mockup id when there is one — keep that up.

**Never build a sentence by concatenation.** Use ICU placeholders, so Hungarian
word order and suffixes stay correct:

```json
"deletedFoodMessage": "Deleted {name}",
"@deletedFoodMessage": {
  "description": "Snackbar after deleting a food",
  "placeholders": {"name": {"type": "String"}}
}
```

For counts use ICU plurals (`one`/`other`, or `=1`/`other`):

```json
"mealsCopiedMessage": "{count, plural, one{1 meal copied} other{{count} meals copied}}",
"@mealsCopiedMessage": {
  "description": "Snackbar after copying a day's meals",
  "placeholders": {"count": {"type": "int"}}
}
```

### 4. Write the Hungarian entry

Same key, same placeholders, same plural branches — only the text differs.

House style, taken from the existing translations:

- **Informal second person** ("Add meg az email címed", "Nézd meg az emailedet"),
  never formal "Ön".
- **No plural noun after a numeral.** Hungarian counts with the singular:
  `other{{count} étkezés}`, not `étkezések`. Keep the `one`/`other` branches —
  they exist so the numeral itself can be dropped in the `one` case — but
  translate the noun as singular in both.
- **Decimal comma** in literal numbers: `0,75L`.
- Translate the meaning, not the words. If English reads naturally and Hungarian
  does not, rewrite the Hungarian rather than tracking the English structure.

### 5. Verify before you call it done

```bash
.claude/skills/localization/scripts/check_arb_sync.sh
```

It fails loudly on: keys missing from either file, `@` blocks that leaked into
the Hungarian file, placeholder sets that differ between EN and HU, and keys
whose `placeholders` block is missing while the value contains `{...}`. Fix
everything it reports — do not eyeball the diff instead.

Then, if you added or changed keys used from Dart:

```bash
cd mobile && flutter gen-l10n && flutter analyze
```

`flutter run`/`build`/`pub get` regenerate automatically (`generate: true`);
`gen-l10n` is only needed to get IDE autocomplete and analyzer results now.

### 6. Use it in the widget

```dart
import '../../../l10n/app_localizations.dart';

final l10n = AppLocalizations.of(context)!;
Text(l10n.editWeatherDialogTitle)
Text(l10n.deletedFoodMessage(food.name))
```

The `!` is safe: `app.dart` always installs `AppLocalizations.delegate`.

## Renaming or deleting a key

1. `grep -rn "l10n\.<oldKey>" mobile/lib mobile/test` and update every call site.
2. Remove the key from `app_en.arb` (**including its `@` block**) and `app_hu.arb`.
3. Run the sync check and `flutter analyze` — a stale call site is a compile error,
   a stale key is silent dead weight, and the check script catches the second.

## Do not localize

- Names coming from domain or DB data: foods, exercises, recipes, water sources —
  anything user- or server-supplied.
- Backend error messages already routed through `friendlyError`.
- Debug output, log lines, and analytics event names.
