# 57 — Cardio & sportedzések: design prompt (Claude Designnak)

> **A fájl célja:** önállóan átadható prompt a cardio/sport edzések felületeinek megtervezéséhez —
> **mobil**, **óra** (Apple Watch + Wear OS) és — kis mértékben — **web** felületre egyszerre.
> A **§0 blokk másolható be egy az egyben**; a §1–§7 a prompt melléklete, ugyanannak a
> beszélgetésnek a folytatásaként adható át. A súlypont a mobil és az óra: a web csak két
> származtatott elemet kap (§6), mert onnan cardio **nem indítható** (lásd
> [58-cardio-web-plan.md](58-cardio-web-plan.md) D-W.1).
> A fájl legvégén — a prompton kívül — a funkció **döntés-naplója** áll.
>
> Technikai háttér: [51-cardio-overview-plan.md](51-cardio-overview-plan.md) (koncepció, metrikák,
> iterációk), [53-cardio-mobile-plan.md](53-cardio-mobile-plan.md) (mobil viselkedés),
> [54-cardio-gps-route-plan.md](54-cardio-gps-route-plan.md) (útvonal),
> [55-cardio-watch-plan.md](55-cardio-watch-plan.md) (óra),
> [56-cardio-statistics-plan.md](56-cardio-statistics-plan.md) (statisztika),
> [58-cardio-web-plan.md](58-cardio-web-plan.md) (web).
> Design-alapok: [../design/18-design-system-prompt.md](../design/18-design-system-prompt.md) (mobil tokenek),
> [../web/06-design-system-web.md](../web/06-design-system-web.md) (web tokenek),
> `../watch/design/Lifey Watch Design.dc.html` (a meglévő watch-canvas, legmagasabb frame: **AW 15 / W 14**),
> [../design/redesign-workout-tab-v2.md](../design/redesign-workout-tab-v2.md) (a legközelebbi rokon képernyő: az edzésnaplózó).
>
> **Ez a fájl a cardio UI kötelező forrása.** A [51-es doc §4](51-cardio-overview-plan.md) szerint a
> **C2, C3, C5 és minden C6+ iteráció kódolása csak a kész canvas után indulhat**; a C1 kézi
> rögzítő lapja az egyetlen kivétel (meglévő sheet-mintát követ).
>
> **Státusz: a prompt lefutott, a design elkészült (2026-08-10) — a blokkolás feloldva.**
> A kész canvasok:
> - [`design/Lifey Cardio Design.dc.html`](design/Lifey%20Cardio%20Design.dc.html) — mobil **M01–M29**
>   (sötét/HU) + **M30–M32** (világos/EN minta) + web **W01–W02** + mozgás/haptika + nyitott kérdések
> - [`design/Lifey Cardio Watch Design.dc.html`](design/Lifey%20Cardio%20Watch%20Design.dc.html) —
>   **AW 16–22** és **W 15–21**, a meglévő watch-canvas számozásának folytatásaként
>
> **A sport-specifikumok (C6–C9) frame-jei nincsenek benne ebben a körben** — azok négy külön,
> szűkített promptot kaptak: [61-cardio-sport-specifics-design-prompts.md](61-cardio-sport-specifics-design-prompts.md)
> (M33–M45), a lépésekhez kötve a [60-as tervben](60-cardio-sport-specifics-plan.md).
>
> A frame → fejlesztési lépés leképezés és a kódolás sorrendje:
> [59-cardio-implementation-plan.md §1](59-cardio-implementation-plan.md).
> A canvas 15. szekciójának **négy nyitott termékkérdése** ott van szétosztva aszerint, melyik
> lépést blokkolja ([59 §1.2](59-cardio-implementation-plan.md)).

---

## 0. A prompt (ezt add át)

> Te a **Lifey** fitness- és táplálkozáskövető alkalmazás design rendszerén dolgozol. A rendszer
> **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss) akcentszínű**, mindenhol
> **generózus lekerekítéssel** (radius-skála: sm ~8 · md ~16 · input ~18 · card ~20 · lg ~24 ·
> nav ~28 · pill = stadium), betűtípus **Plus Jakarta Sans** (számoknál tabular figures),
> **ikon minden akción**, minimál szövegű címkékkel. A lebegő elemek **nem** edge-to-edge
> szélesek: inset margóval „úsznak” a tartalom felett, frosted/blur konténerben, finom
> elevationnel. A felső és alsó sáv görgetésre összecsukódik. Mozgás-tokenek: 150 / 250 / 350 ms,
> a collapse 380 ms egyedi görbével. Meglévő metrika-akcentek (ezekből dolgozz, ne hozz be idegen
> színt): kalória (meleg narancs), fehérje (zöld), szénhidrát (borostyán), zsír (indigó), lépés
> (lila), víz (kék), testsúly (kékesszürke).
>
> **A feladat:** tervezd meg a **cardio- és sportedzések** teljes felületét. Az app ma csak
> szett-alapú (erősítő) edzést ismer; most **hat új edzéstípus** érkezik:
> **szobabicikli, futás, séta, túrázás, kosárlabda, foci** (+ egy „egyéb” menekülőút).
>
> **A tervezés gerince: három „család”, nem hat képernyő.** A típus csak ikont, nevet, színt és
> néhány extra mezőt ad; az elrendezést a család dönti el:
> - **DISTANCE** (futás, séta, túrázás) — idő, táv, tempó/sebesség, szintemelkedés, GPS-nyomvonal, km-splitek, pulzus
> - **MACHINE** (szobabicikli) — idő, táv, kadencia (rpm), teljesítmény (W), ellenállás, pulzus
> - **GAME** (kosárlabda, foci) — **játékidő vs. bruttó idő**, pulzuszónák, intenzitás (1–5), helyszín (terem/szabadtér), opcionális pont/gól-számláló
>
> **Nem alku tárgya (elfogadási feltétel):**
> 1. **Az indítás legyen a leggyorsabb dolog az appban.** Aki futni indul, nem tervez, hanem
>    elindul. Tervezz egy **gyorsindító lapot** (a Workouts FAB hosszú nyomására), amin a
>    felhasználó **négy leggyakoribb** edzése (erősítő tervek és cardio típusok **vegyesen**,
>    gyakoriság szerint rendezve) nagy, hüvelykkel elérhető csempeként szerepel — **egy koppintás
>    = az edzés azonnal fut**, köztes beállító képernyő nélkül.
> 2. **Az edzéstípusokat ikon különbözteti meg** mindenhol: listában, kártyán, statisztikában,
>    értesítésben, órán. Adj **teljes ikon- és színtérképet** a hét típusra (a hat cardio + az
>    erősítő), a fenti metrika-palettából származtatva.
> 3. **Az aktív képernyő futás közben, izzadt kézzel, napfényben is olvasható legyen**: egy
>    domináns szám, legfeljebb három másodlagos metrika, óriási érintőcélpontok, és a
>    **befejezés csak szándékos gesztussal** (húzás vagy hosszú nyomás) történhet, sosem egy
>    véletlen koppintással.
> 4. **A GAME családban a „pályán / padon” kapcsoló a képernyő legfontosabb vezérlője** — egy
>    meccs alatt a felhasználó az idő felét a padon tölti, és a valós edzésidő csak így mérhető.
> 5. **Minden képernyőnek van GPS nélküli változata**, mert a helymeghatározás megtagadható, és
>    ez **soha nem akadályozhatja meg** az edzés indítását.
>
> **Tervezd meg a következőket** (részletes lista és állapotok: a mellékelt §1–§6):
>
> **Mobil**
> 1. Gyorsindító lap (4 csempe + „Összes”) és a teljes aktivitás-választó
> 2. Aktív edzés képernyő **mindhárom családra**, futó / szüneteltetett / befejezés-megerősítés állapotban
> 3. Edzés-összegzés: útvonal, splitek, pulzuszónák, RPE-értékelés, szerkeszthető metrikák
> 4. Kézi (utólagos) rögzítő lap, családfüggő mezőkkel
> 5. Edzéslista-kártyák mind a hét típusra + fajta-szűrő
> 6. Statisztika-bővítés: fajta-szűrő, táv/tempó/szintemelkedés diagramok, magasságprofil
> 7. Élő felületek: iOS Live Activity (zárolási képernyő + Dynamic Island) és Android tartós értesítés
> 8. Engedély-, üres- és hibaállapotok (GPS megtagadva, gyenge jel, nincs adat)
> 9. Kezdőképernyő-widget gyorsindító gombok
>
> **Óra** (a meglévő watch-canvas nyelvén, **AW 16 / W 15**-től folytatva a számozást)
> 10. Egyesített indító lista (tervek + cardio típusok, gyakoriság szerint)
> 11. Aktív cardio képernyő mindhárom családra, a **pulzussal mint kiemelt másodlagos metrikával**
> 12. A GAME „pályán / padon” kapcsoló órai változata
> 13. Edzés-összegzés az órán
>
> **Web** *(szándékosan minimális — a webes felület a cardiót csak **mutatja**, onnan edzés
> nem indítható és nem vezérelhető; a web design-rendszere külön token-készlet, lásd melléklet §6)*
> 14. Az aktivitás-ikon chip web-tokenes változata
> 15. Cardio edzés a listában és a (csak olvasható) részletnézetben: metrika-rács, útvonalrajz,
>     split-táblázat — a mobil frame-ekből származtatva, **nem újratervezve**
>
> **Amit adj le:** (a) az **ikon- és színtérkép** a hét típusra, indoklással; (b) a **három
> családi elrendezés** metrika-hierarchiája (mi a domináns szám, mi a másodlagos sor, mi rejtett);
> (c) minden fenti képernyő frame-je, sötét **és** világos témában, magyar **és** angol felirattal
> (a magyar szavak hosszabbak — a design bírja el); (d) a mozgás- és haptikus visszajelzés terve az
> indítás / szünet / km-mérföldkő / befejezés pillanataira.
>
> Ne hozz be új színcsaládot, ne használj fotó-hátteret, és ne tervezz olyat, ami valódi
> térképcsempét igényel: **az útvonalat saját, téma-színű vonalrajz ábrázolja** (az app minden
> diagramja saját festésű, nincs térkép-SDK).

---

## 1. Melléklet — a hét típus és a három család

| Típus | Magyar | Család | Javasolt ikon | Javasolt akcent (a designer felülírhatja) |
|---|---|---|---|---|
| `RUNNING` | Futás | DISTANCE | `directions_run` | kalória (narancs) |
| `WALKING` | Séta | DISTANCE | `directions_walk` | lépés (lila) |
| `HIKING` | Túrázás | DISTANCE | `hiking` | fehérje (zöld) |
| `INDOOR_BIKE` | Szobabicikli | MACHINE | `pedal_bike` | szénhidrát (borostyán) |
| `BASKETBALL` | Kosárlabda | GAME | `sports_basketball` | zsír (indigó) |
| `FOOTBALL` | Foci | GAME | `sports_soccer` | víz (kék) |
| `OTHER_CARDIO` | Egyéb | GAME | `favorite` / `bolt` | semleges |
| *(meglévő)* | Erősítő | – | `fitness_center` | testsúly (kékesszürke) |

**Kérés a designerhez:** az ikon-chip legyen **egyetlen újrahasznosítható komponens**
(`ActivityChip`: kerek háttér az akcentszín 12–16%-os fedésével, ikon teljes fedéssel, három
méretben: 20 / 32 / 56 px), mert ugyanez jelenik meg a listakártyán, a gyorsindító csempén, a
statisztika-szűrőben, az értesítésben és az órán.

---

## 2. Melléklet — metrika-hierarchia családonként

A tervezés legfontosabb kérdése: **mi a domináns szám**. Ez **eldöntött** bemenet, nem javaslat:

| Család | Domináns (óriási) | Másodlagos sor (3 elem) | Rejtett / lapozva |
|---|---|---|---|
| DISTANCE | **táv** | mozgásidő · aktuális tempó · pulzus | kadencia, szintemelkedés, kalória, split-lista |
| MACHINE | mozgásidő | táv · kadencia (rpm) · teljesítmény (W) | ellenállás, kalória, pulzus, összmunka |
| GAME | **játékidő** | bruttó idő · pulzus · zóna | intenzitás, pont/gól, kalória |

**A DISTANCE családban a táv a domináns szám** (futás, séta, túra). A domináns hely mindig azt a
számot tartja, ami az adott edzést *meghatározza*: egy futás „egy tízes”, egy szobabicikli
„negyven perc”, egy meccs „egy óra játékidő”. Az idő ettől nem tűnik el — a másodlagos sor első
eleme, tehát ugyanolyan olvasható.

**Egy állapot, amit ehhez külön kérünk: „nincs távforrás”.** Futópadon, GPS-engedély nélkül és óra
nélkül nincs mit kiírni a nagy helyre — ott a **mozgásidő** a domináns szám, a táv pedig a
másodlagos sorba kerül, kézzel szerkeszthető mezőként. Kérünk erre egy külön frame-et: a nagy
„0,00 km” a funkció legrosszabb első benyomása lenne.

---

## 3. Melléklet — állapotok, amiket nem szabad kihagyni

| Képernyő | Kötelező állapotok |
|---|---|
| Gyorsindító lap | teljes (4 csempe) · hidegindítás (nincs előzmény → alapértelmezett sorrend) · „Összes” kibontva |
| Aktív edzés | fut · kézi szünet · **auto-pause** (a rendszer szüneteltetett — vizuálisan különbözzön a kézitől!) · gyenge GPS-jel · GPS nélkül · befejezés-megerősítés (húzás közben) |
| Összegzés | útvonallal · útvonal nélkül · GPS-hézaggal (szaggatott szakasz) · értékelés előtt/után · kézzel szerkesztett metrikával („szerkesztve” jelölés) |
| Lista-kártya | mind a hét típus · folyamatban lévő edzés · óráról gazdagított (⌚ jelzés, ez ma is létezik) · értékeletlen |
| Statisztika | van adat · nincs adat az adott fajtára · vegyes hét |
| Engedély | magyarázó lap a rendszer-kérdés előtt · megtagadva · véglegesen megtagadva · pontatlan hely (iOS) |
| Live Activity | DISTANCE / MACHINE / GAME · szüneteltetett · Dynamic Island kompakt és kibontott |

**Az auto-pause és a kézi szünet vizuális elkülönítése** külön kérés: ha a rendszer szüneteltet
(megálltál a lámpánál), a felhasználónak azonnal látnia kell, hogy ez nem az ő döntése volt,
különben azt hiszi, elrontotta a mérést.

---

## 4. Melléklet — az útvonalrajz

Nincs térképcsempe (döntés: az app minden diagramja saját festésű, offline is működik, és nincs
csempe-licenc). Az útvonal:

- téma-színű vonal `surfaceContainer` háttéren, lekerekített végekkel;
- start- és végpont-marker;
- **szaggatott** szakasz ott, ahol a GPS-jel kiesett;
- opcionálisan **tempó szerinti gradiens** a vonalon (lassú → gyors), a metrika-paletta két
  színe között — kérünk erre javaslatot, mert könnyű túltolni;
- két méret: nagy (összegzés) és miniatűr (listakártya, ~64×64), a miniatűrnek marker és
  gradiens nélkül is olvashatónak kell lennie;
- **magasságprofil** a túrához: alacsony, széles területdiagram az útvonal alatt, a
  `TimeSeriesChart` vizuális nyelvén.

---

## 5. Melléklet — óra

A meglévő canvas nyelvét kövesd (AW = Apple Watch, W = Wear OS), a számozást **AW 16 / W 15**-től
folytatva. A legfontosabb eltérés a telefontól: **az órán a pulzus a kiemelt másodlagos metrika**,
mert ez az egyetlen adat, amit csak az óra tud, és a felhasználó ezért néz oda.

Kért frame-ek: egyesített indító lista (a meglévő kiemelt „Quick strength” kártya **marad
legfelül**, a rangsorolt lista alatta kezdődik) · aktív cardio ×3 család · GAME pályán/padon
kapcsoló · összegzés · gyenge jel / nincs pulzus állapot.

---

## 6. Melléklet — web *(kicsi, származtatott)*

A webes felület a cardióra **olvasó**: megjeleníti és statisztikázza, de **nem indít és nem
szerkeszt** ([58 D-W.1, D-W.2](58-cardio-web-plan.md)). Ezért itt nincs aktív edzés-képernyő,
nincs gyorsindító, nincs Live Activity — összesen két dolgot kérünk, és mindkettő a mobil
frame-ekből vezethető le:

1. **`ActivityChip` web-változat** — ugyanaz a komponens a web token-készletével
   ([../web/06-design-system-web.md](../web/06-design-system-web.md)), két méretben
   (lista-sor, részletnézet fejléc).
2. **Cardio edzés a listában és a részletnézetben** — a lista-sor: ikon · aktivitás neve · dátum ·
   a család fő metrikája (ma ott gyakorlatnevek és szettszám áll, ami cardióra üres). A
   részletnézet: metrika-rács a család szerint, **útvonalrajz SVG-ként** (ugyanaz a vizuális
   nyelv, mint mobilon — §4), split-táblázat és pulzuszóna-sáv, ha van adat.

Két helyen **kifejezetten kérünk különbséget** a mai állapothoz képest, mert ma félrevezető
lenne: az edzői kliens-nézetben egy cardio edzés ne „0 gyakorlat / 0 kg volumen”-ként jelenjen
meg, az edzői naptár előnézetében pedig ne „névtelen terv”-ként.

Desktop szélességen a részletnézet kétoszlopos lehet (metrikák | útvonal); ez az egyetlen
elrendezésbeli szabadság, amit a webre kérünk.

---

## 7. Kimenet és forma

> *Utólag, a prompt lefutása után:* a designer a watch-frame-eket **külön fájlba** tette
> (`design/Lifey Cardio Watch Design.dc.html`), a web-frame-eket pedig a mobil canvas 13.
> szekciójába — mindkettő a lent megengedett formák egyike. Az alábbi bekezdés az eredeti,
> változatlanul hagyott kérés.

- **Design canvas** ugyanabban a formában, mint a többi Lifey-design:
  `docs/cardio/design/Lifey Cardio Design.dc.html`, frame-enként címkézve.
- A watch-frame-ek **a meglévő** `docs/watch/design/Lifey Watch Design.dc.html` bővítéseként vagy
  külön fájlként — de a meglévő számozás folytatásával (AW 16+ / W 15+).
- A web-frame-ek (§6) ugyanabban a canvasban, külön, „WEB” előtaggal jelölt szekcióban.
- Minden frame mellé egy rövid jegyzet: milyen tokenekből épül, és mi az indoklás ott, ahol
  eltértél a fenti javaslattól.
- Ami **nem** dönthető el designban (mert termékdöntés), azt jelezd vissza, ne találd ki — a
  splitek megjelenítési mélysége ilyen. A domináns szám **nem** ilyen: a §2 táblája eldöntött
  bemenet, amitől eltérni csak indoklással szabad.

---
---

# Döntés-napló *(a prompton kívül — a designernek nem kell)*

### DD-1 — Miért „család”, és nem hat külön képernyő
Hat típusra hat elrendezés hat karbantartási felület, és a felhasználó szempontjából is
inkonzisztens: a futás és a séta ugyanaz a művelet, más sebességgel. A három család a
metrikakészletből következik ([51 §1.1](51-cardio-overview-plan.md)), nem esztétikai csoportosítás.

### DD-2 — Miért a gyorsindítás az első elfogadási feltétel
A funkció fő kockázata nem technikai, hanem használati: ha az edzés indítása lassabb, mint
elindulni futni, a felhasználó nem fogja használni. Ezért a prompt ezt teszi a lista élére, és
ezért van kimondva a „köztes beállító képernyő nélkül” megkötés.

### DD-3 — Miért nem kérünk térképcsempét
Három ok: (1) új nehéz függőség, amit a CLAUDE.md indoklás nélkül tilt; (2) csempe-szolgáltatói
feltételek és kötelező attribúció; (3) az app minden diagramja saját festésű (`TimeSeriesChart`,
nincs `fl_chart`) — egy fotórealisztikus térkép idegen test lenne a vizuális nyelvben.
Ha később mégis kell, az a [54-es doc](54-cardio-gps-route-plan.md) C4b iterációja, saját
design-körrel.

### DD-7 — Miért kap a web csak két tételt, és miért nincs benne indítás
Mert onnan cardiót indítani értelmetlen: a mérés szenzorfüggő (GPS, pulzus), a használati
helyzet kizárja (senki nem visz laptopot futni), és egy harmadik indító pont új
ütközés-feloldási esetet nyitna a telefon–óra mesterviszonyban, nulla haszonért
([58 D-W.1](58-cardio-web-plan.md)). A web viszont **megjeleníti** a cardiót, és ott ma két
félrevezető állapot keletkezne (üres szett-logoló, „0 gyakorlat” az edzői nézetben) — a §6
pontosan ezt a kettőt célozza, semmi többet. Ezért nincs külön web design-kör sem.

### DD-4 — Miért kérünk kifejezetten magyar **és** angol frame-et
A magyar feliratok rendszeresen 30–50%-kal hosszabbak („Szobabicikli” vs. „Indoor bike”,
„Szintemelkedés” vs. „Elevation”), és a cardio képernyők tele vannak szűk metrika-címkékkel.
Ha ez csak az implementációnál derül ki, a designt kell újranyitni.

### DD-5 — Miért a **táv** lett a DISTANCE család domináns száma *(eldöntve 2026-08-09)*
Két védhető válasz volt: az „idő” a családok közti konzisztenciát tartja, a „táv” a futók
mentális modelljét. A táv nyert, három okból.

1. **A táv a cél alakú szám.** Egy futásnak van neve — „egy ötös”, „egy tízes” —, harminc percnek
   nincs. Amit a felhasználó kimond, azt kell a nagy helyre írni.
2. **A konzisztenciát a *szerep* tartja, nem a metrika.** A domináns hely minden családban
   ugyanaz: az a szám, ami az edzést meghatározza. Ez DISTANCE-nál a táv, MACHINE-nál az idő,
   GAME-nél a játékidő — az olvasási szokás (hol nézzek) ettől nem sérül, csak a mértékegység
   változik, ami amúgy is ott van a szám mellett.
3. **Az egyetlen érv az idő mellett a hiányzó távforrás volt**, és azt nem elrendezéssel kell
   megoldani, hanem a hiány kimondásával: távforrás nélkül (futópad, megtagadott GPS) az idő lép
   a nagy helyre, a táv pedig szerkeszthető mezőként a másodlagos sorba. Így a képernyő sosem
   mutat óriási „0,00 km”-t — ez volt a valódi kockázat, nem a konzisztencia.

Ami ebből a designra tartozik: a §2 táblája a bemenet, plusz a „nincs távforrás” frame kötelező.

### DD-6 — Miért kell külön vizuál az auto-pause-ra
Az egyetlen olyan állapot a funkcióban, amit **nem a felhasználó idézett elő**, mégis a mérését
érinti. Ha nem különbözik a kézi szünettől, bizalmi hiba lesz belőle („miért állt meg? elrontottam?”).
