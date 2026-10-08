# Hátralévő munka — app-szintű backlog

**Szándékosan számozatlan.** A számozott docok tervek; ez egy munkalista, ami minden
felvett vagy elvetett tételnél változik. A landing page / monetizáció saját listája:
[`landing_page/REMAINING-WORK.md`](landing_page/REMAINING-WORK.md) — ez a fájl arra hivatkozik,
nem ismétli meg.

Utolsó átnézés: **2026-10-03** (a chat-eredménykártya — edzés / PR megosztása — lezárása után; korábban 2026-10-02, a progress fotók + testméretek lezárása után; korábban 2026-09-26 a teljes `docs/` alapján).

**Jira (2026-10-07-től):** a státuszt a Jira követi — `hunorkonczey.atlassian.net`, projekt `LIF`. Minden alábbi
tételhez tartozik Story a megfelelő epic alatt (LIF-20…LIF-28); új tételnél a Jira-jegyet is fel kell venni.
Ez a fájl marad a részletes, dokumentumokra hivatkozó leírás.

**Használat:** ha egy tételt felveszel, csináld meg, **töröld a sorát**, és a landolt állapotot
a hozzá tartozó számozott tervbe írd.

---

## 1. Nagy, értékes tételek

### 1.1 AI-bekötés — [`23`](23-ai-calorie-estimation-plan.md)

**1. fázis kész (2026-09-22), backend + mobil:** `POST /api/v1/meals/estimate` valódi
kredit-gate-tel (Free 3 / Pro 100 havonta), a mobilon a Log meal képernyő „Becslés fotóról”
gombja — részletek a `23` két „As built” szakaszában. Hátravan:

- **Lemért ételek próbája:** az élő pass (`23` „Live prompt pass”) szemre ítélt fotókon futott.
  Néhány fotó olyan ételről, aminek ismert a valódi tömege, megmondaná, mennyit téved az adagoknál
  (mindkét modell alábecsül). Ez dönthetné el a `claude-haiku-4-5` → `claude-sonnet-5` váltást is,
  amit a receptgenerálás élő próbája is felvetett (`23` „Live pass”).
- **Eszközös próba:** sem a fotós becslés, sem a receptvarázsló nem futott még valódi telefonon.
- **2. fázis kész** (backend + mobil varázsló, `23` „As built — Phase 2”): `POST
  /api/v1/recipes/generate` és a Receptek fül „Generálás AI-val” gombja.

Az eredeti állapot, amiből indult:

- **1. fázis:** fotóból kalória-/makróbecslés → szerkeszthető eredmény → mentés a meglévő
  offline-first meal flow-n.
- **2. fázis:** receptgeneráló varázsló (diéta, étkezéstípus, kalóriasáv, hozzávalók).

A monetizáció elvarratlan szálai:

- ✅ `72` B1 — a számláló most már növekszik, a 402 / `AI_CREDITS_EXHAUSTED` gate él.
- ✅ `72` B4 — a Pro havi 100-as fair-use limitjét az `EntitlementAiFeatureGate` ellenőrzi.
- ✅ `72` M7 — `AiCreditChip` és `requireAiCredits` a Log meal képernyőn.


### 1.2 Edzői nézet tableten — [`chat/41`](chat/41-trainer-mobile-v2-plan.md) §8.2

A **telefonos** edzői nézet kész (T1–T7, PR #34, `mobile/lib/features/trainer/`). Ami hiányzik:

- ✅ **Tablet-elrendezés kész (2026-09-23).** 900 dp felett a kliens-lista és a
  program-könyvtár kettéosztott nézetre vált (lista + részletező egymás mellett); a
  döntés indoklása és a szándékos kihagyások a [`chat/41`](chat/41-trainer-mobile-v2-plan.md)
  §8.2-ben. Eszközön még nem láttuk.
- **Edzői push-csomag** (41 §8.3): pl. „a kliens kihagyott egy edzést”, „leadta a heti mérést”.
  A [`30`](30-push-notifications-plan.md) infrastruktúrájára épül, külön terv kell hozzá.
- *Nem hiány:* a programszerkesztés tudatos döntés alapján csak weben van (41 T6).

### 1.3 Progress fotók és testméretek — [`05`](05-improvement-roadmap.md) #10 — ✅ kész (2026-10-02)

Testméretek (derék, mellkas, csípő, kar, comb; offline szinkron) és fotó-idővonal oldalankénti
összehasonlítással, a Súly fejléc **Test** gombja mögött ([`80`](80-progress-photos-measurements-plan.md)).
Eszközön még nem láttuk, és a backend Flyway-/Testcontainers-ellenőrzése (Docker) hátravan — a részletek
a `80` §12-ben. Szándékosan kimaradt: edzői láthatóság, offline fotó-várólista, Pro-korlát, bal/jobb méret.

### 1.4 Okosabb súlytrend — [`05`](05-improvement-roadmap.md) #11 — ✅ kész (2026-09-23)

7 napos mozgóátlag a Súly fülön és a statisztika súly-metrikáján, plusz a célsúly-kártya a
becsült dátummal ([`76`](76-smarter-weight-trend-plan.md)). Eszközön még nem láttuk.

### 1.5 Garmin / Strava — [`07`](07-roadmap.md) V4

Nincs integráció. A HealthKit és a Health Connect kész.

---

## 2. Kisebb tételek

| Tétel | Mi | Hol |
|---|---|---|
| Web (marad) | a `/hu` első betöltése ~215 KB gzip (volt 278), a cél 100 KB: a maradék a közös React/Next + React Query/Zustand alap; a marketing tokenek (`72` D5) és a Lighthouse újramérés (`lhci`, telepített URL kell) is nyitva | `landing_page/REMAINING-WORK.md` §2.2, §2.3 |
| Zene M4 | Spotify iOS-en (App Remote) — Spotify Developer regisztráció kell | [`music/46`](music/46-workout-music-controls-plan.md) |
| Design-backlog | a redesign mockupjaiból adódó extra UI-elemek — egyenként ellenőrizni, mi készült el (a kalória-sparkline pl. már kész) | [`design/19`](design/19-new-features.md) |

### 2.1 A mobil-redesign (`77`) után

A redesign lezárult (R0–R7); ami szándékosan kimaradt, vagy közben kiderült. A landolt állapot a
[`redesign/77-mobile-redesign-plan.md`](redesign/77-mobile-redesign-plan.md)-ben van (a chip-kontraszt
is ott oldódott meg: a metrikaszínek AA-k a saját 12 / 16 %-os tintájukon, a `contrast_test` őrzi).

| Tétel | Mi | Hol |
|---|---|---|
| Darabos adagok | „½ db", „1 db" chipek az étel hozzáadása lapon — étel-modellbe darabsúly + sync kell | `77` §6 |
| Health Connect / HealthKit írás | a súly visszaírása; amíg nincs írási út, a „Health Connect-ben is mentve" sor rejtve marad | `77` §6 |
| Natív felületek | iOS widget / Live Activity, Android widget színillesztése (a Watch kész: [`watch/79`](watch/79-watch-redesign-verification.md); watch-komplikáció nincs, külön terv kell). A Wear OS redesign emulátoros végpróbája 2026-10-07-én lefutott (LIF-95, [`redesign-watch/79`](redesign-watch/79-watch-redesign-plan.md) §12): a kilenc elrendezési hibát 2026-10-08-án javítottuk és újrafényképeztük (LIF-131, ugyanott); nyitva: 192 dp AVD, fizikai óra, Always-on, az Apple oldal | `77` §6 |
| Material Symbols ikonfont, golden-tesztek, max-HR beállítás | tudatosan kimaradt | `77` §6 |
| Edzői kliensnézet: lépéscél, tervezett alkalmak | a trainer API-ban nincs kliens-lépéscél és „tervezett / teljesített" darabszám, ezért a KPI-csempék sorai szerényebbek a canvasnál („7 nap átlaga", kihagyott alkalom) | `77` R6.5 |
| Edzői kliensnézet: cél a fejlécben | a canvas „Goal: build muscle" sora mögött nincs tárolt cél | `77` R6.7 |
| `showModalBottomSheet` → `showLifeySheet` | 40 hívás használja még a nyers API-t (témázott lap, de egyedi görgetéssel / `DraggableScrollableSheet`-tel); az egységes keret az összetett lapokra külön kört kér | `77` R7.2 |
| Design-audit a CI-ban | ✅ kész (2026-10-03): a `mobile-ci.yml` futtatja a `dart run tool/design_audit.dart --strict`-et | `77` R7.1 |
| Emulátoros végpróbák | az edzői folyamatok, a hónapnézet és a tablet világos / magyar módja eszközön lefutott 2026-10-07-én (LIF-94, `77` §12 „R6 follow-up”); nyitva: tablet sötét HU, kiosztott / programok panel, offline állapotok, iOS | `77` §12 R6 |


### 2.2 A web-redesign (`78`) után

A web redesign lezárult (W0–W10, a napló a [`78`](redesign-web/78-web-redesign-plan.md) §12-ben); a szándékosan kimaradt (§6) és a közben kiderült tételek:

| Tétel | Mi | Hol |
|---|---|---|
| Meghívó: megosztható link, emlékeztető | az előzmény már kész (`82` S2); a link és az emlékeztető a meghívó-modell bővítését kéri | `78` §6 |
| Súly napszak / jegyzet, étel-adagok, rost / cukor, kedvenc ételek | a `WeightResponse` csak dátumos; az étel-modell nem ismeri az adagot | `78` §6 |
| „Az edződtől" jelölés a kiosztott recepten | a másolat nem őrzi a származást | `78` §6 |
| Edzői étkezés-komment, edzői lépéscél | új végpont / adat | `78` §6 |
| Chat jelenlét, megosztott étkezés kártya | chat-szolgáltatás munka; az edzés / PR kártya kész és kétkészülékes emulátoron végigpróbálva 2026-10-07-én (LIF-92; nyitva: web csempe, iOS; az offline megosztás hibaüzenete a lapon belül látszik (LIF-126), de egy még nem létező szálba offline nem lehet sorba állítani — [`chat/83`](chat/83-chat-result-card-plan.md)), a `kind` bővíthető | `78` §6 |
| Edzői kérelem „végzettség" | nem gyűjtjük | `78` §6 |
| Sablon időtartam, ismétlésszám | a sablon csak szettszámot tárol; az idő becslés | `78` W9.1 |
| Sablonhasználat ütemezésből | a „Használja" csak a kiosztottakat számolja; az ütemezésekhez kliensenként külön lekérés kell | `78` W9.1 |
| Számlázás: két csomagos canvas | a canvas Alap / Pro, a termékben Starter / Pro / Studio; az „utána ingyenes" mondat nincs definiálva | `78` W9.5 |
| ~~Repository-tesztek az új JPQL-ekre~~ | **kész 2026-10-08-án (LIF-98):** `SuperAdminQueriesRepositoryTest`, 7 teszt valódi Postgres 16-on (`member of`, csoportosított darabszám, `min`, join fetch + countQuery, audit-feedek); a lekérdezések eltörése ellenőrizve | `78` W9.b1–b3 |
| Web e2e futtatási feltételek | a backend-függő specek frissítve és zöldek (16 + 10); a chat-spec a chat-szolgáltatást és a `web-chat` webet kéri, a 10 billing-spec `BILLING_ENABLED=true` backendet — ezek nélkül kihagyják magukat / elhasalnak | `78` W10 follow-up |
| ~~Billentyűzetes húzás, 200 %-os nagyítás, telefon-billentyűzet~~ | **végigpróbálva 2026-10-08-án (LIF-96):** a billentyűs elhelyezés (Space → Tab → Enter) működik (új e2e: `trainer-program-keyboard.spec.ts`), a sablon-sorrendezés is; 200 %-on (36 oldal, HU + EN) nincs túlcsordulás; a telefon-billentyűzet a keresőt, a mennyiséget és a chat-composert nem takarja. Talált hibák: a sablon-fogantyú billentyűs húzása nem rak le (LIF-136), a modalok nem adják vissza a fókuszt (LIF-137), az alsó sáv eltakarja a fókuszt 200 %-on (LIF-138), asztali billentyű-súgók telefonon (LIF-139), a naptár-áthelyezés csak húzással megy (LIF-140), `<html lang>` mindig „en” (LIF-141) | `78` napló „LIF-96” |

---

## 3. Félbemaradt ellenőrzések / ismert hibák

- **[`75`](75-log-food-from-foods-tab-plan.md)** — a webes rész (Prompts 4–7) implementálva,
  böngészős ellenőrzés hátravan.
- **[`watch/50`](watch/50-watch-f6c-session-plan-sync-plan.md) (F6c)** — kód kész; a telefonról indított
  edzés fele Android emulátoron végigpróbálva 2026-10-07-én (LIF-90, §8: a telefonon hozzáadott gyakorlat megjelenik
  az órán, az óra választása átáll a telefonon). Az óra főlapja a saját választását most követi (LIF-129: a főlap a standalone pozíció helyett a
  `currentExerciseId` szerinti gyakorlatot írta ki; Android unit teszt, iOS még Apple órán ellenőrizendő). Nyitva: az órán
  indított ág, a törlés, az offline óra és az iOS.
- **Edzés üres szettsorai** — **Android emulátoron ellenőrizve (2026-10-07, LIF-91): a hiba nem reprodukálható.** Kódszinten
  (2026-10-03) a képernyő `targetSets: rows.length`-et ment (`_buildPlanned`), a `planSessionRows` ebből építi újra a sorokat,
  a pull nem írja felül, és a szerver is tárolja (`pull_engine_workout_session_target_sets_test`, `session_row_plan_test`).
  Az emulátoros próba (Pixel 10, Push day sablon, Bench press 1 kitöltött + 3 üres sor): üres sor hozzáadása → kilépés →
  visszatérés, majd az app teljes leállítása és hideg indítása, majd az ongoing értesítésre koppintás — mindháromszor
  mind a 4 sor megmaradt, a szerveren `target_sets = 4` (Bench press) / `3` (Dips). Nyitva csak az iOS Live Activity koppintás
  (Apple-eszköz kell hozzá).
- **[`80`](80-progress-photos-measurements-plan.md)** — testméretek + progress fotók: kód és tesztek kész, a Docker-es
  `mvnw verify` lefutott (2026-10-03, 1159 teszt, zöld — V78–V81 Flyway ↔ entitás `validate` is). Az Android emulátoros
  végigpróba **lefutott (2026-10-07, LIF-88)**: offline mérés → szinkron, fotó galériából és kamerából, szerkesztés,
  összehasonlítás, törlés, világos téma + magyar nyelv — mind rendben (részletek: `80` §12). Nyitva: iOS (Apple-eszköz)
  és a tablet-elrendezés (LIF-94).

---

## 4. Külső feltételre vár

- **Store-indulás** (App Store Connect, Play Console, IAP, AdMob, Stripe, impresszum, jogi
  review) — a cégalapításra vár, tudatosan parkoló. Részletek:
  [`landing_page/REMAINING-WORK.md`](landing_page/REMAINING-WORK.md) §1.

---

## Javasolt sorrend

1. AI kalóriabecslés (1.1, 1. fázis) — kész; hátra a lemért ételes ellenőrzés.
2. ~~Progress fotók + testméretek (1.3)~~ — kész; hátra az eszközös próba és a Docker-es verify.
3. AI receptgenerálás (1.1, 2. fázis).
4. Tablet-elrendezés (1.2) — ha van rá igény az edzők részéről.
