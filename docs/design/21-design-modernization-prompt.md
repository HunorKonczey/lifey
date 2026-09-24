# 21 — Design-modernizáció: prompt Claude Designnak

> **A fájl célja:** önállóan átadható prompt a Lifey mobilapp **vizuális modernizálásához**.
> A §0 blokkot egy az egyben be lehet másolni. Mellé a `lifey-design-screens-part1.zip` és
> `-part2.zip` csomagot kell csatolni. Ketté vannak bontva, mert a feltöltési limit 20 MB.
> Együtt 135 képernyőképet tartalmaznak a mostani állapotról, 11 mappában. Mindkettőben
> benne van a `README.md`, ami leírja a funkciókat és a megfigyeléseket.
>
> Előzmények: [18-design-system-prompt.md](18-design-system-prompt.md) (az első redesign
> promptja, ebből lett a mostani rendszer), [20-design-implementation-tasks.md](20-design-implementation-tasks.md).
> A tokenek a kódban: `mobile/lib/core/theme/app_theme.dart`, `app_tokens.dart`.

---

## 0. A prompt (ezt add át)

> A **Lifey**-n dolgozol. Ez egy offline-first fitness- és táplálkozáskövető mobilapp
> (Flutter, Material 3). A csatolt két zip együtt **135 képernyőképet** tartalmaz a jelenlegi
> állapotról, mappákba rendezve. A part1-ben van az auth és onboarding, a dashboard, az
> étrend, az edzések és a súly. A part2-ben a statisztika, a chat, a beállítások, a világos
> téma, a magyar nyelv és az edzői nézet. Minden mappában van egy
> `_overview.jpg` áttekintő kép. A `README.md` képernyőnként leírja a funkciókat, a mostani
> design tokeneket és egy listát a hibákról és következetlenségekről.
>
> **A cél: modernizáld a designt, legyen szebb.** Az app ma funkcionálisan gazdag, de
> vizuálisan kicsit lapos és zsúfolt: sok egyforma sötét kártya, gyenge hierarchia,
> apró betűk, alig van „wow” pillanat. Azt szeretném, hogy prémiumabb, frissebb és
> letisztultabb legyen, egy 2026-os, élvonalbeli egészség- és fitneszapp szintjén.
> Legyen benne több levegő, markánsabb tipográfiai hierarchia és átgondoltabb mélység
> (rétegek, finom árnyékok, felületi tónusok). A fő számok és a haladás legyenek
> látványosak. Legyenek jól megválasztott, visszafogott animációk. Bátran újragondolhatod
> a kártyák, listák, diagramok és a navigáció formáját. Nem pixelre kell átrajzolni azt,
> ami most van.
>
> **Fontos a betűtípusról: ne kérj új képernyőképeket.** A képeken **Roboto** látszik, de
> ez egy azóta javított hiba mellékterméke volt: a fontfájlok hibásan voltak a repóban.
> Az app valódi betűtípusa a **Plus Jakarta Sans**, amelyből a 400 / 500 / 600 / 700 / 800
> súly van beépítve. **Minden tervet Plus Jakarta Sansszal készíts**, és a képeket úgy
> értelmezd, mintha azzal lennének kiszedve. Ez a font szélesebb, geometrikusabb és
> karakteresebb, mint a Roboto, így a tipográfiai skálát is erre hangold. Nagy, erős
> számjegyek kellenek a metrikákhoz, tabuláris számokkal. Új betűtípust csak jó indokkal
> javasolj.
>
> **A képeken van még két másik műtermék, ezeket ne tekintsd designnak:** a dupla
> gyakorlatok és a „tyui” sablon egy szintén javított adathiba maradványai. A
> státuszsorban látható ⚠ ikon pedig az emulátortól jön.
>
> **Amit tarts meg, mert ez a Lifey identitása:**
> - A **dark-first** megközelítést és a meleg, földszínű, olívás-mohazöld karaktert. A
>   palettát modernizálhatod és finomíthatod, de ne legyen belőle generikus kék–lila
>   fitneszapp. Világos témát is kérek, egyenrangú minőségben.
> - A **metrikánkénti színkódolást**: kalória, fehérje, szénhidrát, zsír, víz, lépés,
>   súly, pulzus. Ez az app egyik erőssége, legyen még következetesebb.
> - A **funkciókat és a navigációs struktúrát**: 5 alsó fül (Áttekintés, Étrend, Edzések,
>   Súly, Statisztika), és egy külön edzői héj a saját 4 fülével. Az elrendezést
>   átalakíthatod, de funkció ne vesszen el.
> - Ami jól működik és érdemes megtartani vagy továbbfejleszteni: az edzésnaplóban a PR 🏆
>   és ↑ jelölések, a pihenőidő-számláló, a „Slide to finish”, a heti összefoglaló és a
>   lebegő alsó navigáció.
>
> **Amit mindenképp javíts (részletesen a README „Fontos megfigyelések” részében):**
> - A görgetett tartalom átcsúszik a státuszsor alá, takarás nélkül.
> - A chat és néhány másodlagos képernyő eltérő, sima AppBart használ. Legyen egységes
>   fejléc-rendszer.
> - Az edzői nézet akcentszíne elüt a kliens olívazöldjétől. Legyen egy család.
> - A diagramokon nincs tengely és értékcímke, és a statisztikában értelmetlen metrika is
>   megjelenik (a súly „Total” értéke).
> - Számformázás és csonkolás: „17518.6 kcal”, „11,414 k…”, „1 exercises”.
> - Alacsony kontrasztú lábjegyzetek és címkék. A tinted chipek szövegkontrasztja nem
>   éri el a WCAG AA szintet.
> - A magyar szövegek hosszabbak: a layout bírja el őket csonkolás nélkül (lásd a
>   `10_hungarian_locale` mappát).
>
> **Keretek:**
> - Flutter + Material 3 alatt megépíthető legyen, nehéz új függőség nélkül. A diagramok
>   saját, egyedi rajzolású komponensek, nem külső chart-könyvtárból jönnek.
> - Telefon: kb. 411 × 923 dp. Az edzői nézetnek tabletes elrendezése is van.
> - Két nyelv van (angol és magyar), és mindkét téma (sötét és világos).
> - Hozzáférhetőség: WCAG AA kontraszt, legalább 48 dp érintési felületek, a dinamikus
>   betűméret ne törje szét a layoutot.
>
> **Amit kérek, ebben a sorrendben:**
> 1. **Designrendszer:**
>    - színtokenek sötét és világos témára, a metrikaszínekkel együtt;
>    - tipográfiai skála Plus Jakarta Sansszal;
>    - térköz-, lekerekítés- és elevációs skála;
>    - mozgás- és animációs elvek;
>    - alapkomponensek: kártya, metrikacsempe, lista-sor, chip, gomb, bottom sheet,
>      fejléc, alsó navigáció, diagramok, üres és hibaállapotok.
> 2. **Kulcsképernyők újratervezve**, prioritás szerint:
>    1. Dashboard
>    2. Étrend (étkezések, étkezés-szerkesztő, makrók, receptek)
>    3. Edzések (lista, élő erőedzés-napló, élő cardio és a cardio részletei)
>    4. Súly
>    5. Statisztika
>    6. Onboarding és belépés
>    7. Chat
>    8. Beállítások
>    9. Edzői nézet
> 3. Minden képernyőhöz egy rövid **előtte–utána indoklás**: mi változott és miért.
