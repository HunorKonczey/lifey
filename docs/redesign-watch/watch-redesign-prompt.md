# Watch redesign — prompt Claude Designnak

> **A fájl célja:** önállóan átadható prompt a Lifey **óraappjainak** (Apple Watch és Wear OS) újratervezéséhez,
> a mobil és a webes redesign (Design System v2) stílusában. A §0 blokkot egy az egyben be lehet másolni. Mellé
> ezeket kell csatolni:
> - `lifey-watch-jelenlegi-allapot.pdf` — 48 oldal, ≈ 2 MB: az **Apple Watch** app 38 képernyő-állapota (AW-01…AW-38)
>   magyarázatokkal, az óraapp térképe, token-összehasonlítás, „Fontos megfigyelések”, angol változatok és az összes
>   szöveg HU/EN;
> - `lifey-wear-jelenlegi-allapot.pdf` — 44 oldal, ≈ 1,6 MB: ugyanez a **Wear OS** apphoz (W-01…W-34), kerek kijelzőn,
>   az Apple Watch-tól való eltérésekkel;
> - a mobil v2 design rendszer: `docs/redesign/Lifey Design System.dc.html` (ha a Claude Design projekt, amelyben a
>   mobil és a webes redesign készült, elérhető, ott folytasd — a design system és a canvasok már bent vannak).
>
> Előzmények: [docs/redesign/77-mobile-redesign-plan.md](../redesign/77-mobile-redesign-plan.md) (a mobil v2
> döntései), [docs/redesign-web/web-redesign-prompt.md](../redesign-web/web-redesign-prompt.md) (a web promptja, ugyanez
> a szerkezet), [docs/watch/41-watch-design-prompt.md](../watch/41-watch-design-prompt.md) és
> [45-watch-f5-f6-design-prompt.md](../watch/45-watch-f5-f6-design-prompt.md) (a mostani óra-design briefjei),
> [docs/watch/design/Lifey Watch Design.dc.html](../watch/design/Lifey%20Watch%20Design.dc.html) és
> [docs/cardio/design/Lifey Cardio Watch Design.dc.html](../cardio/design/Lifey%20Cardio%20Watch%20Design.dc.html)
> (a mostani óra-canvasok). A tokenek a kódban: `mobile/ios/LifeyWatch/Theme/` és
> `mobile/android/wear/src/main/kotlin/com/khunor/lifey/ui/theme/`.

---

## 0. A prompt (ezt add át)

> A **Lifey**-n dolgozol. Ez egy fitness- és táplálkozáskövető rendszer: offline-first Flutter mobilapp, Next.js
> webapp és két **óraapp** — **Apple Watch** (SwiftUI, watchOS 10+) és **Wear OS** (Jetpack Compose for Wear OS).
>
> A mobil és a web redesignja **elkészült**: ez a **Lifey Design System v2** (a csatolt / ebben a projektben lévő
> `Lifey Design System.dc.html` és a képernyő-canvasok). **A feladat: az óraappokat ugyanebbe a design rendszerbe
> hozni.** Ne egy új stílust találj ki — a v2 tokenjeit, tipográfiáját, komponens- és mozgáselveit vidd át, és ahol
> az óra mást igényel (pillantás-méretű képernyő, érintés izzadt ujjal, forgó korona / bezel, kerek és lekerekített
> négyzet alakú kijelző, AMOLED, akku), ott **terjeszd ki** a rendszert, a v2 szellemében.
>
> **A két csatolt PDF az óraappok jelenlegi állapota** (képenként azonosító: `AW-xx` Apple Watch, `W-xx` Wear OS;
> mellette magyarázat: mikor jelenik meg, mit látunk, milyen funkciók vannak, mi a probléma / mit érdemes megtartani).
> A PDF elején: az óraapp térképe (állapotgép, oldalak, két mód), a mostani óra-tokenek és a mobil v2 tokenek
> összehasonlító táblázata, és egy „Fontos megfigyelések” lista. **Ezeket olvasd el először.**
>
> **Fontos a képekről:** a PDF-ben lévő képek **nem szimulátor-képernyőképek**, hanem a forráskódból rekonstruált
> megjelenítések (valódi elrendezés, színek, magyar/angol szövegek; helyettesítő betűtípus; az Apple Watch képeken
> Material ikonok állnak az SF Symbols helyett — a pontos SF Symbol név minden kép alatt fel van sorolva). A
> szélességek pár százalékban eltérhetnek a valóstól. A „**összenyomva**” jelölésű képeknél a tartalom a kódból
> számolva magasabb a kijelzőnél — ezeket eszközön kell ellenőrizni, a design pedig **ne támaszkodjon rájuk**,
> inkább oldja meg, hogy minden elférjen.
>
> **Ne tekintsd designnak:** az angol gyakorlatneveket („Bulgarian Split Squat”, seed adat), a demó értékeket
> (128 bpm, 3.42 km…) és a sablonneveket.
>
> **Ami a mobil v2-ből változtatás nélkül jön át (ez a Lifey identitása):**
> - **Dark-first** — az óra kizárólag sötét (AMOLED), így a v2 **sötét** értékei kellenek: a felületi tónuslétra
>   (bg / card / nested / control / raised), a három szövegszint, a **primary csak vezérlőkre** (nem szövegre, nem
>   nagy kitöltésre), és a **metrikaszínek** v2 értékei: kalória, pulzus (a mostani óra-értékek régiek:
>   `#E0915A`, `#D97F7F`), a tinted chip szabálya (16 % háttér + 100 % szöveg), a szemantikus szerepek.
>   Az óra ma a **v1 palettát** használja (`#161611`, `#9DAE6B`…) — ezt kell a v2-re cserélni.
> - **Lekerekítés** a v2 skálából (tag 8 · control 14 · card 22 · hero 30 · pill), a beágyazott elem = szülő − belső
>   padding szabállyal. Ma az óra 8/16/20/24-et használ.
> - **Betű**: a mobil Plus Jakarta Sans; az óra ma a rendszer betűtípusát használja (SF Pro / SF Rounded; Wear:
>   rendszer). **Javasolj és indokolj**: marad a rendszerbetű (Dynamic Type, olvashatóság, akku), vagy bekerül a
>   Plus Jakarta Sans a nagy számokra / címkékre. Bármelyik legyen: tabuláris számjegyek a ketyegő számokon, és a
>   méretek legyenek a platform szerinti **stílusok** (Dynamic Type stílusok / Wear típusskála), ne fix px.
> - **Mélység**: sötétben felületi tónuslétra, nem keretek és nem árnyékok.
> - **Mozgás**: a v2 időtartamai és görbéi (tap, számláló, kitöltés, oldalváltás, ünneplés), reduced-motion esetén
>   kikapcsolva.
> - A v2 **ikonrendszere**: az óra natív ikonokat használ (Apple: SF Symbols, Wear: Material Icons filled) — a
>   canvasokban a pontos nevet jelöld.
>
> **Ami az óránál új vagy más — ezt kérem kitalálni, a v2 nyelvén:**
> - **Két méretcsalád, két forma**: Apple Watch lekerekített négyzet (45 mm: 198×242 pt, 41 mm kompakt: 176×215 pt),
>   Wear OS kerek (227 dp, kompakt < 200 dp). Közös nyelv, de platform-natív elrendezés: ami az egyiken jól áll, a
>   másikon nem feltétlenül (pl. az Apple-on a bal felső vissza-nyíl működik, a Wear kerek kijelzőn a sarokba eső
>   nyíl kilóg a kijelzőből).
> - **Pillantás-szabály**: egy domináns szám képernyőnként, ≥ 48 pt / dp célfelület, magas kontraszt, izzadt kéz.
>   Ma a strength metrika oldalon az idő, a pulzus és a kalória majdnem egyforma súlyú; döntsd el és indokold, mi
>   a hero (idő vs. pulzus vs. aktuális szett) — és legyen ugyanaz a logika erőedzésen és kardión.
> - **Oldalszerkezet**: a mostani 3 oldalas pager (napló · metrikák · vezérlők) és a kardió 2 oldalas pagere
>   maradhat vagy változhat, de a Digital Crown / rotary viselkedést (lapozás, léptető) rögzítsd.
> - **Always-On (csökkentett fényerő) állapot**: ma nincs — tervezd meg az aktív képernyők AOD változatát (fekete
>   háttér, vékony vagy körvonalas számok, másodperc nélkül, visszafogott színek), mindkét platformra.
> - **Wear-specifikus**: Wear Compose Material 3 használatának lehetősége (ma Material 2), a chipek és a kártyák
>   keveredésének feloldása, TimeText / görgetés-jelző, ScalingLazyColumn skálázás, Ongoing Activity és tile
>   (opcionális javaslatként, **külön jelölve**, nem az alapkör része).
> - **Apple-specifikus**: komplikáció / Smart Stack widget (opcionális javaslatként, külön jelölve).
> - **Óra-specifikus komponensek**: fejléc-chip (ikon + címke + standalone jel), metrika-olvasat (ikon + szám),
>   szett-pontsor / előrehaladás, kör-gomb (+1 szett, Módosítás), ghosted (letiltott) állapot, állapot-pirula
>   (naplózva, hiba, nincs kapcsolat), pihenő-visszaszámláló (ma vízszintes sáv; a kerek kijelzőn gyűrű is lehet),
>   „Mehet!” villanás, léptető (−/érték/+), lista-sor (sablon, kardió-típus, gyakorlat), kompakt chip, effort-
>   kiválasztó (1–10), összegző csempe + szinkron-állapot, pad-keret (csapatsport).
>
> **Amit mindenképp javíts (részletesen a PDF-ek „Fontos megfigyelések” oldalain és a képek melletti szövegekben):**
> - Régi paletta és lekerekítés → v2; a primary ne legyen szöveg- és nagyfelület-szín (az idő számán, a „+1 szett”
>   feliraton, a teljes „Mehet!” villanáson ma az).
> - Hierarchia: ma nincs egyetlen domináns szám a strength metrika oldalon; a pulzus (Wear-en) kicsi.
> - A hiányzó pulzus két platformon és két edzéstípuson négyféleképp jelenik meg — legyen egy szabály.
> - Sűrű képernyők: csapatsport pályán/padon, „nincs pulzus” kardió, szüneteltetett metrika, a Wear léptető, a
>   Wear három chipes vezérlők oldal, az önálló összegzés — minden férjen el, és kerüljön a legfontosabb a
>   hajtás fölé (pl. az önálló összegzés szinkron-állapota ma a hajtás alatt van).
> - Apró célfelületek: effort vissza-nyíl, standalone jel (≈ 16 pt, koppintható „szinkronizálj most”), „Kihagyás”.
> - Wear: a kerek kijelzőn kívül eső elemek (vissza-nyíl), a kétféle komponensnyelv, a ScalingLazyColumn halvány
>   szélső elemei, a kardió vezérlők oldal értelmetlen „Gyakorlat” kártyája.
> - Hosszú magyar szövegek: „Engedélyezd az Egészség-hozzáférést”, „Pulzusmérés ki — érzékelők engedélyezése”,
>   „Szinkronizálás a telefonra”, „ismétlés naplózása”, „Vissza a pályára” — csonkolás vagy 3 soros törés nélkül
>   kell elférniük, vagy a törés legyen tudatos.
>
> **Keretek:**
> - **Natívan megépíthető**: SwiftUI (watchOS 10+) és Compose for Wear OS; nincs képként rajzolt UI, nincs egyedi
>   renderelő — gradiens, lekerekített forma, SF Symbols / Material Icons rendben. A méretek a számlap méretéből
>   (arányokból) számolódnak, nem fix pt-ból; mindkét méretosztályra (normál, kompakt) adj értékeket.
> - AMOLED és akku: fekete / közel fekete fill, az élénk zöld akcentus, nem háttér (a teljes képernyős zöld „Mehet!”
>   ma kivétel — indokold, ha marad).
> - Két nyelv (magyar és angol), a magyar hosszabb; WCAG AA kontraszt; Dynamic Type / betűméret-skála.
> - **Funkció ne vesszen el**: minden, ami a PDF-ekben látszik, maradjon elérhető (az elrendezés változhat). A
>   telefon-vezérelt és az önálló (standalone) mód viselkedése, a szinkron-állapotok, a pihenő-rezgés időzítése és a
>   szett-naplózás folyamata (pending → confirmed / failed) nem változik — csak a megjelenésük.
> - Nincs új backend-adat és nincs új adat az óra–telefon protokollban: amit a design mutat, az a mai adatból
>   számolható legyen; ha valami újat igényelne, jelöld külön.
> - A kardió-metrika címkék és a típusnevek a telefonról érkeznek előre lokalizálva — a design ezeket kezelje
>   változó hosszú szövegként.
>
> **Amit kérek, ebben a sorrendben:**
> 1. **A design rendszer óra-kiterjesztése** (a v2 alapján, egy canvason, platformonként vagy közösen jelölt
>    eltérésekkel): tokenek (v2 sötét + metrikaszínek + az óra-specifikus: ghosted, standalone-jel), betűstílusok,
>    forma- és térköz-skála, az óra-komponensek (fenti lista) állapotokkal, mozgás, haptika-megfeleltetés (a
>    rezgések nem változnak, de jelöld, mi mikor szólal meg), Always-On szabályok, méretosztályok.
> 2. **Apple Watch kulcsképernyők** újratervezve, prioritás szerint, 45 mm-en, a legfontosabbaknál 41 mm-en is:
>    1. Metrika oldal (erőedzés, hero-döntéssel)  2. Napló oldal + léptető + naplózási állapotok
>    3. Pihenő + „Mehet!”  4. Vezérlők + effort + lezárás + összegzés  5. Alapképernyő + kiválasztó + gyakorlatválasztó
>    6. Önálló mód (jel, összegzés, szinkron-állapot)  7. Kardió (távolság, gép, csapatsport pályán/padon, nincs pulzus)
>    8. Hiba- és engedély-állapotok  9. Always-On változatok
> 3. **Wear OS kulcsképernyők** ugyanebben a sorrendben, kerek kijelzőn (227 dp és kompakt), a Wear-specifikus
>    eltérésekkel (nincs lezárás/összegzés a telefonos edzésnél; hibaképernyő „már fut egy edzés”; pulzusengedély-chip).
> 4. Minden képernyőhöz egy rövid **előtte–utána indoklás**: melyik PDF-képre (azonosítóval, pl. `AW-15`, `W-14`)
>    válaszol, mi változott és miért, és melyik mobil v2 elemet vitte át vagy terjesztette ki.

---

## 1. Megjegyzések a prompt használatához

- **Sorrend:** ha a Claude Design egyszerre csak részt tud hozni, az óra-design-rendszer (1. pont) menjen
  először, utána az Apple Watch, végül a Wear OS — ugyanez a sorrend kell majd az implementációhoz is (a két platform
  tokenjei ma érték-azonosak, `LifeyColors.swift` ↔ `LifeyColors.kt`, ezt érdemes megtartani).
- **A PDF-ek készítése:** a képek a SwiftUI / Compose forrásból rekonstruáltak (a 45 mm-es Apple Watch 198×242 pt, a
  Wear 227 dp kerek), mert a konténerben nincs szimulátor és emulátor. Szimulátor- / emulátor-képernyőképekre
  cserélni érdemes, ha lesz: különösen az „összenyomva” jelölt képeket (csapatsport, nincs pulzus, szüneteltetés,
  léptető, önálló összegzés), a Wear vissza-nyíl láthatóságát és a ScalingLazyColumn skálázást kell eszközön
  ellenőrizni. A rekonstrukció generátora **nincs a repóban** (a PDF-ekkel együtt csak az eredmény).
- **Az elkészült design után** a következő lépés a mobil 77-es tervéhez hasonló, lépésekre bontott óra-implementációs
  terv (`../watch` vagy `../redesign-watch` alá), a canvasokkal mint értékforrással; a két platformot érdemes
  párhuzamosan, azonos tokenekkel vinni.
