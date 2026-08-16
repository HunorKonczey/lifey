# Cardio & sportedzések — dokumentáció

Ez a mappa a **nem szett-alapú edzések** (szobabicikli, futás, séta, túrázás, kosárlabda, foci)
támogatásának tervét tartalmazza. Státusz: **teljes egészében terv, nem indult el.**

## Olvasási sorrend

| Fájl | Miről szól | Kinek |
|---|---|---|
| [51-cardio-overview-plan.md](51-cardio-overview-plan.md) | Koncepció, a három „család”, típusonkénti metrikakészlet, **iterációk (C0–C9)**, kockázatok, elfogadási feltételek | **Kezdd itt.** Mindenkinek |
| [52-cardio-domain-backend-plan.md](52-cardio-domain-backend-plan.md) | Enumok, Flyway-migrációk (V66+), entitások, DTO-k, API-bővítés, delta-sync csapdák | Backend |
| [53-cardio-mobile-plan.md](53-cardio-mobile-plan.md) | Drift-táblák, repository, **gyorsindítási UX**, élő edzés-képernyő, Live Activity, C0 audit | Flutter |
| [54-cardio-gps-route-plan.md](54-cardio-gps-route-plan.md) | GPS-rögzítés, szűrés, háttérfutás, akku, polyline, saját útvonalrajz | Flutter |
| [55-cardio-watch-plan.md](55-cardio-watch-plan.md) | Aktivitástípus-térkép, **gyakoriság-rendezett egyesített picker**, standalone cardio | Watch (Swift/Kotlin) + Dart híd |
| [56-cardio-statistics-plan.md](56-cardio-statistics-plan.md) | Ütközési leltár, metrika-definíciók, PR-ok, edzői riportok — **„mi romolhat el”** | Backend + Flutter + Web |
| [57-cardio-design-prompt.md](57-cardio-design-prompt.md) | **Önhordó design prompt a Claude Designnak** (§0 blokk másolható) + döntés-napló | Design |
| [58-cardio-web-plan.md](58-cardio-web-plan.md) | A 11 érintett web-fájl, olvasó cardio-nézet — és **miért nem indítható webről** | Web (Next.js) |
| [59-cardio-implementation-plan.md](59-cardio-implementation-plan.md) | **Fejlesztési terv C0–C5-ig: ~50 prompt-méretű lépés**, frame-leképezéssel, mérföldkövekkel | **Fejlesztés — innen dolgozz** |
| [60-cardio-sport-specifics-plan.md](60-cardio-sport-specifics-plan.md) | **Fejlesztési terv C6–C9-re: 30 lépés** (futás · játék · bicikli · túra), hiányzó design-frame-ek, 6 nyitott döntés | Fejlesztés — a C5 után |
| [61-cardio-sport-specifics-design-prompts.md](61-cardio-sport-specifics-design-prompts.md) | **A C6–C9 négy design promptja** (M33–M45), közös §0 blokkal — átadható a Claude Designnak | Design |
| [`design/`](design) | A két kész design-canvas (mobil + web · óra) | Mind |

## Iterációk egy pillantásra

| # | Név | Fő doc |
|---|---|---|
| C0 | Taxonómia + a szett-feltételezések auditja | 52, 53 |
| C1 | Cardio adat-mag, kézi rögzítés | 52, 53 |
| C2 | Élő cardio a telefonon + gyorsindítás + Live Activity | 53 |
| C1w | Web: cardio megjelenítés (a C1 után, önállóan) | 58 |
| C3 | Statisztika-integráció | 56 |
| C3w | Web: statisztika-paritás (a C3-mal együtt) | 58 |
| C4a / C4b | GPS-nyomvonal / *(opcionális)* valódi térkép | 54 |
| C5 | Óra-integráció | 55 |
| C6–C9 | Sport-specifikumok: futás · szobabicikli · túra · játék | 51 §4, **60** |

**Felületi lefedettség:** mobil (teljes: indítás, élő mérés, összegzés) · óra (teljes: indítás,
élő mérés, standalone) · **web: csak megjelenítés** — onnan cardio nem indítható
([58 D-W.1](58-cardio-web-plan.md)).

**A design elkészült (2026-08-10)** — `design/Lifey Cardio Design.dc.html` (mobil M01–M32,
web W01–W02) és `design/Lifey Cardio Watch Design.dc.html` (AW 16–22 / W 15–21). A korábbi
design-blokkolás ezzel feloldva: **minden iteráció indítható.** A lépésre bontott végrehajtási
sorrend: [59-cardio-implementation-plan.md](59-cardio-implementation-plan.md).

## A három termékdöntés — eldöntve (2026-08-09)

1. **Rövid séta a streakben:** számít, **15 perc mozgásidőtől**; erősítő edzés hossztól függetlenül számít. Nem beállítás — [51 Q1](51-cardio-overview-plan.md#8--döntések-eldöntve-2026-08-09)
2. **A futás domináns száma: a táv.** A DISTANCE család nagy száma a táv, az idő a másodlagos sor első eleme; távforrás nélkül (futópad, megtagadott GPS) a kettő helyet cserél — [57 DD-5](57-cardio-design-prompt.md)
3. **Gép-kalória:** nem számít a napi aktív kalóriába, csak akkor, ha az adott sessionhöz nincs óra-/Health-mérés; összeadni soha — [51 Q4](51-cardio-overview-plan.md#8--döntések-eldöntve-2026-08-09)

Az 51 §8 másik három kérdése (Q2 taxonómia-ütközés, Q3 múltbeli dátum, Q5 foci-GPS) ugyanott,
ugyanazzal a dátummal lezárva.
