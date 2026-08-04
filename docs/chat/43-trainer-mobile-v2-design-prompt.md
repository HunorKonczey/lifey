# 43 — Edzői funkciók mobilon (v2): design prompt (Claude Designnak)

> **A fájl célja:** önállóan átadható prompt a **teljes edzői mobil felület**
> megtervezéséhez — a ma csak weben létező edzői funkciók telefonra fordításához.
> A §0 blokk másolható be egy az egyben; a frame-ek (A–H) az implementációs
> iterációkkal (T1–T7) egy az egyben megfeleltethetők, hogy a terv szállítható
> darabokban is átadható legyen.
>
> Technikai háttér: [41-trainer-mobile-v2-plan.md](41-trainer-mobile-v2-plan.md).
> Előzmény: [42-chat-design-prompt.md](42-chat-design-prompt.md) (a chat az első edzői
> felület — a nyelvét innen visszük tovább).
> Design-alapok: [design/18-design-system-prompt.md](design/18-design-system-prompt.md),
> [personal_trainer/06-design.md](personal_trainer/06-design.md) (edzői nyelv weben),
> `personal_trainer/design/*.dc.html` (a webes edzői képernyők, amiket fordítunk).

---

## 0. A prompt (ezt add át)

> Te a **Lifey** fitness/táplálkozás-követő app design rendszerén dolgozol. A rendszer
> **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss) akcentszínű**, mindenhol
> **generózus lekerekítéssel** (radius: sm ~8 / md ~16 / lg ~24 / pill), **ikonokkal minden
> menüponton és akción**, minimál szövegű címkékkel; a top/bottom sávok inset margóval
> „lebegnek". A platform **Flutter + Material 3**, a navigáció `go_router`
> `StatefulShellRoute`.
>
> **A feladat: az edzői munkafelület megtervezése telefonra.** Ma az edző egy webes
> admin felületen dolgozik (`/admin`: kliensek, naptár, hozzárendelések, programok,
> meghívók), a mobil appban viszont **csak chat** van neki. Ezt a webes felületet kell
> mobilra fordítani — **nem lekicsinyíteni, hanem újragondolni**: ami weben táblázat,
> rács vagy oldalsó fiók, az telefonon lista, agenda és alsó lap.
>
> **Kiinduló kényszer, amit tarts tiszteletben:** a kliens (nem-edző) app öt alsó
> nav-ága — Kezdőlap · Táplálkozás · Edzés · Testsúly · Statisztika — **érintetlen
> marad**. Az edzői felület egy **második, párhuzamos héj**, nem ennek az átszabása.
>
> ---
>
> **A) EDZŐI HÉJ ÉS NÉZETVÁLTÁS**
>
> *A1 · Az edzői shell.* Saját alsó navigáció **négy ággal**: **Klienseim ·
> Naptár · Kiosztott · Programok**. Ugyanaz a lebegő, scroll-reaktív sáv-nyelv, mint a
> kliens oldalon — de az edzői kontextusnak azonnal felismerhetőnek kell lennie.
> A weben ezt egy állandó **[EDZŐ] chip** oldja meg; tervezd meg ennek a **mobil
> megfelelőjét** (javaslat: a felső sávban a cím mellett kompakt chip, plusz az aktív
> nav-elem `tertiary` akcense a kliens-nézet `primary`-jével szemben — de ha van jobb
> ötleted a szűk helyre, mutasd meg mindkettőt).
> A felső sávban jobbra: **chat ikon olvasatlan-badge-dzsel** (a 42-es promptból) és az
> avatar-menü.
>
> *A2 · Nézetváltó.* Nem „mód", hanem navigáció: az avatar-menüben egy tétel visz át
> („Edzői nézet" ↔ „Saját naplóm"). Csak `ROLE_TRAINER` esetén látszik. Tervezd meg
> a menüt mindkét irányban, és az **átmenetet** is (javaslat: rövid, iránnyal bíró
> mozdulat, hogy érezhető legyen a kontextus-váltás — de ne legyen lassú).
>
> *A3 · Első belépés.* Egyszeri, elvethető magyarázó lap: „Ez az edzői nézeted. A saját
> naplód az avatar-menüből érhető el." Nem többlépéses onboarding, egy lap.
>
> ---
>
> **B) KLIENSEIM (a napi belépő)**
>
> *B1 · Lista.* Kártyás lista (nem táblázat), soronként: **monogram-avatar · név ·
> utolsó aktivitás relatív időben · compliance-jelzők**. A jelzők a meglévő
> státusz-nyelvből: kihagyott edzés, elmaradt testsúlymérés, elmaradt naplózás —
> **ikon + rövid szám**, nem hosszú szöveg. A kártya alján egy nagyon halvány
> súly-sparkline (a webes kliens-kártya mintája).
>
> *B2 · „Figyelmet igényel" szekció.* A lista tetején egy kiemelt blokk azokkal, akiknél
> beavatkozás kell. Tervezd meg: (a) van 1–3 ilyen kliens, (b) nincs egy sem (a blokk
> ilyenkor **eltűnik**, nem üres állapotot mutat).
>
> *B3 · Rendezés és keresés.* Rendezés: legutóbbi aktivitás / legkevésbé aktív / legtöbb
> kihagyás / esedékes mérés. Telefonon ez **ne** legyen legördülő menü a fejlécben —
> javaslat: vízszintesen görgethető chip-sor a lista fölött, aktív chip kitöltve.
> Keresés: koppintásra kinyíló mező, nem állandóan látszó.
>
> *B4 · Üres állapot.* „Még nincs kliensed" + „Meghívó küldése" CTA (a H frame-re visz).
>
> ---
>
> **C) KLIENS-RÉSZLETEZŐ**
>
> *C1 · Fejléc + tabok.* Fejléc: avatar, név, kapcsolat kezdete, jobbra „⋯" menü
> (Üzenet írása → chat szál; Kapcsolat bontása → destruktív, megerősítéssel).
> Alatta **görgethető tab-sor**: Áttekintő · Statisztika · Edzések · Táplálkozás ·
> Lépés · Testsúly · Ütemterv. Hét tab telefonon sok — mutasd meg, hogyan marad
> olvasható (görgethető tab-sor csonkolt címkékkel + ikonnal, vagy két sor; javasolj
> és indokolj).
>
> *C2 · „Csak olvasható" szemantika.* A tisztán adatnéző tabokon (Statisztika, Lépés,
> Testsúly, Táplálkozás) a webes felület egy halvány **„Csak olvasható" badge**-et
> használ, és **egyetlen szerkesztő affordance sincs** — a hiány maga is design-elem.
> Vidd át ezt mobilra.
>
> *C3 · Áttekintő tab.* A legfontosabb metrikák kártyákban (heti edzésszám, súlytrend,
> átlagos napi kalória, lépés-átlag), mindegyik koppintásra a részletes tabra visz.
> Ez a képernyő adja meg a választ arra, hogy „mi van ezzel a klienssel", 3 másodperc alatt.
>
> *C4 · Grafikonok telefonon.* A meglévő `TimeSeriesChart` nyelvét használd
> (nincs új chart-könyvtár). Időszak-váltó chip-sor (nap/hét/hónap), az érték
> koppintásra jelenik meg (nincs hover). Tervezd meg a „kevés adat" esetet is
> (1–2 pont: ne rajzoljunk hazug trendvonalat).
>
> ---
>
> **D) EDZÉS-ELŐZMÉNY ÉS EDZŐI MEGJEGYZÉS (az első írás)**
>
> *D1 · Edzés-lista.* Kártyák: dátum, sablon neve, időtartam, gyakorlatszám, és ha van,
> a kliens RPE-je/jegyzete jelzése. Aki már kapott megjegyzést, ott egy kis
> „megjegyzésed" ikon.
>
> *D2 · Edzés-részletező.* Gyakorlatok, szettek, ismétlések, súlyok — a kliens oldali
> edzés-nézet **újrahasznosított** anatómiájával, hogy ne legyen két nyelv.
>
> *D3 · Megjegyzés-szerkesztő.* Alsó lap: többsoros mező, karakterszámláló, Mentés /
> Törlés. **Nincs optimista UI** (a v1 chat az egyetlen kivétel a termékben): a mentés
> folyamatban / kész / hiba állapot **egyértelműen** jelezve. Mentés után visszajelzés,
> hogy a kliens értesítést kapott — ez fontos, mert más ember telefonja fog csörögni.
>
> *D4 · Átjárás a chatbe.* A megjegyzés mellett „Írok is neki" akció → a chat szál,
> az edzésre hivatkozva. Ez az a pont, ahol az edzői felület és a chat összeér.
>
> ---
>
> **E) KIOSZTOTT TARTALOM**
>
> *E1 · Lista.* A kiosztott sablonok/receptek listája, kliens- és típusszűrővel
> (chip-sor). Soronként: tartalom-ikon (súlyzó/tányér) · név · kinek · mikor ·
> visszavonás akció (destruktív, megerősítéssel).
>
> *E2 · Kiosztás.* Alsó lap: először tartalom (a **saját** sablonok/receptek kereshető
> listájából), majd kliens(ek). **Több kliens is kijelölhető** — tervezd meg a
> többes kijelölés vizuálisát (jelölőnégyzet + kiválasztott-számláló a lap alján).
>
> *E3 · Részleges siker.* Tömeges kiosztásnál előfordul, hogy egy része sikerül.
> Tervezz **eredmény-lapot**: „5-ből 4 kiosztva", alatta a hibás sorok okkal, és egy
> „Újrapróbálás a hibásakra" akció. Ez nem hibaüzenet — ez egy eredmény.
>
> ---
>
> **F) NAPTÁR ÉS ÜTEMEZÉS (itt a legtöbb az újratervezés)**
>
> A weben hónap-rács van; **telefonon a hónap-rács nem működik** (30+ cella, több
> esemény/nap). Ezért:
>
> *F1 · Naptár ág — agenda az alapértelmezett.* Felül kompakt **heti sáv** (7 nap,
> ponttal jelezve, melyiken van esemény; a mai kiemelve, oldalra húzva hetet vált),
> alatta **napokra bontott lista** a kártyákkal. Kártya-anatómia: időpont (ha van —
> hangsúlyos, tabular) · monogram-avatar + kliensnév · sablon-név · státusz-chip
> (közelgő / elvégzett / kihagyott / lemondott — **a meglévő státusz-nyelv, változatlanul**).
> Az időpont nélküli alkalmak a nap végén, halvány „Nap folyamán" elválasztó alatt.
> **Nincs kliensenkénti színkódolás** — a szín a státuszé, a klienst a monogram azonosítja.
>
> *F2 · Hónap-nézet — másodlagos.* Csak fekvő tájolásban vagy tableten; álló telefonon
> egy kompakt „hónap-áttekintő" fér el: napok pont-sűrűséggel, koppintásra agenda.
> Tervezd meg ezt a redukált változatot.
>
> *F3 · Alkalom-részletező.* Koppintásra alsó lap (nem popover — az érintéses felületen
> a lap a natív minta): kliens, sablon, dátum/idő, státusz, az ismétlődés emberi nyelven
> („Minden hétfő és csütörtök · 18:00 · júl. 7. – okt. 6."). Akciók: kliens ütemtervének
> megnyitása; elvégzettnél az edzés megnyitása; közelgőnél lemondás (destruktív,
> megerősítéssel).
>
> *F4 · Ütemezés létrehozása.* Alsó lap / teljes képernyős űrlap: kliens (ha nem
> kontextusból jön) → sablon → dátum → opcionális időpont → ismétlődés (nincs / heti /
> adott napokon) → meddig. Az ismétlődés a legnehezebb rész: tervezd meg a **napválasztó
> chip-sort** (H K Sze Cs P Szo V) és az eredmény emberi nyelvű összefoglalóját az űrlap
> alján („Ez 12 alkalmat hoz létre, aug. 5. – okt. 28.").
>
> *F5 · Kliens-szűrő a naptárban.* Több kliens kijelölése; ha aktív a szűrő, azt a
> fejlécen látni kell (chip a szűrt kliensek számával, egy koppintással törölhető).
>
> ---
>
> **G) PROGRAMOK (többhetes)**
>
> *G1 · Program-lista.* Kártyák: név, hossz (hetek), hány kliensnél aktív.
>
> *G2 · Program-részletező (olvasás).* Hetenként **összecsukható szekciók**, benne
> a napok és a hozzájuk rendelt sablonok. A weben ez egy hét × nap **rács drag&droppal** —
> mobilon ne rácsot tervezz.
>
> *G3 · Hozzárendelés klienshez.* Alsó lap: kliens(ek) + kezdődátum; alatta emberi
> nyelvű összefoglaló („A program aug. 5-én indul és okt. 27-ig tart"). Ez a leggyakoribb
> edzői művelet ebben a blokkban — legyen a legkönnyebben elérhető.
>
> *G4 · Szerkesztés (feltételes).* Rács és szabad drag&drop helyett: hetenkénti lista,
> **hosszan nyomásos sorrendezés**, nap-hozzáadás alsó lapról, hét duplikálása akció.
> ⚠️ Ez a blokk kockázatos: ha a te tervezésed közben kiderül, hogy a szerkesztés
> telefonon nem lesz jó élmény, **mondd ki**, és tervezd meg helyette a tiszta
> alternatívát: olvasás + hozzárendelés mobilon, szerkesztés a weben, egy jól
> megfogalmazott, nem szégyenlős átirányító sávval.
>
> ---
>
> **H) MEGHÍVÓK, BEÁLLÍTÁSOK, ÁLLAPOTOK**
>
> *H1 · Meghívók.* Függő meghívók listája lejárattal (relatív idő: „2 nap múlva jár le"),
> visszavonás akció; „+ Meghívó küldése" → alsó lap e-mail mezővel és rövid magyarázattal
> arról, mit fog látni a kliens.
>
> *H2 · Edzői beállítások.* Az edzői nézet beállításai (edzői preferenciák, heti riport
> megtekintése) — a meglévő beállítás-képernyő nyelvén, külön szekcióban.
>
> *H3 · Offline állapot — elsőrendű design-elem.* **Az edzői nézet online-first**: a
> kliensadat nem tárolódik a telefonon (frissesség és adatvédelem miatt). Ezért az
> offline állapotot nem elrejteni kell, hanem jól megtervezni: teljes képernyős
> változat („Az edzői nézet élő adatot használ — nincs kapcsolat"), újrapróbálás
> gombbal, és egy sávos változat, ha a képernyő egy része már betöltött.
>
> *H4 · Skeleton / üres / hiba* minden felsorolt képernyőhöz, a rendszer meglévő nyelvén.
>
> ---
>
> **Kényszerek**
> - **Ne vezess be új design tokent**, és ne vezess be új chart- vagy naptár-könyvtárat.
>   A meglévő `TimeSeriesChart` és a meglévő státusz-chip nyelv kötelező.
> - Az edzői nézet a kliens-nézet **testvére, nem másik app**: azonos tipográfia,
>   spacing, radius, ikonkészlet, mozgás.
> - Minden szöveg **HU/EN kulcs**; a dátum/idő formátum lokál-érzékeny.
> - **Minden írási művelet más ember adatát érinti** → megerősítés vagy visszavonás
>   jár hozzá, és a művelet kimenetele egyértelműen jelzett. Ez az egész v2 vezérelve.
> - Érintési célpont ≥ 44 pt; a compliance-jelzők és a státusz **ne csak színnel**
>   legyenek kódolva; AA kontraszt sötét témán.
> - Ne tervezd meg: superadmin/user-kezelés, tömeges adatexport, hosszú
>   gyakorlat-leírás szerkesztése — ezek weben maradnak.

---

## 1. Kapcsolódó design-precedensek

| Elem | Precedens |
|---|---|
| Mobil héj, lebegő sávok, scroll-reaktív nav | `design/18-design-system-prompt.md` §1.4–1.5 |
| Kliens-kártya, monogram-avatar, sparkline | `personal_trainer/06-design.md` §3.1–3.2 |
| [EDZŐ] chip, „Csak olvasható" badge, edzői akcens | `personal_trainer/06-design.md` §1 |
| Naptár kártya-anatómia, státusz-chipek, „Nap folyamán" | `personal_trainer/13-edzo-naptar-design-prompt.md` §0/A |
| Ütemező űrlap, ismétlődés-leírás | `personal_trainer/design/Lifey Schedule.dc.html` B frame |
| Program-szerkesztő (web-referencia) | `web/src/features/trainer/components/ProgramGridEditor.tsx` |
| Chat nyelv (badge, szál, alsó lap) | `42-chat-design-prompt.md` |

---

## 2. Döntés-napló (a 41-es tervből, ami a designt köti)

1. **Külön edzői shell**, nem átszabott kliens-shell. Két héj él egymás mellett; a
   kliens öt ága érintetlen. Indok: az edző munkafolyamata más, a `StatefulNavigationShell`
   ágait futásidőben cserélni törékeny, és a kettős szerep miatt egyik tabsor sem elég.
2. **Nézetváltás navigáció, nem mód-kapcsoló** — az avatar-menüből, megjegyzett utolsó
   nézettel.
3. **Online-first edzői adat, semmi lokális cache.** Következmény: az offline állapot
   elsőrendű design-elem (H3), és minden képernyőnek van skeleton/hiba állapota.
4. **Agenda-first naptár**, a hónap-rács másodlagos — az időpont nélküli edzések és a
   telefon-szélesség miatt (a webes döntés 4. pontjának mobil folytatása).
5. **Nincs kliensenkénti színkódolás** sehol — monogram + név azonosít, a szín a státuszé.
6. **A program-szerkesztő feltételes**: prototípus után eldől, hogy teljes mobil
   szerkesztő lesz, vagy olvasás + hozzárendelés és „szerkesztés a weben".
7. **A saját tartalom (sablonok, receptek, gyakorlatok) nem része a v2-nek** — azt az
   edző már ma is szerkeszti a kliens-nézetben, ugyanazokkal a képernyőkkel.

---

## 3. Szállítási sorrend (ha darabokban kéred a designt)

| Frame | Iteráció | Miért ebben a sorrendben |
|---|---|---|
| A + B | T1 | a héj és a belépő nélkül semmi más nem tesztelhető |
| C | T2 | a kliens-részletező adja az edzői „miért" választ |
| D | T3 | az első írás — itt dől el az írási műveletek nyelve az egész v2-re |
| E | T4 | a kiosztás önálló, jól körülhatárolt blokk |
| F | T5 | a legtöbb újratervezés; addigra a nyelv már ül |
| G | T6 | a legkockázatosabb; döntési pont van benne |
| H | T7 | záró elemek + a rendszer-szintű állapotok végigfésülése |
