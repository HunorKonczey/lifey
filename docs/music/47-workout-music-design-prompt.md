# 47 — Zenevezérlés edzés közben: design prompt (Claude Designnak)

> **A fájl célja:** önállóan átadható prompt a Claude Designnak az edzés
> közbeni zenevezérlés felületeinek megtervezéséhez. A §0 blokk másolható be
> egy az egyben. A technikai háttér: `46-workout-music-controls-plan.md`;
> a design-alapok: `../design/18-design-system-prompt.md` (tokenek);
> a legközelebbi rokon képernyő: a mobil edzésnaplózó
> (`../design/redesign-workout-tab-v2.md`).
> A fájl legvégén — a prompton kívül — a funkció **döntés-naplója** áll.
>
> **Státusz:** a prompt lefutott, a kész design: `Lifey Music Control.dc.html`.
> A design-review megállapításai (eltérések, döntések) a
> `46-workout-music-controls-plan.md` §6-ában.

---

## 0. A prompt (ezt add át)

> Te a **Lifey** fitness/táplálkozás-követő mobilapp design rendszerén dolgozol.
> A rendszer **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss)
> akcentszínű**, mindenhol **generózus lekerekítéssel** (radius-skála: sm ~8 /
> md ~16 / lg ~24 / pill), betűtípus **Plus Jakarta Sans** (számoknál tabular
> figures), ikonokkal minden akción, minimál szövegű címkékkel. A lebegő
> elemek **nem** edge-to-edge szélesek: inset margóval "úsznak" a tartalom
> felett, blur-hátterű (frosted) konténerben, finom elevationnel.
>
> **Meglévő kontextus — az edzésnaplózó képernyő (futó edzés):** felül lebegő
> top bar (vissza-gomb · sablon-név · eltelt-idő-pill · opcionális ⌚/♥/🔥
> pillek), alatta kitűzött pihenőidő-sáv (countdown + „+15 mp" / „Kihagyás"),
> a tartalom gyakorlat-kártyák listája, alul pedig egy **sticky, teljes
> szélességű „Befejezés" gomb** (primary kitöltés, 54 magas, radius 20, pipa
> ikon) lebeg a safe area felett. Ez a képernyő az app legintenzívebben
> használt felülete: a felhasználó izzadt kézzel, két szett között, fél
> szemmel nézi — minden célpont legyen nagy, minden állapot ránézésre
> olvasható.
>
> **A megtervezendő funkció — zenevezérlés edzés közben:** a felhasználó a
> telefonján szóló zenét (Spotify / YouTube Music / Apple Music) az appból
> vezérli, app-váltás nélkül. A funkció sosem indít zenét magától — ami már
> szól, azt vezérli. Tervezd meg az alábbi **négy felület-elemet** a fenti
> design nyelven, világos és sötét témára, HU/EN szövegekkel:
>
> **A) Sticky zene-gomb (a belépési pont)**
> - Az alsó sticky zóna egy sorrá alakul: balra egy **54×54-es zene-gomb**
>   (radius 20, frosted `surfaceContainer` háttér — a Finish gombbal azonos
>   magasság és formanyelv), jobbra a „Befejezés" gomb `Expanded`-ként viszi
>   a maradék szélességet, köztük ~10 gap.
> - Állapotai: **(1) nincs szolgáltató választva** — semleges zene-hangjegy
>   ikon; **(2) választva, de nem szól semmi** — a szolgáltató monokróm
>   ikonja, nyugalmi; **(3) lejátszás alatt** — a szolgáltató-ikon mellett/
>   helyett finom **3-sávos mini-equalizer animáció** akcentszínnel (dönts:
>   ikon+animáció vagy csere — a gomb 54×54-ben maradjon); **(4) figyelem** —
>   kis figyelmeztető pötty a gomb sarkán (engedély hiányzik / hiba).
> - A gomb csak futó edzés alatt látszik; a szolgáltató-brand színeket **ne**
>   használd háttérként (a rendszer akcentje marad az úr), a szolgáltató-ikon
>   monokróm/tónusos.
>
> **B) Szolgáltató-választó bottom sheet**
> - Drag-handle-ös modal sheet, cím („Zene edzés közben" jellegű), alatta
>   3 nagy választósor: szolgáltató-ikon + név + állapot-alcím, a kiválasztotton
>   pipa/akcent-keret.
> - Az alcím-állapotok: normál (választható) · **„Nincs telepítve"** (halvány,
>   nem választható) · **„iOS-en nem támogatott"** (YouTube Music iOS-en —
>   halvány, nem választható, egy soros indoklással: az iOS nem enged más
>   appot vezérelni).
> - A sheet aljára rövid, megnyugtató lábjegyzet: a zenét a saját appod
>   játssza, a Lifey csak vezérli.
>
> **C) Mini lejátszó bottom sheet (a szokásos lejátszó-sablon)**
> - Fejléc: szolgáltató-chip (ikon + név, tónusos háttér) + jobbra „Váltás"
>   szövegakció (visszavisz B-be).
> - Törzs: **albumborító** (64×64, radius md, hangjegy-placeholderrel ha
>   nincs) · számcím (1 sor, ellipsis, hangsúlyos) + előadó (halvány) ·
>   alatta a **vezérlősor**: ⏮ · nagy kör alakú **play/pause** (primary
>   kitöltés, ~64, a sheet vizuális központja) · ⏭. Nincs progress-csík,
>   nincs hangerő — szándékosan minimál, két szett között egy hüvelykujjal
>   kezelhető.
> - Üres állapot (a szolgáltatóban nem szól semmi): hangjegy-illusztráció +
>   egysoros magyarázat + **„Megnyitás: {szolgáltató}"** CTA-gomb.
> - Hiba-állapot: rövid szöveg + „Újrapróbálás".
>
> **D) Android engedélykérő állapot (a C sheet egyik állapota)**
> - A médiavezérléshez Androidon értesítés-hozzáférés kell. Tervezz a sheet-be
>   egy **világos, bizalomépítő magyarázó állapotot**: ikon, 2–3 rövid sor
>   arról, hogy az engedély *csak* a zenelejátszás észleléséhez és
>   vezérléséhez kell (Play-policy „prominent disclosure"!), majd
>   **„Engedély megadása"** primary CTA (rendszerbeállításokba visz) és egy
>   halvány „Most nem" másodlagos akció.
> - iOS Spotify-hoz analóg, enyhébb változat: „A Spotify egy pillanatra
>   megnyílik a kapcsolódáshoz" előrejelzés a kapcsolódás-CTA felett.
>
> Minden elemhez add meg a világos/sötét változatot, a pontos
> szín-token-használatot, és ügyelj rá, hogy a sticky zóna új sora kis
> kijelzőn (360 dp szélesség) is kényelmes maradjon.

---

## 1. Döntés-napló (a prompton kívül, a tervezőnek háttérként)

- **Miért az alsó sticky zóna, nem a top bar?** A top bar már most legfeljebb
  négy pillt hordoz (idő, ⌚, ♥, 🔥) — kis kijelzőn nincs hely. Az alsó zóna
  a hüvelykujj-zónában van, és a felhasználó „stickyre ragadó" ikont kért.
- **Miért nem brand-színű a gomb?** A design rendszer egy-akcentszínű; a
  Spotify-zöld/YT-piros háttérként szétverné. A szolgáltató-identitást a
  monokróm ikon + a lejátszó-sheet chipje hordozza.
- **Miért nincs progress-csík?** Egyik platform-híd sem pusholja folyamatosan
  a pozíciót (interpoláció + ticker kellene), és a transport-vezérléshez nem
  szükséges — l. terv 3.2. Később bővíthető.
- **Miért látszik a nem választható szolgáltató is a pickerben?** A
  „hol a YouTube Music?" kérdést előzi meg; a letiltott sor indokló alcíme a
  támogatási mátrix (terv 2.3) kommunikációs felülete.
- **Miért kötelező a D) engedély-magyarázat szövege?** Play Store-policy: a
  notification-access használatához feltűnő, használat előtti magyarázat kell,
  különben elutasítják az appot (terv 2.1 és 5. szakasz).
- **Equalizer-animáció:** a „szól-e zene" állapot ránézésre-olvashatóságát
  adja sheet-nyitás nélkül; legyen finom (ne vonja el a figyelmet a
  szettnaplózásról), és `MediaQuery.disableAnimations` / reduce-motion esetén
  álljon statikus ikonra.
