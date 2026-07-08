# 12 — Edző-naptár: terv (web admin)

Alapok: ütemezett edzések — koncepció `08`, backend `09`, web/mobil `10`. Design prompt: `13-edzo-naptar-design-prompt.md`.

## Koncepció

Az ütemezett edzések ma **csak kliensenként** láthatók (kliens-részletek → Ütemterv tab). Az edzőnek hiányzik az összkép: *"mi vár a klienseimre ma / ezen a héten / a hónapban?"* — ezt adja meg az **edző-naptár**: egyetlen naptár-nézet, amelyben az edző **az összes aktív kliensének minden ütemezett edzését** látja előre (és visszamenőleg is, státusszal együtt).

- **Új menüpont a bal oldali sidebarban:** „Naptár" (`calendar_month` ikon), közvetlenül a „Klienseim" alatt — ez napi munkaeszköz, nem adminisztrációs aloldal. Útvonal: `/admin/calendar`.
- **Szerep:** elsősorban áttekintő (read-mostly), de két akció él benne:
  1. **alkalom-lemondás** közelgő edzésen (a meglévő egy-előfordulás-lemondás, confirmmal),
  2. **új ütemezés indítása** a naptárból (a meglévő `ScheduleWorkoutDrawer` kliens-választós módban, a kattintott nap kezdőnapként előtöltve).
- A naptár **nem vezet be új fogalmat**: ugyanazokat az előfordulásokat mutatja (UPCOMING / DONE / MISSED / CANCELLED), amiket a kliens Ütemterv tabja — csak kliens-dimenzióval kiegészítve, naptár-rácsban.

## Backend

### Új végpont: összesített előfordulás-lekérés

A meglévő `GET /trainer/clients/{clientId}/scheduled-sessions?from&to` kliensenkénti. A naptárhoz **egyetlen aggregált hívás** kell — a kliensenkénti N hívás 10+ kliensnél lassú, zajos és inkonzisztens pillanatképet ad (elvetve).

| Módszer | Útvonal | Leírás |
|---|---|---|
| GET | `/api/v1/trainer/scheduled-sessions?from&to` | Az edző **összes aktív kliensének** előfordulásai a megadott dátum-intervallumban, naptár-nézethez |

- **Válasz:** `TrainerCalendarSessionResponse` = a meglévő `ScheduledSessionResponse` mezői (`sessionId`, `scheduledFor`, `scheduledTime`, `templateName`, `status`, `scheduleId`) + **`clientId`** és **`clientEmail`** — a naptárban a kliens azonosítása kötelező.
- **Jogosultság:** `ROLE_TRAINER`; kizárólag az **aktív** kapcsolatú kliensek sorai (bontott kapcsolat edzései nem jelennek meg — a jövőbeliek bontáskor amúgy is törlődnek, lásd `11` döntés-napló 4.).
- **Intervallum-guard:** `from ≤ to`, legfeljebb **62 nap** (két hónap-lapozásnyi) — a naptár hónap/hét nézete sosem kér többet; 400 túllépésnél.
- **Implementáció:** a meglévő `WorkoutScheduleController` + `WorkoutScheduleService` bővül; a lekérdezés a kliensenkénti változat általánosítása (join az aktív trainer–client kapcsolatokra), a származtatott státusz-logika **közös marad** a kliensenkénti végponttal.
- **Tesztek:** csak aktív kliens sorai jönnek; `ROLE_USER` → 403; intervallum-guard 400; több kliens előfordulásai helyesen keverednek; bontott kapcsolat kliense kimarad.

Migráció **nincs** — a végpont a meglévő sémából olvas.

## Web admin (Next.js)

### Útvonal és navigáció

```
web/src/app/(admin)/admin/
  calendar/page.tsx            # ÚJ: edző-naptár
```

`AdminSidebar` `NAV_ITEMS` bővül (a „Klienseim" után, 2. pozíció): `{ href: "/admin/calendar", icon: "calendar_month", key: "calendar" }`.

### Feature-mappa bővítés

```
web/src/features/trainer/
  api.ts        # + calendarSessions(from, to)
  types.ts      # + TrainerCalendarSessionResponse
  components/
    TrainerCalendar.tsx        # nézet-váltó héj: fejléc (Ma gomb, ‹ ›, Hét/Hónap, szűrők) + aktív nézet
    CalendarWeekView.tsx       # 7 napi oszlop, session-kártyákkal
    CalendarMonthView.tsx      # hónap-rács, napcellákban chipek
    CalendarSessionPeek.tsx    # kattintásra nyíló popover (részletek + akciók)
```

Query-kulcs: `queryKeys.trainerCalendar.range(from, to)` → `["trainer-calendar", from, to]`. Az alkalom-lemondás invalidálja a `trainer-calendar` és a `trainer-schedules` kulcsokat is (a kliens Ütemterv tabja konzisztens maradjon).

### Nézetek

**Hét nézet (alapértelmezett).** 7 oszlop (hétfő kezdéssel, mint a `ScheduleTimeline`), oszloponként a nap **idő szerint rendezett session-kártyái**; az időpont nélküliek a nap végén, halvány „Nap folyamán" elválasztó alatt (a meglévő rendezési konvenció: időpont nélküli a nap végére). **Nem óra-rács**: az edzések jelentős részének nincs napon belüli időpontja, az óra-rács ezekkel szétesne — a kártya-oszlop mindkét esetet jól viseli.

**Hónap nézet.** Klasszikus hónap-rács; napcellánként legfeljebb 3 kompakt chip (időpont + kliens-monogram + sablon-név, csonkolva), felette „+N" jelzés, ami a napra kattintva a hét nézetre vált (az adott hétre navigálva).

**Közös fejléc:** „Ma" gomb + ‹ › lapozás + időszak-címke („júl. 7–13." / „2026. július") + Hét/Hónap szegmentált váltó + szűrők. A mai nap oszlopa/cellája kiemelt (`tertiary` keret — a mobil „mai edzés" kiemelés webre fordítva).

### Session-kártya anatómia

`[18:00] (KA monogram-avatar) Kiss Anna · Láb nap [státusz]`

- **Kliens-azonosítás monogram-avatarral + névvel** — nincs kliensenkénti színkódolás (10+ kliensnél szín-káosz, színtévesztőknek követhetetlen); **a szín a státuszé marad**, a `ScheduleTimeline` `STATUS_STYLE` logikájával azonosan (UPCOMING tertiary chip, DONE pipa, MISSED halvány error, CANCELLED áthúzott/halvány). A státusz-stílus **közös modulba emelendő** (`scheduleStatus.ts`), ne duplikálódjon.
- Múltbeli napokon DONE/MISSED kártyák — a naptár visszafelé is lapozható, a compliance-kép része.

### Session-peek (popover)

Kártyára kattintva horgonyzott popover: kliens (avatar + név + e-mail), sablon-név, dátum + időpont, státusz, ismétlődés-leírás (`RecurrenceLabel` a sorozatból — a `scheduleId`-n át); akciók:

- **„Kliens ütemterve"** — navigáció a kliens-részletek Ütemterv tabjára (mélylink),
- **DONE**-nál „Edzés megnyitása" — a session-részletre (Edzések tab nézete, a `ScheduleTimeline` meglévő mintája),
- **UPCOMING**-nál „Alkalom lemondása" — a meglévő confirm-dialog + `cancelOccurrence`.

### Ütemezés a naptárból

Napcella / napi oszlop fejlécének hover-akciója: „+" → `ScheduleWorkoutDrawer` **kliens-választós módban** (a `/admin/workouts` felőli nyitás meglévő módja), a kattintott nap **kezdőnapként előtöltve**. Múltbeli napra a „+" nem jelenik meg (kezdőnap min. ma). Siker után a naptár-query invalidálódik.

### Szűrők

- **Kliens-szűrő:** multi-select (avatar + név), alapértelmezetten mind; kliens-oldali szűrés (az adatok már betöltve).
- **„Lemondottak mutatása"** kapcsoló, alapértelmezetten **ki** — a lemondott alkalom zaj az összképben, de igény esetén visszakapcsolható.

### Állapotok

- **Betöltés:** naptár-rács skeleton (oszlop/cella-vázak, 2-3 kártya-placeholder).
- **Üres (nincs egyetlen előfordulás a nézett időszakban):** nagy naptár-ikon + „Nincs ütemezett edzés ebben az időszakban" + CTA „+ Edzés ütemezése" (drawer).
- **Üres (nincs kliens):** a kliens-lista üres állapotának megfelelő üzenet + CTA a meghívó oldalra.
- **Hiba:** a megszokott hibakártya + újrapróbálás.

### Reszponzivitás

Az admin desktop-first, de tablet alatt a hét nézet 7 oszlopa nem fér el: **agenda-nézetté** esik össze (napok egymás alatt, napi fejléccel — lényegében a `ScheduleTimeline` sor-nyelve). A hónap nézet keskeny nézeten chipek helyett pont-jelzőkkel + nap-kattintásra agenda.

### i18n

Új next-intl kulcsok az `admin.calendar.*` névtér alatt (HU/EN); a sidebar-kulcs `admin.nav.calendar`.

## Ütemterv-illesztés (PT6 fázis)

**PT6 — Edző-naptár**
1. Backend: aggregált `GET /trainer/scheduled-sessions` végpont + tesztek.
2. Web: sidebar-menüpont + naptár oldal (hét/hónap nézet, peek, szűrők, állapotok) + drawer-integráció (design: `13` prompt frame-jei).

**Kész, ha:** edzőként a Naptár menüpontból egy nézetben látom az összes kliensem e heti edzéseit kliens-jelöléssel; hónap nézetre váltva a teljes hónapot; egy közelgő alkalmat a naptárból lemondok és az a kliens Ütemterv tabján is lemondottra vált; egy napcella „+"-áról indítva edzést ütemezek egy kliensnek a kattintott naptól.

## Kockázatok

| Kockázat | Súly | Ellenszer |
|---|---|---|
| Sok kliens × sűrű ütemezés → nagy válasz (hónap nézet) | alacsony | 62 napos guard; a válasz sorai kompaktak; szükség esetén v2: szerver-oldali kliens-szűrő paraméter |
| Naptár és Ütemterv tab státusz-eltérése (duplikált stílus/logika) | közepes | státusz-stílus közös modulba (`scheduleStatus.ts`); a származtatott státusz kizárólag a backendről jön |
| Óra-rács iránti elvárás (klasszikus naptár-kép) vs. időpont nélküli edzések | közepes | tudatos döntés: kártya-oszlop, nem óra-rács — a design prompt explicit erre kéri a megoldást |

A funkció döntés-naplója a `13-edzo-naptar-design-prompt.md` végén.
