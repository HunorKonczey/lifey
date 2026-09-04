# 74 – Store Listing, ASO and Privacy Answers

Status: **copy ready to paste · screenshots exportable (HU) · everything else needs the consoles**
Scope: mobile — App Store Connect and Play Console listing content
Depends on: `69` §5 (the spec this fills in), `63` §5 (legal), `72` F5,
[`devops/deploy-ios-appstore.md`](../../devops/deploy-ios-appstore.md),
[`devops/deploy-android-playstore.md`](../../devops/deploy-android-playstore.md)

The two `devops/` guides above cover **how** to submit — signing, build, upload, review flow.
This document is **what to put in the boxes**: the listing copy in both languages with the
character counts already checked, the exact privacy answers derived from the app's real SDKs,
and where the screenshot files come from.

Nothing here can be applied without the store accounts, so §5 lists precisely what only the
account holder can do, in the order that unblocks the most.

---

## 1. Listing text — Hungarian

Store fields have hard limits and both stores truncate silently in search results, so each
field below is given with its count.

| Field | Limit | Value | Count |
|---|---|---|---|
| App name (iOS) | 30 | `Lifey — Edzés & Táplálkozás` | 27 |
| App name (Play) | 30 | `Lifey — Edzés & Táplálkozás` | 27 |
| Subtitle (iOS) | 30 | `Edzésnapló, kalória, edződ` | 26 |
| Short description (Play) | 80 | `Edzésnapló és kalóriaszámláló — az edződ programjával, offline is.` | 66 |
| Keywords (iOS) | 100 | `edzésnapló,kalóriaszámláló,konditerem,makró,súlyzós,futás,edző,fogyás,kardió,étrend` | 83 |
| Promo text (iOS, updatable without review) | 170 | `Új: az edződ programja és üzenetei egy helyen, az órádon is. Ingyenes — a Pro a reklámokat, a teljes előzményt és az AI-t nyitja.` | 129 |

**Full description (Play, 4000 max · iOS description, 4000 max)** — the same text on both,
because a difference between them is a difference nobody maintains:

```
Edzésnapló, kalóriaszámláló és kardió — egy appban, magyarul.

A Lifey azoknak készült, akik komolyan veszik az edzést, de nem akarnak három appot
nyitogatni hozzá. Naplózd a sorozatokat, kövesd a kalóriát és a makrókat, mentsd a futásod
térképpel — és ha személyi edződ van, az ő programja is itt jelenik meg.

EDZÉS
• Sorozatok, ismétlések, súlyok — gyors bevitellel, előzménnyel
• Saját edzéssablonok és többhetes programok
• Pihenőidő-mérő, egyéni csúcsok (PR), gyakorlat-statisztikák

TÁPLÁLKOZÁS
• Kalória és makrók napi bontásban
• Ételkereső, vonalkód-olvasó, saját receptek
• Vízfogyasztás és testsúly követése

KARDIÓ
• Futás, kerékpár, túra — GPS-útvonallal és tempóval
• Szintemelkedés, pulzuszónák, szakaszok
• Apple Health / Health Connect kapcsolat

EDZŐDDEL EGYÜTT
• Az edződ programot és időpontot oszt ki neked
• Beszélgetés az appon belül
• Amíg az edződ előfizet, a Pro funkciókat díjmentesen kapod

ÓRA ÉS WIDGET
• Óra-alkalmazás az edzés naplózásához
• Kezdőképernyő-widget a napi kalóriával és lépéssel

INGYENES ÉS PRO
A Lifey ingyenesen használható, reklámokkal. A Lifey Pro előfizetés reklámmentessé teszi az
appot, feloldja a teljes előzményt (ingyenesen az utolsó 30 nap látszik) és korlátlanná teszi
az AI-alapú kalóriabecslést (ingyenesen havi 3).

Lifey Pro: 1 490 Ft / hó vagy 11 900 Ft / év. Az előfizetés automatikusan megújul, ha a
lejárat előtt legalább 24 órával nem mondod le. A kezelés és a lemondás a fiókod
beállításaiban érhető el a vásárlás után.

ÁSZF: https://lifey.hu/hu/jogi/aszf
Adatkezelési tájékoztató: https://lifey.hu/hu/jogi/adatkezeles
```

---

## 2. Listing text — English

| Field | Limit | Value | Count |
|---|---|---|---|
| App name | 30 | `Lifey — Workout & Nutrition` | 27 |
| Subtitle (iOS) | 30 | `Training log, calories, coach` | 29 |
| Short description (Play) | 80 | `Workout log and calorie counter — with your coach's plan, offline too.` | 70 |
| Keywords (iOS) | 100 | `workout log,calorie counter,gym,macros,strength,running,coach,weight loss,cardio,diet` | 85 |
| Promo text (iOS) | 170 | `New: your coach's plan and messages in one place, on your watch too. Free — Pro removes ads and unlocks full history and AI.` | 124 |

```
Workout log, calorie counter and cardio — in one app.

Lifey is for people who train seriously but do not want three apps to do it. Log your sets,
track calories and macros, save your runs with a map — and if you have a personal trainer,
their programme shows up here too.

TRAINING
• Sets, reps, weights — fast entry, full history
• Your own templates and multi-week programmes
• Rest timer, personal records, per-exercise statistics

NUTRITION
• Calories and macros, day by day
• Food search, barcode scanner, your own recipes
• Water and body-weight tracking

CARDIO
• Running, cycling, hiking — with GPS route and pace
• Elevation, heart-rate zones, splits
• Apple Health / Health Connect integration

WITH YOUR COACH
• Your coach assigns programmes and sessions
• In-app messaging
• While your coach subscribes, you get the Pro features free

WATCH AND WIDGET
• Watch app for logging a session
• Home-screen widget with today's calories and steps

FREE AND PRO
Lifey is free to use, with ads. Lifey Pro removes the ads, unlocks your full history (the free
tier shows the last 30 days) and makes AI calorie estimation unlimited (3 per month on free).

Lifey Pro: HUF 1,490 / month or HUF 11,900 / year. The subscription renews automatically
unless cancelled at least 24 hours before the period ends. Manage or cancel it in your store
account settings after purchase.

Terms: https://lifey.hu/en/legal/terms
Privacy policy: https://lifey.hu/en/legal/privacy
```

**Both stores reject a listing that sells a subscription without the renewal terms and both
legal links.** They are in the last block above on purpose — do not trim it to fit.

---

## 3. Privacy answers

Filled from the app's **actual** dependencies and manifests, not from a template. Wrong answers
here are a rejection; a repeated wrong answer is an account problem (`69` §5.3).

What the app genuinely touches, and why:

| Data | Where it comes from | Leaves the device? |
|---|---|---|
| E-mail, first/last name | account registration, Google Sign-In | yes — our backend |
| Profile photo | `image_picker` (optional avatar) | yes — our backend |
| Health & fitness (workouts, nutrition, weight, steps, heart rate) | user entry + Apple Health / Health Connect read | yes — the user's own synced entries, our backend |
| Precise location | `geolocator`, only while recording a cardio session | yes — as the route on that session |
| Messages | trainer chat | yes — our backend |
| Purchases | `in_app_purchase` + store receipts | yes — our backend, for entitlement |
| Advertising ID, device/IP | **AdMob**, free tier only | yes — Google |
| Push token | Firebase Messaging | yes — Google + our backend |

There is **no** analytics or crash SDK in `mobile/pubspec.yaml` — no Crashlytics, no Sentry, no
Amplitude. That makes several "diagnostics" answers a clean *no*; keep it that way, or update
this table the day one is added.

### 3.1 Apple — App Privacy

| Category | Collected | Linked to identity | Used for tracking |
|---|---|---|---|
| Contact info (name, e-mail) | yes | yes | no |
| Health & Fitness | yes | yes | no |
| Location — precise | yes | yes | no |
| User content (photos, messages) | yes | yes | no |
| Purchases | yes | yes | no |
| Identifiers (device ID, advertising ID) | yes | yes | **yes** (AdMob, free tier) |
| Usage data | yes | no | **yes** (AdMob) |
| Diagnostics | no | — | — |

The tracking answers are what make `NSUserTrackingUsageDescription` (already in `Info.plist`)
and the ATT prompt mandatory. They apply to the free tier only — a Pro user sees no ads and the
SDK is not asked for personalised ads — but App Privacy is declared for the app as shipped, so
they are declared.

**HealthKit review note** (Apple asks nearly every time — `devops/deploy-ios-appstore.md` says
to have one ready; this is it):

> Lifey reads workouts, steps, weight and heart rate from HealthKit to pre-fill the user's own
> training and nutrition log. The data is shown to the user and synced to their own Lifey
> account so it is available on their other devices and, if they choose, to their personal
> trainer. It is never used for advertising, never sold, and never shared with third parties.

### 3.2 Google Play — Data Safety

Declare collected **and** shared for: Personal info (name, e-mail), Photos, Health and fitness,
Location (precise), Messages, Financial info (purchase history), Device or other IDs.

- **Encrypted in transit:** yes (HTTPS only).
- **Users can request deletion:** yes — account deletion is in the app's settings.
- **Data is not sold.**
- **Shared with third parties:** advertising ID and device data with Google (AdMob), push token
  with Firebase.

Play also needs the **Health Connect declaration** separately (Play Console → App content),
justifying each `android.permission.health.READ_*` the manifest asks for — steps, weight, heart
rate, exercise, active calories. Budget review time for it; the manifest already carries the
`ViewPermissionUsageActivity` alias and the rationale intent filter Play requires
(`devops/deploy-android-playstore.md`).

**Ads declaration: yes, the app contains ads.** Content rating questionnaire: answer honestly
about the ad presence; everything else in Lifey is PEGI 3 / Everyone.

---

## 4. Screenshots and graphics

```bash
node devops/export-store-screenshots.mjs
```

Renders straight from `docs/landing_page/design/Lifey Paywall.dc.html` into
`devops/store-assets/` (gitignored — regenerate rather than commit):

| Folder | Size | Frames |
|---|---|---|
| `apple-6.9/` | 1290 × 2796 | P18–P23 |
| `apple-6.5/` | 1242 × 2688 | P18–P23 |
| `play-phone/` | 1080 × 1920 | P18–P23 |
| `play-feature-graphic/` | 1024 × 500 | P25 |

The frames are HTML, so the export **re-renders** them at store size instead of upscaling a
440 px bitmap — the text stays sharp at 1290 px wide. All six show the unlocked state: no ad
slot, no lock glyphs, no history boundary row (`69` §5.1).

### ⚠️ The English set does not exist yet

`69` §5.1 asks for the six frames "per platform, per language". The canvas delivers the six at
full size in **Hungarian** (P18–P23) and English only as **P24, a contact sheet** — thumbnails
at roughly a third scale, with simplified in-frame content. There is nothing to export from it.

Three ways out, cheapest first:

1. **Ship Hungarian screenshots in both storefronts initially.** Both stores allow it; the
   English listing simply shows the Hungarian screenshots. Least work, and the captions are the
   only text an English speaker cannot read.
2. **Translate at export time.** The six frames' strings are few (caption, a date, a name, a
   dozen labels). A string map in the exporter would produce the EN set with no redraw. Maybe
   an hour, and it puts translations in a script rather than in the design.
3. **Draw six EN frames** next to P18–P23 in the canvas, with `data-screen-label="P18-en"` … —
   the exporter picks them up with no code change. Correct, and the only option that survives a
   later design revision cleanly.

Recommendation: **1 for the first submission, 3 before any English-language marketing push.**
Option 2 reads like a shortcut and becomes the place translations rot.

---

## 5. What only the account holder can do

In the order that unblocks the most:

1. **Company identity** — still outstanding from `72` F1 Prompt 6, and now blocking twice over:
   the Impresszum page has five `[kitöltendő]` fields, and both stores need a legal entity name
   and address on the developer account. Needed: company name, registered address, company
   registration number, tax number, representative.
2. **Create the two app records** — App Store Connect and Play Console. Bundle id / package name
   must match `mobile/`'s existing ones.
3. **Create the two IAP products in each store**: `lifey.pro.monthly` (1 490 Ft) and
   `lifey.pro.yearly` (11 900 Ft), auto-renewing subscriptions in one subscription group
   (`63` D-M6). Their ids are already compiled into the app.
4. **AdMob console**: create the app on both platforms and the four ad units (banner +
   interstitial × 2). Then the ids go in via `--dart-define`, and
   `dart run tool/check_release_ad_ids.dart` from `mobile/` confirms all six are real
   (`72` Prompt 11).
5. **Paste this document into the consoles** — §1 and §2 into the listing fields, §3 into App
   Privacy / Data Safety / Health Connect declaration, §4's PNGs into the media sections.
6. **Then** the store sandbox matrix can finally run:
   [`73`](73-billing-verification-runbook.md) §2.

Once the listings exist, one code change remains (`72` Prompt 20): the real store URLs go into
`web/src/components/marketing/StoreBadges.tsx`, whose badges are inert "Hamarosan" placeholders
today, and the official Apple/Google badge artwork replaces the neutral glyph placeholders
(`68` §12.2 DV-11).
