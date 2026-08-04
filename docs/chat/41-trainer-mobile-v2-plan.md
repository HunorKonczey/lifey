# 41 – Edzői funkciók mobilon (v2)

> **Cél:** a ma **csak weben** elérhető edzői funkcionalitás (`web/src/app/(admin)/**`)
> teljes átvitele a Flutter appba, hogy az edző a telefonjáról is el tudja végezni a napi
> munkáját — ne csak chateljen.
>
> **Ez a v2.** A v1 a chat ([40-trainer-chat-plan.md](40-trainer-chat-plan.md), I1–I5),
> ami az **első** edzői felületet hozza a mobilba. Ez a dokumentum arról szól, hogyan lesz
> a chat melletti egyetlen belépőből **teljes edzői app**.
>
> **Design:** a képernyők promptja külön fájlban —
> [43-trainer-mobile-v2-design-prompt.md](43-trainer-mobile-v2-design-prompt.md)
> (frame-ei A–H, egy az egyben megfeleltethetők az itteni T1–T7 iterációknak).
>
> ⚠️ **Ez a terv tudatosan felülír egy korábbi döntést.**
> A [personal_trainer/05-mobil-terv.md](personal_trainer/05-mobil-terv.md) §5 így szól:
> *„A kliens appban **nincs** edző-funkció (az edző a webet használja; a mobil app
> edző-nézete nem cél…)”*. A 40-es terv (chat mindkét szerepkörben) ezt már megbontotta;
> ez a dokumentum rögzíti a szándékos irányváltást, és a régi mondat innentől elavult.
> A `05-mobil-terv.md` §5-be egy „⚠ Felülírva: lásd docs/41” sor kerüljön a T1 során.

---

## 1. Leltár: mi van ma weben, ami mobilon nincs

Forrás: `web/src/app/(admin)/**` + `web/src/features/trainer/**` + a
`com.lifey.trainer` controllerek. A backend API **készen áll** — a v2 túlnyomó része
kliensoldali munka (a kivételeket a §5 sorolja).

| # | Funkció | Web képernyő | Backend végpont(ok) | Mobil relevancia |
|---|---|---|---|---|
| 1 | Kliens-lista + rendezés + „figyelmet igényel” | `/admin` | `GET /trainer/clients` | ✅ **magas** — ez a napi belépő |
| 2 | Compliance-jelzők (kihagyott edzés, elmaradt mérés) | `ComplianceBadges`, `NeedsAttentionSection` | származtatott | ✅ magas — [29-compliance-overview-plan.md](29-compliance-overview-plan.md) |
| 3 | Kliens-részletező: áttekintő | `/admin/clients/[id]` | `GET /trainer/clients/{id}/statistics/*` | ✅ magas |
| 4 | Kliens statisztika (napi/heti/havi) | `ClientStatisticsTab` | `GET .../statistics/{daily,weekly,monthly}` | ✅ magas |
| 5 | Kliens lépés / testsúly | `ClientStepsTab` | `GET .../steps`, `.../weights` | ✅ magas |
| 6 | Kliens edzés-előzmény + **edzői megjegyzés** | `ClientWorkoutsTab` | `GET .../workout-sessions`, `PUT/DELETE .../workout-sessions/{id}/comment` | ✅ **magas** — [31-session-feedback-loop-plan.md](31-session-feedback-loop-plan.md) |
| 7 | Kliens táplálkozás + célok | `ClientNutritionTab` | `GET .../meals`, `GET/PUT .../nutrition-goals` | ✅ magas — [32-trainer-nutrition-goals-plan.md](32-trainer-nutrition-goals-plan.md) |
| 8 | Tartalom-hozzárendelés (sablon/recept) | `/admin/assignments`, `AssignToClientDrawer` | `POST /trainer/assignments`, `GET /trainer/assignments/clients`, `DELETE …/{id}` | ✅ magas |
| 9 | Tömeges hozzárendelés | `AssignToClientDrawer` (multi) | ugyanaz | 🟡 közepes — [35-bulk-assignment-plan.md](35-bulk-assignment-plan.md) |
| 10 | Edzés-ütemezés (egyszeri + ismétlődő) | `ScheduleWorkoutDrawer`, `ClientScheduleTab` | `POST /trainer/schedules`, `GET .../schedules`, `.../scheduled-sessions` | ✅ magas |
| 11 | Edzői naptár (hónap/hét/agenda) | `/admin/calendar`, `TrainerCalendar` | `GET /trainer/scheduled-sessions` | 🟡 **átszabandó** — a hónapnézet mobilon más UX |
| 12 | Többhetes programok (szerkesztő rács) | `/admin/programs/*`, `ProgramGridEditor` | `/trainer/programs/**` | 🟡 **a legnehezebb** — [34-multi-week-program-plan.md](34-multi-week-program-plan.md) |
| 13 | Program hozzárendelése klienshez | `AssignProgramDrawer` | `POST /trainer/programs/{id}/assignments` | ✅ magas |
| 14 | Meghívók (küldés, lista, visszavonás) | `/admin/invites` | `/trainer/invites/**` | ✅ magas |
| 15 | Edzői preferenciák | (settings) | `GET/PUT /trainer/preferences` | ✅ alacsony effort |
| 16 | Heti riport | e-mail | `TrainerWeeklyReportJob` | 🟡 olvasó-nézet mobilon, [33-weekly-trainer-report-plan.md](33-weekly-trainer-report-plan.md) |
| 17 | Superadmin (user-kezelés) | `/superadmin/users` | `/api/v1/superadmin/**` | 💻 **web-only, nem cél** |
| 18 | Saját (nem edzői) tartalom-CRUD: gyakorlatok, sablonok, receptek | `(app)/**` | meglévő | ✅ **már megvan mobilon** — nem kell újra |

**Fontos megfigyelés a scope-hoz:** a 18. sor miatt a v2 kisebb, mint elsőre látszik. Az
edző a *saját* sablonjait, receptjeit, gyakorlatait már ma is szerkeszti mobilon (ugyanaz
a felület, mint a kliensnek) — a v2-nek „csak” a **kliensre irányuló** műveleteket kell
hoznia: kit látok, mit csinált, mit adok neki, mikorra.

---

## 2. Architektúra-döntések

### 2.1 Navigáció: külön edzői shell, nem átszabott kliens-shell

A 40-es tervben a chat még elfért egy shellen kívüli útvonalon (`/chat`) — hét-nyolc
edzői képernyő már nem fér el így. A `MainShell` öt fix ága (dashboard / nutrition /
workouts / weight / statistics) a **kliens** munkafolyamata; az edzőé teljesen más.

Három opció:

1. **Az öt ág bővítése / szerepkör-függő tabsor** → a `StatefulNavigationShell` ágait
   futásidőben cserélni GoRouterben törékeny, a kettős szerep (edző, akinek saját edzője
   is van) miatt pedig egyik tabsor sem elég. **Elvetve** (már a 40-es tervben is).
2. **Minden edzői képernyő shellen kívüli push-útvonal** → nyolc képernyőnél a felhasználó
   elveszti a helyérzetét, nincs hova „visszatérni”. **Elvetve.**
3. **Külön `TrainerShell` saját `StatefulShellRoute`-tal**, `/trainer/...` útvonalakon,
   négy ággal: **Klienseim · Naptár · Hozzárendelések · Programok** (+ a chat ikon a
   fejlécben, ahogy a v1-ben). A két shell **egymás mellett** él, nem egymás helyett.
   **Ezt választjuk.**

**Váltás a két világ között.** Nem „mód”, hanem navigáció: a kliens-oldali dashboard
fejlécében egy avatar-menü tartalmaz egy **„Edzői nézet”** tételt (csak `ROLE_TRAINER`
esetén látszik), az edzői shell fejlécében pedig egy **„Saját naplóm”** tétel vissza.
Az utolsó választás megjegyződik (`SharedPreferences`), és az app oda indul — így az az
edző, aki soha nem naplózik magának, nem lát fölösleges lépést.

> **Miért nem külön app?** Mert a chat, a push-regisztráció, az auth, a téma, az i18n és
> a design rendszer közös; egy második Flutter target duplikálná a kiadási folyamatot és
> a store-jelenlétet, miközben a felhasználók egy része *mindkét* szerepben van.

### 2.2 Adatréteg: online-first, **nem** delta sync

Ez a v2 legfontosabb technikai döntése.

A mobil app offline-first magja (drift + `PullEngine` + `OutboxWriter`,
[15-delta-sync.md](15-delta-sync.md)) **a bejelentkezett user saját adatára** van szabva:
a lokális táblák user-scope-oltak, a sync-kurzor egy user-é, a konfliktuskezelés a
„az én eszközöm vs. a szerver” esetre készült.

A kliens-adat ehhez nem illik:
- **Más user adata**, ami bármikor változhat az ő eszközéről — egy elavult lokális
  másolat az edzőnél nem kényelem, hanem **hiba forrása** (rossz döntés régi adat alapján).
- A halmaz N kliensszer akkora, és nagy része sosem kell (aki 3 hónapja nem lépett be).
- Az edzői **írás** (hozzárendelés, ütemezés, megjegyzés) offline sorba állítva
  veszélyes: egy két napja elküldött, „megérkezettnek hitt” programot nem lehet
  visszacsinálni a kliens fejében.

**Döntés: az edzői felület online-first**, pontosan mint a web (lásd
[web/04-frontend-architecture.md](web/04-frontend-architecture.md) §1). Következmények:
- minden edzői képernyőnek **skeleton / üres / hiba / offline** állapota van
  (az offline állapot itt elsőrendű UI-elem, nem szélső eset);
- rövid életű memória-cache a navigáció simaságáért (Riverpod `AsyncNotifier` + pull-to-refresh),
  de **semmi drift tábla** az edzői adatra;
- az edzői mutációk optimista UI nélkül, egyértelmű „mentés folyamatban / kész / hiba”
  visszajelzéssel mennek — a chat az egyetlen kivétel (ott az optimista buborék indokolt,
  lásd 40-es terv §6.1).

### 2.3 Kódszervezés

```
mobile/lib/features/trainer/                      ← új, edzői gyökér
├── clients/        {data,application,presentation}   kliens-lista, compliance
├── client_detail/  … tabok: overview / statistics / steps / weight / workouts / nutrition
├── assignments/    … tartalom-hozzárendelés, tömeges hozzárendelés
├── schedule/       … ütemezés + naptár
├── programs/       … többhetes program szerkesztő + hozzárendelés
├── invites/        … meghívók
└── shared/         client_avatar.dart, compliance_badge.dart, client_picker.dart

mobile/lib/shared/widgets/trainer_shell.dart      ← második shell
mobile/lib/core/auth/current_role_provider.dart   ← már a v1-ben elkészül
```

**Újrahasznosítás.** A kliens-részletező grafikonjai, az edzés-részletező nézet és a
makró-összegzők a meglévő `features/statistics`, `features/workouts`,
`features/nutrition` prezentációs widgetjeiből építhetők, ha azok **adatforrás-függetlenek**
(paraméterként kapják a modellt, nem providerből olvassák). Ahol ma nem azok, ott a T2/T3
első lépése egy kis kiemelés — ez a v2 „rejtett” munkája, és a becslésekben benne van.

---

## 3. Iterációk

Előfeltétel: a 40-es terv **I1–I2** kész (chat backend + mobil chat mindkét szerepben) —
onnan jön a `currentRolesProvider`, a szerepkör-tudatos navigáció mintája és az
edzői belépés élménye. Az I3–I5 nem előfeltétel.

Minden iteráció végén az edzői shell **használható marad** (nincs félkész tab: ami még
nincs kész, az meg sem jelenik a navigációban).

---

### T1 – Edzői váz + kliens-lista · ~5 nap

**Cél:** az edző belép a mobilon az „Edzői nézetbe”, látja a klienseit, és rájuk tud
koppintani. Ez az iteráció adja az összes többi alapját.

- `TrainerShell` + `StatefulShellRoute` a `/trainer/...` útvonalakra (egyelőre **egy**
  aktív ág: Klienseim; a többi ág a saját iterációjában kapcsolódik be).
- Nézetváltó az avatar-menüben mindkét irányba + utolsó nézet megjegyzése.
- Kliens-lista: `GET /trainer/clients`, kártyák avatarral, rendezés (legutóbbi aktivitás /
  legkevésbé aktív / legtöbb kihagyás / esedékes mérés) — a web `compliance.ts`
  rendezési logikájának Dart-portja, **azonos szemantikával**.
- „Figyelmet igényel” szekció a lista tetején (29-es terv szabályai).
- Üres állapot: „Még nincs kliensed – küldj meghívót” → a T7 meghívó-képernyőre mutat
  (addig a webre irányító szöveg).
- Offline állapot: teljes képernyős „Nincs kapcsolat – az edzői nézet online adatot
  használ” + újrapróbálás.

Tesztek: a rendezési logika portjára **karakterről karakterre azonos** unit tesztek, mint
a webes `compliance.test.ts`; widget teszt a lista/üres/offline/hiba állapotokra;
navigációs teszt a nézetváltásra kettős szerepű userrel.

**Kész, ha:** egy edző bejelentkezik, átvált edzői nézetbe, a kliensei ugyanabban a
sorrendben és ugyanazokkal a jelzőkkel jelennek meg, mint a weben.

---

### T2 – Kliens-részletező: adatnézetek · ~6 nap

**Cél:** az edző mindent lát a kliensről, amit ma weben lát — csak olvas, még nem ír.

- `ClientDetailScreen` fejléc (avatar, név, kapcsolat kezdete) + tabok:
  **Áttekintő · Statisztika · Lépés · Testsúly · Táplálkozás**.
- Adatforrás: `GET /trainer/clients/{id}/statistics/{daily,weekly,monthly}`, `/steps`,
  `/weights`, `/meals`.
- Grafikonok: a `features/statistics` meglévő chart-widgetjei, adatforrás-függetlenné
  emelve (§2.3). **Ha egy widget kiemelése többe kerülne, mint újraírni** — akkor újraírás,
  de a design tokenek kötelezően közösek.
- Az utoljára nézett tab megjegyzése kliensenként (a web ugyanezt csinálja).
- Mély link: a chat szálból („Adatai megtekintése”) és a push-ból ide is lehessen jutni.

Tesztek: widget tesztek tabonként (adat / üres / hiba); a tab-emlékezet perzisztálása;
időzóna-határ a napi statisztikán.

**Kész, ha:** egy kliens minden adatnézete megegyezik a webes megfelelőjével
(kézi összehasonlítás egy valós fiókon, képernyőképekkel dokumentálva).

---

### T3 – Edzés-előzmény + edzői megjegyzés · ~4 nap

**Cél:** az első edzői **írás** mobilon — a visszajelzési kör bezárása.

- „Edzések” tab: `GET /trainer/clients/{id}/workout-sessions`, lista + részletező
  (gyakorlatok, szettek, RPE, kliens jegyzete).
- Megjegyzés szerkesztése: `PUT/DELETE .../workout-sessions/{id}/comment` —
  a 31-es terv szerint, a mentés kimenetele egyértelműen jelezve (nincs optimista UI).
- A megjegyzés mentése pusht küld a kliensnek (backend oldalon már működik, ez ingyen jön).
- **Kapcsolódás a chathez:** a megjegyzés mellett egy „Írok is neki” gomb, ami a
  chat szálba visz az edzés hivatkozásával — ez az a pont, ahol a v1 és a v2 összeér.

Tesztek: megjegyzés írás/törlés/hálózati hiba; a lista lapozása; a chat-ugrás.

**Kész, ha:** az edző mobilról kommentel egy edzést, a kliens telefonja csörren, és a
koppintás a helyes edzésre visz.

---

### T4 – Tartalom-hozzárendelés · ~5 nap

- Kliensenkénti hozzárendelés-lista (`GET /trainer/clients/{id}/assignments`) és
  globális nézet (`GET /trainer/assignments/clients`) az „Hozzárendelések” ágon,
  kliens- és típusszűrővel.
- Hozzárendelés: alsó lap (bottom sheet) sablon-/recept-választóval a **saját** meglévő
  tartalomból (a mobil app már ismeri ezeket a listákat — újrahasznosítás).
- Visszavonás (`DELETE /trainer/assignments/{id}`) megerősítéssel.
- **Tömeges hozzárendelés** (35-ös terv): több kliens kijelölése a kliens-listából →
  egy tartalom mindenkinek; részleges sikert kezelő eredmény-összegzés
  (`BulkAssignmentResponse` már ezt adja vissza).

Tesztek: részleges siker megjelenítése; duplikált hozzárendelés (`V61` unique constraint)
kezelése hibaüzenettel, nem összeomlással.

**Kész, ha:** az edző mobilról kioszt egy receptet öt kliensnek, és a hibás sorokat
külön látja.

---

### T5 – Ütemezés + naptár · ~7 nap

Ez az iteráció **nem port, hanem újratervezés** — a webes hónapnézet-rács telefonon
nem működik.

- **Ütemezés** (a kliens-részletező „Ütemezés” tabjában): egyszeri és ismétlődő edzés
  létrehozása (`POST /trainer/schedules`), sablonválasztóval, dátum/idő/ismétlődés
  beállítással; meglévő ütemezések listája, törlés (sorozat vs. egy alkalom –
  `DELETE /trainer/schedules/{id}` vs. `/scheduled-sessions/{id}`).
- **Naptár ág**: alapértelmezett nézet **agenda (napokra bontott lista)**, nem hónaprács;
  fölötte egy kompakt heti sáv a napok közti ugráshoz. Hónapnézet csak fekvő tájolásban
  vagy tableten (`MediaQuery` szélesség-küszöb). Ez az elrendezés a webes
  `CalendarAgendaView` + `CalendarWeekView` mobilra szabott kombinációja.
- Kliens-szűrő a naptárban (`CalendarClientFilter` megfelelője).
- Alkalom „bekukkantó” (peek) lap: kliens, sablon, idő, státusz, gyors törlés.

Tesztek: ismétlődés-szabályok (`Recurrence`) generálása és megjelenítése; időzóna;
sorozat vs. alkalom törlés; a nézetváltás küszöbe.

**Kész, ha:** az edző telefonról beütemez egy heti ismétlődő edzést, és a következő
hét eseményei helyesen jelennek meg mindkét nézetben.

---

### T6 – Többhetes programok · ~8 nap

A legnagyobb kockázatú darab: a webes `ProgramGridEditor` egy **hét × nap rács
drag&droppal**, ami telefonon nem használható változtatás nélkül.

- **Program-lista + részletező** (olvasás, hozzárendelés) először — ez már önmagában
  értékes, és a T6 első felében kész van.
- **Program hozzárendelése klienshez** (`POST /trainer/programs/{id}/assignments`,
  kezdődátummal) — ez a leggyakoribb művelet, ezért előrébb kerül a szerkesztésnél.
- **Szerkesztés mobil-formában:** rács helyett **hetenkénti, összecsukható lista**
  (Hét 1 → Hétfő: Push nap · Szerda: Pull nap …), sorrendezés hosszan nyomással
  (`ReorderableListView`), nem szabad drag&droppal. Nap-hozzáadás alsó lapról.
- **Ha a szerkesztés mobilon túl drága**, a T6 leszűkíthető olvasás + hozzárendelés +
  „szerkesztés a weben” hivatkozásra. Ezt a döntést a T6 közepén, prototípus után
  hozzuk meg — a terv mindkét kimenetelt elfogadja.

Tesztek: a `program.ts` üzleti logika Dart-portjának unit tesztjei (a webes
`program.test.ts` eseteivel); sorrendezés; hozzárendelés kezdődátum-számítása.

**Kész, ha:** az edző mobilról hozzárendel egy programot; és vagy szerkeszteni is tud,
vagy egyértelmű útmutatást kap a webre.

---

### T7 – Meghívók, preferenciák, riport, záró élmény · ~4 nap

- **Meghívók**: `POST/GET/DELETE /trainer/invites` — küldés e-mail címre, függő
  meghívók listája lejárattal, visszavonás. (A kliens oldali *elfogadás* már ma megvan.)
- **Edzői preferenciák** (`GET/PUT /trainer/preferences`) az edzői nézet beállításai
  között.
- **Heti riport** olvasó-nézet mobilon (33-as terv), a levél tartalmának megfelelője.
- **Táplálkozási célok szerkesztése** (`PUT .../nutrition-goals`, 32-es terv) —
  a T2-ben olvasott adathoz itt jön az írás.
- Záró: onboarding-tipp az első edzői belépéskor, üres állapotok végigfésülése,
  teljes i18n-audit (HU + EN), akadálymentesítési átnézés (érintési célpontok,
  kontraszt, képernyőolvasó címkék).

**Kész, ha:** egy edző a teljes napi munkáját el tudja végezni mobilról, és a webre csak
akkor kell ülnie, ha ő akar (vagy a T6 döntése miatt program-szerkesztéshez).

---

### Összesítő

| Iteráció | Tartalom | Becslés |
|---|---|---|
| T1 | Edzői shell + kliens-lista + compliance | ~5 nap |
| T2 | Kliens-részletező adatnézetek | ~6 nap |
| T3 | Edzés-előzmény + megjegyzés (első írás) | ~4 nap |
| T4 | Tartalom-hozzárendelés + tömeges | ~5 nap |
| T5 | Ütemezés + mobil naptár | ~7 nap |
| T6 | Többhetes programok | ~8 nap |
| T7 | Meghívók, preferenciák, riport, záró | ~4 nap |
| | **Összesen** | **~39 fejlesztői nap (≈ 8 hét)** |

A T1–T3 önmagában is értelmes szállítmány („az edző mobilról követi és visszajelzi”),
a T4–T5 teszi ténylegesen munkavégzésre alkalmassá, a T6–T7 a teljesség. **Ha csak
a felére van keret, a T1–T3 + T5 a javasolt vágás** (követés + ütemezés), mert a
hozzárendelés és a program-szerkesztés az, amit egy edző elfogadhatóan csinál hetente
egyszer, asztali gépen.

---

## 4. Mobil-specifikus UX kihívások

| Webes minta | Miért nem megy telefonon | Mobil megoldás |
|---|---|---|
| Hónapnézetű naptár-rács | 30+ cella, több esemény/nap, olvashatatlan | agenda-lista + heti sáv; hónaprács csak fekvőben/tableten (T5) |
| Program-rács drag&drop | pontos húzás kis felületen | hetenkénti összecsukható lista + hosszan nyomásos sorrendezés (T6) |
| Széles táblázatok (hozzárendelések, étkezések) | vízszintes görgetés = rossz | kártyás lista, a másodlagos mezők a részletezőben |
| Több-paneles kliens-részletező | nincs hely | tabok, kliensenként megjegyzett utolsó tabbal (T2) |
| Modális oldalsó fiókok (drawer) | jobbról becsúszó panel idegen | alsó lapok (`showModalBottomSheet`), teljes képernyős lapok összetett űrlaphoz |
| Egérrel hover-információ | nincs hover | koppintásra nyíló „peek” lap (T5) |

A fenti sorok mindegyike külön frame-ként szerepel a design promptban
([43-trainer-mobile-v2-design-prompt.md](43-trainer-mobile-v2-design-prompt.md) §0/F–G).

Egy általános szabály az egész v2-re: **minden edzői írási művelet megerősítést vagy
visszavonási lehetőséget kap**, mert a telefonon nagyobb az elgépelés/félrekoppintás
esélye, és a művelet **más ember** adatait érinti.

---

## 5. Backend hiányok

A v2 majdnem teljes egészében kliensoldali, de négy dolgot érdemes a backenden
rendezni — mindegyik **additív**, egyik sem töri a webet:

1. **Lapozás a kliensre szűrt listákon.** A `GET /trainer/clients/{id}/workout-sessions`
   és `/meals` ma teljes listát ad. Weben elmegy, mobilon adatforgalom és memória.
   → `page`/`size` paraméterek a [14-pagination-plan.md](14-pagination-plan.md) mintájára
   (a T2/T3 előtt, ~1 nap).
2. **Összevont kliens-lista végpont.** A mobil kliens-lista ma N+1 hívás lenne
   (lista + kliensenként compliance-adat). → `GET /trainer/clients?include=compliance`
   egy válaszban (a T1 előtt, ~1 nap). Ha ez csúszik, a T1 párhuzamos hívásokkal is
   megoldható — de rossz hálózaton érezhető.
3. **Kliens avatar URL** a `TrainerClientResponse`-ban, ha még nincs benne (a
   [22-profile-picture-plan.md](22-profile-picture-plan.md) alapján) — a lista-kártyákhoz.
4. **Heti riport olvasható API-ból** (ma e-mail-ként generálódik) a T7-hez, ha a riport
   mobilon is kell (~1 nap). Ha nem, a T7 e pontja kimarad.

Összesen ~3–4 backend nap, a fenti táblázat 39 napján **felül**.

---

## 6. Kockázatok

| Kockázat | Hatás | Mérséklés |
|---|---|---|
| **Két felület, egy backend → kettős karbantartás.** Minden új edzői funkció innentől web + mobil | lassuló szállítás | az üzleti logika (compliance-rendezés, program-számítás, ütemezés-státusz) **tesztekkel párban** portolódik, hogy a két oldal ne szakadjon el; új edzői funkció elfogadási feltétele mindkét felület |
| A program-szerkesztő mobilon nem lesz használható | T6 elúszik | prototípus a T6 közepén, döntési pont: teljes szerkesztő vs. „szerkesztés a weben” (§3 T6) |
| Online-first edzői nézet gyenge hálón | az edző „nem tud dolgozni” | minden képernyőn kifejezett offline állapot + újrapróbálás; a *saját* tartalom (sablonok) offline is elérhető marad, mert az a régi sync-en jön |
| A kliensadat mobilon = megnövelt adatvédelmi felület (elveszett telefon) | más emberek adatai | eszköz-szintű védelem feltételezése mellett: az edzői nézet **nem cache-el kliensadatot lemezre** (§2.2) — ez egyben adatvédelmi érv is, nem csak frissesség |
| Scope-robbanás: „ha már edzői app, legyen benne X is” | végtelen v2 | a §1 leltár a **teljes** scope; ami nincs benne (17. sor, superadmin), az v3 |
| A `05-mobil-terv.md` régi mondata megzavarja az olvasót | rossz döntés régi doksi alapján | a T1-ben odakerül a felülíró hivatkozás (lásd fejléc) |

---

## 7. Amit **nem** viszünk mobilra

- **Superadmin felület** (user-kezelés, szerepkör-osztás) — ritka, kockázatos, asztali
  művelet. Marad weben.
- **Tömeges adat-export / hosszú riportok** — a telefon nem az a hely.
- **Hosszú szöveges tartalom szerkesztése** (részletes gyakorlat-leírás) — mobilon
  olvasható, szerkesztésre a web ajánlott (nem tiltott).

---

## 8. Nyitott kérdések

1. **A T6 program-szerkesztő teljes legyen-e mobilon?** Döntés prototípus után, a T6
   közepén. Javaslat: olvasás + hozzárendelés kötelező, szerkesztés opcionális.
2. **Kell-e tablet-elrendezés?** A naptár hónapnézete és a program-rács tableten
   *működne*. Ha az edzők jelentős része iPaden dolgozik, az érv erős — ehhez használati
   adat kell, nem tervezői megérzés.
3. **Legyen-e „edzői” push-csomag** (kliens kihagyott edzést, kliens leadta a heti
   mérését)? Ez természetes folytatás a 30-as terv infrastruktúráján, de **külön terv** —
   nem a v2 része.
4. **Mikor induljon a v2?** Javaslat: a 40-es terv I2 (mobil chat) éles visszajelzései
   után. Ha az edzők a chatet mobilról használják, a v2 igazolt; ha nem, a v2 sorrendje
   újragondolandó.
