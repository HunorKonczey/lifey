# 58 – Cardio: web (Next.js) — mit kell hozzányúlni, és mit nem

Státusz: **TERV.** Iteráció: **C1w** (megjelenítés, a C1 backend után bármikor), **C3w** (statisztika, a C3-mal együtt).
Előzmény: [51-cardio-overview-plan.md](51-cardio-overview-plan.md),
[52-cardio-domain-backend-plan.md](52-cardio-domain-backend-plan.md) (API),
[56-cardio-statistics-plan.md](56-cardio-statistics-plan.md) (metrika-definíciók).
Web-alapok: [../web/01-feature-inventory.md](../web/01-feature-inventory.md),
[../web/06-design-system-web.md](../web/06-design-system-web.md), [../web/07-screen-specifications.md](../web/07-screen-specifications.md).

> Ez a doc arra a kérdésre válaszol, hogy *„weben is lesznek apró módosítások, nem csak a
> listázóban?”* — **igen, kilenc helyen**, és ebből **kettő valódi hiba lenne**, ha kimarad
> (§2 W1 és W2). Az „indítás webről” viszont **tudatosan nincs benne** (D-W.1).

---

## 1. Alapdöntések

### D-W.1 — Cardiót **nem lehet webről indítani**

Egyetértek a felvetéssel: értelmetlen. Az indoklás, hogy ne kelljen később újra elővenni:

- A cardio mérése **szenzorfüggő** — GPS, pulzus, kadencia. Ezek egyike sem érhető el
  értelmesen egy asztali böngészőből, tehát a webről indított edzés eleve csak egy stopper lenne.
- A használati helyzet kizárja: senki nem visz laptopot futni, kosarazni vagy túrázni.
- Az élő session **egy eszközön mester** (a telefon, standalone esetben az óra —
  [55 §5](55-cardio-watch-plan.md)). Egy harmadik indító pont új ütközés-feloldási esetet nyitna
  (mi van, ha weben és telefonon is fut egy?), nulla haszonért.

**Következmény:** a `SessionsView` „gyorsindítás sablonból” blokkja **változatlan marad**, és
oda cardio bejegyzés **nem** kerül. A [53 §3](53-cardio-mobile-plan.md) gyorsindítási rangsora
web-oldali megfelelő nélkül marad.

### D-W.2 — A web V1-ben a cardióra **olvasó felület**

Megjeleníti, szűri, statisztikázza — de nem szerkeszti. Indok: a cardio adat a telefonon
keletkezik, és a webnek nincs olyan hozzáadott értéke (nyomvonal-rajz, splitek), ami miatt a
szerkesztő-felület megérné a duplikált validációt.

**Nyitva hagyott, olcsó bővítés:** *kézi, utólagos rögzítés webről* (a mobil `LogCardioSheet`
párja) — ez az egyetlen web-szerkesztés, aminek van valós forgatókönyve: „tegnapi túrát beírom a
gépnél”. Nem V1; ha kell, a C1w után egy önálló, kis lépés. A meglévő web `SessionLogger`
(erősítő) létezése miatt ez paritás-kérdés is lehet — **termékdöntés, nem technikai**.

---

## 2. Ütközési leltár — a konkrét fájlok

Az alábbiak a `web/src/` alatt, ellenőrzött sorokkal. A **W1** és **W2** valódi hiba, a többi
kozmetikai vagy adat-pontossági.

| # | Fájl | Mai viselkedés | Cardióval |
|---|---|---|---|
| **W1** | `features/workouts/components/SessionLogger.tsx` | egy session megnyitása **szett-logolót** nyit (`session.exercises`, `session.sets`) | Egy cardio session megnyitása **üres szett-logolót** adna, ahol nincs mit logolni. **Kell egy `kind`-elágazás**: cardio → olvasó részletnézet (metrikák + útvonal + splitek), sosem a logoló |
| **W2** | `features/trainer/components/ClientWorkoutsTab.tsx:68,93,131` | volumen = `Σ reps × weight`, „N gyakorlat”, gyakorlat-bontás | Cardiónál 0 volumen és „0 gyakorlat” — az edző azt látja, hogy a kliens **üres edzést** csinált. `kind`-elágazás: ikon + fő metrika + időtartam |
| W3 | `features/workouts/components/SessionsView.tsx:177,210` | kártya-cím = gyakorlatnevek összefűzve; alcím „· N szett” | Cardiónál üres cím és „· 0 szett”. Cím = aktivitás neve, alcím = családfüggő fő metrika + `ActivityChip` ikon |
| W4 | `features/trainer/components/CalendarSessionPeek.tsx:125,175` | `templateName ?? "unnamedTemplate"` | Cardiónál mindig a fallback-szöveg („névtelen terv”) — félrevezető. Aktivitás-név + ikon |
| W5 | `features/statistics/aggregate.ts:68` | volumen a szettekből | Önmagában helyes (cardio 0-t ad), de **fajta-szűrő** és a cardio-adatsorok ([56 §3](56-cardio-statistics-plan.md)) hiányoznak |
| W6 | `features/statistics/types.ts` (`workoutCount`) | egy szám | Additív bontás ([56 D-C3.2](56-cardio-statistics-plan.md)): erősítő/cardio, mozgásidő, össztáv |
| W7 | `features/workouts/recommendation.ts:16` | `templateId`-ciklusból javasol | Cardio session-ök `templateId`-je null → **zaj a ciklus-detektálásban**; szűrni kell `kind === 'STRENGTH'`-re |
| W8 | `features/workouts/progress.ts:21,29` | gyakorlatonkénti haladás a szettekből | Cardio session szettek nélkül automatikusan kiesik — **de ezt tesztelni kell**, nem feltételezni |
| W9 | `features/workouts/types.ts` | `WorkoutSessionResponse` alakja | Bővítés: `sessionKind`, `activityType`, `movingSeconds`, `cardio`, `splits` — a többi mező érintetlen |
| W10 | `app/(app)/dashboard/page.tsx`, `app/(app)/statistics/page.tsx` | edzésszám, metrika-választó | Bontás-sor + fajta-szűrő ([56 D-C3.4](56-cardio-statistics-plan.md)) |
| W11 | `lib/i18n` | – | Új kulcsok: aktivitás-nevek, cardio-metrikák, fajta-szűrő (EN + HU) |

**Ellenőrizendő, nem feltételezendő:** az `app/(admin)/admin/workouts` felület (gyakorlat-adminisztráció)
minden jel szerint érintetlen, de a C1w első lépése nézze meg.

---

## 3. Mit lát a felhasználó a weben egy cardio edzésből

**Lista-kártya** (`SessionsView`, `ClientWorkoutsTab`): `ActivityChip` ikon · aktivitás neve ·
dátum · a család fő metrikája (`DISTANCE`: táv + mozgásidő · `MACHINE`: mozgásidő + táv ·
`GAME`: játékidő) · a meglévő ⌚ és értékelés-jelzések változatlanul.

**Részletnézet** (új, olvasó — a `SessionLogger` cardio-ága): metrika-rács a család szerint ·
**útvonal-rajz** a `route_polyline`-ból (a mobil `RoutePainter` web-megfelelője, ugyanaz a
vizuális nyelv, SVG-ként — [54 §6.1](54-cardio-gps-route-plan.md)) · split-táblázat, ha van ·
pulzuszóna-sáv, ha van · RPE + jegyzet + edzői komment (a meglévő komponensek, változatlanul).

**Statisztika**: fajta-szűrő + a [56 §3](56-cardio-statistics-plan.md) metrikái, a mobil
definícióival — a **paritás-teszt** (ST11) mindkét kódbázisra vonatkozik.

### D-W.3 — Az útvonal weben is saját rajz, nem térkép

Ugyanaz az érvelés, mint mobilon ([51 D-C.6](51-cardio-overview-plan.md)): a `route_polyline`
dekódolása és SVG-`path`-ként kirajzolása néhány tucat sor, nulla függőség, nulla csempe-licenc,
és a web design-rendszer színeivel illeszkedik. Térkép-komponens (Leaflet/MapLibre) csak a
C4b-vel együtt, ha az egyáltalán elindul.

---

## 4. Feladatlista

### C1w — megjelenítés (a C1 backend után, a C3-tól függetlenül)
| # | Lépés |
|---|---|
| WB1 | `types.ts` bővítés (W9) + az API-réteg átengedi az új mezőket |
| WB2 | `ActivityChip` komponens a web design-rendszer tokenjeivel (a mobil chip párja) |
| WB3 | `SessionsView` kártya `kind`-elágazása (W3) |
| WB4 | **`SessionLogger` `kind`-kapu + olvasó cardio részletnézet** (W1) — ez a legfontosabb tétel |
| WB5 | `ClientWorkoutsTab` edzői kártya + részletek `kind`-elágazása (W2) |
| WB6 | `CalendarSessionPeek` aktivitás-név (W4) |
| WB7 | `recommendation.ts` erősítő-szűrő (W7) + `progress.ts` regressziós teszt (W8) |
| WB8 | Útvonal-SVG komponens (D-W.3) |
| WB9 | i18n kulcsok EN + HU (W11) |

### C3w — statisztika (a C3-mal egy időben, hogy a definíciók ne csússzanak szét)
| # | Lépés |
|---|---|
| WB10 | `aggregate.ts` fajta-szűrő + cardio-adatsorok (W5) |
| WB11 | `types.ts` / dashboard / statisztika-oldal bontás és szűrő (W6, W10) |
| WB12 | **Paritás-teszt** a mobil aggregációval szemben ([56 ST11](56-cardio-statistics-plan.md)) |

---

## 5. Elfogadás

- [ ] Egy cardio session megnyitása a weben **nem** nyit szett-logolót, és nem mutat „0 gyakorlat”-ot
- [ ] Az edzői kliens-nézetben a cardio edzés felismerhető (ikon + fő metrika), nem „üres edzés”
- [ ] A `SessionsView` gyorsindító blokkja **nem** kínál cardiót (D-W.1)
- [ ] Az útvonal megjelenik a részletnézetben, világos és sötét témában
- [ ] A web és a mobil ugyanarra az adathalmazra ugyanazt a heti összesítést adja
- [ ] Tisztán erősítő előzményű felhasználónál minden web-felület bitre azonos a cardio előttivel

---

## 6. Design

**Kész (2026-08-10).** A web-frame-ek a mobil canvas 13. szekciójában vannak
([`design/Lifey Cardio Design.dc.html`](design/Lifey%20Cardio%20Design.dc.html)):
**W01** — `ActivityChip` a web token-készletével, **W02** — edzéslista-sor cardióval és
erősítővel egymás mellett. A részletnézet ezekből származtatva épül (a canvas nem rajzolta külön,
mert a mobil M13/M15 elrendezése és a web tokenek együtt meghatározzák).

A lépések: [59-cardio-implementation-plan.md §7](59-cardio-implementation-plan.md) — C1w.1–C1w.4 és C3w.1.
