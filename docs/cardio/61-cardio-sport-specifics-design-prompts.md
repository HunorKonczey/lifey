# 61 — Sport-specifikumok (C6–C9): design

> **Státusz: a design elkészült (2026-08-16).** Canvas:
> [`design/Lifey Cardio Sport-specifikumok.dc.html`](design/Lifey%20Cardio%20Sport-specifikumok.dc.html)
> — **M33–M45**, hézag nélkül folytatva az M01–M32 számozását, plusz állapot-kivágatok és
> iterációnként egy világos/angol minta.
>
> **Ez a doc a C6–C9 UI kötelező forrása.** A §1–§5 a **leszállított design** leírása
> frame-enként (elrendezés, tokenek, állapotok, indoklás, eltérések) — **innen dolgozz**, ne a
> canvas HTML-jéből és ne emlékezetből. A §6 a designer által **visszaadott nyolc termékdöntés**.
> A §7 a lefuttatott promptok, változatlanul, a napló kedvéért.
>
> Lépések és függések: [60-cardio-sport-specifics-plan.md](60-cardio-sport-specifics-plan.md).
> Alap-canvas (M01–M32): [`design/Lifey Cardio Design.dc.html`](design/Lifey%20Cardio%20Design.dc.html).

---

## 0. A canvas alapszabályai

- **Semmit nem tervez újra** az M01–M32-ből: minden frame egy meglévő képernyő **különbsége**, a
  hivatkozott frame számával a címben („M13/M14 bővítése", „M05 +", „M15 +", „M16 +", „M04 +",
  „M06 +").
- Ugyanazok a tokenek: `161611` surface · `1C1E16` surfaceLow (kártya) · `22241B`
  surfaceContainer (kártyán belüli sáv/sor) · `9DAE6B` primary · radius sm 8 / md 16 / card 20–22 /
  lg 26 / pill. Plus Jakarta Sans, **tabular számok** mindenhol.
- **Nincs új színcsalád.** Az aktivitás-akcentek a meglévő metrika-palettából jönnek; a futás
  rampája egy hue két fokozata: `8A5333` (lassú) → `E0915A` (gyors).
- A teljes képernyők mellett **állapot-kivágatok** állnak: csak az a blokk, ami változik. Ezek
  **nem kaptak saját frame-számot**, a bővített frame számára hivatkoznak.

---

## 1. Frame-leltár → melyik lépés használja

| Frame | Mit bővít | Tartalom | Lépés ([60](60-cardio-sport-specifics-plan.md)) |
|---|---|---|---|
| **M33** | M13/M14 | Tempó-diagram (oszlop) + split-lista, kölcsönös kiemeléssel | **C6.4** |
| **M34** | M13 | „Legjobb résztávok" kártya (1/5/10 km) + rekord-sor | **C6.7** |
| **M35** | *(új lap)* | Km-visszajelzés beállító lap (rezgés · hang · beszélt „hamarosan") | **C6.6** |
| **M36** | *(új dialógus)* | Több rekord egyszerre — **egy** ünneplés | **C6.7** |
| **M37** | *(új képernyő)* | Intervallum-szerkesztő, ismétlés-blokkokkal | **C7.4** |
| **M38** | M05 | Intervallum-lejátszó az élő MACHINE képernyőn | **C7.5** |
| **M39** | M15 | Összmunka + szakasz-lista + **kétoldalas kalória-kártya** | **C7.6**, C7.7 |
| **M40** | M16 | Valódi magasságprofil: hézag-sáv, csúcs, kiválasztott pont | **C8.3** |
| **M41** | M04 | Útpont-jelölés az élő túra képernyőn | **C8.4** |
| **M42** | M15 | Terep-blokk (max magasság, GAP), hátizsák, időjárás, útpont-lista | **C8.2, C8.5, C8.6** |
| **M43** | M14 | Pulzuszóna-panel | **C9.1** |
| **M44** | M06 | Box score léptető (rejtett → felajánlott → nyitott) | **C9.2** |
| **M45** | *(új lap)* | Formátum · helyszín · kültéri GPS-mód indításkor | **C9.3, C9.4** |

**Világos/angol minta**: M33 · M38 · M42 · M43 (iterációnként egy) — a többi frame ezekből
származtatható. A magyar címkék hosszabbak: a designer külön ellenőrizte, hogy a zóna-nevek
(„küszöb" vs. „threshold") és a szakasz-típusok mindkét nyelven beférnek 56 px-be.

---

## 2. C6 · Futás — M33–M36

### M33 · Tempó-diagram + split-blokk

**Elrendezés** (az összegzés legörgetett állapota, M14 fejlécével: 44 px kapszula, vissza-gomb +
cím + a táv jobbra):

1. **Tempó-kártya** (`1C1E16`, radius 22, padding 15/16). Fejléc: `TEMPÓ · PERC/KM` (11 px, w700,
   tracking 1.2, `777264`) + jobbra egy pill (`22241B`, radius 999) `arrow_upward` + „gyorsabb".
2. **Oszlopdiagram**, 150 px magas, viewBox 330×150: splitenként egy 26 px széles, radius 7-es
   oszlop, **a magasabb a gyorsabb** (fordított tempó-skála). Szaggatott átlagvonal (`3C3E32`,
   dash 3 5). A leggyorsabb oszlop kap felirat-értéket (`5:02`, 9 px, akcentszín). A részleges
   utolsó split **szürke** (`3C3E32`) és **nem kap saját oszlopot** az értékelésben.
3. Tengely-sor: `1. km` · `átlag 5:22` · `8,42 km` (10 px, w600).
4. **Split-lista kártya** ugyanabban a formában, `expand_less` ikonnal (összecsukható). Egy sor:
   **index** (12 px w800, 14 px széles) · **sáv** (10 px magas, radius 5, alap `22241B`, kitöltés a
   futás-rampából, szélesség a tempóval arányos) · **idő** (12,5 px w800, 40 px jobbra zárva) ·
   **szintkülönbség** (10,5 px w700, `+12` / `−4`, 34 px jobbra zárva).
5. **Kiválasztott split**: a sor `22241B` háttérrel, negatív margóval kiszélesedik (radius 12), az
   index és az idő akcentszínt kap — **és ugyanakkor a diagram oszlopa is világít**.
6. Alul magyarázó sáv (`touch_app`): „A kiválasztott split kiemeli a saját oszlopát — a lista és a
   diagram egy adat két nézete."

**Miért oszlop, nem terület:** a splitek diszkrét egységek (1 km = egy oszlop); a területdiagram
folytonosságot állítana, ami nem igaz, és egy terület nem koppintható szakaszonként.

**Eltérés a prompt javaslatától:** nem külön „kijelölés" állapot készült, hanem a **lista sora és
az oszlop egyszerre** világít — így nem kell megtanulni, hogy a kettő összefügg.

**Állapotok:** `15+ split` → a lista összecsukva, a diagram sűrűbb oszlopokkal (14 px szélesség) ·
`1 split` → **nincs diagram**, csak a lista · `hiányzó szintadat` → a jobb oszlop helyén egyszeri
`terrain` + „nincs szintadat" felirat, a sorok szint-oszlopa üresen marad.

### M34 · „Legjobb résztávok" kártya

Az összegzés metrika-rácsa alatt (`LEGJOBB RÉSZTÁVOK` + `info` ikon). **Három sor**, soronként
három információ: a **résztáv** (1 km / 5 km / 10 km, 14 px w800, 44 px széles), a **legjobb idő**
(19 px w800) + alatta **hol volt** („a 7,1–8,1 km szakaszon", 10 px), és jobbra a **normalizált
tempó** (12,5 px w800) — csak ez az összemérhető a három résztáv között.

**Rekord-sor**: nem külön háttérszín, hanem borostyán (`D8B35A`) **12%-os töltés + 34%-os szegély**
+ egy `trophy`-pill („rekord", `D8B35A` alapon `161611` szöveggel), és a tempó is borostyán. Ez
ugyanaz a „kiemelt sor" minta, mint a statisztika rekord-listáján.

**Állapotok:** `részleges` (4 km-es futás) → csak az 1 km-es sor létezik, **az 5 és 10 km sehogy
nem jelenik meg** — se szürkén, se „nincs elég táv" szöveggel (egy 4 km-es futáson a 10 km-es
résztáv nem hiányzó adat, hanem nem létező fogalom) · `nincs nyomvonal` → az egész kártya kiesik,
a splitek és a zóna-sáv zárja a képernyőt.

### M35 · Km-visszajelzés beállító lap

Az **auto-pause lap mintája**: sheet radius 30, `22241B` sorok, 52×32-es toggle-ök, alul primary
„Kész". Tartalom sorrendben: **Automatikus szünet** (meglévő, „Be · 2 km/h") · **Kilométer-
visszajelzés** szekció-fejléc · **Rezgés** (`vibration`, „Két rövid koppintás") · **Hangjelzés**
(`volume_up`, „Rövid csengő, a zene alatt") · **Beszélt visszajelzés** (`record_voice_over`,
**„hamarosan"** jelöléssel, példával: „3. kilométer, 5:12 tempó").

A nem létező funkció **szaggatott szegélyt** kap, nem csak szürke szöveget — így nem tűnik
elromlott kapcsolónak, de a helye látszik. *(Ez a [60 Q-C6.1](60-cardio-sport-specifics-plan.md)
javaslatának designbeli megerősítése: TTS most nem épül.)*

Az utolsó sor a **mértékegység magyarázata**, nem beállítása: „A mértékegység a profilból jön:
most **kilométer**. Mérföldre váltva a jelzés **mérföldenként** szól, és a splitek is mérföldre
váltanak." — két helyen állítható mértékegység garantált hibajelentés.

**Állapotok:** csak rezgés · minden ki · mérföldes profil.

### M36 · Több rekord egyszerre — egy ünneplés

**Egy dialógus, egy lista, egy haptika** (siker-minta, 350 ms) — nem négy ünneplés. A fejléc a
darabszámot mondja ki („**Négy rekord** egyetlen futáson", `trophy` ikonnal). Soronként: ikon +
rekord neve + **az előző érték dátummal** („előző: 24:36 · október 12.") + az új érték + a
**különbség** primary-zölddel („−48 s", „+0,8"). Négynél több rekordnál a lista görgethető, a
fejléc számol.

Záró sor: „Egy ünneplés, egy haptika, egy lista. A rekordok az összegzés sorain is ott maradnak."
Gombok: **Összegzés megnyitása** (primary) · Bezárás.

**Állapotok:** egy rekord → kompakt, egysoros változat („Új rekord: leggyorsabb 5 km · 23:48 · 48
másodperccel jobb") · a rekord az **összegzés sorában** → a „Leggyorsabb 5 km" sor a résztáv-
kártyán belül, „a nyomvonalon számolva" alcímmel.

---

## 3. C7 · Szobabicikli — M37–M39

### M37 · Intervallum-szerkesztő

Teljes képernyő, `close` + „Intervallum-terv" + „Mégse" fejléccel.

1. **Terv neve** mező (`A TERV NEVE` label, „Kedd esti 4×4", `edit` ikon).
2. **Három élő szám a fejlécben**: `38:00` teljes hossz · `10` szakasz · **`16:00` kemény idő** —
   egy intervallum-tervet valójában az utolsó határoz meg.
3. **Szakasz-lista**: `1C1E16` kártyák, `drag_indicator` fogantyúval. Egy szakasz: név
   („Bemelegítés") + intenzitás-címke („könnyű") + időtartam (`5:00`).
4. **Ismétlés-blokk**: külön keret `ISMÉTLÉS-BLOKK` fejléccel, benne a szakaszok `22241B` sorokként
   — **a beágyazottság mélységgel látszik, nem behúzással** (390 px-en a behúzás elfogyna). A
   blokk fejlécében helyben szerkesztős számláló (`−` `×4` `+`), az alján a kiszámolt
   **`4 × 7:00 = 28:00`** — itt ellenőrzi a felhasználó, hogy azt kapja-e, amit gondolt.
5. Hozzáadás-sor: **`add` Szakasz** · **`repeat` Ismétlés**.
6. Alul: **Mentés és indítás** (primary) · **Csak mentés**.

**Állapotok:** `üres` → „Építs egy tervet" magyarázat + **„Kezdj a 4×4-tel"** sablon-ajánlat
(4 perc kemény / 3 perc könnyű, négyszer) · `szakasz szerkesztése` → időtartam-stepper +
intenzitás-választó · `hosszú terv görgetve` → az ismétlés-blokkok **összecsukva** egy sorra
(„4× (4:00 kemény + 3:00 könnyű) · 28:00", `expand_more`).

### M38 · Lejátszó az élő MACHINE képernyőn

A lejátszó a **fejléc és a domináns szám közé** kerül, és egyiktől sem vesz el helyet:

- A mozgásidő **96 → 82 px**-re csökken (ez az **egyetlen** méret-csökkentés az M05-höz képest).
- Az ellenállás-léptető **pixelre a helyén** marad.
- A jobb alsó kör (M05-ben „Kör") most **`skip_next` „Léptet"** — ugyanaz a méret, ugyanaz a hely,
  más funkció. A befejezés-gesztus útjába semmi nem került.

**Lejátszó-blokk**: `3/10. SZAKASZ` · a szakasz típusa nagy betűvel (`KEMÉNY`) · **visszaszámláló**
(`1:48` + „van hátra") · **`arrow_forward` Utána: 3:00 könnyű**. Kemény szakasznál a képernyő
**felső harmadát borostyán gradiens festi be** — izzadtan, periférikus látással a nagy színfolt
üzen, nem a szöveg.

A fejléc jobb oldalán `bluetooth_connected` **„Gép"** pill jelzi a párosított szenzort.
*(Implementációs megjegyzés: az app ma nem párosít BLE-trainert — a pill csak akkor jelenjen meg,
ha tényleg van forrás; enélkül a kadencia/watt kézzel megadott érték marad,
[51 §3.3](51-cardio-overview-plan.md).)*

**Állapotok:** `könnyű szakasz` (nincs gradiens) · **`utolsó 3 másodperc`** → „MOST JÖN · 4:00
KEMÉNY" + nagy `3` visszaszámláló, **haptika: három rövid koppintás (3–2–1, 60 ms), majd a váltás**
· `szünet alatt` → „3/10. SZAKASZ · SZÜNETEL", „áll", és a magyarázat: **a szakasz órája a
szünettel együtt megáll — a terv nem fut le a semmibe** · `terv nélkül` → **pontosan az M05**,
a funkciónak semmi nyoma.

### M39 · MACHINE összegzés

1. **Összmunka-kártya**: `bolt` `386` **kJ összmunka** + „a teljesítményből" · mellette `speed`
   `168` átl. watt + „max 248".
2. **`INTERVALLUM-SZAKASZOK`** kártya, fejlécében `repeat` `4×(4+3)` chip. A sorok formája
   **pontosan a futás km-splitjeié**, két különbséggel: balra a **szakasz típusa** áll a kilométer
   helyett, és a **sáv hossza az intenzitást** mutatja, nem a tempót. Jobbra idő + átlag watt.
   Alul „Mind a 10 szakasz" + `expand_more`.
3. **Kalória-kártya — a kulcs**: **egy kártya, két oldal, közte vonal**. Bal: `local_fire_department`
   **AKTÍV** `486` „kcal · a napi keretbe ez számít bele" — kalória-narancs, teljes kontraszt.
   Jobb: `monitor` **A GÉP KIJELZÉSE** `612` „kcal · tájékoztató, nem adjuk össze" — `777264`
   másodlagos tónus. Alul `info`: „A gépek kalóriabecslése testsúlyt nem ismer — ezért soha nem
   kerül a napi összegbe."
   **Két külön kártya rosszabb volt**: úgy két egyenrangú számnak látszottak, és az összeadás
   gyanúja megmaradt.

**Állapotok:** `watt-adat nélkül` → az összmunka-kártya helyén mozgásidő + átl. rpm · `terv nélkül`
→ nincs szakasz-lista.

---

## 4. C8 · Túra — M40–M42

### M40 · Valódi magasságprofil

- **A hézag sáv, nem vonal**: a kieső szakasz **szélessége arányos a távval**, két szélén szaggatott
  határ, a kitöltés a meglévő figyelmeztető barnából (`C49A6C`) **9%-on**, „hézag" felirattal. Így
  látszik, hogy **nem nulla lett a magasság, hanem nincs adat**.
- **Csúcs**: marker a görbén + felirat (`756 m`), a tengely alatt „csúcs 756 m · 5,8 km".
- **Kiválasztott pont**: `location_on` chip a kártya fejlécében („kiválasztott pont · 6,4 km"),
  a görbén **ejtővonal**, és a kártya alján **három számos readout**: `my_location 612 m` magasság ·
  `8,4 km` idáig · `2:38` eltelt. **Nincs lebegő tooltip** — 390 px-en kilógna vagy letakarná a
  görbét.
- Alatta a szokásos 3-cellás rács: `14,2` km · `4:12` óra · `756` m csúcs.
- Záró magyarázó sáv: `gps_off` „620 m-en nem volt jel. A profil itt **nem folytatódik** — a
  szintadat erre a szakaszra nincs meg."

**Állapotok:** `sima emelkedés` → `EGYENLETES` chip + `+512 m` · `hullámzó terep` · **`degradált`**
→ `MAGASSÁGPROFIL · EGYSZERŰSÍTETT` + `history`: „A részletes nyomvonal 30 nap után törlődik a
telefonról. A csúcs, az emelkedés és a táv **megmarad**."

### M41 · Útpont-jelölés az élő túra képernyőn

- **A gomb 88 px magas, teljes szélességű hasáb** (`add_location_alt` „Útpont jelölése" + „ahol most
  vagy"), közvetlenül a hüvelyk zónája fölött, **a befejezés-gesztus sávja fölött** — azt nem szeli
  át. Nem kör: így nem keverhető össze a három vezérlő-körrel, és túrabakancsban, kesztyűvel is
  eltalálható.
- Az útvonalrajzon **sorszámozott markerek** (1, 2, 3).
- **Visszajelzés**: `check_circle` „3. útpont megjelölve" + **a számok** („8,24 km · 612 m ·
  12:19") + **„Vissza"** gomb. **4 s után magától eltűnik.** A számok azért kellenek, mert az
  útpontnak V1-ben nincs más tartalma.
- A metrika-sor túrán: mozgásidő · **m szint** · **m tszf.** (tengerszint feletti magasság).

**Állapotok:** `50 útpont` → a markerek sűrűsödnek, a szám a marker mellé kerül · **`GPS nélkül`**
→ a gomb **nem tűnik el, hanem nem elérhető** (`location_off`, „helyadat nélkül nincs mit
megjelölni"); koppintásra a helyengedély-magyarázat nyílik (M25) · `0 útpont` → a lista nem jelenik
meg.

### M42 · Túra-mezők

1. **`TEREP` blokk**: `756` m max magasság · `684` m emelkedés · **`17:44` /km nyers tempó** és
   mellette **`14:02` /km GAP · normált** — a GAP **ugyanabban a kártyában, kisebb fokozattal**
   (24 → 17 px, teljes → másodlagos szín), hogy ne lehessen összekeverni, melyik a mért érték.
   Magyarázat: „A GAP azt mutatja, mit hozna ez a teljesítmény sík terepen. **Nem helyettesíti a
   nyers tempót.**"
2. **Hátizsák-súly**: `8 kg` + a meglévő „szerkesztve" chip mintája **„kézzel"** felirattal —
   ez az egyetlen mező, amit csak a felhasználó tudhat. Alcím: „pontosítja a kalória-becslést".
3. **`IDŐJÁRÁS INDULÁSKOR`**: „8:12 · pillanatkép" + `partly_cloudy_day` `7 °C` hőmérséklet ·
   `12` km/h szél · `0` mm csapadék.
4. **`ÚTPONTOK`** lista: „3 db", soronként sorszám · táv · magasság · idő.

**Állapotok:** `sík terep` → **a GAP nem duplikál**: „A terep sík volt (28 m emelkedés) — a normált
tempó megegyezik a nyerssel, ezért nem mutatjuk kétszer." · `nincs időjárás-adat` → `cloud_off`
+ magyarázat (offline indulás vagy megtagadott hely).

---

## 5. C9 · Játék — M43–M45

### M43 · Pulzuszóna-panel

- **22 px magas halmozott sáv** válaszol a „kemény meccs volt-e" kérdésre a Z4–Z5 dominanciájából,
  a végein „könnyű"/„kemény" felirattal.
- A fejlécben **chip mondja ki szóban is**: `local_fire_department` **„kemény meccs"** (kemény /
  kiegyensúlyozott / könnyű) — mert a színek önmagukban **nem elérhetők színvakon**.
- **Öt sor**: zóna-kód (`Z1`…`Z5`) + **zóna-név** („bemelegítés · alap · tempó · küszöb ·
  maximum") + idő + százalék. A **zóna-szín csak a címkén és a kis sávon** van, **a szám mindig
  teljes kontrasztú**.
- Záró sor: „Az óra pulzusadatából, a profil maximális pulzusa alapján. **Becslés nincs.**"
- A GAME-összegzés fejléce: `JÁTÉKIDŐ 34:12` · `58:40` bruttó · `162` átl. bpm · `642` kcal, és az
  identitás-sorban „Ma 19:10 · terem · 5v5" + `watch` „Óra" pill.

**Állapotok:** `részleges pulzusadat` → `timelapse` „a meccs 62%-a" + a hiányzó rész **sraffozott**
sávként · **`nincs zóna-adat`** (a leggyakoribb eset) → a **panel teljesen eltűnik**, az összegzés
maradéka nem lóg ki tőle.

*(A Tweaks panelen a skála átváltható egy borostyán-fokozatos változatra — a designer alternatívája,
nem külön állapot.)*

### M44 · Box score léptető

- A **„pályán / padon" kapcsoló változatlan** méretben és helyen marad (96 px, primary tálcán) — a
  léptető **fölé** került, nem a helyére.
- **A léptető nem áll mindig nyitva**: a jobb alsó kör (**`scoreboard` „Box"** gomb) nyitja, és
  **6 s tétlenség után magától becsukódik** („6 s után bezár" felirat a panel fejlécében) — zsebben
  vagy védekezés közben nem lehet véletlenül nyomni.
- Három oszlop kosárnál: **PONT · LEPATTANÓ · GÓLPASSZ**, mindegyik `−` érték `+` hármassal. A
  **`+` gomb 44 px magas és 1,4× szélesebb**, mint a `−`: a hozzáadás a gyakori művelet, a javítás
  a ritka. **Focinál ugyanez a komponens két oszloppal** (gól · gólpassz).

**Állapotok:** `rejtett alapállapot` → csak a „Box" kör látszik, panel nincs · **`egyszeri
felajánlás`** → „Vezessük a statisztikát? — Pont, lepattanó és gólpassz, egy koppintás a meccs
közben. **Ha nem érdekel, többé nem kérdezzük.**" + „Igen, kérem" / elutasítás · `az összegzésen és
a kézi lapon` → ugyanaz a hármas, **`edit` „szerkesztés"** móddal.

### M45 · Formátum, helyszín, kültéri mód

Indításkor felugró lap („A beállítás utólag is módosítható."):

1. **`FORMÁTUM`** — segmented **2×2-ben** (5v5 · Kispálya · Edzés · Meccs), mert négy elem egy
   sorban magyarul („Kispálya") nem fér ki.
2. **`HELYSZÍN`** — `home_work` Terem / `park` Szabadtér.
3. **GPS-sor — csak szabadtéren**: `gps_fixed` „GPS bekapcsolása" + „Több akkut használ", és
   **rögtön alatta a mit kapok / mit nem ígéret**: „**Kapsz távot és útvonalat.** Tempót nem: egy
   meccsen a perc/km nem értelmezhető szám." — ez az egyetlen hely, ahol a tempó hiányát kimondjuk,
   hogy az összegzésen ne tűnjön hibának.
4. **`play_arrow` Indítás** — **a lap nem blokkolja az indítást**: minden mezőnek van alapértéke (a
   legutóbbi választás), az „Indítás" az első koppintással is elérhető.

**Állapotok:** `terem` → **nincs GPS-sor**, nincs „engedélyezd a helyet" kérés, és az összegzésen
sincs táv — „nem letiltva, hanem nem létezik" · `szabadtér GPS nélkül`.

---

## 6. A designer által visszaadott nyolc termékdöntés

A canvas 6. szekciója. Mindegyikhez van **javaslat**, de a döntés nem designkérdés. A sorrend a
blokkolási sorrend — **az első három az implementációt is érinti**.

| # | Kérdés | A design javaslata | Blokkolja |
|---|---|---|---|
| **Q-D1** | A split-sor mélysége | **táv + tempó + szint** (így készült az M33). A **pulzus ne** kerüljön a sorba: négy szám 390 px-en 10,5 px-es tipográfiát kényszerít. Az átlagpulzus a kiválasztott split részletében férne el | **C6.4** |
| **Q-D2** | Javítható-e kézzel egy split? | **Nem** — egyetértés a tervvel. Szerkeszthető splitnél a diagram és a lista **két különböző igazságot** mutatna, és a „legjobb résztáv" értelmezhetetlenné válna. A session-szintű táv szerkesztése (M14) marad az egyetlen felülírás: **a splitek ilyenkor arányosan újraszámolódnak**, és a kártya megkapja a „szerkesztve" jelölést | **C6.4** |
| **Q-D3** | A cél-intenzitás skálája | **Három fokozat** az alap (M37 így készült). Az ellenállás-fokozat gépenként más skálán fut → a terv nem lenne újrahasznosítható; a watt-cél a többségnél üres mező. Ha a gép ad wattot: **opcionális watt-sáv ugyanabban a sorban** („kemény · 200–230 W") | **C7.4** |
| **Q-D4** | Kell-e hang a szakaszváltásra? | **Legyen, de kikapcsolhatóan** — a szobabicikli mellett gyakran szól zene, és a kormányra csíptetett telefon elnyeli a rezgést. A helye adott: az **M35 lapjának mintája** (rezgés/hang kapcsolópár) MACHINE-ra átvéve | **C7.5** |
| **Q-D5** | Címke az útpontnak utólag? | A V1 enélkül is értelmes (sorszám + táv + magasság + idő), **de** egy hónap múlva a „2. útpont · 5,8 km" nem mond semmit → **címke a következő körre**, az összegzés listáján helyben szerkeszthető sorként. **Az élő képernyőn ne legyen beírás** | C8.4 (V2) |
| **Q-D6** | A max magasság hova tartozik? | **Mindkettő** (M40 rács + M42 Terep blokk). A marker a „hol"-ra válaszol, de a szám kell a rácsba is: a lista-kártyán, a megosztott képen és a degradált nézetben csak a rács marad | **C8.3/C8.5** |
| **Q-D7** | A zóna-panel minden cardióhoz? | **Minden típusnál, ahol van zóna-adat.** Az M43 panelje legyen **az** zóna-komponens; két különböző zóna-vizuál ne éljen egymás mellett. **A sorrend viszont típusfüggő**: DISTANCE-nál a splitek után, GAME-nél közvetlenül a domináns szám után | **C9.1** |
| **Q-D8** | Megéri a sprint-szám saját vizuált? | **Most ne.** Amíg a „mi számít sprintnek" nyitott, a saját vizuál olyan pontosságot ígér, ami nincs meg. Ha bekerül: **egy szám a metrika-rácsban** („14 sprint"), nem diagram — a zóna-panel ugyanezt már megadja intenzitásként | C9.4 |

### Amit a design közben eldöntött (a [60](60-cardio-sport-specifics-plan.md) nyitott kérdései közül)

- **Q-D2 (box score alapból látszik-e)** — az M44 megerősíti: **rejtve, egyszeri felajánlással**,
  végleg elutasíthatóan. Ezzel a [59 §1.2](59-cardio-implementation-plan.md) utolsó nyitott
  canvas-kérdése is lezárva.
- **Q-C6.1 (TTS)** — az M35 „hamarosan" sora a design megerősítése: **most nem épül**, de a helye
  megvan.
- **Q-C8.1 (időjárás-forrás)** — **továbbra is nyitott**: az M42 megtervezi a kártyát és a „nincs
  adat" állapotot, de a forrást (külső API vs. kézi) nem dönti el.
- **Q-C7.1 (intervallum-terv entitás)** — nem designkérdés, változatlanul a [60 D-C7.1](60-cardio-sport-specifics-plan.md) szerint.

---

## 7. A lefuttatott promptok *(napló — ez futott le 2026-08-16-án)*

### 7.1 Közös blokk

> Te a **Lifey** fitness- és táplálkozáskövető alkalmazás design rendszerén dolgozol. A rendszer
> **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss) akcentszínű**, mindenhol
> **generózus lekerekítéssel** (radius-skála: sm ~8 · md ~16 · input ~18 · card ~20 · lg ~24 ·
> nav ~28 · pill = stadium), betűtípus **Plus Jakarta Sans** (számoknál tabular figures),
> **ikon minden akción**, minimál szövegű címkékkel. Metrika-akcentek (**ezekből dolgozz, ne hozz
> be idegen színt**): kalória (meleg narancs), fehérje (zöld), szénhidrát (borostyán), zsír
> (indigó), lépés (lila), víz (kék), testsúly (kékesszürke).
>
> **Ami már megvan, és amihez illeszkedned kell.** Az app cardio-felülete elkészült és le is
> szállt: a `docs/cardio/design/Lifey Cardio Design.dc.html` canvas **M01–M32** frame-jei. **Ez a
> kör nem tervez újra semmit ebből** — a feladat kizárólag **egy sportág specifikus finomságait**
> teszi hozzá a már meglévő képernyőkhöz. Ha egy meglévő frame-et bővítesz, hivatkozz rá a
> számával, és csak a **különbséget** rajzold ki.
>
> **A három család** (eldöntött bemenet): **DISTANCE** — domináns szám a **táv** · **MACHINE** — a
> **mozgásidő** · **GAME** — a **játékidő**.
>
> **Kötelező kilépési feltételek:** (1) sötét **és** világos téma, magyar **és** angol felirat;
> (2) **üres/hiányzó adat állapot** minden új blokkra — ebben a funkcióban a „nincs adat" nem
> kivétel, hanem gyakori eset, ilyenkor a blokk **tűnjön el**; (3) nincs új színcsalád, fotó-háttér
> vagy térképcsempe; (4) az **egykezes használat** marad követelmény, és **semmi új elem nem
> kerülhet a „befejezés" gesztus útjába**.
>
> **Amit adj le:** a kért frame-ek, frame-enként egy rövid jegyzettel (tokenek + hol tértél el a
> javaslattól, indoklással). Ami **termékdöntés és nem design**, azt **kérdésként add vissza**.
> A kimenet a meglévő canvas számozásának folytatása **M33-tól**.

### 7.2 Iterációnkénti kérések

| Iteráció | A prompt kérése | Eredmény |
|---|---|---|
| **C6** | M33 tempó-diagram + split-blokk (3–5 / 15+ / 1 split / hiányzó szint) · M34 legjobb résztávok (mindhárom / részleges / egyik sem / rekord) · M35 km-visszajelzés beállító lap (a TTS helye, de nem maga a funkció) · M36 rekord-visszajelzés, **több rekord egyszerre** | §2 |
| **C7** | M37 intervallum-szerkesztő (üres / kész 4×(4+3) / hosszú / szakasz-szerkesztés) · M38 lejátszó az M05-ön (könnyű / kemény / utolsó 3 mp / szünet / terv nélkül) · M39 összmunka + szakaszok + **külön gép-kalória** | §3 |
| **C8** | M40 valódi magasságprofil (hézag, csúcs, kiválasztott pont, degradált) · M41 útpont-jelölés (0 / 3 / 50 útpont, GPS nélkül) · M42 túra-mezők (max magasság, hátizsák, GAP, időjárás; sík terep, nincs időjárás) | §4 |
| **C9** | M43 zóna-panel (teljes / részleges / **nincs zóna-adat**) · M44 box score (rejtett / felajánlás / aktív; kosár vs. foci) · M45 formátum + helyszín + kültéri mód (terem / szabadtér / szabadtér GPS-szel) | §5 |

---

## 8. Ha újabb design-kör kell

- A számozás **M46-tól** folytatódik, hézag nélkül.
- Az állapot-kivágatok továbbra sem kapnak saját számot — a bővített frame számára hivatkoznak.
- A §6 nyitott tételei (**Q-C8.1 időjárás-forrás**, **Q-D5 útpont-címke V2**, **Q-D8 sprint**) az
  első jelöltek egy következő körre.
