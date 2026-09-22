# Hátralévő munka — app-szintű backlog

**Szándékosan számozatlan.** A számozott docok tervek; ez egy munkalista, ami minden
felvett vagy elvetett tételnél változik. A landing page / monetizáció saját listája:
[`landing_page/REMAINING-WORK.md`](landing_page/REMAINING-WORK.md) — ez a fájl arra hivatkozik,
nem ismétli meg.

Utolsó átnézés: **2026-09-22** (a teljes `docs/` státuszsorai + kódellenőrzés alapján).

**Használat:** ha egy tételt felveszel, csináld meg, **töröld a sorát**, és a landolt állapotot
a hozzá tartozó számozott tervbe írd.

---

## 1. Nagy, értékes tételek

### 1.1 AI-bekötés — [`23`](23-ai-calorie-estimation-plan.md)

**Backend 1. fázis kész (2026-09-22):** `POST /api/v1/meals/estimate`, valódi kredit-gate-tel
(Free 3 / Pro 100 havonta) — részletek a `23` „As built” szakaszában. Hátravan:

- **Élő próba** valódi fotókon (`ANTHROPIC_API_KEY` kell hozzá) — a prompt és a modellválasztás
  finomhangolása (`23` 3. lépés). Alapértelmezett modell: `claude-haiku-4-5` (~0,003 $/becslés);
  ha valódi fotókon gyengén becsül, a `claude-sonnet-5` a következő lépcső (`23` „Usable models”).
- **Mobil** (`23` 4–5. lépés): fotózás → eredmény-lap → mentés meal-ként; itt kerül képernyőre
  az `AiCreditChip` és a `requireAiCredits`.
- **2. fázis:** receptgeneráló varázsló.

Az eredeti állapot, amiből indult:

- **1. fázis:** fotóból kalória-/makróbecslés → szerkeszthető eredmény → mentés a meglévő
  offline-first meal flow-n.
- **2. fázis:** receptgeneráló varázsló (diéta, étkezéstípus, kalóriasáv, hozzávalók).

A monetizáció elvarratlan szálai:

- ✅ `72` B1 — a számláló most már növekszik, a 402 / `AI_CREDITS_EXHAUSTED` gate él.
- ✅ `72` B4 — a Pro havi 100-as fair-use limitjét az `EntitlementAiFeatureGate` ellenőrzi.
- ⏳ `72` M7 — `AiCreditChip` és `requireAiCredits` még egyik képernyőre sincs kitéve; a mobil
  résszel együtt kerül be.


### 1.2 Edzői nézet tableten — [`chat/41`](chat/41-trainer-mobile-v2-plan.md) §8.2

A **telefonos** edzői nézet kész (T1–T7, PR #34, `mobile/lib/features/trainer/`). Ami hiányzik:

- **Tablet-elrendezés.** Jelenleg csak a naptár havi rácsa igazodik a szélességhez
  (`trainer/schedule/presentation/widgets/month_overview.dart`). Nincs master–detail
  (kliens-lista + adatlap egymás mellett), a program-rács sem használja ki a szélességet.
  Akkor éri meg, ha a célzott edzők tényleg iPaden / tableten dolgoznak.
- **Edzői push-csomag** (41 §8.3): pl. „a kliens kihagyott egy edzést”, „leadta a heti mérést”.
  A [`30`](30-push-notifications-plan.md) infrastruktúrájára épül, külön terv kell hozzá.
- *Nem hiány:* a programszerkesztés tudatos döntés alapján csak weben van (41 T6).

### 1.3 Progress fotók és testméretek — [`05`](05-improvement-roadmap.md) #10

Nincs belőle semmi a kódban.

- Fotó-idővonal, egymás melletti összehasonlítás.
- Méretek: derék, mellkas, kar, comb — előzmény + grafikon.
- A meglévő képfeltöltési infrastruktúra (recept / avatar) újrahasznosítható.

### 1.4 Okosabb súlytrend — [`05`](05-improvement-roadmap.md) #11

A célsúlyt az onboarding bekéri (`userdetails`), de:

- nincs 7 napos mozgóátlag a nyers napi pontok helyett;
- nincs „várhatóan ekkor éred el a célsúlyt” becslés a statisztika oldalon.

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
| Chip-kontraszt | a színezett chip + azonos színű szöveg az app egészén AA alatt van — design-döntés kell, nem folt | — |

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

## 5. Elavult dokumentáció (státusz-frissítés kell)

| Doc | Mit állít | Valóság |
|---|---|---|
| [`cardio/README.md`](cardio/README.md), [`cardio/51`](cardio/51-cardio-overview-plan.md), [`cardio/59`](cardio/59-cardio-implementation-plan.md) | „terv, nem indult el” | a cardio le van szállítva (C0–C5, a `62` szerint) |
| [`cardio/60`](cardio/60-cardio-sport-specifics-plan.md) | C7 és C8 (túra) hátravan | időjárás-, útpont- és magasságprofil-kód már létezik — ellenőrizni, mi kész |
| [`16-delta-sync-rollout.md`](16-delta-sync-rollout.md) | a Foods-on kívül minden „Not started” | szinte minden kontroller támogatja már a delta sync-et |
| [`14-pagination-plan.md`](14-pagination-plan.md), [`15-delta-sync.md`](15-delta-sync.md), [`15-set-rest-time-plan.md`](15-set-rest-time-plan.md) | „proposed” / „design only” | Foods-ra kész; a set-időbélyegek a `39` szerint kész |
| [`05-improvement-roadmap.md`](05-improvement-roadmap.md) | #10, #11 jelöletlen | valóban hiányoznak (lásd §1.3, §1.4) — ez stimmel |

---

## Javasolt sorrend

1. AI kalóriabecslés (1.1, 1. fázis) — backend kész; élő próba, majd mobil.
2. Progress fotók + testméretek (1.3), mellé a súlytrend (1.4) mint gyors nyerés.
3. AI receptgenerálás (1.1, 2. fázis).
4. Tablet-elrendezés (1.2) — ha van rá igény az edzők részéről.
