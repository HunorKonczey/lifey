# 13 — Edző-naptár: design prompt (Claude Designnak)

> **A fájl célja:** önállóan átadható prompt a Claude Designnak az edző-naptár
> képernyőinek megtervezéséhez. A §0 blokk másolható be egy az egyben.
> A technikai háttér: `12-edzo-naptar-terv.md`; a design-alapok:
> `docs/design/18-design-system-prompt.md` (tokenek) és `06-design.md` (admin nyelv);
> a legközelebbi rokon design: `design/Lifey Schedule.dc.html` (ütemezett edzések).
> A fájl legvégén — a prompton kívül — a funkció **döntés-naplója** áll.

---

## 0. A prompt (ezt add át)

> Te a **Lifey** fitness/táplálkozás-követő app design rendszerén dolgozol. A rendszer
> **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss) akcentszínű**, mindenhol
> **generózus lekerekítéssel** (radius-skála: sm ~8 / md ~16 / lg ~24 / pill), **ikonokkal
> minden menüponton és akción**, minimál szövegű címkékkel. A top/bottom sávok **nem**
> edge-to-edge szélesek: inset margóval "lebegnek", finom elevationnel. Most a **webes
> edző-admin** felületen dolgozol (Next.js, `/admin` útvonalak, a személyi edzőnek):
> itt az akcensszerep a `tertiary` (a saját nézet `primary`-jával szemben), bal oldali
> sidebar navigál (ikon + rövid címke, aktív elem `tertiary` kitöltésű pill), a
> kontextust állandó **[EDZŐ] chip** jelzi. Minden képernyőhöz kötelező a betöltés-
> (skeleton), üres- és hibaállapot, HU/EN lokalizációval.
>
> **Meglévő kontextus:** az edző a kliens-részletek "Ütemterv" tabján egyszeri vagy
> ismétlődő edzéseket ütemez a klienseinek (legfeljebb 3 hónapra előre, opcionális
> napon belüli időponttal, pl. 18:00 — az edzések egy részének **nincs** időpontja,
> csak napja). Minden előfordulásnak négy állapota lehet: **közelgő** (tertiary chip),
> **elvégzett** (pipa), **kihagyott** (halvány error chip), **lemondott** (áthúzott,
> halvány) — ez a státusz-nyelv már létezik, változtatás nélkül veendő át.
>
> **A megtervezendő funkció — Edző-naptár:** új menüpont a bal oldali sidebarban
> („Naptár", naptár-ikon, közvetlenül a „Klienseim" alatt), amely az edző **összes
> kliensének minden ütemezett edzését** mutatja egyetlen naptárban — előre és
> visszamenőleg is. Ez az edző napi munkaeszköze: reggel ránéz, látja, kinek mi a
> dolga ma és a héten. Elsősorban áttekintő nézet, de két akció él benne: közelgő
> alkalom lemondása, és új ütemezés indítása a naptárból (a meglévő ütemező drawer
> nyílik, a kattintott nap előtöltve).
>
> Tervezd meg az alábbi **négy felület-elemet**, a fenti design nyelven:
>
> **A) Hét nézet (alapértelmezett)** (`/admin/calendar`)
> - Fejléc: „Ma" gomb + ‹ › lapozás + időszak-címke („júl. 7–13.") + **Hét/Hónap**
>   szegmentált váltó + kliens-szűrő (multi-select, avatar + név) + „Lemondottak
>   mutatása" kapcsoló (alapból ki).
> - 7 napi oszlop (hétfő kezdéssel), oszloponként a nap session-kártyái **idő szerint
>   rendezve**; az időpont nélküliek a nap végén, halvány „Nap folyamán" elválasztó
>   alatt. **Fontos: NEM óra-rács** — az edzések egy részének nincs időpontja, ezért
>   kártya-oszlopokban gondolkodj, ne idővonalas (Google Calendar-szerű) órasávokban.
> - Kártya-anatómia: időpont (ha van — hangsúlyos, tabular) · **kliens-monogram-avatar
>   + kliensnév** · sablon-név (csonkolva) · státusz (a meglévő chip-nyelv). A kliens
>   azonosítása monogram + név — **nincs kliensenkénti színkódolás**, a szín a
>   státuszé.
> - A mai nap oszlopa kiemelt (`tertiary` keret vagy container-tónus); múltbeli
>   napokon elvégzett/kihagyott kártyák látszanak (compliance-összkép).
> - Napi oszlop fejlécén hover-akció: „+" → ütemező drawer, a nap kezdőnapként
>   előtöltve (múltbeli napon nincs „+").
>
> **B) Hónap nézet**
> - Klasszikus hónap-rács; napcellánként legfeljebb 3 kompakt chip (időpont +
>   monogram + sablon-név csonkolva) + „+N" jelzés, ha több van; a napra kattintás
>   a hét nézetre vált az adott héthez. Mai nap cellája kiemelt; szomszéd hónapok
>   napjai halványak.
> - A fejléc azonos az A-val (a címke itt „2026. július").
>
> **C) Session-peek (popover)**
> - Kártyára/chipre kattintva horgonyzott popover (nem modal): kliens (avatar + név +
>   e-mail), sablon-név, dátum + időpont, státusz-chip, a sorozat ismétlődés-leírása
>   emberi nyelven („Minden hétfő és csütörtök · 18:00 · júl. 7. – okt. 6.").
> - Akciók: **„Kliens ütemterve"** (link a kliens-részletek Ütemterv tabjára);
>   elvégzettnél **„Edzés megnyitása"**; közelgőnél **„Alkalom lemondása"**
>   (destruktív tónus, confirm dialoggal — a meglévő minta).
>
> **D) Állapotok + keskeny nézet**
> - Betöltés: naptár-rács skeleton (oszlop/cella-vázak, kártya-placeholderek).
> - Üres időszak: nagy naptár-ikon + „Nincs ütemezett edzés ebben az időszakban" +
>   „+ Edzés ütemezése" CTA. Hiba: a megszokott hibakártya + újrapróbálás.
> - Tablet alatt a hét nézet **agenda-listává** esik össze: napok egymás alatt, napi
>   fejléccel, azonos kártya-anatómiával; a hónap nézet cellái chipek helyett
>   pont-jelzőkkel, nap-kattintásra agenda.
>
> Kényszerek: ne vezess be új design tokent — a meglévő palettából és radius/spacing
> skálából építkezz; a státusz-nyelv (chip-színek, ikonok) azonos az Ütemterv tabéval;
> minden szöveg HU/EN kulcsként értendő; a naptár billentyűzettel bejárható (nap- és
> kártya-fókusz, nyíl-navigáció), a státusz és a mai-nap-kiemelés ne csak színnel
> legyen kódolva (AA kontraszt a sötét témán); a popover Esc-re és kívülre
> kattintásra zárul, fókusz-csapdával.

---

## 1. Kapcsolódó design-precedensek (a prompt kontextusa)

| Elem | Precedens |
|---|---|
| Státusz-chipek, sor-anatómia | `design/Lifey Schedule.dc.html` A frame — Ütemterv idővonal |
| Ütemező drawer (a „+" célja) | `design/Lifey Schedule.dc.html` B frame |
| Skeleton / üres / hiba nyelv | `design/Lifey Schedule.dc.html` E frame |
| Sidebar, aktív menüpont-pill | `06-design.md` §2 — admin shell |
| Monogram-avatar | `06-design.md` §3.1 — kliens-lista sorok |
| Confirm dialog | `06-design.md` §3.6 — megerősítő dialogok |

---

## 2. Eldöntött kérdések (döntés-napló, mind 2026-07-08)

1. ~~Kliensenkénti nézet vagy összesített naptár?~~ → **Összesített**: egyetlen naptár az összes aktív kliens előfordulásaival, kliens-szűrővel. A kliensenkénti mélynézet továbbra is az Ütemterv tab.
2. ~~Hol a menüpont?~~ → **Sidebar 2. pozíció**, a „Klienseim" után (`/admin/calendar`, `calendar_month` ikon) — napi munkaeszköz, nem aloldal.
3. ~~Backend: aggregált végpont vagy N kliensenkénti hívás?~~ → **Új aggregált végpont** (`GET /trainer/scheduled-sessions?from&to`, + `clientId`/`clientEmail` a válaszban, 62 napos intervallum-guard). Az N-hívás elvetve (lassú, zajos, inkonzisztens pillanatkép).
4. ~~Óra-rács vagy kártya-oszlop?~~ → **Kártya-oszlop**: az időpont nélküli edzések miatt az óra-rács szétesne; időpont szerint rendezés, időpont nélküliek a nap végén („Nap folyamán").
5. ~~Kliensenkénti színkódolás?~~ → **Nincs**: 10+ kliensnél szín-káosz és akadálymentességi gond; a kliens monogram-avatarral + névvel azonosított, **a szín a státusz-nyelvé marad** (közös modulba emelve az Ütemterv tabbal).
6. ~~Alapértelmezett nézet?~~ → **Hét** — az edző tipikus kérdése heti léptékű; a hónap áttekintő, kattintásra hétre vált.
7. ~~Lemondott alkalmak?~~ → **Alapból rejtve**, „Lemondottak mutatása" kapcsolóval — zaj az összképben, de visszakapcsolható.
8. ~~Múlt látszik?~~ → **Igen**: a naptár visszafelé is lapozható, elvégzett/kihagyott státuszokkal — a compliance-kép a naptárban is él.
9. ~~Cselekvés a naptárból?~~ → **MVP-ben kettő**: alkalom-lemondás (meglévő confirm + végpont) és ütemezés-indítás (meglévő drawer, kliens-választós módban, kezdőnap előtöltve). Sorozat-szerkesztés továbbra sincs (v2, lásd `11` döntés-napló 5.).
10. ~~Drag-and-drop átütemezés?~~ → **v2** — az MVP-ben nincs alkalom-áthelyezés (a backend sem támogatja az in-place módosítást); a naptár először lásson, aztán mozgasson.

Nincs több nyitott kérdés — a terv designra és megvalósításra kész.
