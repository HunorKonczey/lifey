# 06 — Design terv: edző admin (web) + meghívó-kártya (mobil)

Alap: a meglévő Lifey design rendszer — **sötét-first, meleg barnás-zöld (olive/moss) akcent, magas kontraszt, generózus lekerekítés** (`docs/design/18-design-system-prompt.md`), webre a `docs/web/03-design-brief.md` tokenei. Ez a dokumentum **nem vezet be új tokent** — az admin ugyanabból a palettából épül, két kiegészítő szemantikus szereppel.

## 1. Admin-identitás a közös rendszeren belül

Az edző nézetnek azonnal felismerhetőnek kell lennie ("most nem a saját adataimat nézem"), de nem lehet idegen:

- **Admin-jelzés a top barban:** a `/admin` alatt a top bar bal oldalán a logó mellett egy állandó **"EDZŐ" chip** (pill, `tertiary` szín, kis dumbbell ikon). Ez az elsődleges "hol vagyok" jel.
- **Sidebar akcent:** az aktív menüpont-indikátor az admin nézetben `tertiary` (a saját nézet `primary`-jával szemben). Minden más token azonos — a két nézet testvér, nem két külön app.
- **Read-only szemantika:** a kliens-adat nézetek fejlécében visszatérő **"Csak olvasható" badge** (szem-ikon + felirat, halvány `outline` stílus). A read-only képernyőkön *egyetlen* create/edit affordance sincs — a hiány maga is design-elem.

## 2. Admin shell (desktop-first)

```
┌────────────────────────────────────────────────────────────────┐
│ ◧ Lifey  [EDZŐ]                          🔔?   (avatar ▾)      │  top bar (floating, inset, rounded)
├──────────┬─────────────────────────────────────────────────────┤
│ 👥 Klien- │                                                    │
│    seim   │              tartalom                              │
│ ✉ Meghí- │                                                     │
│    vók    │                                                    │
│ 🏋 Edzés- │                                                     │
│    terveim│                                                    │
│ 🍽 Ételeim│                                                     │
│ 📋 Kiosz- │                                                     │
│    tott   │                                                     │
│  ────────│                                                      │
│ ↩ Saját  │                                                      │
│   nézet   │                                                     │
└──────────┴─────────────────────────────────────────────────────┘
```

- A mobil app "floating, inset, rounded" bár-elve webre fordítva: a top bar és a kártyák nem érnek edge-to-edge, `lg` radius, finom elevation.
- Ikon minden menüponton (a design rendszer "icons everywhere" elve), rövid címkék.
- Reszponzív: tablet alatt a sidebar drawer-ré csukódik; az admin elsődleges célja azonban a desktop (az edző munkaeszköze).

## 3. Kulcsképernyők

### 3.1 Kliens-lista modal (belépéskor)

- Középre igazított dialog, `lg` radius, max ~560px széles; cím: "Klienseid", alcím a kliensszámmal.
- Soronként: **avatar (36px, kör) — név — utolsó aktivitás** (relatív idő, halvány) — chevron. Hover: surface-emelés.
- Alul két akció: "Bezárás" (ghost) és "+ Kliens meghívása" (primary → `/admin/invites`).
- Üres állapot (nincs kliens): illusztráció-szintű nagy ikon (users), "Még nincs kliensed" + CTA "Hívd meg az elsőt" — ilyenkor **a modal ki sem nyílik**, ez a dashboard üres állapota.

### 3.2 Kliens-kártya (dashboard rács)

```
┌──────────────────────────────┐
│ (avatar)  Kiss Anna      ⋯   │
│ Utolsó aktivitás: tegnap     │
│ ▁▂▃▂▄▅▄  súlytrend (spark)   │
│ 📋 2 terv    🏋 3 edzés/hét  │
└──────────────────────────────┘
```

- Rács: 3 oszlop desktopon (→ 2 → 1), kártya `lg` radius, `surface-container` háttér.
- Sparkline a `tertiary` színnel; a metrika-sor ikon+érték párok (minimál szöveg).
- "⋯" menü: Megnyitás / Kapcsolat bontása (destruktív, `error` szín, confirm dialoggal).

### 3.3 Meghívó oldal

- Felül **egysoros form-kártya**: e-mail mező (teljes szélesség) + "Meghívás" primary gomb egy sorban.
- Hibák inline, a mező alatt (`error` token): "Nincs ilyen felhasználó" / "Már a kliensed" / "Erre a címre 24 órán belül már küldtél meghívót".
- Alatta **"Függőben" lista**: e-mail — küldve (relatív) — **lejárati visszaszámláló chip** ("még 16 ó", `tertiary`; utolsó 3 órában `error`-ba vált) — visszavonás (ghost, x-ikon).
- Üres állapot: "Nincs függő meghívó" + rövid magyarázat a 24 órás szabályról (a szabály a UI-ban is tanítva van, ne support-kérdés legyen).

### 3.4 "Add to user" + hozzárendelő drawer

- A sablon-/recept-kártyákon az admin nézetben megjelenő extra gomb: **"Kiosztás"** (user-plus ikon, `tertiary` tónus) — a saját nézetben ez a gomb **nem létezik**.
- Kattintásra **jobb oldali drawer** (~420px):
  1. cím: "{Sablon/Recept neve} kiosztása";
  2. kereshető **kliens-választó** (avatar+név sorok, single select);
  3. **tartalom-összefoglaló**: sablonnál gyakorlat-lista cél-szettekkel; receptnél hozzávalók + makró-összesítő;
  4. ha volt már kiosztva ennek a kliensnek → **figyelmeztető sáv** (`warning`/`tertiary-container`): "Már kiosztottad {dátum}-kor. Új másolat készül, a kliens régi példánya megmarad.";
  5. láb: "Mégse" (ghost) + "Hozzárendelés" (primary, csak kliens-választás után aktív).
- Siker: toast "Kiosztva {név} részére" + a drawer zárul.

### 3.5 Kliens-részletek

- **Fejléc-sáv:** avatar (48px), név, e-mail; jobb oldalt "Csak olvasható" badge + kapcsolat kezdete.
- **Tab-sor** ikonokkal: Áttekintés / Statisztika / Lépések / Edzések. (Nincs Víz tab.)
- **Áttekintés:** 4 KPI-kártya (heti kcal-átlag, aktuális súly+trendnyíl, edzés/hét, lépés-átlag) + "Kiosztott tervek" lista (típus-ikon, név, dátum).
- **Statisztika:** a saját nézet statisztika-komponensei változatlan vizuállal (Recharts, idősáv-szegmens napi/heti/havi) — a konzisztencia bizalmat ad; a különbség csak a fejléc-badge.
- **Edzések:** session-sorok (dátum, időtartam, gyakorlatszám, volumen); kiosztott sablonból végzett edzésen kis "📋 {sablonnév}" chip — **ez az edző fő fejlődés-követő jele**.
- Grafikon-színek: elsődleges adatsor `primary`, összehasonlító/trend `tertiary` — azonos a saját nézettel.

### 3.6 Super admin — Felhasználók (`/superadmin/users`)

A super admin felület **tudatosan dísztelen**: ritkán használt, biztonság-kritikus eszköz — itt az egyértelműség a design.

```
┌────────────────────────────────────────────────────────────┐
│ ◧ Lifey  [RENDSZER]                        (avatar ▾)      │
├────────────────────────────────────────────────────────────┤
│  Felhasználók                     [🔍 keresés e-mailre  ]  │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ (av) anna@…      USER TRAINER      [Edző visszavonása] │ │
│ │ (av) peter@…     USER              [Edzővé tétel]      │ │
│ │ (av) én@…        USER SUPER_ADMIN  —                   │ │
│ └────────────────────────────────────────────────────────┘ │
│                    ‹ 1 2 3 ›                               │
└────────────────────────────────────────────────────────────┘
```

- **Kontextus-chip:** a top barban `[RENDSZER]` chip — az `[EDZŐ]` chip mintájára, de **neutrális/outline** stílusban (nem `tertiary`), hogy a három nézet (saját / edző / rendszer) chip-színről is megkülönböztethető legyen.
- **Szerepkör-badge-ek:** kis pillek; `USER` halvány outline, `TRAINER` `tertiary-container`, `ADMIN`/`SUPER_ADMIN` neutrális, hangsúlyos keret. Nem szín-only: a felirat mindig kiírva.
- **Akciógombok:** "Edzővé tétel" tonal/primary; "Edző visszavonása" outline `error` tónussal (jog-elvétel — vizuálisan súlyos, de nem törlés-vörös tömb).
- **Megerősítő dialogok:** cím + egymondatos következmény-magyarázat + a cél-user e-mailje félkövéren; a megerősítő gomb szövege konkrét ("Edzővé teszem"), nem "OK".
- **Audit-történet:** sor-expand (chevron) → idővonal-lista: `2026-07-03 · GRANT ROLE_TRAINER · én@…` — monospace dátum, halvány másodlagos szöveg.
- A saját sorban akciógomb helyett "—" (nem disabled gomb: a lehetőség nem létezik, nem tiltott).
- Állapotok: keresésre nincs találat → "Nincs ilyen felhasználó"; betöltés → táblázat-skeleton.

## 4. Mobil: meghívó-kártya (Flutter)

A "lebegő" igényhez a design rendszer floating-pill nyelvét használjuk:

```
╭──────────────────────────────────────╮
│ (avatar)  Kovács Péter               │
│ Meghívott, hogy legyen a személyi    │
│ edződ. · Lejár: 18 óra múlva         │
│                                      │
│ [ Elutasítom ]      [ Elfogadom ]    │
╰──────────────────────────────────────╯
```

- **Pozíció:** a képernyő alján, a bottom nav **felett** lebegő kártya (inset margókkal, `lg` radius, elevation + finom blur-háttér) — nem teljes szélességű, a floating-bár elv szerint.
- **Megjelenés:** alulról csúszik be (a design rendszer motion tokenjeivel), a tartalom fölött lebeg, de nem modális — az app használható marad alatta.
- **Gombok:** "Elfogadom" filled/primary; "Elutasítom" text/ghost (nem `error` — az elutasítás legitim, nem destruktív aktus). Elhúzás (swipe-dismiss) = "később".
- **Lejárat-jelzés** halvány másodlagos szövegben; az avatar az edzőé (bizalomépítés — látszik, *ki* hív).
- Válasz után a kártya kicsúszik + snackbar-megerősítés.

### "Edzőtől" badge (sablon/recept kártyán)

- Kis pill a kártya sarkában: 🎓 vagy dumbbell ikon + "Edzőtől" (`tertiary-container` háttér, `on-tertiary-container` szöveg), tap-re tooltip/bottom-sheet az edző nevével és a kiosztás dátumával.

## 5. Állapotok (minden admin-képernyőre kötelező)

| Állapot | Megoldás |
|---|---|
| Betöltés | skeleton kártyák/sorok (a web app meglévő skeleton-mintái) |
| Üres | ikon + egymondatos magyarázat + CTA (lásd képernyőnként fent) |
| Hiba | inline hibasáv + "Újra" gomb; 403 (bontott kapcsolat közben) → "Ez a kliens már nem elérhető" + vissza a listára |
| Lejárt meghívó a másik oldalon | a lista frissítéskor egyszerűen kikerül — nincs külön "lejárt" vizuális szemét |

## 6. Hozzáférhetőség

- A "read-only" nem csak vizuális: a kliens-nézetek interaktív elemei ténylegesen hiányoznak (nem disabled — hiányzó), így screen readerrel sem félrevezető.
- Visszaszámláló chipek szövegesen is (nem csak színnel) jelzik a sürgősséget; kontraszt a dark témán AA szint.
- A mobil meghívó-kártya fókusz-sorrendje: szöveg → Elutasítom → Elfogadom; swipe-dismiss mellett gombos "később" is elérhető legyen (a kártya x-e), mert a swipe nem akadálymentes.
