# Hátralévő munka — app-szintű backlog

**Szándékosan számozatlan.** A számozott docok tervek; ez egy munkalista, ami minden
felvett vagy elvetett tételnél változik. A landing page / monetizáció saját listája:
[`landing_page/REMAINING-WORK.md`](landing_page/REMAINING-WORK.md) — ez a fájl arra hivatkozik,
nem ismétli meg.

Utolsó átnézés: **2026-09-26** (a teljes `docs/` státuszsorai + kódellenőrzés alapján).

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

### 1.3 Progress fotók és testméretek — [`05`](05-improvement-roadmap.md) #10

Nincs belőle semmi a kódban.

- Fotó-idővonal, egymás melletti összehasonlítás.
- Méretek: derék, mellkas, kar, comb — előzmény + grafikon.
- A meglévő képfeltöltési infrastruktúra (recept / avatar) újrahasznosítható.

### 1.4 Okosabb súlytrend — [`05`](05-improvement-roadmap.md) #11 — ✅ kész (2026-09-23)

7 napos mozgóátlag a Súly fülön és a statisztika súly-metrikáján, plusz a célsúly-kártya a
becsült dátummal ([`76`](76-smarter-weight-trend-plan.md)). Eszközön még nem láttuk.

### 1.5 Garmin / Strava — [`07`](07-roadmap.md) V4

Nincs integráció. A HealthKit és a Health Connect kész.

---

## 2. Kisebb tételek

| Tétel | Mi | Hol |
|---|---|---|
| Web first-load JS | `/hu` ~275 KB gzip a 100 KB-os cél helyett; bundle-analyzer + az Analytics/SpeedInsights halasztása | `landing_page/REMAINING-WORK.md` §2.2 |
| Web apróságok | sitemap `x-default`, EUR-os ármondat, reconciliation-runbook, marketing tokenek | `landing_page/REMAINING-WORK.md` §2.3 |
| Zene M4 | Spotify iOS-en (App Remote) — Spotify Developer regisztráció kell | [`music/46`](music/46-workout-music-controls-plan.md) |
| Chat kiszervezése | `com.lifey.chat` → önálló `lifey-chat` szolgáltatás; terv jóváhagyásra vár, csak skálázási igény esetén sürgős | [`chat/44`](chat/44-chat-service-extraction-plan.md) |
| Design-backlog | a redesign mockupjaiból adódó extra UI-elemek — egyenként ellenőrizni, mi készült el (a kalória-sparkline pl. már kész) | [`design/19`](design/19-new-features.md) |

### 2.1 A mobil-redesign (`77`) után

A redesign lezárult (R0–R7); ami szándékosan kimaradt, vagy közben kiderült. A landolt állapot a
[`redesign/77-mobile-redesign-plan.md`](redesign/77-mobile-redesign-plan.md)-ben van (a chip-kontraszt
is ott oldódott meg: a metrikaszínek AA-k a saját 12 / 16 %-os tintájukon, a `contrast_test` őrzi).

| Tétel | Mi | Hol |
|---|---|---|
| Web palettaillesztés | a Next.js app még a régi palettát használja; külön terv kell a `web/`-re | `77` §6 |
| Chat-eredménykártya | edzés / PR megosztása chat-kártyaként — a csatolmány jelenleg csak kép, a chat-szolgáltatáson is változtatni kell | `77` §6 |
| Darabos adagok | „½ db", „1 db" chipek az étel hozzáadása lapon — étel-modellbe darabsúly + sync kell | `77` §6 |
| Health Connect / HealthKit írás | a súly visszaírása; amíg nincs írási út, a „Health Connect-ben is mentve" sor rejtve marad | `77` §6 |
| Natív felületek | Watch, iOS widget / Live Activity, Android widget színillesztése | `77` §6 |
| Material Symbols ikonfont, golden-tesztek, max-HR beállítás | tudatosan kimaradt | `77` §6 |
| Edzői kliensnézet: lépéscél, tervezett alkalmak | a trainer API-ban nincs kliens-lépéscél és „tervezett / teljesített" darabszám, ezért a KPI-csempék sorai szerényebbek a canvasnál („7 nap átlaga", kihagyott alkalom) | `77` R6.5 |
| Edzői kliensnézet: cél a fejlécben | a canvas „Goal: build muscle" sora mögött nincs tárolt cél | `77` R6.7 |
| `showModalBottomSheet` → `showLifeySheet` | 40 hívás használja még a nyers API-t (témázott lap, de egyedi görgetéssel / `DraggableScrollableSheet`-tel); az egységes keret az összetett lapokra külön kört kér | `77` R7.2 |
| Design-audit a CI-ban | `dart run tool/design_audit.dart --strict` — most 0, érdemes kapuzni | `77` R7.1 |
| Emulátoros végpróbák | a chat-szolgáltatást igénylő edzői folyamatok (üzenet / ütemezés lapok, kommentelés), a naptár hónapnézete, a tablet világos / magyar módja eszközön még nem látott | `77` §12 R6 |

---

## 3. Félbemaradt ellenőrzések / ismert hibák

- **[`75`](75-log-food-from-foods-tab-plan.md)** — a webes rész (Prompts 4–7) implementálva,
  böngészős ellenőrzés hátravan.
- **[`watch/50`](watch/50-watch-f6c-session-plan-sync-plan.md) (F6c)** — kód kész, eszközös
  végpróba hátravan.
- **Edzés üres szettsorai** — ismert bug (2026-07-15-én még javítatlan), az edzői feature után
  újra kellett volna nézni.
- **Chat-csatolmány tesztek Windowson** — 2–4 teszt fájl-lock miatt elbukik (`72` M10); zaj
  minden teljes futásban.

---

## 4. Külső feltételre vár

- **Store-indulás** (App Store Connect, Play Console, IAP, AdMob, Stripe, impresszum, jogi
  review) — a cégalapításra vár, tudatosan parkoló. Részletek:
  [`landing_page/REMAINING-WORK.md`](landing_page/REMAINING-WORK.md) §1.

---

## Javasolt sorrend

1. AI kalóriabecslés (1.1, 1. fázis) — kész; hátra a lemért ételes ellenőrzés.
2. Progress fotók + testméretek (1.3), mellé a súlytrend (1.4) mint gyors nyerés.
3. AI receptgenerálás (1.1, 2. fázis).
4. Tablet-elrendezés (1.2) — ha van rá igény az edzők részéről.
