# 10 — Ütemezett edzések: web admin és mobil terv

Backend-alapok: `09-utemezett-edzesek-domain-backend.md`. Design prompt: `11-utemezett-edzesek-design-prompt.md`.

> **Forrás design (ebből dolgozunk):** [`design/Lifey Schedule.dc.html`](design/Lifey%20Schedule.dc.html) — az elkészült, kanonikus mockup, 5 frame:
>
> | Frame | Tartalom | Terv-szekció |
> |---|---|---|
> | **A** | Web admin — "Ütemterv" tab a kliens-részleteken: sorozat-kártyák + heti idővonal | §Ütemterv tab |
> | **B** | Web admin — ütemező drawer (a kiosztó-drawer testvére) | §Ütemező drawer |
> | **C** | Mobil — "Közelgő" szekció (Workouts → Sessions) | §Mobil 2. |
> | **D** | Mobil — felugró edzés-kártya (a meghívó-kártya testvére) | §Mobil 3. |
> | **E** | Állapotok — idővonal-skeleton, üres Ütemterv, betöltési hiba | §Ütemterv tab, állapotok |
>
> Eltérés esetén a mockup az irányadó a vizuális részletekben (elrendezés, chipek, tipográfia); az itteni terv a viselkedésben (szabályok, adatfolyam, végpontok).

## Web admin (Next.js)

### Útvonalak

```
web/src/app/(admin)/admin/
  clients/[clientId]/
    schedule/page.tsx          # ÚJ: a kliens ütemterve (sorozatok + előfordulás-idővonal)
```

A kliens-részletek tab-sora bővül: **Áttekintés / Statisztika / Lépések / Edzések / Ütemterv**. Az Ütemterv az egyetlen kliens-tab, ami **nem read-only** — a "Csak olvasható" badge itt nem jelenik meg (helyette a fejlécben a "+ Edzés ütemezése" CTA él).

### Feature-mappa bővítés

```
web/src/features/trainer/
  api.ts        # + createSchedule, schedulesForClient, scheduledSessions(clientId, from, to),
                #   cancelSchedule, cancelOccurrence
  hooks.ts      # + useSchedules(clientId), useScheduledSessions(clientId, range),
                #   useCreateSchedule, useCancelSchedule, useCancelOccurrence
  schemas.ts    # + scheduleSchema (recurrence-függő feltételes validáció, 3 hónapos horizont, opcionális HH:mm időpont)
  types.ts      # + Recurrence, WorkoutSchedule, ScheduledSession (+ státusz-unió)
  components/
    ScheduleWorkoutDrawer.tsx  # ütemező drawer (lásd lent)
    ScheduleList.tsx           # aktív sorozatok kártyái
    ScheduleTimeline.tsx       # előfordulások hetekre bontva, státusz-chipekkel
    RecurrenceLabel.tsx        # 'Minden hétfő, csüt · júl. 7. – okt. 6.' formázó
```

### Ütemező drawer (`ScheduleWorkoutDrawer`) — design: B frame

Az `AssignToClientDrawer` mintájára, jobb oldali drawer:

1. **Sablon-választó** — kereshető lista az edző saját sablonjaiból (ha a drawer a kliens Ütemterv tabjáról nyílik, kliens már adott; a `/admin/workouts` sablon-kártya "⋯ → Ütemezés kliensnek" menüpontjából nyitva a sablon adott és kliens-választó jelenik meg).
2. **Ismétlődés** — szegmentált választó: *Egyszeri / Naponta / Heti napokon*; Heti esetén hétköznap-chipek (H K Sze Cs P Szo V, többválasztós).
3. **Dátumok és időpont** — kezdőnap (min: ma); *Egyszeri*-nél nincs zárónap-mező, egyébként zárónap (max: kezdőnap + 3 hónap — a picker ennél tovább nem enged); alatta **„Időpont (opcionális)"** mező (`HH:mm` time picker, üresen hagyható) — a megadott időpont a sorozat minden alkalmára vonatkozik.
4. **Előnézet-sor** — élőben számolt összesítő: „**18 edzés** jön létre (minden hétfő és csütörtök **18:00-kor**, okt. 6-ig)" — időpont nélkül az időrész elmarad. Ha a sablon még nem volt kiosztva ennek a kliensnek → info-sáv: „A sablon másolata létrejön a kliensnél."
5. Láb: „Mégse" + „Ütemezés" (primary; csak érvényes állapotban aktív). Siker: toast „18 edzés ütemezve {név} részére".

Hibaleképezés: 422 → „Legfeljebb 3 hónapra előre ütemezhetsz"; 400 → mezőszintű hibák (Zod és backend összhangban).

### Ütemterv tab (`/admin/clients/[clientId]/schedule`) — design: A frame (állapotok: E frame)

- **Aktív sorozatok** felül, kártyánként: sablon-név, `RecurrenceLabel` (az időpontot is tartalmazza: „Minden hétfő, csüt · 18:00 · júl. 7. – okt. 6."), progressz (✅ 12 elvégzett · ⚠ 3 kihagyott · 21 hátra), „⋯" menü → *Sorozat lemondása* (confirm dialog: „A jövőbeli edzések törlődnek a kliens appjából; az elvégzettek megmaradnak.").
- **Idővonal** alatta: előfordulások **hetekre csoportosítva** (e hét / jövő hét / …), soronként dátum (+ időpont, ha van) + sablon-név + státusz-chip; napon belül időpont szerint rendezve (időpont nélküliek a nap végén):
  - `UPCOMING` — tertiary chip, jövőbeli sorokon lemondás-ikon (egy-előfordulás lemondása, confirmmal);
  - `DONE` — pipa, kattintva a meglévő session-részletre ugrik (Edzések tab nézete);
  - `MISSED` — halvány error chip („kihagyta");
  - `CANCELLED` — áthúzott, halvány (edző mondta le / kliens törölte — a kettő megkülönböztetve tooltipben).
- Múlt/jövő váltó vagy görgetés: alapnézet a mai naptól előre, „Előzmények" szakasz visszafelé nyitható.
- Üres állapot: naptár-ikon + „Még nincs ütemezett edzés" + CTA a drawerre.

### i18n

Új next-intl kulcsok az `admin.schedule.*` névtér alatt (HU/EN).

## Mobil (Flutter)

Elv változatlan: a kliens élménye minimálisan bővül, minden a meglévő sync-re épül — **nincs új API-hívás**.

### 1. Drift séma + sync

- `workout_sessions` drift tábla: + `scheduled_for` (date, nullable), + `scheduled_time` (time/`HH:mm` szöveg, nullable), + `schedule_id` (int, nullable); `started_at` **nullable-re** vált.
- Sync DTO-k ugyanígy bővülnek; push-nál a mezők változatlanul mennek vissza (a szerver úgyis read-only-ként kezeli őket).
- A nullable `started_at` nem igényel kompatibilitás-védelmet — az app még nincs kiadva (lásd 09 §Delta sync hatás); a sémafrissítés a backenddel együtt, normál módon megy ki.

### 2. „Közelgő" kategória (Workouts → Sessions tab) — design: C frame

- A Sessions tab listája kettéválik: felül **„Közelgő"** szekció, alatta a meglévő előzmény.
- Közelgő = lokális query: `started_at is null AND deleted_at is null AND scheduled_for BETWEEN ma AND ma+6` — **a 7 napos ablak itt érvényesül**; a távolabbi (akár 3 havi) sorok a lokális DB-ben vannak, de nem jelennek meg.
- Csoportosítás: **Ma / Holnap / hét további napjai** (nap nevével); napon belül időpont szerint rendezve (időpont nélküliek a nap végén). Sor: sablon-név + „Edzőtől" badge (a meglévő minta: az ütemezett session definíció szerint edzőtől jön) + időpont, ha van („18:00" — kiemelt, hiszen ez az edző által kért idősáv).
- Sor-akciók: **Kezdés** (primary) → a meglévő sablonból-indítás flow, de **ugyanazt a sort** frissíti (`started_at` = most, tervezett gyakorlatok betöltése a sablon-másolatból); **törlés** (swipe/menü, confirm) → meglévő session-törlés (tombstone fel).
- Múltba csúszott, el nem indított sor (kihagyott): a Közelgőből egyszerűen kikerül, az előzményben **nem** jelenik meg (ott csak elvégzett van) — a mobilon a kihagyás nem kap bűntudat-UI-t, az az edző nézetének dolga.

### 3. Felugró kártya (aznapi edzés) — design: D frame

A meghívó-kártya mintájára (lásd `05-mobil-terv.md` §1, `06-design.md` §4), de **lokális adatból** — nincs polling:

- App-indulás / előtérbe kerülés után, ha van **mai** közelgő session és a kártya ma még nem volt eltüntetve → lebegő kártya a bottom nav felett: „**Ma{ 18:00-kor}: {sablon-név}** · {edző neve}" + [Kezdés] [Később] (az időpont-rész csak akkor, ha az edző megadta). **Csak az aznapi edzésre** jelenik meg — jövőbeli napok edzéséhez nincs kártya (eldöntött kérdés).
- „Később" / swipe-dismiss → aznap már nem jön vissza (lokális `dismissedOn` dátum-flag, pl. shared_preferences); másnap az aznapi edzéshez újra megjelenik.
- „Kezdés" → session-indítás flow (mint fent).
- Ha egy napon több edzés van: a kártya az elsőt mutatja + „és még 1" jelzés.
- A meghívó-kártyával ütközés esetén a **meghívó nyer** (ritkább és sürgősebb), az edzés-kártya a következő megnyitáskor jön.

### 4. Ami nem változik

- Navigáció, tabok, offline-first működés; a sima (kliens által indított) sessionök életciklusa.
- Nincs kliens-oldali ütemezés-szerkesztés: a kliens nem tudja átütemezni az edzést (törölni tudja) — átütemezés-kérés v2 ötlet.

### 5. Lokalizáció

Minden új szöveg ARB kulcs (EN + HU) — a Közelgő szekció, a kártya és a confirm dialogok szövegei.

## Ütemterv-illesztés (PT5 fázis)

A `07-utemterv-es-kockazatok.md` fázisai után:

**PT5 — Ütemezett edzések**
1. `V45__workout_schedules.sql` + entity/repo + a `started_at`-audit (statisztika/lista szűrések) + regressziós tesztek.
2. `WorkoutScheduleService` (generálás, materializálás, lemondás, bontás-hook) + controller + tesztek.
3. Web: Ütemterv tab + `ScheduleWorkoutDrawer` + idővonal + sablon-kártya menüpont (design: A/B/E frame).
4. Mobil: drift séma + Közelgő szekció + felugró kártya + indítás-flow (design: C/D frame).

**Kész, ha:** edzőként heti ismétlődő edzést ütemezek 3 hónapra; a kliens mobilján csak a következő 7 nap látszik, az aznapi felugró kártyán elindítja, és az ütemtervemben pipát kap; egy kihagyott nap „kihagyta" jelzést mutat; a sorozat lemondása után a kliens közelgő listája kiürül.

## Kockázatok

| Kockázat | Súly | Ellenszer |
|---|---|---|
| Közelgő sessionök **beszivárognak a statisztikába / előzménybe** | magas | repository-szintű `started_at is not null` szűrés + regressziós tesztek (09 §audit) |
| Nagy sorozat sync-terhelése (92 sor + későbbi tombstone-ok) | alacsony | csak fejléc-sorok (nincs gyermek-materializálás); 100-as cap |
| Edző-írás a kliens fiókjába — szabály-erózió | közepes | a kivétel szűken definiált és dokumentált (08 §kivétel); csak jövőbeli üres sorok, csak guard mögött |
| Kliens törli a sablon-másolatot, a közelgő session „árván" indul | alacsony | `template_name` snapshot; indítás üres sessionként is működik |

A funkció döntés-naplója (minden korábbi nyitott kérdés eldőlt) a `11-utemezett-edzesek-design-prompt.md` végén szerepel.
