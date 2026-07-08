# 11 — Ütemezett edzések: design prompt (Claude Designnak)

> **A fájl célja:** önállóan átadható prompt a Claude Designnak az ütemezett-edzések
> funkció képernyőinek megtervezéséhez. A §0 blokk másolható be egy az egyben.
> A technikai háttér: `08–10-utemezett-edzesek-*.md`; a design-alapok:
> `docs/design/18-design-system-prompt.md` (mobil tokenek) és `06-design.md` (admin nyelv).
> A fájl legvégén — a prompton kívül — a funkció **döntés-naplója** áll (minden korábbi
> nyitott kérdés eldőlt).
>
> ✅ **A design elkészült:** [`design/Lifey Schedule.dc.html`](design/Lifey%20Schedule.dc.html)
> (5 frame: A ütemterv tab · B ütemező drawer · C mobil közelgő · D felugró kártya ·
> E állapotok). A megvalósítás **a mockupból dolgozik** — frame-térkép a
> `10-utemezett-edzesek-web-mobil.md` elején; ez a prompt innentől archív referencia.

---

## 0. A prompt (ezt add át)

> Te a **Lifey** fitness/táplálkozás-követő app design rendszerén dolgozol. A rendszer
> **sötét-first, magas kontrasztú, meleg barnás-zöld (olive/moss) akcentszínű**, mindenhol
> **generózus lekerekítéssel** (radius-skála: sm ~8 / md ~16 / lg ~24 / pill), **ikonokkal
> minden menüponton és akción**, minimál szövegű címkékkel. A top/bottom sávok **nem**
> edge-to-edge szélesek: inset margóval "lebegnek", finom elevationnel. Két felülete van:
> a **mobil app** (Flutter, Material 3, a kliensnek) és a **webes edző-admin** (Next.js,
> `/admin` útvonalak, a személyi edzőnek). Az admin nézetben az akcensszerep a `tertiary`
> (a saját nézet `primary`-jával szemben), a top barban állandó **[EDZŐ] chip** jelzi a
> kontextust. Minden képernyőhöz kötelező a betöltés- (skeleton), üres- és hibaállapot,
> HU/EN lokalizációval.
>
> **A megtervezendő funkció — Ütemezett edzések:** az edző a webes adminban jövőbeli
> edzéseket ütemez a kliensének egy saját edzéssablonból — egyszerit vagy ismétlődőt
> (naponta, vagy kiválasztott hétköznapokon), **legfeljebb 3 hónapra** előre, és a
> sorozathoz **opcionálisan napon belüli időpontot** is adhat (pl. 18:00), amely minden
> alkalomra vonatkozik — időpont nélkül az edzés "aznapra" szól. A kliens
> mobiljában ezek "közelgő edzésként" jelennek meg, de **csak 7 napra előre** (a
> távolabbiakat az app szándékosan nem mutatja). Az edzés négy állapotot járhat be:
> **közelgő** (jövőbeli, még el nem kezdett), **elvégzett** (a kliens elindította és
> befejezte), **kihagyott** (a nap eltelt, a kliens nem kezdte el), **lemondott** (az
> edző vagy a kliens törölte). A kihagyott/elvégzett állapot az edzőnek fontos
> (compliance-követés); a kliensnél a kihagyás nem kap hangsúlyt (nincs bűntudat-UI).
>
> Tervezd meg az alábbi **négy felület-elemet**, a fenti design nyelven:
>
> **A) Web admin — "Ütemterv" tab a kliens-részleteken** (`/admin/clients/{id}/schedule`)
> - A kliens-részletek meglévő tab-sora (Áttekintés / Statisztika / Lépések / Edzések)
>   ötödik tabot kap: **Ütemterv** (naptár-ikon). Ez az egyetlen tab, ahol az edző
>   *cselekszik* is — a fejlécben "+ Edzés ütemezése" primary CTA (a többi tabon lévő
>   "Csak olvasható" badge itt nincs).
> - Felül az **aktív sorozatok** kártyái: sablon-név, ismétlődés-leírás emberi nyelven,
>   időponttal, ha van ("Minden hétfő és csütörtök · 18:00 · júl. 7. – okt. 6."),
>   kompakt progressz-sor
>   (✅ 12 elvégzett · ⚠ 3 kihagyott · 21 hátra), "⋯" menü → "Sorozat lemondása"
>   (destruktív, confirm dialoggal: a jövőbeliek törlődnek, az elvégzettek maradnak).
> - Alatta **idővonal**: az előfordulások hetekre csoportosítva ("E hét", "Jövő hét", …),
>   soronként dátum + időpont (ha van, halvány másodlagos szövegként) + sablon-név +
>   **státusz-chip**: közelgő = `tertiary` chip;
>   elvégzett = pipa (kattintva a session-részletre visz); kihagyott = halvány `error`
>   chip "kihagyta" felirattal; lemondott = áthúzott, halvány. Jövőbeli soron egy-
>   előfordulás lemondás-ikon (confirmmal). A múlt "Előzmények" szakaszként nyitható.
> - Üres állapot: nagy naptár-ikon + "Még nincs ütemezett edzés" + CTA a drawerre.
>
> **B) Web admin — ütemező drawer** (jobb oldali, ~420px, a meglévő kiosztó-drawer
> testvére)
> - Lépései fentről le: (1) **sablon-választó** — kereshető lista az edző saját
>   sablonjaiból (ha sablon-kártyáról nyílt, a sablon adott és kliens-választó van
>   helyette); (2) **ismétlődés** — szegmentált választó: *Egyszeri / Naponta / Heti
>   napokon*, Heti esetén hétköznap-chipek (H K Sze Cs P Szo V, többválasztós, pill);
>   (3) **dátumok és időpont** — kezdőnap (min. ma), nem-egyszerinél zárónap (a picker
>   legfeljebb kezdőnap + 3 hónapot enged), alatta **"Időpont (opcionális)"** mező
>   (HH:mm time picker, üresen hagyható — a design tegye egyértelművé, hogy elhagyható);
>   (4) **élő előnézet-sor**: "**18 edzés** jön létre (minden hétfő és csütörtök
>   18:00-kor, okt. 6-ig)" — időpont nélkül az időrész elmarad; ez a megerősítés fő
>   eszköze; ha a sablon
>   még nem volt kiosztva ennek a kliensnek, info-sáv: "A sablon másolata létrejön a
>   kliensnél."; (5) láb: "Mégse" (ghost) + "Ütemezés" (primary, csak érvényes
>   állapotban aktív). Siker: toast "18 edzés ütemezve Kiss Anna részére".
> - Hibaszövegek inline: "Legfeljebb 3 hónapra előre ütemezhetsz", "Válassz legalább
>   egy napot".
>
> **C) Mobil — "Közelgő" szekció** (Workouts → Sessions tab)
> - A session-lista tetején új, vizuálisan elkülönülő **"Közelgő"** szekció, alatta a
>   meglévő előzmény-lista. Csoportosítás: **Ma / Holnap / a hét további napjai**
>   (nap nevével), napon belül időpont szerint rendezve (időpont nélküliek a nap végén).
>   Legfeljebb 7 nap látszik előre — ezt a UI nem magyarázza, egyszerűen ennyit mutat.
> - Sor-anatómia: sablon-név + kis **"Edzőtől" badge** (dumbbell-ikon pill,
>   `tertiary-container` — a meglévő minta) + **időpont, ha van** ("18:00" — hangsúlyos,
>   ez az edző által kért idősáv; időpont nélkül csak a napszó); jobb oldalt **"Kezdés"**
>   akció (primary). Swipe/menü: törlés (confirm: "Az edződ látni fogja, hogy törölted.").
> - A mai edzés sora enyhén kiemelt (pl. `tertiary` keret vagy container-tónus).
> - Üres állapot: a szekció **el sem jelenik meg**, ha nincs közelgő edzés (nincs zaj).
>
> **D) Mobil — felugró edzés-kártya** (a meghívó-kártya testvére)
> - **Kizárólag az aznapi edzésre** jelenik meg (jövőbeli napokéra soha): app-megnyitáskor,
>   ha ma van ütemezett, még el nem kezdett edzés — a bottom nav **felett lebegő** kártya
>   (inset margók, lg radius, elevation + finom blur, alulról csúszik be, nem modális):
>   "**Ma 18:00: Láb nap** · Kovács Péter edződtől" (időpont nélkül: "**Ma: Láb nap**")
>   + két gomb: **[Kezdés]** (filled/primary) és **[Később]** (ghost). Swipe-dismiss =
>   Később; aznap már nem jön vissza, másnap az aznapi edzéshez újra.
> - Ha aznap több edzés van: az első + "és még 1" halvány jelzés.
> - A meghívó-kártyával egyszerre nem jelenhet meg (a meghívó nyer).
>
> Kényszerek: ne vezess be új design tokent — a meglévő palettából és radius/spacing
> skálából építkezz; minden állapot (loading/üres/hiba) legyen megtervezve; minden
> szöveg HU/EN kulcsként értendő; a webes idővonal legyen billentyűzettel bejárható,
> a státusz ne csak színnel, hanem felirattal/ikonnal is kódolt (AA kontraszt a sötét
> témán); a mobil kártya fókusz-sorrendje: szöveg → Később → Kezdés.

---

## 1. Kapcsolódó design-precedensek (a prompt kontextusa)

| Elem | Precedens |
|---|---|
| Ütemező drawer | `06-design.md` §3.4 — AssignToClientDrawer (kiosztó drawer) |
| Felugró kártya | `06-design.md` §4 — meghívó-kártya (floating pill nyelv) |
| "Edzőtől" badge | `06-design.md` §4 — sablon/recept-kártya badge |
| Státusz-chipek | `06-design.md` §3.3 — lejárati visszaszámláló chip logikája |
| Kliens-részletek tab-sor | `06-design.md` §3.5 |

---

## 2. Eldöntött kérdések (döntés-napló, mind 2026-07-04)

1. ~~Időpont is, vagy csak nap?~~ → **Opcionális napon belüli időpont is van** (`HH:mm`, fali óra szerinti, időzóna nélkül; minden előfordulásra öröklődik; a kihagyottá válást továbbra is a nap eltelte dönti el). Részletek: `08` §ismétlődés-modell 4. pont, `09` (V45 `time_of_day` / `scheduled_time`), `10` (drawer + mobil sorok).
2. ~~A felugró kártya csak aznapra, vagy a hét első edzésére is?~~ → **Kizárólag az aznapi edzésre** — jövőbeli napok edzéséhez nincs kártya.
3. ~~Kihagyott edzés a kliensnél?~~ → **Eltűnik** (se közelgő, se előzmény) — a mobil bűntudat-mentes marad, a compliance az edző nézetének dolga.
4. ~~Kapcsolat-bontáskor a jövőbeli edzések?~~ → **Törlődnek** — a bontás után az edző ütemterve nem él tovább a kliens naptárában.
5. ~~Sorozat szerkesztése?~~ → **MVP-ben nincs** — lemondás + újra létrehozás; in-place módosítás v2.
6. ~~Aktív jelzés új ütemezéskor?~~ → **Nem kell** — a közelgő edzések a sync-kel csendben megjelennek, az aznapi kártya elég; "új sorozat" jelzés v2.
7. ~~Helyi emlékeztető az időpontra?~~ → **v2** — MVP-ben az időpont megjelenítés (nem kerül be a `flutter_local_notifications` függőség).
8. ~~Régi app-verziók védelme a nullable `started_at` sync-en?~~ → **Nem kell** — az app még nincs kiadva, nincs régi verzió a felhasználóknál; a mobil sémafrissítés a backenddel együtt, normál módon megy ki, API-verzió-kapu és koordinált release-kényszer nélkül.

Nincs több nyitott kérdés — a terv megvalósításra kész.
