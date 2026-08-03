# 42 — Edző ↔ kliens chat: design prompt (Claude Designnak)

> **A fájl célja:** önállóan átadható prompt a chat képernyőinek megtervezéséhez —
> **mobil kliens**, **mobil edző** és **web edző** felületre egyszerre.
> A §0 blokk másolható be egy az egyben.
>
> Technikai háttér: [40-trainer-chat-plan.md](40-trainer-chat-plan.md).
> Design-alapok: [design/18-design-system-prompt.md](design/18-design-system-prompt.md)
> (mobil tokenek), [web/03-design-brief.md](web/03-design-brief.md) +
> [web/06-design-system-web.md](web/06-design-system-web.md) (web tokenek),
> [personal_trainer/06-design.md](personal_trainer/06-design.md) (edzői nyelv).
> A fájl végén — a prompton kívül — a funkció **döntés-naplója** áll.

---

## 0. A prompt (ezt add át)

> Te a **Lifey** fitness/táplálkozás-követő app design rendszerén dolgozol. A rendszer
> **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss) akcentszínű**, mindenhol
> **generózus lekerekítéssel** (radius-skála: sm ~8 / md ~16 / lg ~24 / pill), **ikonokkal
> minden menüponton és akción**, minimál szövegű címkékkel. A top/bottom sávok **nem**
> edge-to-edge szélesek: inset margóval „lebegnek", finom elevationnel, a tartalom alattuk
> gördül. Mobilon Flutter + Material 3, weben Next.js + Tailwind/shadcn — **ugyanaz a
> token-készlet**, két renderelés.
>
> **A megtervezendő funkció — chat az edző és a kliense között.** Ma nincs semmilyen
> üzenetküldés a termékben; ez az első. 1:1 beszélgetés, pontosan egy edző–kliens
> kapcsolatra. Szöveges üzenet (max 2000 karakter, sima szöveg). Az edző több klienssel
> chatel, a kliensnek jellemzően egy (ritkán több) edzője van. Ha a kapcsolat megszűnik,
> a szál **archív** lesz: olvasható, de nem írható.
>
> **Fontos működési tény, ami látszik is a designon:** az üzenet **azonnal megjelenik**
> a küldőnél „küldés alatt" állapotban (offline is), és utólag lép át elküldött →
> kézbesítve → olvasva állapotba. A tervnek ezt a négy állapotot vizuálisan hordoznia
> kell, feltűnősködés nélkül.
>
> Tervezd meg az alábbi **négy blokkot**. Az A és B ugyanaz a két képernyő, két
> szerepkörben — **ne tervezz két külön appot**, csak a különbségeket mutasd meg.
>
> ---
>
> **A) MOBIL — kliens nézet**
>
> *A1 · Belépő.* A chat **nem kap saját alsó nav-ikont** (az öt meglévő ág marad
> érintetlenül). Belépő: a dashboard felső sávjában egy **chat ikon olvasatlan-badge-dzsel**
> (pötty ≤9-ig számmal, fölötte „9+"). Tervezd meg a badge-et nyugalmi, 1-jegyű és
> 9+ állapotban is. Másodlagos belépő: az „Edzőim" lista sorában egy „Üzenet" akció.
>
> *A2 · Beszélgetés-lista* (teljes képernyő, vissza a dashboardra).
> Sor-anatómia: **monogram-avatar** (a rendszerben meglévő minta) · név · utolsó üzenet
> egy sorban csonkolva · jobb oldalt relatív idő + olvasatlan-pötty. Az olvasatlan sor
> hangsúlyosabb (erősebb szövegszín + a pötty), **nem** külön háttérszín.
> A kliensnek jellemzően 1–2 sora van — tervezd meg az **egy-elemű lista** esetét is,
> hogy ne érződjön üresnek (javaslat: a sor alatt az edző rövid kontextusa, pl. mióta
> az edződ).
>
> *A3 · Szál* (teljes képernyő). Fejléc: vissza + avatar + név + státusz-alsorral
> („online" / „utoljára aktív …" — **csak ha van rá valós adat**; ha nincs, ne legyen
> hamis jel). Üzenetfolyam alul kezdődik, felfelé görgetve tölt régebbieket.
> **Buborék-anatómia:**
> - saját üzenet: jobbra igazítva, `primary`-container tónus, alul-jobbra sarok
>   kevésbé lekerekített (a „farok" helyett — ne rajzolj klasszikus buborék-farkat);
> - a másik fél üzenete: balra, `surface-container-high` tónus;
> - egymás utáni, azonos feladótól érkező üzenetek **csoportosulnak** (kisebb köz,
>   avatar és idő csak az utolsón);
> - időbélyeg diszkréten, a buborék alján vagy mellette, `labelSmall`;
> - **állapot-ikon csak a saját üzeneteken**, az idő mellett: óra (küldés alatt) →
>   egy pipa (elküldve) → két pipa (kézbesítve) → két **kitöltött/akcens** pipa
>   (olvasva). Sikertelen küldés: `error` színű felkiáltójel + koppintásra
>   „Újraküldés / Törlés" választó.
> - **nap-elválasztó** chip a folyamban („Ma", „Tegnap", „aug. 1.");
> - törölt üzenet helyén dőlt, halvány tombstone: „Az üzenetet törölték".
>
> *A4 · Composer.* Alul rögzített, `lg` radius, inset margóval (a lebegő-sáv elvvel
> összhangban): többsoros, magasodó beviteli mező (max ~5 sor, utána belül gördül),
> jobbra küldés-gomb (ikon, `primary`, letiltott állapot üres mezőnél). Billentyűzet
> nyitásakor a folyam alja marad látható. Az archív szálban a composer helyén egy
> halvány, ikonos sáv: „A kapcsolat lezárult — a beszélgetés csak olvasható."
>
> *A5 · Állapotok.* Skeleton (lista: 3 sor-váz; szál: váltakozó buborék-vázak),
> üres szál („Még nincs üzenet — írj elsőként", nagy ikon + rövid biztató szöveg),
> hiba (a megszokott hibakártya + újrapróbálás), **offline sáv** a fejléc alatt
> („Nincs kapcsolat — az üzeneteid elküldjük, amint újra van"). Az offline állapot
> **nem tiltja le a composert** — ez a design egyik lényegi üzenete.
>
> ---
>
> **B) MOBIL — edző nézet (ugyanaz a két képernyő, három eltéréssel)**
>
> Az edző ugyanazt a listát és szálat látja. **Ne tervezz „edző módot", ne tervezz
> külön alkalmazás-héjat.** Amit meg kell tervezni:
>
> *B1 · Lista fejléc és üres állapot* — „Klienseim" cím, üresen „Még nincs kliensed".
> A lista itt **hosszú** (10–50 sor): tervezd meg a keresés/szűrés sávot a lista
> tetején (koppintásra kinyíló, nem állandóan látszó), és a sorok sűrűbb ritmusát.
>
> *B2 · „Új beszélgetés" akció* — csak edzőnél látszik (FAB vagy fejléc-akció; a
> lebegő alsó sáv nélküli képernyőn a FAB szabad). Megnyit egy **alsó lapot**:
> kereshető kliens-lista azokból, akikkel még nincs szál (avatar + név + e-mail),
> kiválasztás → egyenesen a szálba. Üres állapot: „Minden kliensednek van már szála."
>
> *B3 · Kettős szerep.* Egy edzőnek lehet **saját edzője is**. Ilyenkor egyetlen
> vegyes listát látunk: a saját edzője és az összes kliense egyben. A sorokon egy
> diszkrét, szöveges címke különbözteti meg őket („Edződ" / „Klienced") — **ne
> színkódolással**, és ne két külön szekcióval, ha csak egy „Edződ" sor van.
> Tervezd meg mindkét esetet: (a) tiszta edzői lista, (b) vegyes lista egy edzővel
> a tetején.
>
> ---
>
> **C) WEB — edzői felület (`/chat`)**
>
> A webes edzői kontextus jele az állandó **[EDZŐ] chip** a top barban, az akcensszerep
> `tertiary`, bal oldali sidebar navigál — ez a nyelv már létezik, változtatás nélkül
> veendő át. A chat új menüpont a sidebarban (chat-ikon, olvasatlan-badge-dzsel).
>
> *C1 · Két hasábos elrendezés.* Bal: beszélgetés-lista (fix ~320–360 px, saját
> görgetéssel, kereső a tetején). Jobb: a kiválasztott szál, fejléccel és composerrel.
> Kiválasztás nélkül a jobb hasáb **üres állapota**: „Válassz beszélgetést" nagy ikonnal.
> A buborék-, állapot- és nap-elválasztó nyelv **azonos a mobillal** — a web nem talál
> ki újat, csak nagyobb képernyőre lélegzik (szélesebb maximum-buborék, ~65ch olvasási
> szélesség fölött ne nyúljon).
>
> *C2 · Web-specifikus finomságok.* Enter = küldés, Shift+Enter = új sor (a composer
> alatt halvány súgó-sor). Olvasatlan jelzés a böngészőfül címében (`(3) Lifey`) —
> ezt szövegesen írd le, nem kell rajzolni. Hover-en a sor jobb szélén „⋯" menü
> (némítás, kliens megnyitása). Tablet alatt a két hasáb **egymás után** csúszik
> (lista → szál, vissza-gombbal), azaz a mobil viselkedés.
>
> ---
>
> **D) KÖZÖS RENDSZER-ELEMEK (mindhárom felületre egyszer)**
>
> *D1 · Push-értesítés előnézet.* Zárolt képernyős értesítés mobilon: cím = a feladó
> neve, törzs = az üzenet első ~120 karaktere; több üzenetnél összevonva „3 új üzenet".
> Tervezz egy iOS és egy Android mintát (elég vázlatosan) — a szövegek HU/EN kulcsok.
>
> *D2 · Némítás és archív.* A szál fejléc-menüjében: „Némítás" (időtartam-választó),
> „Kliens megnyitása". A némított szál sorát a listán halvány áthúzott-harang ikon
> jelzi. Az archív szál sorát halványabb tónus + „Lezárt" címke.
>
> *D3 · Gépelés-jelző (későbbi fázis, de tervezd meg).* A szál alján, a composer
> fölött: három animált pont + „{név} gépel…", `labelSmall`, halvány. Sose tolja el
> a folyamot ugrásszerűen.
>
> *D4 · Rendszerüzenet (opcionális elem).* Középre igazított, buborék nélküli,
> halvány sor a folyamban, ikonnal — pl. „Új program lett hozzád rendelve". Tervezd
> meg a mintát, még ha az első kiadásban nem is használjuk.
>
> ---
>
> **Kényszerek**
> - **Ne vezess be új design tokent** — a meglévő palettából, radius- és spacing-skálából
>   építkezz. Ha valami hiányzik, jelezd, ne találj ki újat.
> - Minden szöveg **HU/EN kulcsként** értendő; hardcode-olt string nincs.
> - Az állapotok (küldés alatt / elküldve / kézbesítve / olvasva / hiba) **ne csak
>   színnel** legyenek kódolva — ikon + forma is hordozza; AA kontraszt a sötét témán.
> - Az üzenet-buborékban a szöveg **kijelölhető/másolható** kell legyen; a hosszan
>   nyomás menüje (Másolás / Törlés / Újraküldés) tervezendő.
> - Képernyőolvasóra: a buborék bejelentendő tartalma „{feladó}, {idő}: {szöveg},
>   {állapot}" — a vizuális pipákhoz szöveges megfelelő tartozik.
> - Ne tervezz: hangüzenetet, videóhívást, reakciókat, csoportos szálat, üzenet-
>   szerkesztést, végponti titkosítás-jelzést. Kép-csatolmány **csak** ha marad idő,
>   külön, jelölten (későbbi fázis).
> - Minden képernyőhöz kötelező a **skeleton / üres / hiba / offline** állapot.

---

## 1. Kapcsolódó design-precedensek (a prompt kontextusa)

| Elem | Precedens |
|---|---|
| Mobil lebegő top/bottom sáv, radius-skála | `design/18-design-system-prompt.md` §1.2–1.5 |
| Monogram-avatar, kliens-sor anatómia | `personal_trainer/06-design.md` §3.1 |
| Web admin shell, [EDZŐ] chip, sidebar-pill | `personal_trainer/06-design.md` §1–2 |
| Skeleton / üres / hiba nyelv (web) | `web/03-design-brief.md` §2.9 |
| Alsó lap (bottom sheet) minta mobilon | meglévő gyors-naplózó lapok, `27-faster-meal-logging-plan.md` |
| Megerősítő dialog, destruktív tónus | `personal_trainer/06-design.md` §3.6 |

---

## 2. Döntés-napló (a 40-es tervből, ami a designt köti)

1. **Nincs saját alsó nav-ág a chatnek.** Az öt meglévő ág a kliens munkafolyamata; a
   chat shellen kívüli útvonal (`/chat`), belépő a dashboard fejléc-ikonja. Indok: a
   hatodik ikon az `AdaptiveBottomNav` és a FAB elrendezésének újratervezését kényszerítené.
2. **Nincs „edző mód".** A beszélgetés-lista végpont szerepkörtől függetlenül a saját
   szálakat adja vissza, ezért a képernyők ~95%-a közös; a szerepkör három ponton látszik
   (fejléc, „Új beszélgetés" gomb, üres állapot szövege).
3. **Kettős szerep egy listában**, `peer.role` szöveges címkével — nem külön nézet, nem
   mód-váltó, nem színkód.
4. **Optimista küldés.** Az üzenet offline is azonnal megjelenik `pending` állapotban —
   ezért kell négy állapot-ikon. A chat az egyetlen felület a termékben, ahol optimista
   UI-t használunk.
5. **A push akkor megy ki, ha a címzett nem látta** (nincs élő kapcsolata, vagy más
   szálat néz, vagy háttérben van); 60 mp-en belül összevonva. A designnak ezért kell
   „3 új üzenet" változatú értesítés-előnézet.
6. **Archív szál olvasható marad**, a composer helyén magyarázó sávval — a kapcsolat
   megszűnése nem törli az előzményt.
7. **Web push nincs** az első kiadásban; a webes jelzés a sidebar-badge és a fül-cím.

---

## 3. Ami a designból kimarad (és miért)

| Kimarad | Ok |
|---|---|
| Hangüzenet, hívás | nincs backend, nincs termék-igény |
| Reakciók, válasz-idézés | 1:1 szálban kis érték, sok felület |
| Üzenet-szerkesztés | törlés (tombstone) van helyette — egyszerűbb és őszintébb |
| Csoportos szál | a domain 1:1 (egy edző–kliens kapcsolat = egy szál) |
| Kliensenkénti színkódolás a listán | 10+ kliensnél szín-káosz; monogram + név azonosít (a naptárnál is ez a döntés született) |
