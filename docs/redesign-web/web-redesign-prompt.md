# Web redesign — prompt Claude Designnak

> **A fájl célja:** önállóan átadható prompt a Lifey **webes felületének** (Next.js, `../../web`) újratervezéséhez,
> a mobilapp már elkészült redesignjának (Design System v2) stílusában.
> A §0 blokkot egy az egyben be lehet másolni. Mellé ezeket kell csatolni:
> - `lifey-web-jelenlegi-allapot.pdf` — 309 oldal, 17,8 MB (a Claude Design 20 MB-os limitje alatt): bevezető,
>   oldaltérkép, token-összehasonlítás, „Fontos megfigyelések”, tartalomjegyzék, majd ≈ 215 képernyőkép magyarázattal —
>   a kliens app minden oldala és dialógusa világos és sötét témában, mobil/tablet szélességen és angolul; az edzői
>   munkafelület (világos, sötét, mobil); edzői jelentkezés; superadmin; kontextusként a marketing oldalak;
> - a mobil v2 design rendszer: `docs/redesign/Lifey Design System.dc.html` (ha a Claude Design projekt, amelyben a mobil
>   redesign készült, elérhető, ott folytasd — akkor a design system és a hat képernyő-canvas már bent van).
>
> Előzmények: [docs/design/21-design-modernization-prompt.md](../design/21-design-modernization-prompt.md) (a mobil
> redesign promptja), [77-mobile-redesign-plan.md](../redesign/77-mobile-redesign-plan.md) (a mobil v2 döntései, D-R0.x),
> [docs/web/03-design-brief.md](../web/03-design-brief.md) és [06-design-system-web.md](../web/06-design-system-web.md)
> (a mostani web design első briefje). A web tokenjei a kódban: `../../web/src/app/globals.css`.

---

## 0. A prompt (ezt add át)

> A **Lifey**-n dolgozol. Ez egy fitness- és táplálkozáskövető rendszer: offline-first Flutter mobilapp a
> klienseknek, és egy **Next.js webapp**, amelyben (1) a kliensek ugyanazt használhatják böngészőből, (2) a
> **személyi edzők** egy teljes munkafelületen kezelik a klienseiket, (3) egy superadmin kezeli a szerepköröket.
>
> A mobilapp redesignja **elkészült**: ez a **Lifey Design System v2** (a csatolt / ebben a projektben lévő
> `Lifey Design System.dc.html` és a hat képernyő-canvas: Dashboard, Nutrition, Workouts, Weight + Stats,
> Onboarding + Chat + Settings, Trainer). **A feladat: a webet ugyanebbe a design rendszerbe hozni.** Ne egy új
> stílust találj ki — a v2 tokenjeit, tipográfiáját, komponenseit és mozgáselveit vidd át, és ahol a web mást
> igényel (széles képernyő, egér/billentyűzet, sűrű adat, táblázatok, többpaneles nézetek), ott **terjeszd ki**
> a rendszert, a v2 szellemében.
>
> **A csatolt PDF a web jelenlegi állapota**, ≈ 215 képernyőképpel, valódi demo adatokkal. Minden kép fölött
> azonosító (pl. `client-004`), szekció, URL és viewport; minden kép mellett magyarázat: mit látunk, mik a
> funkciók, mi a probléma, mit érdemes megtartani. A PDF elején: a webapp térképe (három „héj”: kliens,
> edző, superadmin), a mostani web tokenek és a mobil v2 tokenek összehasonlító táblázata, és egy „Fontos
> megfigyelések” lista. **Ezeket olvasd el először.** A marketing oldalak (a PDF vége) már egy frissebb,
> külön designt kaptak — azokat nem kell újratervezni, de a bejelentkezett felület illeszkedjen hozzájuk.
>
> **Ne tekintsd designnak** (a PDF bevezetője is felsorolja): a duplikált sablonokat/gyakorlatokat (az edzői
> kiosztás másolatai a demóban), az angol gyakorlatneveket (seed adat), a kliensnevek végén lévő számokat
> („Kata Nagy 09271425” — demo e-mail), az `e2e-…@example.com` fiókokat, és a „Push nap · 0 perc” edzést. Az
> ékezetes nevek elrontása („Ãšj FelhasznÃ¡lÃ³”) egy kódhiba, külön javítjuk.
>
> **Ami a mobil v2-ből változtatás nélkül jön át (ez a Lifey identitása):**
> - **Dark-first**, meleg, földszínű, olívás karakter; a világos téma egyenrangú, saját (nem invertált) értékekkel.
> - A v2 **színtokenjei** (bg / card / nested / control / raised / float / scrim, három szövegszint, primary
>   csak vezérlőkre) és a **metrikaszínek** mindkét témára: kalória, fehérje, szénhidrát, zsír, víz, lépés, súly,
>   pulzus — a fehérje **nem** azonos a primary olívával. A tinted chip szabálya (sötét: 16 % háttér + 100 % szöveg,
>   világos: 12 % háttér + sötét tónusú metrikaszín) és a szemantikus szerepek (javulás, rekord, csökkenés, növekedés).
> - Az edzői szerep színe a **clay (agyag)**, nem egy második zöld.
> - **Plus Jakarta Sans** (400–800), tabuláris számjegyek, a v2 típusskálája (display / headline / title / body /
>   label); a mértékegység a szám mellett kisebben, szöveg-2 színnel; CAPS csak szekciócímkén.
> - **Lekerekítés**: tag 8 · control 14 · card 22 · hero 30 · pill; beágyazott elem = szülő − belső padding.
> - **Mélység**: sötétben felületi tónuslétra, világosban árnyék — nem keretek.
> - **Mozgás**: a v2 időtartamai és görbéi (tap, számláló, gyűrű/sáv kitöltés, oldalváltás, sheet, ünneplés),
>   reduced-motion esetén kikapcsolva.
> - A v2 **komponensei**: hero kártya, metrika-csempe, gyűrű, lista-sor, tinted chip, gomb, sheet, fejléc, üres és
>   hibaállapot, diagramok (3 feliratos Y tengely, szaggatott célvonal, kiemelt „ma”, halvány rács, 7 napos átlag,
>   jelmagyarázat), PR 🏆 és ↑ jelölés, pihenőidő, ünneplés.
>
> **Ami a webnek új vagy más — ezt kérem kitalálni, a v2 nyelvén:**
> - **Rács és töréspontok**: asztali 1440 és 1280, tablet 1024, mobil 390. Maximális tartalomszélesség, oszloprács,
>   margók. Ma az asztali szélesség kihasználatlan (nagy üres területek, keskeny panelek középen) — a redesign
>   használja ki: több oszlop, oldalpanelek, részletek egymás mellett.
> - **Navigációs héj**: a kliens és az edző oldalsávja egy család legyen (a kliensé: Áttekintő, Táplálkozás, Edzések,
>   Testsúly, Víz, Lépések, Statisztika + Beállítások; az edzőé: Klienseim, Naptár, Chat, Meghívók, Számlázás,
>   Edzésterveim, Programok, Ételeim & receptjeim, Kiosztott tervek + Saját nézet), összecsukható állapottal, és a
>   **superadmin** se lógjon ki (ma felső sávos, eltérő héj). A felső sáv: oldalcím + a **globális dátumléptető**
>   (Előző nap · Ma · Következő nap — ezt tartsd meg) + téma. Mobil szélességen a mobilapp alsó navigációja vagy egy
>   annak megfelelő minta.
> - **Web-specifikus komponensek**: adattáblázat (rendezés, sűrűség, soron belüli műveletek „⋯” menüben), kétpaneles
>   lista + részlet, modal és jobb oldali drawer (a mobil sheet webes párja), toast visszavonással, popover/menü,
>   hover-, fókusz- és billentyűzet-állapotok, tooltip, szegmentált vezérlő, dátum- és időválasztó, űrlapmezők a
>   hiba-állapottal együtt.
> - **Diagramok Rechartsszal** — a v2 diagram-szabályai szerint (lásd a PDF „Diagramok” megfigyeléseit: ma le vannak
>   vágva a tengelyfeliratok, a monotone görbe túllendül, az adat nélküli napok 0-ként rajzolódnak, nincs célvonal).
>
> **Amit mindenképp javíts (részletesen a PDF „Fontos megfigyelések” oldalain és a képek melletti szövegekben):**
> - Lapos, egyforma kártyák, gyenge hierarchia; a fő számok (kalória, súly) kapjanak hero kezelést.
> - Reszponzív hibák: 390 px-en a Táplálkozás és a Beállítások kétoszlopos elrendezése nem törik meg (olvashatatlan),
>   a fülsorok kilógnak, az edzői kliens-részletek fejléce levágódik.
> - Diagramok: tengelyek, célvonal, átlag, üres napok kezelése, a mai részleges nap, lokalizált dátumok.
> - Szám- és dátumformázás: magyar felületen „69,6 kg”, „1,6 / 2,5 L”, „szept. 26.”; nincs nyers tizedes („166.68 g”)
>   vagy nyers kulcs (`workouts.activityTypes.CYCLING`, `ROLE_USER`).
> - Hiányzó megerősítések és visszavonás: étkezés törlése, kijelentkezés (a mobil v2-ben: őszinte kijelentkezés a
>   Beállítások alján, megerősítéssel).
> - Az élő edzésnapló a weben szegényes: nincs időmérő, pihenőidő-számláló, PR-jelölés, és a befejezés nem ünnepel;
>   a lezárt edzés ugyanabban a szerkeszthető nézetben nyílik — kell egy olvasásra optimalizált összefoglaló.
> - Az edzői főoldal kliens-kártyái szinte üresek, a figyelmet igénylő kliens (pl. 6 napja inaktív) nincs kiemelve,
>   és egy felugró „Klienseid” modal eltakarja az oldalt.
> - Üres állapotok: cselekvésre hívjanak (mit tegyen a felhasználó), ne csupa 0-t mutassanak.
>
> **Keretek:**
> - Next.js 16 (App Router) + Tailwind CSS v4 CSS-változó tokenekkel + saját komponensek (nincs komponens-könyvtár),
>   Recharts diagramok, Material Symbols Rounded ikonok, Plus Jakarta Sans. Új, nehéz függőség csak jó indokkal.
> - Két téma (sötét és világos), két nyelv (magyar és angol — a magyar szövegek hosszabbak, csonkolás nélkül kell
>   elférniük), WCAG AA kontraszt, látható fókusz, teljes billentyűzetes kezelhetőség, 44 px-es érintési célok mobilon.
> - Funkció ne vesszen el: minden, ami a PDF-ben látszik, maradjon elérhető (elrendezése változhat).
> - Nincs új backend-adat: amit a design mutat, az a mai API-ból számolható legyen; ha valami új adatot igényelne,
>   jelöld külön.
>
> **Amit kérek, ebben a sorrendben:**
> 1. **A design rendszer webes kiterjesztése** (a v2 alapján, egy canvason): rács és töréspontok, a három héj
>    (kliens, edző, superadmin) egy családban, felső sáv, oldalsáv (nyitott / összecsukott / mobil), webes
>    komponensek (táblázat, drawer, modal, toast, menü, űrlapmezők állapotokkal, dátumválasztó), Recharts diagram-
>    stílus, üres / hiba / betöltés állapotok, hover/fókusz szabályok. Sötét és világos, magyar és angol példákkal.
> 2. **Kulcsképernyők újratervezve**, prioritás szerint, asztali (1440) nézetben, a legfontosabbaknál tablet és
>    mobil változattal is:
>    1. Kliens Áttekintő (dashboard)
>    2. Táplálkozás (étkezésnapló + étel-hozzáadás, Ételek táblázat, Receptek)
>    3. Edzések (napló, lezárt erőedzés és cardio összefoglaló, élő edzésnapló + befejezés/ünneplés, sablonok)
>    4. Testsúly, Víz, Lépések
>    5. Statisztika
>    6. Beállítások, belépés/regisztráció, onboarding
>    7. Edzői Klienseim + Kliens részletei (mind a hat fül)
>    8. Edzői Naptár, Program-szerkesztő, Chat
>    9. A többi edzői oldal (sablonok, receptek, kiosztott tervek, meghívók, számlázás, jelentkezés) és a Superadmin
> 3. Minden képernyőhöz egy rövid **előtte–utána indoklás**: melyik PDF-képre (azonosítóval) válaszol, mi változott és
>    miért, és melyik mobil v2 elemet vitte át vagy terjesztette ki.

---

## 1. Megjegyzések a prompt használatához

- **Sorrend:** ha a Claude Design egyszerre csak részt tud hozni, a design rendszer webes kiterjesztése (1. pont)
  menjen először, utána a kliens képernyők, végül az edzői felület — ugyanez a sorrend kell majd az implementációhoz is.
- **A képek készítése** (ha frissíteni kell): helyi backend (`:8080`), chat service (`:8081`, a webet
  `NEXT_PUBLIC_CHAT_BASE_URL=http://localhost:8081/api/v1`-lel kell indítani), Next.js dev (`:3000`), demo adatok
  seed scripttel, Playwright capture script. A teljes oldalas képnél a viewportot előbb az oldal magasságára kell
  állítani és kivárni a Recharts animációt, különben a vonalak hiányoznak a grafikonokról.
- **Az elkészült design után** a következő lépés a mobil 77-es tervéhez hasonló, lépésekre bontott webes
  implementációs terv (`../redesign` alá), a canvasokkal mint értékforrással.
